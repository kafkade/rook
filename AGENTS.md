# Agent Instructions

## Start Here

Read [PROJECT-BRIEF.md](PROJECT-BRIEF.md) before starting work. It preserves the
product context, approved decisions, open questions, and reference projects.
This file defines how agents should work; the brief records what has been
decided. Keep both consistent when the user approves a change.

Do not turn a recommendation into an approved decision. Ask before resolving
choices that materially affect scope, architecture, security, or recovery.

## Current Project State

- Working name: **Rook**, approved for now. Its story is that we remain
  eternal rookies: always learning and improving. Do not reopen naming unless
  requested. App Store reservation and legal clearance remain unverified.
- The prototype source is public at `kafkade/rook`. The maintainer performed
  the initial commit/push and scoped infrastructure bootstrap. Git writes and
  remote applies remain maintainer-only actions.
- The encrypted full-loop iPhone slice is implemented. Build instructions and
  recovery boundaries are in `README.md` and `SECURITY.md`.
- Approved visual direction: Route markers. Preserve native controls,
  adaptive navy/slate and amber, SF/Dynamic Type, and completion markers.
  The inline workout chart is deferred; separate basic Progress is implemented.
  Read `DESIGN.md` for the built tokens and `.impeccable/surfaces/active-workout.md`
  for the active-workout contract; sidecar previews are illustrative only.
- Historical name proposals are preserved in ignored local history, not an
  active task. Rook is the working name.
- Ease of typing and finding the app on a phone is a primary naming constraint.
  Abstract meaning must not require cryptic spelling. Favor predictable
  letter-only spelling and memorable pronunciation; evaluate suggested names
  against this constraint rather than assuming short names are easy to find.
- The user approved a name-first approach: assess everyday use ("Open X",
  "I logged it in X") before explaining etymology or backstory. A meaningful
  reference must not be used to justify a name the user does not enjoy using.
- Approved stack: **Swift/SwiftUI + Rust core + SQLite**.
- Approved bindings: **UniFFI**, with synchronous Rust methods called off the
  main thread through a serial Swift worker.
- Approved initial privacy direction: **app-level database encryption,
  Keychain-protected keys, and encrypted export/restore**.
- First release: iOS, initially for personal use, with possible App Store
  distribution. No account, server, or cloud sync required.
- Essentials: routines, sets/reps/weight, rest timer, history, progress charts.
- Curated exercise library and Apple Health belong to the following release.
  Manual exercise definitions are needed before the curated library exists.
- Apple Watch support is planned; a web interface is a later possibility.
- Keep naming broad enough for strength training, future runs, and possible
  race tracking. Do not add those future activities to the initial release
  scope merely because the brand should accommodate them.
- Approved storage: **SQLCipher**, with a random Keychain-protected key
  accessible when unlocked. Portable backups use **age passphrase encryption**.
- The prototype starts empty with an optional example routine, supports kg/lb,
  and requires confirmation before replacing data during restore.
- MIT licensing is approved; ask for an original-project link as a courtesy,
  not a binding extra condition. Biometrics and production distribution remain
  open.

Local prototype implementation is authorized. Do not choose permanent signed
product identifiers, provision infrastructure, or publish anything as a side
effect. Resolve material prototype and security choices before implementing
them.

The staged DevOps plan in `DEVOPS-PLAN.md` was approved on 2026-10-10.
Local preparation is authorized after the license discussion. Repository
creation, initial Git push, and scoped OpenTofu applies are maintainer steps;
provide exact commands and wait for confirmation at each manual gate.
The directory move and license discussion are complete. Rust minimum 1.91 /
pinned 1.96.0 is approved. `docs/ci.md` records the passing initial hosted
main run on Xcode 26.6, and the verified PR/default-branch protections and
Actions policy. PR-path validation and `CI Pass` enforcement remain manual
bootstrap gates; do not claim the required gate is enabled yet.

## Product Constraints

1. **Local-first:** core workout functionality must work fully offline and
   without an account. Future integrations must not become prerequisites.
2. **User data ownership:** provide portable export and restore without vendor
   lock-in. Encryption must not remove the user's ability to recover data.
3. **Privacy by design:** keep workout data on-device unless the user explicitly
   requests an export or opts into a future network feature. Do not introduce
   telemetry or third-party data collection without approval.
4. **Apple-first experience:** use native UI and platform APIs. Rust code
   sharing is not a requirement to share UI across platforms.
5. **Incremental delivery:** build the requested slice end to end. Avoid
   speculative servers, CLI products, plugin systems, or platform scaffolds.
6. **Open source:** keep publishable code and documentation public-ready, but
   never include personal data, secrets, or signing credentials.

Strong and Hevy are functional references, not sources of proprietary code,
branding, or assets. Toku's CLI-first and book-specific policies do not apply.

## Architecture Boundaries

- **Swift:** SwiftUI, presentation state, Swift Charts, notifications,
  accessibility, Keychain, and later HealthKit and WatchConnectivity.
- **Rust core:** domain models, workout rules, validation, session transitions,
  and calculations. Keep platform-independent logic free of platform I/O.
- **Persistence:** encrypted SQLite, versioned migrations, transactions, and
  portable data operations behind a clear boundary.
- **Bindings:** a narrow, explicit interface between Swift and Rust. Define
  ownership, thread safety, cancellation, and error propagation; never let a
  Rust panic unwind across the foreign-language boundary.

Keep business rules out of views and avoid duplicate implementations across
Swift and Rust. Generated bindings must be reproducible rather than manually
patched. UniFFI is the selected binding mechanism.

Future web support may reuse domain logic through WebAssembly, but native
database, Keychain, and UI code will need platform-specific adapters. Do not
build those adapters until requested.

## Security and Data Boundaries

Treat local encryption, backup encryption, transport security, authentication,
and future end-to-end encrypted sync as separate guarantees. Never claim that
one automatically supplies the others, or describe planned protection as
implemented, audited, or verified.

- Generate keys with a cryptographically secure random source and protect
  device key material using Keychain.
- Use maintained cryptographic libraries and established encrypted-storage
  implementations. Do not design custom encryption or authentication protocols.
- Include database journals, sidecars, temporary files, and exports in the
  storage threat model; do not protect only the main database file.
- Never silently fall back to a plaintext database or a key stored in a file
  when encryption or Keychain access fails. Surface an actionable error.
- Never replace a missing key, erase an unreadable database, or reset storage
  automatically to make a failed open look successful.
- Keep keys, credentials, and workout contents out of logs, diagnostics, crash
  reports, source control, and test fixtures. Use synthetic fixtures.
- Select key accessibility and device-lock behavior deliberately. Consider
  locked-screen timers and background work without silently weakening security.
- Design recovery with encryption: a device-only key cannot restore onto a
  replacement phone. Do not assume ordinary iCloud Backup solves this.
- Encrypted backups must have a documented, versioned format and a tested
  restore path. Make any plaintext export explicit and clearly warn the user.

Future sync and provider-assisted recovery require a separate design decision.
Authentication recovery must not be confused with permission to decrypt data.
Document who can decrypt contents and what metadata remains visible.

Use private vulnerability reporting when available; do not publish exploit
details or sensitive data in public issues.

## Implementation and Quality

- Inspect existing code and prior art before editing. Make focused changes;
  preserve unrelated work and do not fix unrelated issues.
- Prefer simple modules and explicit types over premature abstractions.
- Use typed errors in Rust libraries, following Toku's `thiserror` pattern
  where appropriate. Avoid `unwrap()`/`expect()` in user-facing paths and
  forced unwraps in Swift. Propagate failures into useful UI states.
- Keep schema changes versioned and data-preserving. Do not use database
  deletion as a migration strategy.
- Treat stable IDs, active-workout recovery, historical records independent of
  routine edits, and persisted timer deadlines as design requirements to
  resolve when implementing those features.
- Use accessible native controls, localization-ready strings, and explicit
  unit handling. Respect platform lifecycle and background execution limits.
- Update directly related documentation with behavior and architecture changes.
  Record significant approved trade-offs in ADRs once that structure exists.

Run the smallest relevant checks using tooling actually present in the
project. Include Rust tests/checks, formatting and Clippy when Rust is changed,
and relevant simulator builds/tests when Swift or bindings are changed.
Changes to bindings must be checked from both languages, not Rust alone.

Test encryption and recovery against wrong or missing keys, tampered backups,
replacement-device restore, and interrupted operations. Test persistence and
timer behavior across suspension and relaunch. Report blocked checks honestly.

Do not claim commands, schemes, CI jobs, or tests exist until they have been
introduced and verified. `PRODUCT.md` records current product truth.

## Git, CI, and Release Policies

**Use read-only Git operations only.** Leave edits uncommitted for maintainer
review. Do not stage, commit, push, tag, stash, merge, rebase, reset, revert, or
otherwise modify Git state. Read-only commands such as `git status`,
`git diff`, `git log`, and `git branch --list` are acceptable when a repo exists.

- Follow Toku's PR title convention: `feat:`, `fix:`, `docs:`, `test:`,
  `refactor:`, or `chore:`.
- Once a changelog exists, put normal user-facing changes under `Unreleased`.
  Version bumps and release stamping belong to an explicitly requested release.
- Do not tag, publish releases, upload to TestFlight/App Store, or run
  infrastructure applies as an incidental part of development.
- Keep signing, store credentials, and other secrets outside source control.

GitHub settings belong in the existing `github-infra` project, using OpenTofu
root modules under `repos/<name>/`, independent state, and `modules/oss-repo`.
Inject credentials through 1Password CLI; never commit secrets or state.
Required status checks must match actual CI job names. Flag and coordinate
changes to merge gates with the corresponding IaC configuration.

No application cloud infrastructure is needed for the initial local-only app.

## Reference Projects

The public reference is `kafkade/toku`; infrastructure belongs in the
maintainer's private `github-infra` checkout. Inspect available references as
needed, but do not make building this app depend on sibling repositories.

Toku provides useful Rust/Swift boundaries, error handling, migration,
documentation, Git, and CI conventions. Its documented working database is
plaintext despite encrypted sync: do not copy that storage policy into this
project or assume its cryptographic implementation has been audited.
