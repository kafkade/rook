# Rook: decisions and current state

Updated 2026-10-10. This is the public-ready decision summary, not a security
audit or a release claim. The full earlier naming/conversation record is
preserved locally in ignored `PROJECT-HISTORY.local.md`.

## Product

Rook is the approved working name: we remain eternal rookies, always learning.
Do not reopen naming unless requested. App Store reservation and legal
clearance remain unverified.

The user accepted the prototype as a first cut for code, Rust/Swift bindings,
and design language. It targets iPhone first and works offline without an
account, server, telemetry, or sync prerequisite.

Current slice: manually defined routines; kg/lb set/repetition logging; rest
deadlines; resumable active workouts; immutable historical snapshots; basic
separate Progress; encrypted backup and confirmed replacement restore.
The first run is empty, with an optional structure-only example routine.

Route markers is the approved native direction: adaptive navy/slate and amber,
system SF/Dynamic Type, completion markers, and native controls. Inline workout
comparison charts are deferred, not the separate basic Progress view.

Curated exercises and Apple Health belong to a following release. Apple Watch,
runs/races, sync, and web remain future possibilities, not implemented scope.

## Architecture and privacy decisions

- SwiftUI/Charts and Apple APIs for presentation, Keychain, notifications,
  accessibility, and platform lifecycle.
- Platform-independent Rust rules/models, SQLCipher persistence, and portable
  age operations behind narrow typed UniFFI bindings.
- Synchronous Rust methods called off the main actor by a serial Swift actor.
- Random 32-byte Keychain database key requiring an unlocked device, with
  device-only accessibility and complete file protection.
- SQLCipher, no plaintext fallback, no automatic key replacement or unreadable
  database reset, and transactional/versioned data operations.
- Portable age passphrase backups do not contain the device key. Confirm before
  replacing data; no passphrase reset or provider-assisted recovery.
- Exclude the working store from ordinary iCloud Backup. Portable backups and
  their passphrases are the cross-device recovery path.

See `SECURITY.md` for actual format, resource limits, and recovery boundaries.
Local encryption is not authentication, transport encryption, or an automatic
future end-to-end sync guarantee.

## License and DevOps

MIT is approved and present in `LICENSE`. Notice retention is sufficient.
Request a link to the original project as a courtesy, not a binding restriction.
Dependencies retain their licenses, including UniFFI's MPL-covered files.

The staged plan in `DEVOPS-PLAN.md` is approved. The working directory has been
moved to `rook`. Local documentation, validation, workflows, and infrastructure
preparation are authorized; Git writes and remote operations remain gated
maintainer actions.

Public `kafkade/rook` now exists as a personal-account repository. The maintainer
created it, pushed initial commit `0c6edbe`, and imported/applied its settings
through the private `github-infra/repos/rook` root.

Sole-maintainer merge policy: PRs, passing CI, squash merges, zero required
outside approvals, and emergency admin bypass. Required code PR checks include
Rust, generated bindings, Swift transport, native UI tests, and unsigned device
compilation; only explicitly classified documentation-only PRs may skip Apple.
PR/default-branch protection and the SHA-pinned Actions allowlist are active.
`CI Pass` passed on the initial main run but is not required yet; documentation-only
and code-affecting PR paths must be proved before IaC enforces it.

Rust 1.91 minimum / 1.96.0 normal toolchain was explicitly approved after the
original 1.88 declaration failed against the existing lockfile. CI uses a
stable Xcode 26.6 / iOS 26.5 ARM baseline, now verified in the initial hosted
main run. Private reporting, read-only workflow defaults, all-external fork
approval, secret scanning, and push protection are verified enabled.
Git writes and remote applies were performed by the maintainer, not the agent.
No signing secret, release workflow, or signed app distribution was added.

## Verification and open boundaries

The prototype's Rust tests, typed Swift transport test, native UI suite, and
simulator/unsigned-device targets have passed locally. Native test fixtures
are isolated from the normal store; this is not verification on physical
hardware. A keyboard-edit invalid-frame warning remains documented.
Local DevOps preparation also passed source-only regeneration and native
validation, nineteen gate/tooling policy tests, workflow/shell/documentation
lint, dependency policy, and scoped IaC validation. The
[initial hosted CI run](https://github.com/kafkade/rook/actions/runs/38073209917)
passed all seven jobs, including the Swift transport test, five native UI tests
without skips, unsigned device compilation, and `CI Pass`. The scoped bootstrap
apply is verified; PR-path proof, final check enforcement, and infrastructure
version-control handoff remain outstanding.

No independent security audit, physical-device/VoiceOver verification,
production signing, app-store delivery, biometric policy, or future sync
recovery design is complete. Binary redistribution also needs complete
third-party notices; source compatibility checks do not replace that work.

## References and continuation

[Toku](https://github.com/kafkade/toku) is architecture/workflow inspiration,
not a build dependency. Its plaintext local-store policy is not Rook's policy.
Strong/Hevy are functional references, not sources of assets or code.
GitHub settings use the existing `github-infra` per-repo OpenTofu pattern;
do not make public app builds depend on that private sibling checkout.

Read `AGENTS.md`, this summary, `README.md`, and `docs/ci.md` before changes.
Follow the next incomplete manual gate in `DEVOPS-PLAN.md`, preserve unrelated
work, and do not stage, commit, push, provision, apply, or publish incidentally.
