# Architecture

Rook is a local-first iPhone application, not a server or shared cross-platform
UI. Extensions should preserve the offline workout loop and data ownership.

## Boundaries

| Layer | Responsibility |
| --- | --- |
| `rook-core` | Models, units, validation, stable IDs, historical snapshots, and workout rules; no platform I/O |
| `rook-db` | SQLCipher opening, migrations, persistence/transactions, and age archive operations |
| `rook-ffi` | Narrow typed throwing UniFFI API; mutex-protected engine ownership |
| `RookKit` | Generated Swift/C transport and a real Rust-backed integration test |
| `RookRepository` | Serial Swift actor; Keychain, protected file location, bounded backup reads, engine operations |
| `RookModel` | Main-actor presentation, pending edits, sequencing, lifecycle, error presentation, rest notifications |
| SwiftUI views | Native presentation, accessible controls, Charts, and explicit user actions |

Generated Swift comes from Rust metadata and `crates/rook-ffi/uniffi.toml`.
The build script stages only static archives for app linking; the host dylib
is used for generation, not loaded into the app.

## Persistence and recovery

The engine allows one active workout. Completed history contains snapshots
independent of later routine changes. Exercise template IDs maintain progress
series across renames. Canonical weights are kilograms; display/edit conversion
preserves values rather than resaving rounded display text on completion.

Valid draft inputs debounce-save and explicit actions flush pending edits.
Incomplete invalid input remains a visible edit, not a fabricated successful
save. A monotonic sequence prevents stale snapshot delivery from replacing newer
presentation state.

Rest is a persisted UTC deadline. The app does not rely on continuous background
execution. Optional generic local notifications are separate from database/key
availability while locked.

See [SECURITY.md](../SECURITY.md) for Keychain accessibility, file protection,
backup format/limits, replacement semantics, and loss boundaries. Do not
describe local encryption as authentication or future encrypted sync.

## Extensions and decisions

Do not introduce cloud services, telemetry, curated catalogs, Watch targets,
HealthKit, or browser adapters until requested. A shared Rust domain does not
make native storage, Keychain, or SwiftUI portable to the web.

Use a short ADR in `docs/adr/` for an approved material change to architecture,
schema, security, or recovery. Do not turn a proposal into an approved decision
or retroactively claim a formal ADR was reviewed.
