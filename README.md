# Rook

A local-first iPhone training journal. Always learning. Always your record.

This is a native, encrypted **prototype** with public MIT-licensed source at
[kafkade/rook](https://github.com/kafkade/rook), not a distributed signed app or
security-audited product. Rook is the working name; App Store reservation,
trademark clearance, and production signing remain undecided.

## What works

Create routines with manually named exercises, record weight and repetitions in
kg or lb, complete sets, manage rest, and finish into history. Valid edits save
without requiring set completion. An unfinished workout can be resumed after
relaunch. Completed history retains the exercise and routine names recorded at
the time, independently of later routine edits.

Progress shows top recorded weight and completed repetitions for an exercise
within a routine. Inline workout charts are deferred. The first run is empty:
the optional example creates a routine structure, not fabricated history or
recommended working weights.

Settings provides units, optional local rest notifications, and
passphrase-encrypted backup and restore. There is no account, server, analytics,
or network prerequisite.

## Architecture

| Location | Responsibility |
| --- | --- |
| `crates/rook-core` | Platform-independent models, validation, units, and workout rules |
| `crates/rook-db` | SQLCipher persistence, migrations, transactions, and age backups |
| `crates/rook-ffi` | Typed, throwing UniFFI APIs |
| `apple/RookKit` | Generated Swift bindings and transport integration test |
| `apple/Rook` | SwiftUI, Charts, Keychain, notifications, and presentation state |
| `apple/RookUITests` | Isolated native workflow and appearance tests |

A serial Swift actor calls the synchronous Rust engine off the main actor.
SQLite is the source of truth. Stable IDs preserve exercise series across
renames; historical workouts contain snapshots rather than live routine links.
Rest uses a persisted deadline, not continuous background execution.

## Build and run

Requirements: Apple Silicon macOS, full Xcode with command-line tools selected,
Python 3.12+, the pinned Rust 1.96.0 toolchain (minimum 1.91), and XcodeGen 2.45.4.
The app targets portrait iPhones on iOS 17 or later. Local builds/tests have
passed with Xcode 27. The
[initial hosted CI run](https://github.com/kafkade/rook/actions/runs/38073209917)
also passed with stable Xcode 26.6, including the Swift transport test, all five
native UI tests, and unsigned device compilation. See `docs/ci.md` for the
tested runtime and remaining PR-validation checkpoints.

Install missing prerequisites using their normal installers/package managers:

```sh
python3 scripts/install-tools.py xcodegen
export PATH="$PWD/target/ci-tools/bin:$PATH"
rustup target add aarch64-apple-ios-sim aarch64-apple-ios
```

From the project root:

```sh
bash scripts/build-apple.sh simulator
open apple/Rook.xcodeproj
```

Choose the **Rook** scheme and an iPhone simulator, then Run. No signing team
is required for simulator use. The build script generates the icon, typed
bindings, static Rust archives, and Xcode project from `apple/project.yml`.
Do not edit generated bindings or the generated Xcode project.

For an unsigned device compilation:

```sh
bash scripts/build-apple.sh device
xcodebuild -project apple/Rook.xcodeproj -scheme Rook \
  -destination 'generic/platform=iOS' \
  -derivedDataPath target/device-build build CODE_SIGNING_ALLOWED=NO
```

Running on a real iPhone requires selecting your own signing team in Xcode.
`dev.rook.prototype` is a temporary bundle identifier, not an approved
production identifier. Do not change it casually on a device holding data:
app-container and Keychain access are tied to the application's identity.

## Local checks

```sh
bash scripts/check-rust.sh
cargo deny check
SIMULATOR_UDID=<available-iPhone-UUID> bash scripts/check-apple.sh
```

Find the UUID with `xcrun simctl list devices available`. Install the pinned
XcodeGen as shown above. See [docs/ci.md](docs/ci.md) for dependency-checker
installation, repository checks, the complete toolchain, and job/skip policy.
Native UI tests use DEBUG-only UUID-scoped database directories and Keychain
accounts; their synthetic records never populate the normal app store.
Apple static archives are staged separately from the host dylib used for
binding generation so the native linker cannot select the wrong library.
Verbose test diagnostics are disabled in the wrapper because Xcode 27 stalled
finalizing a report on the iOS 18.2 simulator; ordinary test results and
screenshot attachments are still produced. The current suite passes, but the
keyboard-edit test reports a SwiftUI invalid-frame runtime warning. Its cause
has not been established; do not treat the run as warning-free.

## Privacy and recovery

The local database is SQLCipher-encrypted using a random 32-byte device key.
The key is stored in Keychain with
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. The database directory uses
complete file protection and is excluded from ordinary iCloud Backup.
Rook covers private UI when inactive and closes its database in the background.

**Create an encrypted backup before relying on the app for irreplaceable
records.** Losing the device key without a portable backup loses access to
the records. Rook does not silently create a replacement key or erase a
database that cannot be opened. A backup passphrase is not an account password;
there is no provider-assisted passphrase reset.

See [SECURITY.md](SECURITY.md) for the format, limits, threat model, and restore
semantics. Protection at rest is not a guarantee against a compromised,
unlocked device, screenshots taken by the user, or plaintext present in app
memory. This implementation has not received an independent security audit.

## Incremental scope

Apple Watch, HealthKit, a curated exercise library, run/race tracking, sync,
and web are not implemented. Reuse the core when those features are requested;
do not assume Apple's storage or UI adapters will run in a browser.

[PRODUCT.md](PRODUCT.md) records product truth, [PROJECT-BRIEF.md](PROJECT-BRIEF.md)
preserves decisions, [DESIGN.md](DESIGN.md) records the built native design system,
and [AGENTS.md](AGENTS.md) defines contribution constraints.
Repository settings are managed separately through `github-infra/repos/rook`,
not by the local build. PR/default-branch protection and the SHA-pinned Actions
allowlist are active. The `CI Pass` context passed on the initial main run;
it will become required only after the remaining PR-validation checkpoints.

## Contributing and license

Read [CONTRIBUTING.md](CONTRIBUTING.md), [docs/architecture.md](docs/architecture.md),
and [docs/dependencies.md](docs/dependencies.md). Rook's original source is
licensed under [MIT](LICENSE); dependencies retain their own obligations.

A link to the original project is appreciated when you build on Rook, but is
not an extra license condition. No signed app binary is distributed by this
repository setup; binary distribution requires complete third-party notices
and a separate signing/release decision.
