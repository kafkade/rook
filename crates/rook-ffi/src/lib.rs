use std::path::Path;
use std::sync::{Arc, Mutex};

use rook_core as core;
use rook_db::{DataError, Database};
use thiserror::Error;

uniffi::setup_scaffolding!();

#[derive(Debug, Error, uniffi::Error)]
pub enum RookError {
    #[error("{message}")]
    Operation { message: String },
}

impl From<DataError> for RookError {
    fn from(error: DataError) -> Self {
        Self::Operation {
            message: error.to_string(),
        }
    }
}

#[derive(Clone, Copy, uniffi::Enum)]
pub enum WeightUnit {
    Kg,
    Lb,
}

impl From<WeightUnit> for core::WeightUnit {
    fn from(value: WeightUnit) -> Self {
        match value {
            WeightUnit::Kg => Self::Kg,
            WeightUnit::Lb => Self::Lb,
        }
    }
}

impl From<core::WeightUnit> for WeightUnit {
    fn from(value: core::WeightUnit) -> Self {
        match value {
            core::WeightUnit::Kg => Self::Kg,
            core::WeightUnit::Lb => Self::Lb,
        }
    }
}

#[derive(uniffi::Record)]
pub struct ExerciseDraft {
    pub id: Option<String>,
    pub name: String,
    pub sets: u32,
    pub reps: u32,
    pub weight_kg: f64,
    pub rest_seconds: u32,
}

#[derive(uniffi::Record)]
pub struct ExercisePlan {
    pub id: String,
    pub name: String,
    pub sets: u32,
    pub reps: u32,
    pub weight_kg: f64,
    pub rest_seconds: u32,
}

#[derive(uniffi::Record)]
pub struct Routine {
    pub id: String,
    pub name: String,
    pub exercises: Vec<ExercisePlan>,
}

#[derive(uniffi::Record)]
pub struct WorkoutSet {
    pub id: String,
    pub weight_kg: f64,
    pub reps: u32,
    pub completed: bool,
}

#[derive(uniffi::Record)]
pub struct WorkoutExercise {
    pub id: String,
    pub template_id: String,
    pub name: String,
    pub rest_seconds: u32,
    pub sets: Vec<WorkoutSet>,
}

#[derive(uniffi::Record)]
pub struct Workout {
    pub id: String,
    pub routine_id: String,
    pub routine_name: String,
    pub started_ms: i64,
    pub finished_ms: Option<i64>,
    pub rest_end_ms: Option<i64>,
    pub exercises: Vec<WorkoutExercise>,
    pub completed_sets: u32,
    pub volume_kg: f64,
}

#[derive(uniffi::Record)]
pub struct Snapshot {
    pub unit: WeightUnit,
    pub rest_alerts: bool,
    pub routines: Vec<Routine>,
    pub history: Vec<Workout>,
    pub active: Option<Workout>,
}

impl From<core::Routine> for Routine {
    fn from(value: core::Routine) -> Self {
        Self {
            id: value.id,
            name: value.name,
            exercises: value
                .exercises
                .into_iter()
                .map(|exercise| ExercisePlan {
                    id: exercise.id,
                    name: exercise.name,
                    sets: exercise.sets,
                    reps: exercise.reps,
                    weight_kg: exercise.weight_kg,
                    rest_seconds: exercise.rest_seconds,
                })
                .collect(),
        }
    }
}

impl From<core::Workout> for Workout {
    fn from(value: core::Workout) -> Self {
        let completed_sets = value.completed_sets();
        let volume_kg = value.volume_kg();
        Self {
            id: value.id,
            routine_id: value.routine_id,
            routine_name: value.routine_name,
            started_ms: value.started_ms,
            finished_ms: value.finished_ms,
            rest_end_ms: value.rest_end_ms,
            completed_sets,
            volume_kg,
            exercises: value
                .exercises
                .into_iter()
                .map(|exercise| WorkoutExercise {
                    id: exercise.id,
                    template_id: exercise.template_id,
                    name: exercise.name,
                    rest_seconds: exercise.rest_seconds,
                    sets: exercise
                        .sets
                        .into_iter()
                        .map(|set| WorkoutSet {
                            id: set.id,
                            weight_kg: set.weight_kg,
                            reps: set.reps,
                            completed: set.completed,
                        })
                        .collect(),
                })
                .collect(),
        }
    }
}

fn snapshot(database: &Database) -> Result<Snapshot, RookError> {
    let archive = database.archive()?;
    let mut history = Vec::new();
    let mut active = None;
    for workout in archive.workouts {
        if workout.finished_ms.is_some() {
            history.push(workout.into());
        } else {
            active = Some(workout.into());
        }
    }
    let mut routines: Vec<Routine> = archive.routines.into_iter().map(Into::into).collect();
    routines.sort_by_key(|routine| routine.name.to_lowercase());
    Ok(Snapshot {
        unit: archive.settings.unit.into(),
        rest_alerts: archive.settings.rest_alerts,
        routines,
        history,
        active,
    })
}

#[derive(uniffi::Object)]
pub struct RookEngine {
    database: Mutex<Option<Database>>,
}

impl RookEngine {
    fn with_database<T>(
        &self,
        operation: impl FnOnce(&mut Database) -> Result<T, RookError>,
    ) -> Result<T, RookError> {
        let mut guard = self.database.lock().map_err(|_| RookError::Operation {
            message: "The database worker failed. Close and reopen Rook.".into(),
        })?;
        let database = guard.as_mut().ok_or_else(|| RookError::Operation {
            message: "Rook is locked. Unlock the device and reopen the app.".into(),
        })?;
        operation(database)
    }
}

#[uniffi::export]
impl RookEngine {
    #[uniffi::constructor]
    pub fn new(path: String, key: Vec<u8>) -> Result<Arc<Self>, RookError> {
        Ok(Arc::new(Self {
            database: Mutex::new(Some(Database::open(Path::new(&path), key)?)),
        }))
    }

    #[uniffi::constructor]
    pub fn create_restored(
        path: String,
        key: Vec<u8>,
        ciphertext: Vec<u8>,
        passphrase: String,
    ) -> Result<Arc<Self>, RookError> {
        Ok(Arc::new(Self {
            database: Mutex::new(Some(Database::create_restored(
                Path::new(&path),
                key,
                ciphertext,
                passphrase,
            )?)),
        }))
    }

    pub fn read_snapshot(&self) -> Result<Snapshot, RookError> {
        self.with_database(|database| snapshot(database))
    }

    pub fn close(&self) -> Result<(), RookError> {
        let mut guard = self.database.lock().map_err(|_| RookError::Operation {
            message: "The database worker failed. Close and reopen Rook.".into(),
        })?;
        if let Some(database) = guard.take()
            && let Err((database, error)) = database.close()
        {
            *guard = Some(database);
            return Err(error.into());
        }
        Ok(())
    }

    pub fn save_routine(
        &self,
        id: Option<String>,
        name: String,
        exercises: Vec<ExerciseDraft>,
    ) -> Result<Snapshot, RookError> {
        self.with_database(|database| {
            database.save_routine(
                id,
                name,
                exercises
                    .into_iter()
                    .map(|exercise| core::ExerciseDraft {
                        id: exercise.id,
                        name: exercise.name,
                        sets: exercise.sets,
                        reps: exercise.reps,
                        weight_kg: exercise.weight_kg,
                        rest_seconds: exercise.rest_seconds,
                    })
                    .collect(),
            )?;
            snapshot(database)
        })
    }

    pub fn delete_routine(&self, id: String) -> Result<Snapshot, RookError> {
        self.with_database(|database| {
            database.delete_routine(&id)?;
            snapshot(database)
        })
    }

    pub fn start_workout(&self, routine_id: String) -> Result<Snapshot, RookError> {
        self.with_database(|database| {
            database.start_workout(&routine_id)?;
            snapshot(database)
        })
    }

    pub fn update_set(
        &self,
        set_id: String,
        weight: f64,
        unit: WeightUnit,
        reps: u32,
        completed: Option<bool>,
    ) -> Result<Snapshot, RookError> {
        self.with_database(|database| {
            database.update_set(
                &set_id,
                core::WeightUnit::from(unit).to_kg(weight),
                reps,
                completed,
            )?;
            snapshot(database)
        })
    }

    pub fn add_set(&self, exercise_id: String) -> Result<Snapshot, RookError> {
        self.with_database(|database| {
            database.add_set(&exercise_id)?;
            snapshot(database)
        })
    }

    pub fn set_completed(&self, set_id: String, completed: bool) -> Result<Snapshot, RookError> {
        self.with_database(|database| {
            database.set_completed(&set_id, completed)?;
            snapshot(database)
        })
    }

    pub fn remove_set(&self, set_id: String) -> Result<Snapshot, RookError> {
        self.with_database(|database| {
            database.remove_set(&set_id)?;
            snapshot(database)
        })
    }

    pub fn adjust_rest(&self, additional_seconds: u32) -> Result<Snapshot, RookError> {
        self.with_database(|database| {
            database.adjust_rest(additional_seconds)?;
            snapshot(database)
        })
    }

    pub fn skip_rest(&self) -> Result<Snapshot, RookError> {
        self.with_database(|database| {
            database.skip_rest()?;
            snapshot(database)
        })
    }

    pub fn finish_workout(&self) -> Result<Snapshot, RookError> {
        self.with_database(|database| {
            database.finish_workout()?;
            snapshot(database)
        })
    }

    pub fn discard_workout(&self) -> Result<Snapshot, RookError> {
        self.with_database(|database| {
            database.discard_workout()?;
            snapshot(database)
        })
    }

    pub fn delete_workout(&self, id: String) -> Result<Snapshot, RookError> {
        self.with_database(|database| {
            database.delete_workout(&id)?;
            snapshot(database)
        })
    }

    pub fn update_settings(
        &self,
        unit: WeightUnit,
        rest_alerts: bool,
    ) -> Result<Snapshot, RookError> {
        self.with_database(|database| {
            database.update_settings(core::Settings {
                unit: unit.into(),
                rest_alerts,
            })?;
            snapshot(database)
        })
    }

    pub fn export_backup(&self, passphrase: String) -> Result<Vec<u8>, RookError> {
        self.with_database(|database| Ok(database.export_backup(passphrase)?))
    }

    pub fn restore_backup(
        &self,
        ciphertext: Vec<u8>,
        passphrase: String,
        confirmed: bool,
    ) -> Result<Snapshot, RookError> {
        self.with_database(|database| {
            database.restore_backup(ciphertext, passphrase, confirmed)?;
            snapshot(database)
        })
    }
}

#[uniffi::export]
pub fn display_weight(weight_kg: f64, unit: WeightUnit) -> Result<f64, RookError> {
    core::validate_values(weight_kg, 1).map_err(|error| RookError::Operation {
        message: error.to_string(),
    })?;
    let displayed = core::WeightUnit::from(unit).from_kg(weight_kg);
    if !displayed.is_finite() {
        return Err(RookError::Operation {
            message: "This value cannot be represented in the selected unit.".into(),
        });
    }
    Ok(displayed)
}

#[uniffi::export]
pub fn canonical_weight(weight: f64, unit: WeightUnit) -> Result<f64, RookError> {
    let kg = core::WeightUnit::from(unit).to_kg(weight);
    core::validate_values(kg, 1).map_err(|error| RookError::Operation {
        message: error.to_string(),
    })?;
    Ok(kg)
}
