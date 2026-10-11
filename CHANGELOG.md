# Changelog

## Unreleased

### Added

- Native iPhone workout loop: manual routines, kg/lb set logging, persisted
  rest deadlines, resumable sessions, historical snapshots, and basic Progress.
- SQLCipher storage with Keychain-protected keys and age passphrase-encrypted
  portable backup/restore.
- Route markers design with adaptive appearance and Dynamic Type layouts.
- MIT licensing, contribution guidance, and reproducible local validation.
- PR workflows for Rust, binding/native tests, dependency policy,
  repository hygiene, and a fail-closed aggregate check.
- Public source repository with verified private vulnerability reporting,
  PR/default-branch protection, and a SHA-pinned Actions allowlist.
- Required `CI Pass` merge check with strict up-to-date policy, enabled after
  successful main and documentation/code PR validation.
- Verified failed-prerequisite/recovery behavior and merged infrastructure
  definition, with a final scoped plan confirming no resource drift.

### Fixed

- Align Rust and bundled native host dependencies with RookKit's macOS 14
  deployment floor, with archive/dylib metadata checks before Swift linking.

### Known limitations

- Prototype only; no independently audited security, physical-device or
  VoiceOver verification, signed distribution, Watch, HealthKit, or sync.
- A SwiftUI invalid-frame runtime warning remains during keyboard editing.
