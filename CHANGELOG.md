# Changelog

## Unreleased

### Added

- Native iPhone workout loop: manual routines, kg/lb set logging, persisted
  rest deadlines, resumable sessions, historical snapshots, and basic Progress.
- SQLCipher storage with Keychain-protected keys and age passphrase-encrypted
  portable backup/restore.
- Route markers design with adaptive appearance and Dynamic Type layouts.
- MIT licensing, contribution guidance, and reproducible local validation.
- Prepared PR workflows for Rust, binding/native tests, dependency policy,
  repository hygiene, and a fail-closed aggregate check.

### Known limitations

- Prototype only; no independently audited security, physical-device or
  VoiceOver verification, signed distribution, Watch, HealthKit, or sync.
- A SwiftUI invalid-frame runtime warning remains during keyboard editing.
- Hosted CI and remote repository protection are not verified until bootstrap.
