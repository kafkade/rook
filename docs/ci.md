# Local and PR validation

The public repository and initial hosted main run are verified. PR/default-branch
protection and the SHA-pinned Actions allowlist are active; `CI Pass` is not yet
a required check. The documentation-only PR path is verified; the code-affecting
PR path still needs hosted proof before the final merge gate is enabled.

## Verified bootstrap evidence

The [initial CI run](https://github.com/kafkade/rook/actions/runs/38073209917)
at commit `0c6edbe` passed all seven jobs on 2026-10-10, including `CI Pass`.
The Apple job used ARM `macos-26`, Xcode 26.6 (17F113), and the configured
iPhone 17 Pro / iOS 26.5 simulator. It regenerated bindings and the Xcode
project, passed the Rust-backed Swift transport test, compiled the unsigned
device target, and passed all five native UI tests without skips.

This proves the main-push path on that runner, not every PR path or future
runner image. Local source-only regeneration also passed on Xcode 27.
Neither result establishes physical-device, VoiceOver, or independent security
verification.

The initial hosted Swift transport link reported a deployment-target mismatch:
bundled native host objects targeted macOS 26.5 while the Swift package declared
macOS 14. `build-apple.sh` now explicitly exports
`MACOSX_DEPLOYMENT_TARGET=14.0` for the host Rust and bundled SQLCipher/OpenSSL
builds. It keeps the separate iPhone target at iOS 17.0.

`check-apple.sh` inspects every reported deployment record in the staged host
archive and the binding-generation dylib before linking the Swift test. Missing
or invalid metadata, non-macOS platforms, or any minimum above macOS 14 fail the
check instead of being accepted as a linker warning. This verifies compiled
deployment metadata, not execution on macOS 14 hardware or the iOS 17 runtime.

[Documentation PR #1](https://github.com/kafkade/rook/pull/1) passed with
`code=false`, successful hygiene, four intentional code-job skips, and a
successful aggregate. It was squash-merged as `d7bb1ac`; the full code PR and
required gate enforcement remain pending.

## Toolchain

| Tool | Source of truth |
| --- | --- |
| Rust development/CI | `rust-toolchain.toml`: 1.96.0, minimal profile, formatting/Clippy |
| Rust minimum | `Cargo.toml`: 1.91; full workspace/all-target/all-feature check includes bindgen |
| Xcode CI baseline | `scripts/tool-versions.json`: 26.6, on ARM `macos-26` |
| Simulator CI baseline | iPhone 17 Pro, iOS 26.5; fail if absent or ambiguous |
| XcodeGen | Checksum-pinned 2.45.4 archive, including setting presets |
| Actionlint / ShellCheck | Checksum-pinned releases in `scripts/tool-versions.json` |
| Dependency checker | cargo-deny 0.19.9; `deny.toml` policy |
| Markdown lint | `package.json` and `package-lock.json`; Node 22.17+ |

Python 3.12+ is needed for repository tooling. Full Xcode and Apple Silicon
are required for Apple builds. Use per-command `DEVELOPER_DIR` to select
Xcode; never silently change global `xcode-select` configuration.

The 1.88 declaration was incompatible with the existing lockfile: UUID needed
1.89 and UniFFI's tooling needed 1.91. Raising the declared minimum to 1.91 was
explicitly approved and verified, without dependency downgrades.

## Commands

```sh
python3 scripts/install-tools.py actionlint shellcheck xcodegen
npm ci --ignore-scripts
cargo install cargo-deny --version 0.19.9 --locked
bash scripts/check-repository.sh
bash scripts/check-rust.sh
cargo deny check
SIMULATOR_UDID=<available-iPhone-UUID> bash scripts/check-apple.sh
```

The installer checks publisher SHA-256 digests before extraction and installs
under `target/ci-tools`; it does not install globally. To build outside the
check wrapper using its XcodeGen:

```sh
export PATH="$PWD/target/ci-tools/bin:$PATH"
bash scripts/build-apple.sh simulator
```

`check-apple.sh` regenerates bindings/project/icon, runs the host Swift
transport test, compiles the unsigned iPhone target, and runs the entire native
UI suite. It also checks the host archive/dylib deployment metadata against
RookKit's macOS 14 floor. It selects exactly one available simulator before doing the work.
`SIMULATOR_NAME` and `SIMULATOR_RUNTIME` may select an exact local pair, or
`SIMULATOR_UDID` may select an already available iPhone on another runtime.
CI still asserts its pinned Xcode version.

Use `xcrun simctl list devices available` to find local identifiers. Each
simulator has its own apps/data. Build-only success does not install Rook on
every booted simulator; Xcode Run or explicit `simctl install`/`launch` is needed.

Checks use fresh CI-specific build directories after moving the project, not
the prototype's old DerivedData. XCTest results have unique names under
`target/ci-results`. The CI upload includes only synthetic UI-test bundles,
not application containers, backups, keys, or signing files, and expires after
seven days.

Verbose diagnostic collection is disabled because it stalled local Xcode
report finalization; ordinary results and screenshot attachments remain.
The known keyboard-edit invalid-frame warning is not fixed or suppressed by
this CI work. UI tests use isolated UUID-scoped stores. Compilation/test passes
do not establish hardware, VoiceOver, or independently audited security.

## Required check and skips

`CI Pass` is the verified context intended for the final required gate.
Its prerequisites are Classify changes, Repository hygiene, Rust validation,
Minimum Rust validation, Dependency policy, and Apple validation.

Every PR runs classification and hygiene. Only a diff containing exclusively
recognized Markdown documentation paths can skip the four code checks.
Unknown paths, workflow/config/tool changes, shared Rust dependencies, Swift,
and build scripts all require the complete code path. Renames are examined as
old and new paths so renaming source to Markdown cannot hide its removal.
Main pushes and manual CI dispatches run everything.

The aggregate always evaluates all prerequisites. Classification and hygiene
must succeed; required code jobs must succeed; documentation-only code jobs
must be intentionally skipped. Missing outputs, failed classification,
unexpected skips, failures, and cancellations cannot produce a green gate.
Unit tests exercise these cases without pretending to run GitHub orchestration.

PR title validation supports the types in `CONTRIBUTING.md`; `edited` events
rerun it. Titles and event values are passed through environment variables,
never interpolated into shell source.

## Trust and dependency maintenance

PRs use `pull_request`, read-only token permissions, SHA-pinned actions, and
checkout without persistent credentials. No privileged PR checkout,
self-hosted personal runner, production certificate, signing secret, or
release workflow is included. Caches are deliberately omitted until hosted
timing evidence justifies them; add only with a reviewed trust policy.

Weekly dependency monitoring checks advisories, licenses, sources, and bans
even when no code changes occur. It reports failures in Actions without
publishing vulnerability details automatically into public issues.
Dependabot prepares Cargo, Actions, and documentation-tool update PRs.
Other tool-version updates must change their pin/checksum and pass validation.

`cargo deny` covers Rust packages, not npm tooling or all code vulnerability
classes. Source-level security scanning and binary distribution notices require
separate implementation/review; no unsupported badge or assurance is implied.

## Bootstrap protection

The private `github-infra` project holds `repos/rook`, initially with no required
CI context. It manages the public repository, `main`, squash/PR protection,
labels, dependency alerts, and SHA-pinned allowed Actions.
The bootstrap plan has been applied and its remote settings verified.
No shared-module policy changes were needed.

The main run proved the exact `CI Pass` context. After documentation-only and
code-affecting PR runs prove the remaining workflow paths, the
maintainer changes Rook's `required_status_checks` to `["CI Pass"]`, reviews a
scoped plan, and applies it. A local test is not permission to enforce an
unproven context. Admin bypass is break-glass, not the normal contribution path.

The selected provider does not expose private vulnerability reporting or
default workflow token permissions. Those are explicit manual bootstrap
settings, not managed resources. The maintainer enabled private vulnerability
reporting, read-only workflow defaults with no PR-approval permission, and
approval for all external fork contributors. These settings were verified
through the GitHub API, along with secret scanning and push protection.
