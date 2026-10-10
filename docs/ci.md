# Local and PR validation

The workflow files are prepared; hosted execution and merge protection remain
unverified until the maintainer bootstraps the repository. Local success is
not a claim that the GitHub-hosted runner has passed.

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
UI suite. It selects exactly one available simulator before doing the work.
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

`CI Pass` is the single proposed required context. Its prerequisites are
Classify changes, Repository hygiene, Rust validation, Minimum Rust validation,
Dependency policy, and Apple validation.

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
No shared-module policy changes are needed.

After actual hosted main/PR runs prove the exact `CI Pass` context, the
maintainer changes Rook's `required_status_checks` to `["CI Pass"]`, reviews a
scoped plan, and applies it. A local test is not permission to enforce an
unproven context. Admin bypass is break-glass, not the normal contribution path.

The selected provider does not expose private vulnerability reporting or
default workflow token permissions. Those are explicit manual bootstrap
settings, documented in the infrastructure root's README, not falsely claimed
as managed resources.
