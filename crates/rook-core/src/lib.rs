use std::collections::HashSet;

use serde::{Deserialize, Serialize};
use thiserror::Error;
use uuid::Uuid;

pub const MAX_EXERCISES: usize = 50;
pub const MAX_SETS: u32 = 100;
pub const MAX_REST_SECONDS: u32 = 3_600;
pub const KG_PER_POUND: f64 = 0.453_592_37;

#[derive(Debug, Error)]
#[error("{0}")]
pub struct ValidationError(pub String);

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum WeightUnit {
    Kg,
    Lb,
}

impl WeightUnit {
    pub fn to_kg(self, value: f64) -> f64 {
        match self {
            Self::Kg => value,
            Self::Lb => value * KG_PER_POUND,
        }
    }

    pub fn from_kg(self, value: f64) -> f64 {
        match self {
            Self::Kg => value,
            Self::Lb => value / KG_PER_POUND,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Settings {
    pub unit: WeightUnit,
    pub rest_alerts: bool,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            unit: WeightUnit::Kg,
            rest_alerts: false,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ExercisePlan {
    pub id: String,
    pub name: String,
    pub sets: u32,
    pub reps: u32,
    pub weight_kg: f64,
    pub rest_seconds: u32,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Routine {
    pub id: String,
    pub name: String,
    pub exercises: Vec<ExercisePlan>,
}

#[derive(Debug, Clone)]
pub struct ExerciseDraft {
    pub id: Option<String>,
    pub name: String,
    pub sets: u32,
    pub reps: u32,
    pub weight_kg: f64,
    pub rest_seconds: u32,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct WorkoutSet {
    pub id: String,
    pub weight_kg: f64,
    pub reps: u32,
    pub completed: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct WorkoutExercise {
    pub id: String,
    pub template_id: String,
    pub name: String,
    pub rest_seconds: u32,
    pub sets: Vec<WorkoutSet>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Workout {
    pub id: String,
    pub routine_id: String,
    pub routine_name: String,
    pub started_ms: i64,
    pub finished_ms: Option<i64>,
    pub rest_end_ms: Option<i64>,
    pub exercises: Vec<WorkoutExercise>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Archive {
    pub version: u32,
    pub settings: Settings,
    pub routines: Vec<Routine>,
    pub workouts: Vec<Workout>,
}

pub fn new_id() -> String {
    Uuid::new_v4().to_string()
}

fn require(condition: bool, message: &str) -> Result<(), ValidationError> {
    if condition {
        Ok(())
    } else {
        Err(ValidationError(message.to_owned()))
    }
}

pub fn validate_id(id: &str) -> Result<(), ValidationError> {
    require(
        Uuid::try_parse(id).is_ok_and(|uuid| uuid.to_string() == id && !uuid.is_nil()),
        "A record has an invalid identifier.",
    )
}

pub fn validate_name(name: &str) -> Result<(), ValidationError> {
    require(
        !name.trim().is_empty() && name.chars().count() <= 120,
        "Names must contain between 1 and 120 characters.",
    )
}

pub fn validate_values(weight_kg: f64, reps: u32) -> Result<(), ValidationError> {
    require(
        weight_kg.is_finite()
            && weight_kg >= 0.0
            && reps > 0
            && (weight_kg * f64::from(reps)).is_finite(),
        "Enter a finite, non-negative weight and at least one repetition.",
    )
}

pub fn validate_rest(seconds: u32) -> Result<(), ValidationError> {
    require(
        seconds <= MAX_REST_SECONDS,
        "Rest must be between zero and 60 minutes.",
    )
}

fn unique_id(id: &str, ids: &mut HashSet<String>) -> Result<(), ValidationError> {
    validate_id(id)?;
    require(ids.insert(id.to_owned()), "Duplicate record identifiers.")
}

impl Routine {
    pub fn from_draft(
        id: Option<String>,
        name: String,
        exercises: Vec<ExerciseDraft>,
    ) -> Result<Self, ValidationError> {
        let routine = Self {
            id: id.unwrap_or_else(new_id),
            name: name.trim().to_owned(),
            exercises: exercises
                .into_iter()
                .map(|exercise| ExercisePlan {
                    id: exercise.id.unwrap_or_else(new_id),
                    name: exercise.name.trim().to_owned(),
                    sets: exercise.sets,
                    reps: exercise.reps,
                    weight_kg: exercise.weight_kg,
                    rest_seconds: exercise.rest_seconds,
                })
                .collect(),
        };
        routine.validate()?;
        Ok(routine)
    }

    pub fn validate(&self) -> Result<(), ValidationError> {
        validate_id(&self.id)?;
        validate_name(&self.name)?;
        require(
            !self.exercises.is_empty() && self.exercises.len() <= MAX_EXERCISES,
            "A routine must have between 1 and 50 exercises.",
        )?;
        let mut ids = HashSet::new();
        for exercise in &self.exercises {
            unique_id(&exercise.id, &mut ids)?;
            validate_name(&exercise.name)?;
            validate_values(exercise.weight_kg, exercise.reps)?;
            validate_rest(exercise.rest_seconds)?;
            require(
                (1..=MAX_SETS).contains(&exercise.sets),
                "An exercise must have between 1 and 100 planned sets.",
            )?;
        }
        Ok(())
    }
}

impl Workout {
    pub fn from_routine(routine: &Routine, started_ms: i64, previous: Option<&Self>) -> Self {
        Self {
            id: new_id(),
            routine_id: routine.id.clone(),
            routine_name: routine.name.clone(),
            started_ms,
            finished_ms: None,
            rest_end_ms: None,
            exercises: routine
                .exercises
                .iter()
                .map(|plan| {
                    let earlier = previous.and_then(|workout| {
                        workout
                            .exercises
                            .iter()
                            .find(|exercise| exercise.template_id == plan.id)
                    });
                    WorkoutExercise {
                        id: new_id(),
                        template_id: plan.id.clone(),
                        name: plan.name.clone(),
                        rest_seconds: plan.rest_seconds,
                        sets: (0..plan.sets)
                            .map(|index| {
                                let last = earlier
                                    .and_then(|exercise| exercise.sets.get(index as usize))
                                    .filter(|set| set.completed);
                                WorkoutSet {
                                    id: new_id(),
                                    weight_kg: last.map_or(plan.weight_kg, |set| set.weight_kg),
                                    reps: last.map_or(plan.reps, |set| set.reps),
                                    completed: false,
                                }
                            })
                            .collect(),
                    }
                })
                .collect(),
        }
    }

    pub fn completed_sets(&self) -> u32 {
        self.exercises
            .iter()
            .flat_map(|exercise| &exercise.sets)
            .filter(|set| set.completed)
            .count() as u32
    }

    pub fn volume_kg(&self) -> f64 {
        self.exercises
            .iter()
            .flat_map(|exercise| &exercise.sets)
            .filter(|set| set.completed)
            .map(|set| set.weight_kg * f64::from(set.reps))
            .sum()
    }

    pub fn validate(&self) -> Result<(), ValidationError> {
        validate_id(&self.id)?;
        validate_id(&self.routine_id)?;
        validate_name(&self.routine_name)?;
        require(self.started_ms > 0, "Invalid workout start time.")?;
        if let Some(finished) = self.finished_ms {
            require(finished >= self.started_ms, "Invalid workout finish time.")?;
            require(
                self.completed_sets() > 0,
                "A finished workout needs a completed set.",
            )?;
            require(
                self.rest_end_ms.is_none(),
                "A finished workout cannot be resting.",
            )?;
        }
        require(
            self.rest_end_ms.is_none_or(|time| time >= self.started_ms),
            "Invalid rest deadline.",
        )?;
        require(
            !self.exercises.is_empty() && self.exercises.len() <= MAX_EXERCISES,
            "Invalid workout exercise count.",
        )?;
        let mut ids = HashSet::new();
        let mut templates = HashSet::new();
        for exercise in &self.exercises {
            unique_id(&exercise.id, &mut ids)?;
            unique_id(&exercise.template_id, &mut templates)?;
            validate_name(&exercise.name)?;
            validate_rest(exercise.rest_seconds)?;
            require(
                !exercise.sets.is_empty() && exercise.sets.len() <= MAX_SETS as usize,
                "Invalid workout set count.",
            )?;
            for set in &exercise.sets {
                unique_id(&set.id, &mut ids)?;
                validate_values(set.weight_kg, set.reps)?;
            }
        }
        require(
            self.volume_kg().is_finite(),
            "Workout volume exceeds the supported range.",
        )
    }
}

impl Archive {
    pub fn validate(&self) -> Result<(), ValidationError> {
        require(self.version == 1, "This backup version is not supported.")?;
        let mut routine_ids = HashSet::new();
        let mut template_ids = HashSet::new();
        for routine in &self.routines {
            routine.validate()?;
            unique_id(&routine.id, &mut routine_ids)?;
            for exercise in &routine.exercises {
                unique_id(&exercise.id, &mut template_ids)?;
            }
        }
        let mut ids = HashSet::new();
        let mut active = 0;
        for workout in &self.workouts {
            workout.validate()?;
            unique_id(&workout.id, &mut ids)?;
            active += usize::from(workout.finished_ms.is_none());
            for exercise in &workout.exercises {
                unique_id(&exercise.id, &mut ids)?;
                for set in &exercise.sets {
                    unique_id(&set.id, &mut ids)?;
                }
            }
        }
        require(
            active <= 1,
            "A backup cannot contain multiple active workouts.",
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn units_round_trip_without_changing_the_canonical_weight() {
        let kg = WeightUnit::Lb.to_kg(135.0);
        assert!((kg - 61.234_969_95).abs() < 1e-9);
        assert!((WeightUnit::Lb.from_kg(kg) - 135.0).abs() < 1e-9);
    }

    #[test]
    fn invalid_values_and_boundaries_are_explicit_errors() {
        assert!(validate_values(f64::NAN, 8).is_err());
        assert!(validate_values(f64::INFINITY, 8).is_err());
        assert!(validate_values(-1.0, 8).is_err());
        assert!(validate_values(60.0, 0).is_err());
        assert!(validate_values(f64::MAX, 2).is_err());
        assert!(validate_values(0.0, 8).is_ok());
        assert!(validate_rest(3_600).is_ok());
        assert!(validate_rest(3_601).is_err());
    }
}
