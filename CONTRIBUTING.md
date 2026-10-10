# Contributing to Rook

Keep the workout loop offline, native, and recoverable. Discuss changes to
encryption, recovery, scope, architecture, and production identifiers before
implementation. Be respectful and constructive.

## Development

See [README.md](README.md) for build prerequisites and
[docs/architecture.md](docs/architecture.md) for boundaries. Use the pinned
Rust toolchain and generated UniFFI bindings; do not edit generated Swift or
the generated Xcode project.

Before a code-affecting PR:

```sh
bash scripts/check-rust.sh
cargo deny check
SIMULATOR_UDID=<your-available-iPhone-UUID> bash scripts/check-apple.sh
```

For repository/documentation changes:

```sh
python3 scripts/install-tools.py actionlint shellcheck
npm ci --ignore-scripts
bash scripts/check-repository.sh
```

The tools are installed only under ignored `target/ci-tools`. They do not
modify your global toolchain or Xcode selection. See [docs/ci.md](docs/ci.md)
for versions, intentional skips, and the merge gate.

## Pull requests

Use a feature branch and a title starting with `feat:`, `fix:`, `docs:`,
`test:`, `refactor:`, or `chore:`. Optional scopes and breaking-change `!` are
accepted, for example `chore(deps): Update dependencies`.

Describe the behavior change, recovery/data implications, and checks actually
run. Update user-facing entries under `Unreleased` in `CHANGELOG.md`; do not
stamp releases or bump versions as part of an ordinary PR.

Use synthetic test fixtures only. Never submit a real workout database,
encrypted personal backup, Keychain key, passphrase, signing credential, or
test result bundle. Tests must not reset or reuse the normal app's store.

Keep routines and historical snapshots independent. Make schema changes
transactional, versioned, and data-preserving. A missing key or failed
decryption must never look like a successful empty first run.

## Issues and security

Bug reports should include platform/tool versions, steps, expected behavior,
and actual behavior. Remove personal records from screenshots and diagnostics.
Feature requests should explain the user's task without turning future Watch,
HealthKit, runs, or web possibilities into current capabilities.

Do not publish vulnerability details in an issue. Follow
[SECURITY.md](SECURITY.md). Private GitHub reporting must be verified enabled
before that channel is advertised as operational.

## License and attribution

Contributions are licensed under [MIT](LICENSE). Preserve applicable
third-party license obligations; see [docs/dependencies.md](docs/dependencies.md).

If you fork or build on Rook, a link to the original
[kafkade/rook](https://github.com/kafkade/rook) project is appreciated. This is
a courtesy request, **not** an additional license condition.

Agents may edit files but must not stage, commit, push, or otherwise modify
Git state. Maintainers review and perform those actions themselves.
