# Rook repository and PR validation plan

Status: public source, initial hosted CI, and scoped infrastructure bootstrap
verified, along with documentation/code PR validation and required `CI Pass`
configuration. Negative/recovery proof, infrastructure merge, and final scoped
no-drift plan verified. Final documentation PR checks/merge remain.
Updated 2026-10-11.

The maintainer approved the staged plan and local preparation after the license
discussion. Git writes, infrastructure applies, repository creation, and
publication remain manual gated actions. Execute one stage at a time.
When a stage needs a maintainer action, provide the exact commands, stop, and
wait for confirmation before continuing. Preserve both projects' read-only Git
policy for agents.

## Confirmed decisions

- Target repository: public `kafkade/rook`, owned by a personal GitHub account.
- Final local location: the `rook` working directory. The move from `next` is
  complete; project contents were preserved.
- License: **MIT**, approved. Retaining copyright/license notices is sufficient.
  Ask forks to link to the original project as a courtesy, not an added binding
  license restriction. The license and dependency policy checks are now present;
  complete binary-distribution notices remain a release gate.
- Merge policy: PRs, passing CI, squash merges, zero required outside
  approvals for the sole maintainer, and emergency admin bypass.
- Apple validation is required for code-affecting PRs. Only explicitly
  classified documentation-only changes may skip it.
- The maintainer creates the empty GitHub repository and makes the initial
  push. Then import the repository into `github-infra` and apply its settings.
- PR validation only: no TestFlight, App Store delivery, crates.io publishing,
  application cloud infrastructure, or signing secrets in this stage.

## Evidence and scope

The local prototype has three Rust crates, generated UniFFI Swift bindings,
an XcodeGen project, a Swift transport test, and five native UI tests.
Rust/Swift tests and simulator/unsigned-device builds passed locally.
There is still a documented SwiftUI keyboard-layout warning; passing CI must
not be described as independent security, VoiceOver, or hardware verification.

Inspiration:

- `github-infra/repos/toku` and `repos/kite`: per-repository root modules,
  sole-maintainer protection, labels, vulnerability alerts, and dependency
  updates.
- `github-infra/repos/arkki`: staged enablement of actual CI checks, rather
  than protecting a branch with checks that do not exist yet.
- `github-infra/modules/oss-repo`: squash merges, branch deletion/force-push
  protection, and independent local OpenTofu state.
- `toku/.github/workflows/validate.yml`: separate Rust, documentation, and
  Apple jobs with an aggregate gate.

Improve the patterns for Rook rather than copying them:

- The aggregate gate includes change detection itself and explicitly
  validates which jobs must succeed. Unexpected skips are failures.
- Shared Rust dependencies and build/toolchain/workflow changes trigger Apple
  checks, not only changes to the FFI crate or Swift files.
- Native validation regenerates bindings and runs transport and UI tests,
  rather than treating compile-only validation as workout verification.
- Required-check names are verified from real runs before IaC enforces them.
- Pin action commit SHAs and explicit tool versions; use locked dependencies.
- No signing or release workflows that succeed by silently doing nothing.
- Do not add platform matrices for unimplemented Watch/web/Windows apps.

The infrastructure worktree currently has unrelated modified/untracked files.
Preserve them. Scope changes and commands to `repos/rook` and any explicitly
approved shared-module extension; never use bulk apply for this task.

Local preparation evidence (2026-10-10): formatting/Clippy and nine Rust
tests passed on pinned 1.96.0; the complete workspace/all-feature check passed
on minimum 1.91.0. Nineteen CI-policy/simulator/result tests, Actionlint,
ShellCheck, Markdown lint, and cargo-deny passed. Swift transport, all five
native tests without skips, and unsigned device compilation also passed from
a fresh source-only staging copy with regenerated bindings/project.
Native evidence is Xcode 27 / iPhone 18 Pro / iOS 27, not proof of the hosted
Xcode 26.6 baseline. Scoped provider initialization, formatting, and validation
passed; no remote plan/apply was run.

Bootstrap evidence (2026-10-10): the maintainer pushed initial commit `0c6edbe`
to public `kafkade/rook`. Its
[first hosted run](https://github.com/kafkade/rook/actions/runs/38073209917)
passed all seven jobs, including `CI Pass`, with Xcode 26.6 and five native
tests without skips. Private reporting, read-only workflow defaults, all-external
fork approval, secret scanning, and push protection are verified.
The scoped saved plan added 15 resources and updated four without destruction;
the maintainer applied it. Squash-only merges, active PR/default protection,
labels, and the SHA-pinned Actions allowlist were verified afterward.
The required status list was initially empty until PR-path proof.

Documentation PR #1 passed run `38091984030` with four explicit code-job skips
and merged as `d7bb1ac`. Code PR #2 passed all seven jobs in run `38108441675`
and merged as `17b6768`; the host deployment-target mismatch was fixed and
verified on Xcode 26.6. The infrastructure definition is committed at
`2fd730e`, followed by evidence commit `33796a3`; private `github-infra` PR #2
is now squash-merged as `0279313`.
The maintainer reviewed/applied a saved plan containing exactly one ruleset
update. `CI Pass` and strict up-to-date checks are active in both the ruleset
and effective `main` rules.

Enforcement PR #3 failed deliberately in run `38152143962`: its invalid title
failed hygiene and the required aggregate, and merge readiness was `BLOCKED`.
Correcting only the title triggered run `38152230683` on the same `573b0d6`
commit; the checks passed and readiness became `CLEAN`. No bypass or failing
merge was attempted. After the infrastructure merge and local main sync, the
final scoped saved plan reported no resource changes. Only the checked final
documentation handoff remains.

The earlier conversation record is preserved in ignored
`PROJECT-HISTORY.local.md`; the public `PROJECT-BRIEF.md` is a concise decision
summary. No application data, credentials, or generated libraries belong in
the initial commit.

## Stages and stop points

| Step | Work | Completion / manual gate |
| --- | --- | --- |
| 1. Resolve license and approve plan | Completed: MIT selected, optional courtesy project link, staged plan approved. | No public source push before the actual license and publication-readiness checks are in place. |
| 2. Move the working directory | Completed: the maintainer moved `next` to `rook`; project files are present. | Local preparation resumed from the new cwd. |
| 3. Prepare publication-ready files | Completed: MIT source, contributor/PR/issue docs, changelog, dependency configuration, and public-ready decision context. | The maintainer reviewed the 66-file inventory and chose to keep all current documentation versioned. Private history/data/generated outputs were excluded. |
| 4. Make local validation reproducible | Completed: approved Rust minimum/pin, checksum-pinned tools, locked Cargo, exact simulator selection, and self-contained icon provenance. | Source-only checks passed locally; initial hosted Xcode 26.6/native validation also passed. |
| 5. Prepare and locally validate CI and IaC | Completed: fail-closed aggregate workflow, policy tests, scoped Rook root, and provider lockfile validated. | Required contexts were left empty for bootstrap. No shared-module policy change. |
| 6. Create and publish the initial repository | Completed by the maintainer: initial commit, empty public repo, manual security settings, and initial push. | Initial `0c6edbe` passed; subsequent PRs merged and local/remote main synchronized. |
| 7. Import and configure the repository | Completed by the maintainer: scoped imports, reviewed saved plans/applies, and infrastructure PR merge. | Remote settings verified; definition and proof merged at `0279313`. Unrelated working-tree edits preserved. |
| 8. Prove the PR pipeline | Main, documentation-only PR #1, and full code PR #2 passed. PR #3 proved failed hygiene propagates to the aggregate and recovers after title correction. | Hosted failure/recovery verified on the same commit without bypass. Cancellation/skip cases have unit coverage, not separately staged hosted failures. |
| 9. Enforce the final merge gate | Completed scoped saved-plan apply: `CI Pass` required with strict up-to-date checks; effective main rules verified. | Failed proof PR was `BLOCKED`, corrected run restored `CLEAN`. Shared module still has no producer-binding input. |
| 10. Close the bootstrap | Infrastructure merged and final scoped plan verified no drift. Final documentation records the evidence and preserved boundaries. | The maintainer must commit/push this final evidence and merge Rook PR #3 only after its new head passes required CI. |

Step 7 may be performed before the validation PR so PR/branch protections are
active without an unproven required context. The initial push is a documented
one-time bootstrap, not the normal contribution path.

Git writes, infrastructure changes to remote settings, and publication are
distinct actions. A successful local test or plan is not permission to do
the next one.

## Proposed PR checks

Stable required status context: **CI Pass**. Individual diagnostic jobs can
evolve without repeatedly changing branch protection.

| Job | Initial responsibility | Trigger |
| --- | --- | --- |
| Classify changes | Determine whether the exact diff is documentation-only; unknown paths and build/config changes default to full checks. Publish explicit outputs. | Every PR; main pushes run full checks. |
| Repository hygiene | Workflow syntax, shell checks for build scripts, scoped Markdown lint, tracked-file exclusions, and relevant repository configuration validation. PR titles accept appropriate Conventional Commit types, including CI/dependency changes. | Every PR, with relevant checks scoped inside the job. |
| Rust validation | Formatting, Clippy with warnings denied, all workspace tests, and the declared minimum supported Rust check using the committed dependency resolution. | Code-affecting changes and main pushes. |
| Dependency advisories | Check the Rust lockfile against RustSec; schedule independent periodic checks so unchanged dependencies do not go unmonitored. Treat infrastructure/network failure as failure, not "no advisories." | Code-affecting PRs, main, scheduled/manual runs. |
| Apple validation | Generate UniFFI bindings and Xcode project; run the host Swift transport test; build/test on an available pinned iPhone simulator runtime; compile the unsigned iPhone target. Upload bounded test results, with synthetic data only. | Code-affecting changes and main pushes. |
| CI Pass | Always evaluate classification plus all prerequisite outcomes; allow only the documented intentional skips. Fail if any required job failed, was cancelled, or unexpectedly skipped. | Every PR and main push. |

Use one ARM GitHub-hosted macOS job initially so the Rust host archive,
generated Swift bindings, simulator/device archives, and native tests share a
verified toolchain without passing trust-sensitive artifacts across jobs.
Use Linux for inexpensive repository and Rust-only checks.

The currently documented `macos-26` ARM image has stable Xcode 26.6 and iOS
26.5 SDKs; Xcode 27 uses a separate public-preview runner. Prefer stable Xcode
26.6 if Rook's clean-source build/tests pass there; keep Xcode 27 a separate
compatibility check rather than silently making preview software a merge
prerequisite. The exact Xcode/runtime pair must be rechecked before workflow
implementation because hosted images change.

The iOS 17 deployment floor is not a claim of iOS 17 runtime testing. Additional
runtime/device coverage is future work. No missing simulator may cause a
success-shaped skip. UI-test signing must use the runner's simulator mechanism,
not production certificates; unsigned device compilation is separate from
running UI tests.

## Workflow and repository safeguards

- `pull_request` for untrusted PR code; no privileged PR checkout through
  `pull_request_target`.
- Read-only token by default, `persist-credentials: false`, and per-job
  permissions only when actually needed.
- Rust minimum 1.91 and normal builds 1.96.0 were explicitly approved and
  verified locally, without dependency downgrades.
- SHA-pinned actions with readable version comments; pinned dependencies/tools
  and automatic update PRs instead of floating versions.
- Concurrency cancellation, bounded job/test timeouts, and bounded retention
  for synthetic test reports. No personal database, backup, or signing artifact
  uploads.
- Use ephemeral hosted runners; do not expose the personal development machine
  as a self-hosted runner for public PRs.
- Cache build inputs safely, with appropriate toolchain/target/lockfile keys;
  permit cache saves only on trusted main runs when needed.
- Weekly Cargo, Actions, and npm documentation-tool dependency update PRs;
  XcodeGen/toolchain updates
  are deliberate and tested. The current Swift package has no remote Swift
  dependencies, so do not invent an unused update ecosystem.
- Enable vulnerability alerts, dependency updates, available secret-scanning
  protections, and private vulnerability reporting; verify availability and
  actual settings for a personal public repository.
- Keep code-scanning expansion separate unless its complete build-integrated
  setup is implemented and verified. No badge or security claim for checks
  that do not exist.
- Keep public metadata modest: no unprovisioned homepage, signed release claim,
  legal clearance claim, or app-store availability.
- Preserve per-repo ignored OpenTofu state and commit the provider dependency
  lockfile. Document secure backup/import recovery. Do not introduce a new
  cloud state backend without a separate decision.
- Shared-module additions must be opt-in/backward-compatible; do not apply
  changed policy to sibling repositories incidentally.

## Sources for current recommendations

- [GitHub Actions secure use](https://docs.github.com/en/actions/reference/security/secure-use)
- [Hosted runner capabilities and public-repository availability](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [macOS 26 ARM image and Xcode versions](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)
- [Repository ruleset rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
- [Private vulnerability reporting](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting/configure-for-a-repository)
