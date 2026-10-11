"""Classify changes and fail closed when a required CI prerequisite is absent."""

import argparse
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

CODE_JOBS = ("rust", "msrv", "dependencies", "apple")
ALWAYS_JOBS = ("classify", "hygiene")
PR_TITLE = re.compile(r"^(feat|fix|docs|test|refactor|chore)(\([^()\n]+\))?!?: \S[^\n]*$")


def code_required(paths):
    if not paths:
        raise ValueError("An empty change list cannot be classified as documentation-only")
    for value in paths:
        path = PurePosixPath(value)
        if (
            path.is_absolute()
            or ".." in path.parts
            or path.suffix != ".md"
            or not (
                len(path.parts) == 1
                or path.parts[0] == "docs"
                or path.parts[:2] == (".github", "ISSUE_TEMPLATE")
                or value == ".github/pull_request_template.md"
                or path.parts[:2] == (".impeccable", "surfaces")
            )
        ):
            return True
    return False


def check_gate(needs):
    expected = set(ALWAYS_JOBS + CODE_JOBS)
    if set(needs) != expected:
        raise ValueError("CI prerequisite list changed without updating the gate policy")
    for job in ALWAYS_JOBS:
        if needs[job]["result"] != "success":
            raise ValueError(f"Required job {job}: {needs[job]['result']}")
    classification = needs["classify"]["outputs"].get("code")
    if classification not in ("true", "false"):
        raise ValueError("Missing or invalid change-classification output")
    required = "success" if classification == "true" else "skipped"
    for job in CODE_JOBS:
        if needs[job]["result"] != required:
            raise ValueError(f"Job {job}: expected {required}, got {needs[job]['result']}")


def check_native_summary(summary):
    if (
        summary["result"] != "Passed"
        or summary["failedTests"] != 0
        or summary["skippedTests"] != 0
        or summary["expectedFailures"] != 0
        or summary["passedTests"] < 5
        or summary["totalTestCount"] != summary["passedTests"]
    ):
        raise ValueError("The complete prototype UI suite did not pass without skips")


def check_host_deployment(headers):
    count = 0
    for command in headers.split("Load command"):
        if re.search(r"\bcmd LC_BUILD_VERSION\b", command):
            platform = re.search(r"^\s*platform (\S+)\s*$", command, re.MULTILINE)
            minimum = re.search(r"^\s*minos (\S+)\s*$", command, re.MULTILINE)
            if platform is None or platform[1].lower() != "macos":
                raise ValueError("Host archive contains a non-macOS or missing platform")
        elif re.search(r"\bcmd LC_VERSION_MIN_MACOSX\b", command):
            minimum = re.search(r"^\s*version (\S+)\s*$", command, re.MULTILINE)
        else:
            continue
        if minimum is None or not re.fullmatch(r"\d+(\.\d+){0,2}", minimum[1]):
            raise ValueError("Host object has invalid deployment metadata")
        version = tuple(int(part) for part in minimum[1].split("."))
        version += (0,) * (3 - len(version))
        if version > (14, 0, 0):
            raise ValueError(f"Host object requires macOS {minimum[1]}, above RookKit's macOS 14 floor")
        count += 1
    if count == 0:
        raise ValueError("Host deployment metadata is missing; compatibility was not checked")
    return count


def classify(event, base, head):
    if event != "pull_request":
        return True
    for commit in (base, head):
        if not re.fullmatch(r"[0-9a-f]{40}", commit):
            raise ValueError("PR base/head must be complete commit SHAs")
    result = subprocess.run(
        ["git", "diff", "--no-renames", "--name-only", "-z", f"{base}...{head}"],
        check=True, stdout=subprocess.PIPE,
    )
    return code_required(result.stdout.decode().rstrip("\0").split("\0") if result.stdout else [])


def check_files():
    result = subprocess.run(["git", "ls-files", "-z"], check=True, stdout=subprocess.PIPE)
    forbidden = []
    for name in result.stdout.decode().split("\0"):
        if not name:
            continue
        path = PurePosixPath(name)
        if (
            path.parts[0] in ("target", "node_modules")
            or name.startswith(("apple/Rook.xcodeproj/", ".impeccable/review/", ".impeccable/build/"))
            or name.startswith(("apple/RookKit/Sources/RookKit/Generated/", "apple/RookKit/Sources/RookFFI/"))
            or path.name.startswith(".env")
            or name.endswith((".local.md", ".sqlite", ".sqlite-journal", ".sqlite-wal", ".sqlite-shm",
                              ".rook.age", ".p12", ".p8", ".pem", ".key", ".pfx",
                              ".mobileprovision", ".tfstate", ".tfplan"))
            or ".tfstate." in path.name
            or "xcuserdata" in path.parts
        ):
            forbidden.append(name)
    if forbidden:
        raise ValueError("Forbidden tracked artifacts: " + ", ".join(forbidden))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command", choices=("classify", "gate", "title", "files", "native-result", "host-deployment")
    )
    args = parser.parse_args()
    if args.command == "classify":
        code = classify(os.environ["EVENT_NAME"], os.environ.get("BASE_SHA", ""), os.environ.get("HEAD_SHA", ""))
        value = f"code={str(code).lower()}\n"
        with Path(os.environ["GITHUB_OUTPUT"]).open("a") as output:
            output.write(value)
        print(value, end="")
    elif args.command == "gate":
        check_gate(json.loads(os.environ["NEEDS_JSON"]))
        print("All required checks passed; only explicitly allowed jobs were skipped.")
    elif args.command == "title":
        if not PR_TITLE.fullmatch(os.environ["PR_TITLE"]):
            raise ValueError("PR title must use feat:, fix:, docs:, test:, refactor:, or chore: (optional scope/!)")
    elif args.command == "native-result":
        summary = json.load(sys.stdin)
        check_native_summary(summary)
        print(f"Native suite passed: {summary['passedTests']} tests without skips")
    elif args.command == "host-deployment":
        count = check_host_deployment(sys.stdin.read())
        print(f"Host deployment verified: {count} Mach-O records require macOS 14 or earlier")
    else:
        check_files()


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
