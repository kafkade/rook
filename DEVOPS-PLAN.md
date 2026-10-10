# Rook repository and PR validation plan

Status: directory move and local preparation complete; waiting for maintainer
review and initial Git/GitHub bootstrap. Hosted CI and remote settings unverified.
Updated 2026-10-10.

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

The earlier conversation record is preserved in ignored
`PROJECT-HISTORY.local.md`; the public `PROJECT-BRIEF.md` is a concise decision
summary. No application data, credentials, or generated libraries belong in
the initial commit.

## Stages and stop points

| Step | Work | Completion / manual gate |
| --- | --- | --- |
| 1. Resolve license and approve plan | Completed: MIT selected, optional courtesy project link, staged plan approved. | No public source push before the actual license and publication-readiness checks are in place. |
| 2. Move the working directory | Completed: the maintainer moved `next` to `rook`; project files are present. | Local preparation resumed from the new cwd. |
| 3. Prepare publication-ready files | Add the selected license, contribution guide, PR/issue templates, CODEOWNERS, Unreleased changelog, dependency-update configuration, and concise architecture/CI documentation. Refresh README, SECURITY, AGENTS, and PRODUCT links. Remove machine-specific assumptions and publication-only stale claims. Keep decision history without publishing private planning notes, data, credentials, or a lengthy rejected-name narrative by accident. | Leave changes uncommitted for review. Establish exactly which source/docs/assets belong in the first commit. |
| 4. Make local validation reproducible | Rust minimum 1.91 / pinned 1.96.0 approved after 1.88 failed. Checksum-pinned XcodeGen and validators, locked Cargo, local check entry points, and deterministic simulator selection are implemented. Static-only linking and self-contained icon provenance are preserved. | Run the checks against a clean-source staging copy or clean checkout when available. Hosted Xcode 26.6 proof still needs the first GitHub run. |
| 5. Prepare and locally validate CI and IaC | Write the workflow jobs below, their fail-closed aggregate gate, and `github-infra/repos/rook/{main,providers,variables}.tf`. Initially leave required CI contexts empty; retain PR/branch protections when applied. Validate workflow/HCL syntax and gate behavior; initialize the scoped provider lockfile when approved. | No remote apply yet. Review the proposed diff and dependency between workflow names and IaC. Do not commit unrelated infrastructure changes. |
| 6. Create and publish the initial repository | Supply exact maintainer commands for Git initialization, selective staging, initial commit, empty GitHub repository creation, remote setup, and initial push. Enable private reporting/read-only workflow defaults on the empty repo before the source push. Do not create remote files that produce a competing history. | Maintainer reviews, commits, creates `kafkade/rook`, configures the manual security settings, and pushes. Stop at each gate, then inspect the first workflow run. |
| 7. Import and configure the repository | Provide scoped 1Password/OpenTofu init, import, and plan commands. Reconcile automatically existing resources before apply; check that the plan manages only Rook and contains no destruction. Configure private vulnerability reporting and repository Actions policy declaratively where the provider supports it; otherwise document a narrow manual step. | Maintainer reviews the scoped plan and applies it. Stop until confirmed. Verify actual GitHub settings and state without reading or publishing secrets. |
| 8. Prove the PR pipeline | The maintainer opens a small validation PR. Observe actual check names, runner/tool versions, forks' read-only behavior, documentation-only classification, and code-triggered Apple tests. Fix real failures in files; the maintainer commits/pushes fixes. Explicitly test that failures, cancellations, failed classification, and unexpected skipped prerequisites cannot yield a passing aggregate. | Wait after every required commit/push. Do not enable a required check while its workflow is unproven. |
| 9. Enforce the final merge gate | Set `required_status_checks = ["CI Pass"]` once that context exists and passes. Confirm `main` is the actual default branch. Plan/apply only Rook; bind the expected check producer where supported. | Maintainer reviews/applies; stop until confirmed. Verify that a PR is blocked on failed/pending CI and succeeds only after its required checks. |
| 10. Close the bootstrap | Finish remaining reviewed PRs in Rook and `github-infra`, reconcile docs/status, and verify the final scoped plan is clean. Record the runner baseline, required context, known limitations, and recovery instructions for local state. | Maintainer merges infrastructure/code PRs. Completion means the remote settings, recorded IaC, and actual PR runs agree. |

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
