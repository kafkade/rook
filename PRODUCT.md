# Rook

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack

SwiftUI and Swift Charts with a Rust core, UniFFI-generated Swift bindings,
and SQLCipher-encrypted SQLite persistence. Apple Keychain holds the random
device database key. Portable backups use age passphrase encryption.

## Users

Initially a personal iPhone app, used between sets at the gym to record
training quickly and review progress later. Source is public and MIT-licensed
at `kafkade/rook`. Signed app distribution and eventual App Store publication
remain future milestones.

## Product Purpose

Record routines, sets, repetitions, and weights; manage rest; preserve workout
history; show progress. Success means completing this loop offline without
an account and being able to restore an encrypted backup on another device.

## Positioning

Local-first data ownership and native Apple interaction. Rook is a working
name, not a cleared trademark or reserved App Store title.

## Operating Context

Fast, one-handed interaction between sets, often with a locked or suspended
phone during rest. Weight units must support kg and lb. Historical workouts
must remain independent of later routine edits.

## Capabilities and Constraints

- The first prototype is a usable encrypted slice, not a synthetic-data demo.
- Cover routines, workout logging, rest timer, history, and basic charts.
- Defer the inline active-workout comparison chart; a basic separate progress
  view remains in scope.
- Start with no workout history; offer an explicitly optional example routine.
- Require an unlocked device for database key access.
- Back up without an account using a user-chosen passphrase.
- Require explicit confirmation before replacing data on restore.
- No silent plaintext or new-key fallback on storage errors.
- Apple Watch, HealthKit, a curated exercise library, runs, races, and web
  support are future work, not prototype features.
- Keep domain logic separate from platform I/O for future extensions.
- No telemetry, social feed, or server dependency.

## Brand Commitments

Rook: we remain eternal rookies, always learning and improving.
The name must work in everyday use without requiring its story to be known.
No existing visual assets or design system have been supplied.
The user approved the Route markers direction from the visual mockups:
adaptive navy/slate and amber, clear completion markers, and native controls.

## Evidence on Hand

`PROJECT-BRIEF.md` records approved decisions. `AGENTS.md` defines
agent policies. Toku is architecture and workflow prior art, not an app
dependency. Native simulator captures and hosted tests use isolated synthetic
stores, not user workout data. No testimonials, independently audited security
claims, or published App Store product exist.

## Product Principles

- Keep recording fast and recovery deliberate.
- Own and restore data in a documented format.
- Show honest records, not judgment or fabricated achievements.
- Use native controls and accessible layouts.
- Make failures actionable instead of pretending data was saved.
