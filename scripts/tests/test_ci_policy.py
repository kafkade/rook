import copy
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parent.parent


def load(name):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


policy = load("ci-policy")
simulator = load("simulator")


def needs(code=True):
    result = {
        job: {"result": "success" if code else "skipped"}
        for job in policy.CODE_JOBS
    }
    result.update({
        "classify": {"result": "success", "outputs": {"code": str(code).lower()}},
        "hygiene": {"result": "success"},
    })
    return result


class ClassificationTests(unittest.TestCase):
    def test_only_explicit_documentation_paths_can_skip(self):
        self.assertFalse(policy.code_required([
            "README.md", "docs/ci.md", ".github/pull_request_template.md",
            ".impeccable/surfaces/active-workout.md",
        ]))

    def test_code_shared_dependencies_and_unknown_paths_require_apple(self):
        for path in (
            "Cargo.lock", "Cargo.toml", "rust-toolchain.toml",
            "crates/rook-db/src/lib.rs", "apple/project.yml",
            "scripts/build-apple.sh", ".github/workflows/ci.yml",
            "scripts/tool-versions.json", "package-lock.json",
            ".github/dependabot.yml", "new-directory/notes.md",
            "docs/image.png", "scripts/README.md",
        ):
            with self.subTest(path=path):
                self.assertTrue(policy.code_required(["README.md", path]))

    def test_empty_classification_fails(self):
        with self.assertRaises(ValueError):
            policy.code_required([])

    def test_main_manual_events_run_everything(self):
        self.assertTrue(policy.classify("push", "", ""))
        self.assertTrue(policy.classify("workflow_dispatch", "", ""))

    def test_invalid_commit_cannot_become_a_git_option(self):
        with self.assertRaises(ValueError):
            policy.classify("pull_request", "--output=/tmp/x", "b" * 40)

    def test_diff_disables_rename_detection_and_preserves_filenames(self):
        response = subprocess.CompletedProcess([], 0, stdout=b"old.rs\0new.md\0")
        with patch.object(policy.subprocess, "run", return_value=response) as run:
            self.assertTrue(policy.classify("pull_request", "a" * 40, "b" * 40))
            self.assertIn("--no-renames", run.call_args.args[0])
            self.assertIn("-z", run.call_args.args[0])

    def test_unrecognized_empty_diff_fails(self):
        response = subprocess.CompletedProcess([], 0, stdout=b"")
        with patch.object(policy.subprocess, "run", return_value=response):
            with self.assertRaises(ValueError):
                policy.classify("pull_request", "a" * 40, "b" * 40)


class GateTests(unittest.TestCase):
    def test_full_success_and_explicit_docs_skip(self):
        policy.check_gate(needs(True))
        policy.check_gate(needs(False))

    def test_every_failure_cancellation_or_unexpected_skip_blocks(self):
        for job in policy.ALWAYS_JOBS + policy.CODE_JOBS:
            for result in ("failure", "cancelled", "skipped"):
                data = needs()
                data[job]["result"] = result
                with self.subTest(job=job, result=result), self.assertRaises(ValueError):
                    policy.check_gate(data)

    def test_docs_classification_cannot_hide_a_failed_job(self):
        for job in policy.CODE_JOBS:
            for result in ("failure", "cancelled"):
                data = needs(False)
                data[job]["result"] = result
                with self.subTest(job=job, result=result), self.assertRaises(ValueError):
                    policy.check_gate(data)

    def test_missing_extra_or_unknown_classification_blocks(self):
        for value in (None, "", "TRUE", "maybe"):
            data = needs()
            data["classify"]["outputs"]["code"] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                policy.check_gate(data)
        for job in policy.ALWAYS_JOBS + policy.CODE_JOBS:
            data = needs()
            del data[job]
            with self.subTest(missing=job), self.assertRaises(ValueError):
                policy.check_gate(data)
        data = needs()
        data["forgotten-job"] = {"result": "success"}
        with self.assertRaises(ValueError):
            policy.check_gate(data)

    def test_gate_does_not_modify_results(self):
        data = needs()
        original = copy.deepcopy(data)
        policy.check_gate(data)
        self.assertEqual(data, original)


class RepositoryTests(unittest.TestCase):
    def test_prototype_build_or_data_artifacts_cannot_be_tracked(self):
        for path in (
            "target/ci-results/output.xcresult/Info.plist",
            "private.sqlite", "export.rook.age", "secret.p8", ".env",
            "terraform.tfstate.backup", "private.pem",
            "PROJECT-HISTORY.local.md", "apple/Rook.xcodeproj/project.pbxproj",
            "apple/RookKit/Sources/RookKit/Generated/RookKit.swift",
        ):
            response = subprocess.CompletedProcess([], 0, stdout=path.encode() + b"\0")
            with self.subTest(path=path), patch.object(policy.subprocess, "run", return_value=response):
                with self.assertRaises(ValueError):
                    policy.check_files()

    def test_title_convention_supports_scopes_and_breaking_changes(self):
        for title in ("feat: Add routines", "chore(deps): Update Cargo", "fix(storage)!: Change archive"):
            self.assertIsNotNone(policy.PR_TITLE.fullmatch(title))
        for title in ("Update", "feat: ", "feat: A\nsecond line"):
            self.assertIsNone(policy.PR_TITLE.fullmatch(title))


class SimulatorTests(unittest.TestCase):
    runtime = "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
    identifier = "C7EE1546-E09A-4461-8DD5-5CD9C23037F3"

    def devices(self):
        return {self.runtime: [{
            "name": "iPhone 17 Pro", "udid": self.identifier, "isAvailable": True,
        }]}

    def test_exact_runtime_and_name(self):
        self.assertEqual(simulator.select(self.devices(), "iPhone 17 Pro", self.runtime), self.identifier)

    def test_explicit_identifier_supports_local_runtime(self):
        self.assertEqual(
            simulator.select(self.devices(), "other", "other", self.identifier.lower()),
            self.identifier,
        )

    def test_missing_unavailable_ambiguous_and_non_ios_devices_fail(self):
        unavailable = self.devices()
        unavailable[self.runtime][0]["isAvailable"] = False
        ambiguous = self.devices()
        ambiguous[self.runtime].append(dict(ambiguous[self.runtime][0]))
        wrong_os = {"com.apple.CoreSimulator.SimRuntime.watchOS-26-5": self.devices()[self.runtime]}
        for data in ({}, unavailable, ambiguous, wrong_os):
            with self.subTest(data=data), self.assertRaises(ValueError):
                simulator.select(data, "iPhone 17 Pro", self.runtime)


class NativeResultTests(unittest.TestCase):
    def summary(self):
        return {
            "result": "Passed", "failedTests": 0, "skippedTests": 0,
            "expectedFailures": 0, "passedTests": 5, "totalTestCount": 5,
        }

    def test_complete_suite_passes(self):
        policy.check_native_summary(self.summary())

    def test_empty_partial_failed_and_skipped_suites_cannot_pass(self):
        for key, value in (
            ("passedTests", 0), ("passedTests", 4), ("totalTestCount", 6),
            ("failedTests", 1), ("skippedTests", 1), ("expectedFailures", 1),
            ("result", "Failed"),
        ):
            summary = self.summary()
            summary[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                policy.check_native_summary(summary)


class HostDeploymentTests(unittest.TestCase):
    def record(self, minimum="14.0", platform="macos"):
        return (
            "Load command 1\n"
            "       cmd LC_BUILD_VERSION\n"
            "   cmdsize 24\n"
            f"  platform {platform}\n"
            "       sdk 27.0\n"
            f"     minos {minimum}\n"
            "    ntools 0\n"
        )

    def test_all_host_objects_and_dylib_match_the_package_floor(self):
        headers = self.record("11.0") + self.record("14.0")
        self.assertEqual(policy.check_host_deployment(headers), 2)
        self.assertEqual(policy.check_host_deployment(self.record(platform="MACOS")), 1)

    def test_any_sdk_default_above_floor_fails(self):
        for version in ("14.0.1", "14.1", "26.5", "27.0"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                policy.check_host_deployment(self.record("11.0") + self.record(version))

    def test_missing_malformed_or_wrong_platform_cannot_pass(self):
        for headers in (
            "", "Archive: unreadable.a", self.record("n/a"),
            self.record("14.0", "iossimulator"), self.record().replace("minos 14.0", ""),
        ):
            with self.subTest(headers=headers), self.assertRaises(ValueError):
                policy.check_host_deployment(headers)

    def test_legacy_macos_minimum_record(self):
        self.assertEqual(policy.check_host_deployment(
            "Load command 1\ncmd LC_VERSION_MIN_MACOSX\nversion 11.0\nsdk 14.0\n"
        ), 1)


if __name__ == "__main__":
    unittest.main()
