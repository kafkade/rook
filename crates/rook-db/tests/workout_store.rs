use std::fs;
use std::io::Write;
use std::path::Path;

use age::secrecy::SecretString;
use rook_core::{Archive, ExerciseDraft, Settings, WeightUnit};
use rook_db::Database;
use tempfile::TempDir;

const PASSPHRASE: &str = "synthetic backup phrase for tests";
const MARKER: &str = "PRIVATE_SYNTHETIC_ROUTINE";

fn database(path: &Path) -> Database {
    Database::open(path, vec![17; 32]).expect("test database must open")
}

fn routine(database: &mut Database) -> String {
    database
        .save_routine(
            None,
            MARKER.into(),
            vec![ExerciseDraft {
                id: None,
                name: "Synthetic press".into(),
                sets: 2,
                reps: 8,
                weight_kg: 60.0,
                rest_seconds: 90,
            }],
        )
        .expect("synthetic routine must save");
    database.archive().expect("read archive").routines[0]
        .id
        .clone()
}

fn encrypted_archive(archive: &Archive) -> Vec<u8> {
    let encryptor = age::Encryptor::with_user_passphrase(SecretString::from(PASSPHRASE.to_owned()));
    let mut output = Vec::new();
    let mut writer = encryptor.wrap_output(&mut output).expect("age writer");
    writer
        .write_all(&serde_json::to_vec(archive).expect("serialize fixture"))
        .expect("write fixture");
    writer.finish().expect("finish age");
    output
}

#[test]
fn encrypted_store_reopens_but_wrong_keys_and_plain_sqlite_cannot_read_it() {
    let directory = TempDir::new().expect("temporary fixture directory");
    let path = directory.path().join("rook.sqlite");
    let mut store = database(&path);
    routine(&mut store);
    let bytes = fs::read(&path).expect("read encrypted fixture");
    assert!(!bytes.starts_with(b"SQLite format 3"));
    assert!(
        !bytes
            .windows(MARKER.len())
            .any(|window| window == MARKER.as_bytes())
    );
    store
        .close()
        .map_err(|(_, error)| error)
        .expect("close store");
    assert!(Database::open(&path, vec![18; 32]).is_err());
    assert_eq!(fs::read(&path).expect("read unchanged fixture"), bytes);
    let plain = rusqlite::Connection::open(&path).expect("SQLite connection");
    assert!(plain.prepare("SELECT * FROM routines").is_err());
    assert_eq!(
        database(&path)
            .archive()
            .expect("reopened archive")
            .routines
            .len(),
        1
    );
}

#[test]
fn invalid_key_length_and_values_do_not_create_successful_records() {
    let directory = TempDir::new().expect("temporary fixture directory");
    let path = directory.path().join("rook.sqlite");
    assert!(Database::open(&path, vec![1; 31]).is_err());
    assert!(!path.exists());
    let mut store = database(&path);
    let routine_id = routine(&mut store);
    store.start_workout(&routine_id).expect("start workout");
    let before = store.archive().expect("archive");
    let id = before.workouts[0].exercises[0].sets[0].id.clone();
    assert!(store.update_set(&id, f64::NAN, 8, Some(true)).is_err());
    assert!(store.update_set(&id, -1.0, 8, Some(true)).is_err());
    assert!(store.update_set(&id, 60.0, 0, Some(true)).is_err());
    assert_eq!(store.archive().expect("archive"), before);
}

#[test]
fn full_workout_loop_preserves_drafts_rest_deadlines_and_historical_snapshots() {
    let directory = TempDir::new().expect("temporary fixture directory");
    let path = directory.path().join("rook.sqlite");
    let mut store = database(&path);
    let routine_id = routine(&mut store);
    store.start_workout(&routine_id).expect("start workout");
    assert!(store.start_workout(&routine_id).is_err());
    assert!(store.finish_workout().is_err());
    let original = store.archive().expect("archive");
    let first = original.workouts[0].exercises[0].sets[0].id.clone();
    store
        .update_set(&first, 62.5, 9, Some(true))
        .expect("complete set");
    let after_set = store.archive().expect("archive");
    assert!(after_set.workouts[0].rest_end_ms.is_some());
    assert_eq!(after_set.workouts[0].volume_kg(), 562.5);
    store
        .close()
        .map_err(|(_, error)| error)
        .expect("close store");
    let mut store = database(&path);
    assert_eq!(store.archive().expect("archive"), after_set);
    store.adjust_rest(30).expect("extend rest");
    store.skip_rest().expect("skip rest");
    assert!(
        store.archive().expect("archive").workouts[0]
            .rest_end_ms
            .is_none()
    );
    store.finish_workout().expect("finish");
    let finished = store.archive().expect("archive").workouts[0].clone();
    assert!(finished.finished_ms.is_some());
    let plan = store.archive().expect("archive").routines[0].exercises[0].clone();
    store
        .save_routine(
            Some(routine_id.clone()),
            "Renamed routine".into(),
            vec![ExerciseDraft {
                id: Some(plan.id),
                name: "Renamed exercise".into(),
                sets: 2,
                reps: 12,
                weight_kg: 30.0,
                rest_seconds: 0,
            }],
        )
        .expect("edit routine");
    assert_eq!(store.archive().expect("archive").workouts[0], finished);
    store.start_workout(&routine_id).expect("restart");
    let active = store
        .archive()
        .expect("archive")
        .workouts
        .into_iter()
        .find(|workout| workout.finished_ms.is_none())
        .expect("active workout");
    assert_eq!(active.exercises[0].sets[0].weight_kg, 62.5);
    assert_eq!(active.exercises[0].sets[0].reps, 9);
    store.delete_routine(&routine_id).expect("delete template");
    assert_eq!(store.archive().expect("archive").workouts.len(), 2);
}

#[test]
fn encrypted_backup_restores_on_a_replacement_device_with_a_different_database_key() {
    let directory = TempDir::new().expect("temporary fixture directory");
    let mut original = database(&directory.path().join("original.sqlite"));
    let id = routine(&mut original);
    original.start_workout(&id).expect("start");
    let set = original.archive().expect("archive").workouts[0].exercises[0].sets[0]
        .id
        .clone();
    original.update_set(&set, 60.0, 8, Some(true)).expect("set");
    original
        .update_settings(Settings {
            unit: WeightUnit::Lb,
            rest_alerts: true,
        })
        .expect("settings");
    let expected = original.archive().expect("archive");
    let backup = original.export_backup(PASSPHRASE.into()).expect("backup");
    assert!(backup.starts_with(b"age-encryption.org/v1"));
    assert!(
        !backup
            .windows(MARKER.len())
            .any(|window| window == MARKER.as_bytes())
    );
    let restored = Database::create_restored(
        &directory.path().join("replacement.sqlite"),
        vec![99; 32],
        backup,
        PASSPHRASE.into(),
    )
    .expect("restore with a different device key");
    assert_eq!(restored.archive().expect("archive"), expected);
}

#[test]
fn wrong_passphrase_tampering_and_unconfirmed_restore_leave_existing_data_unchanged() {
    let directory = TempDir::new().expect("temporary fixture directory");
    let mut store = database(&directory.path().join("rook.sqlite"));
    routine(&mut store);
    let before = store.archive().expect("archive");
    let backup = store.export_backup(PASSPHRASE.into()).expect("backup");
    assert!(
        store
            .restore_backup(backup.clone(), PASSPHRASE.into(), false)
            .is_err()
    );
    assert!(
        store
            .restore_backup(backup.clone(), "wrong synthetic passphrase".into(), true)
            .is_err()
    );
    let mut tampered = backup;
    let last = tampered.last_mut().expect("nonempty age fixture");
    *last ^= 1;
    assert!(
        store
            .restore_backup(tampered, PASSPHRASE.into(), true)
            .is_err()
    );
    assert_eq!(store.archive().expect("archive"), before);
}

#[test]
fn unsupported_or_invalid_backup_is_rejected_before_replacement_or_file_creation() {
    let directory = TempDir::new().expect("temporary fixture directory");
    let mut store = database(&directory.path().join("rook.sqlite"));
    let id = routine(&mut store);
    store.start_workout(&id).expect("start");
    let before = store.archive().expect("archive");
    let mut invalid = before.clone();
    invalid.version = 2;
    let ciphertext = encrypted_archive(&invalid);
    assert!(
        store
            .restore_backup(ciphertext.clone(), PASSPHRASE.into(), true)
            .is_err()
    );
    let path = directory.path().join("should-not-exist.sqlite");
    assert!(Database::create_restored(&path, vec![1; 32], ciphertext, PASSPHRASE.into()).is_err());
    assert!(!path.exists());
    invalid.version = 1;
    invalid.workouts.push(invalid.workouts[0].clone());
    assert!(
        store
            .restore_backup(encrypted_archive(&invalid), PASSPHRASE.into(), true)
            .is_err()
    );
    assert_eq!(store.archive().expect("archive"), before);
}

#[test]
fn encrypted_journal_does_not_contain_workout_text() {
    let directory = TempDir::new().expect("temporary fixture directory");
    let path = directory.path().join("rook.sqlite");
    let mut store = database(&path);
    routine(&mut store);
    let connection = rusqlite::Connection::open(&path).expect("fixture connection");
    connection
        .pragma_update(None, "key", format!("x'{}'", "11".repeat(32)))
        .expect("set synthetic key");
    connection
        .execute_batch("BEGIN IMMEDIATE; UPDATE routines SET body = body || ' ';")
        .expect("open transaction");
    let journal = fs::read(directory.path().join("rook.sqlite-journal")).expect("journal exists");
    assert!(
        !journal
            .windows(MARKER.len())
            .any(|window| window == MARKER.as_bytes())
    );
    connection.execute_batch("ROLLBACK").expect("rollback");
}
