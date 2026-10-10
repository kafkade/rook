use std::fs::OpenOptions;
use std::io::{Read, Write};
use std::path::Path;
use std::time::Duration;

use age::secrecy::SecretString;
use chrono::Utc;
use rook_core::{
    Archive, ExerciseDraft, MAX_SETS, Routine, Settings, ValidationError, Workout, WorkoutSet,
    new_id, validate_id, validate_values,
};
use rusqlite::{Connection, OpenFlags, OptionalExtension, params};
use thiserror::Error;
use zeroize::Zeroizing;

pub const MAX_BACKUP_BYTES: usize = 64 * 1024 * 1024;

#[derive(Debug, Error)]
pub enum DataError {
    #[error("{0}")]
    Invalid(#[from] ValidationError),
    #[error("Storage could not complete the operation: {0}")]
    Sql(#[from] rusqlite::Error),
    #[error("The stored record or backup format is invalid: {0}")]
    Json(#[from] serde_json::Error),
    #[error("The backup file could not be read or written: {0}")]
    Io(#[from] std::io::Error),
    #[error("{0}")]
    State(String),
    #[error("Backup encryption or decryption failed. Check the passphrase and file integrity.")]
    Crypto,
}

pub struct Database {
    connection: Connection,
}

impl Database {
    pub fn open(path: &Path, key: Vec<u8>) -> Result<Self, DataError> {
        let key = Zeroizing::new(key);
        if key.len() != 32 {
            return Err(DataError::State("A 32-byte device key is required.".into()));
        }
        let connection = Connection::open_with_flags(
            path,
            OpenFlags::SQLITE_OPEN_READ_WRITE
                | OpenFlags::SQLITE_OPEN_CREATE
                | OpenFlags::SQLITE_OPEN_FULL_MUTEX,
        )?;
        let version: Option<String> = connection
            .query_row("PRAGMA cipher_version", [], |row| row.get(0))
            .optional()?;
        if version.is_none_or(|version| version.is_empty()) {
            return Err(DataError::State(
                "SQLCipher is unavailable. Rook will not open an unencrypted store.".into(),
            ));
        }
        let encoded = Zeroizing::new(
            key.iter()
                .map(|byte| format!("{byte:02x}"))
                .collect::<String>(),
        );
        let raw_key = Zeroizing::new(format!("x'{}'", encoded.as_str()));
        connection.pragma_update(None, "key", raw_key.as_str())?;
        // Read before any schema writes: a wrong key must not initialize or reset a store.
        connection.query_row("SELECT count(*) FROM sqlite_master", [], |row| {
            row.get::<_, i64>(0)
        })?;
        connection.busy_timeout(Duration::from_secs(3))?;
        connection.execute_batch(
            "PRAGMA foreign_keys = ON;
             PRAGMA temp_store = MEMORY;
             PRAGMA journal_mode = DELETE;
             PRAGMA synchronous = FULL;",
        )?;
        let schema: u32 = connection.query_row("PRAGMA user_version", [], |row| row.get(0))?;
        match schema {
            0 => connection.execute_batch(
                "BEGIN IMMEDIATE;
                 CREATE TABLE routines (id TEXT PRIMARY KEY, body TEXT NOT NULL);
                 CREATE TABLE workouts (
                    id TEXT PRIMARY KEY,
                    started_ms INTEGER NOT NULL,
                    finished_ms INTEGER,
                    body TEXT NOT NULL
                 );
                 CREATE UNIQUE INDEX one_active_workout ON workouts((1))
                    WHERE finished_ms IS NULL;
                 CREATE TABLE settings (id INTEGER PRIMARY KEY CHECK(id = 1), body TEXT NOT NULL);
                 INSERT INTO settings VALUES (1, '{\"unit\":\"Kg\",\"rest_alerts\":false}');
                 PRAGMA user_version = 1;
                 COMMIT;",
            )?,
            1 => {}
            _ => {
                return Err(DataError::State(
                    "This database was created by a newer Rook version.".into(),
                ));
            }
        }
        Ok(Self { connection })
    }

    pub fn close(self) -> Result<(), (Self, DataError)> {
        self.connection
            .close()
            .map_err(|(connection, error)| (Self { connection }, DataError::Sql(error)))
    }

    pub fn archive(&self) -> Result<Archive, DataError> {
        let settings_json: String =
            self.connection
                .query_row("SELECT body FROM settings WHERE id = 1", [], |row| {
                    row.get(0)
                })?;
        let mut routine_statement = self
            .connection
            .prepare("SELECT body FROM routines ORDER BY id")?;
        let routines = routine_statement
            .query_map([], |row| row.get::<_, String>(0))?
            .map(|row| Ok(serde_json::from_str(&row?)?))
            .collect::<Result<Vec<Routine>, DataError>>()?;
        let mut workout_statement = self
            .connection
            .prepare("SELECT body FROM workouts ORDER BY started_ms DESC, id")?;
        let workouts = workout_statement
            .query_map([], |row| row.get::<_, String>(0))?
            .map(|row| Ok(serde_json::from_str(&row?)?))
            .collect::<Result<Vec<Workout>, DataError>>()?;
        let archive = Archive {
            version: 1,
            settings: serde_json::from_str(&settings_json)?,
            routines,
            workouts,
        };
        archive.validate()?;
        Ok(archive)
    }

    pub fn save_routine(
        &mut self,
        id: Option<String>,
        name: String,
        exercises: Vec<ExerciseDraft>,
    ) -> Result<(), DataError> {
        let state = self.archive()?;
        if let Some(id) = &id {
            let previous = state
                .routines
                .iter()
                .find(|routine| &routine.id == id)
                .ok_or_else(|| DataError::State("The routine no longer exists.".into()))?;
            for exercise in &exercises {
                if let Some(exercise_id) = &exercise.id
                    && !previous
                        .exercises
                        .iter()
                        .any(|item| &item.id == exercise_id)
                {
                    return Err(DataError::State(
                        "An exercise identifier does not belong to this routine.".into(),
                    ));
                }
            }
        } else if exercises.iter().any(|exercise| exercise.id.is_some()) {
            return Err(DataError::State(
                "New routines must use new exercise identifiers.".into(),
            ));
        }
        let routine = Routine::from_draft(id, name, exercises)?;
        self.connection.execute(
            "INSERT INTO routines (id, body) VALUES (?1, ?2)
             ON CONFLICT(id) DO UPDATE SET body = excluded.body",
            params![routine.id, serde_json::to_string(&routine)?],
        )?;
        Ok(())
    }

    pub fn delete_routine(&mut self, id: &str) -> Result<(), DataError> {
        validate_id(id)?;
        let count = self
            .connection
            .execute("DELETE FROM routines WHERE id = ?1", [id])?;
        if count == 0 {
            return Err(DataError::State("The routine no longer exists.".into()));
        }
        Ok(())
    }

    pub fn start_workout(&mut self, routine_id: &str) -> Result<(), DataError> {
        let state = self.archive()?;
        if state
            .workouts
            .iter()
            .any(|workout| workout.finished_ms.is_none())
        {
            return Err(DataError::State(
                "Resume or discard the current workout before starting another.".into(),
            ));
        }
        let routine = state
            .routines
            .iter()
            .find(|routine| routine.id == routine_id)
            .ok_or_else(|| DataError::State("The routine no longer exists.".into()))?;
        let previous = state
            .workouts
            .iter()
            .find(|workout| workout.routine_id == routine_id);
        let workout = Workout::from_routine(routine, Utc::now().timestamp_millis(), previous);
        self.store_workout(&workout)
    }

    fn active(&self) -> Result<Workout, DataError> {
        self.archive()?
            .workouts
            .into_iter()
            .find(|workout| workout.finished_ms.is_none())
            .ok_or_else(|| DataError::State("No active workout. Start a routine first.".into()))
    }

    fn store_workout(&mut self, workout: &Workout) -> Result<(), DataError> {
        workout.validate()?;
        self.connection.execute(
            "INSERT INTO workouts (id, started_ms, finished_ms, body) VALUES (?1, ?2, ?3, ?4)
             ON CONFLICT(id) DO UPDATE SET finished_ms = excluded.finished_ms, body = excluded.body",
            params![
                workout.id,
                workout.started_ms,
                workout.finished_ms,
                serde_json::to_string(workout)?
            ],
        )?;
        Ok(())
    }

    pub fn update_set(
        &mut self,
        set_id: &str,
        weight_kg: f64,
        reps: u32,
        completed: Option<bool>,
    ) -> Result<(), DataError> {
        validate_values(weight_kg, reps)?;
        let mut workout = self.active()?;
        let mut found = false;
        for exercise in &mut workout.exercises {
            if let Some(set) = exercise.sets.iter_mut().find(|set| set.id == set_id) {
                set.weight_kg = weight_kg;
                set.reps = reps;
                if let Some(value) = completed {
                    let newly_completed = value && !set.completed;
                    set.completed = value;
                    if newly_completed {
                        workout.rest_end_ms = if exercise.rest_seconds == 0 {
                            None
                        } else {
                            Some(
                                Utc::now().timestamp_millis()
                                    + i64::from(exercise.rest_seconds) * 1_000,
                            )
                        };
                    }
                }
                found = true;
                break;
            }
        }
        if !found {
            return Err(DataError::State("The set no longer exists.".into()));
        }
        self.store_workout(&workout)
    }

    pub fn add_set(&mut self, exercise_id: &str) -> Result<(), DataError> {
        let mut workout = self.active()?;
        let exercise = workout
            .exercises
            .iter_mut()
            .find(|exercise| exercise.id == exercise_id)
            .ok_or_else(|| DataError::State("The exercise no longer exists.".into()))?;
        if exercise.sets.len() >= MAX_SETS as usize {
            return Err(DataError::State(
                "This exercise already has 100 sets.".into(),
            ));
        }
        let previous = exercise
            .sets
            .last()
            .ok_or_else(|| DataError::State("The exercise has no valid sets.".into()))?;
        exercise.sets.push(WorkoutSet {
            id: new_id(),
            weight_kg: previous.weight_kg,
            reps: previous.reps,
            completed: false,
        });
        self.store_workout(&workout)
    }

    pub fn set_completed(&mut self, set_id: &str, completed: bool) -> Result<(), DataError> {
        let workout = self.active()?;
        let set = workout
            .exercises
            .iter()
            .flat_map(|exercise| &exercise.sets)
            .find(|set| set.id == set_id)
            .ok_or_else(|| DataError::State("The set no longer exists.".into()))?;
        self.update_set(set_id, set.weight_kg, set.reps, Some(completed))
    }

    pub fn remove_set(&mut self, set_id: &str) -> Result<(), DataError> {
        let mut workout = self.active()?;
        let exercise = workout
            .exercises
            .iter_mut()
            .find(|exercise| exercise.sets.iter().any(|set| set.id == set_id))
            .ok_or_else(|| DataError::State("The set no longer exists.".into()))?;
        if exercise.sets.len() == 1 {
            return Err(DataError::State(
                "Keep at least one set per exercise.".into(),
            ));
        }
        exercise.sets.retain(|set| set.id != set_id);
        self.store_workout(&workout)
    }

    pub fn adjust_rest(&mut self, additional_seconds: u32) -> Result<(), DataError> {
        let mut workout = self.active()?;
        let now = Utc::now().timestamp_millis();
        let end =
            workout.rest_end_ms.unwrap_or(now).max(now) + i64::from(additional_seconds) * 1_000;
        if end - now > 3_600_000 {
            return Err(DataError::State("Rest cannot exceed 60 minutes.".into()));
        }
        workout.rest_end_ms = Some(end);
        self.store_workout(&workout)
    }

    pub fn skip_rest(&mut self) -> Result<(), DataError> {
        let mut workout = self.active()?;
        workout.rest_end_ms = None;
        self.store_workout(&workout)
    }

    pub fn finish_workout(&mut self) -> Result<(), DataError> {
        let mut workout = self.active()?;
        if workout.completed_sets() == 0 {
            return Err(DataError::State(
                "Complete at least one set before saving a workout.".into(),
            ));
        }
        workout.finished_ms = Some(Utc::now().timestamp_millis());
        workout.rest_end_ms = None;
        self.store_workout(&workout)
    }

    pub fn discard_workout(&mut self) -> Result<(), DataError> {
        let workout = self.active()?;
        self.connection
            .execute("DELETE FROM workouts WHERE id = ?1", [workout.id])?;
        Ok(())
    }

    pub fn delete_workout(&mut self, id: &str) -> Result<(), DataError> {
        validate_id(id)?;
        let count = self.connection.execute(
            "DELETE FROM workouts WHERE id = ?1 AND finished_ms IS NOT NULL",
            [id],
        )?;
        if count == 0 {
            return Err(DataError::State(
                "The completed workout no longer exists.".into(),
            ));
        }
        Ok(())
    }

    pub fn update_settings(&mut self, settings: Settings) -> Result<(), DataError> {
        self.connection.execute(
            "UPDATE settings SET body = ?1 WHERE id = 1",
            [serde_json::to_string(&settings)?],
        )?;
        Ok(())
    }

    pub fn export_backup(&self, passphrase: String) -> Result<Vec<u8>, DataError> {
        validate_passphrase(&passphrase)?;
        let plaintext = Zeroizing::new(serde_json::to_vec(&self.archive()?)?);
        if plaintext.len() > MAX_BACKUP_BYTES {
            return Err(DataError::State(
                "The backup exceeds the prototype's 64 MiB limit.".into(),
            ));
        }
        let encryptor = age::Encryptor::with_user_passphrase(SecretString::from(passphrase));
        let mut ciphertext = Vec::new();
        let mut writer = encryptor
            .wrap_output(&mut ciphertext)
            .map_err(|_| DataError::Crypto)?;
        writer.write_all(&plaintext)?;
        writer.finish().map_err(|_| DataError::Crypto)?;
        Ok(ciphertext)
    }

    pub fn restore_backup(
        &mut self,
        ciphertext: Vec<u8>,
        passphrase: String,
        confirmed: bool,
    ) -> Result<(), DataError> {
        if !confirmed {
            return Err(DataError::State(
                "Confirm replacement before restoring a backup.".into(),
            ));
        }
        let archive = decrypt_backup(&ciphertext, passphrase)?;
        self.replace_archive(&archive)
    }

    pub fn create_restored(
        path: &Path,
        key: Vec<u8>,
        ciphertext: Vec<u8>,
        passphrase: String,
    ) -> Result<Self, DataError> {
        let archive = decrypt_backup(&ciphertext, passphrase)?;
        let file = OpenOptions::new().write(true).create_new(true).open(path)?;
        drop(file);
        let mut database = Self::open(path, key)?;
        database.replace_archive(&archive)?;
        Ok(database)
    }

    fn replace_archive(&mut self, archive: &Archive) -> Result<(), DataError> {
        archive.validate()?;
        let transaction = self.connection.transaction()?;
        transaction.execute("DELETE FROM routines", [])?;
        transaction.execute("DELETE FROM workouts", [])?;
        transaction.execute(
            "UPDATE settings SET body = ?1 WHERE id = 1",
            [serde_json::to_string(&archive.settings)?],
        )?;
        for routine in &archive.routines {
            transaction.execute(
                "INSERT INTO routines (id, body) VALUES (?1, ?2)",
                params![routine.id, serde_json::to_string(routine)?],
            )?;
        }
        for workout in &archive.workouts {
            transaction.execute(
                "INSERT INTO workouts (id, started_ms, finished_ms, body) VALUES (?1, ?2, ?3, ?4)",
                params![
                    workout.id,
                    workout.started_ms,
                    workout.finished_ms,
                    serde_json::to_string(workout)?
                ],
            )?;
        }
        transaction.commit()?;
        Ok(())
    }
}

fn validate_passphrase(passphrase: &str) -> Result<(), DataError> {
    if passphrase.chars().count() < 12 {
        return Err(DataError::State(
            "Use at least 12 characters for the backup passphrase; several random words are better."
                .into(),
        ));
    }
    Ok(())
}

pub fn decrypt_backup(ciphertext: &[u8], passphrase: String) -> Result<Archive, DataError> {
    if ciphertext.len() > MAX_BACKUP_BYTES + 1024 * 1024 {
        return Err(DataError::State(
            "The backup exceeds the prototype's size limit.".into(),
        ));
    }
    let decryptor = age::Decryptor::new_buffered(ciphertext).map_err(|_| DataError::Crypto)?;
    if !decryptor.is_scrypt() {
        return Err(DataError::State(
            "Choose a passphrase-encrypted Rook backup.".into(),
        ));
    }
    let mut identity = age::scrypt::Identity::new(SecretString::from(passphrase));
    identity.set_max_work_factor(20);
    let mut reader = decryptor
        .decrypt(std::iter::once(&identity as &dyn age::Identity))
        .map_err(|_| DataError::Crypto)?
        .take((MAX_BACKUP_BYTES + 1) as u64);
    let mut plaintext = Zeroizing::new(Vec::new());
    reader
        .read_to_end(&mut plaintext)
        .map_err(|_| DataError::Crypto)?;
    if plaintext.len() > MAX_BACKUP_BYTES {
        return Err(DataError::State(
            "The decrypted backup exceeds the prototype's size limit.".into(),
        ));
    }
    let archive: Archive = serde_json::from_slice(&plaintext)?;
    archive.validate()?;
    Ok(archive)
}
