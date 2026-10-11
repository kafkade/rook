#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
ROOT="$PWD"
export PATH="$ROOT/target/ci-tools/bin:$PATH"
if [[ "${CI:-}" == true ]]; then
  EXPECTED="$(python3 -c 'import json; print(json.load(open("scripts/tool-versions.json"))["xcode"])')"
  if [[ "$(xcodebuild -version | head -1)" != "Xcode $EXPECTED" ]]; then
    printf 'CI requires Xcode %s; set DEVELOPER_DIR to the pinned installation.\n' "$EXPECTED" >&2
    exit 1
  fi
fi
SIMULATOR="$(python3 scripts/simulator.py)"
rustup target add aarch64-apple-ios-sim aarch64-apple-ios
bash scripts/build-apple.sh all
xcrun llvm-objdump --macho --private-headers target/apple-ffi/macos/librook_ffi.a \
  | python3 scripts/ci-policy.py host-deployment
xcrun vtool -show-build target/release/librook_ffi.dylib \
  | python3 scripts/ci-policy.py host-deployment
swift test --package-path apple/RookKit \
  --scratch-path "$ROOT/target/ci-swift" \
  -Xlinker -L -Xlinker "$ROOT/target/apple-ffi/macos" --quiet
xcodebuild -project apple/Rook.xcodeproj -scheme Rook \
  -destination 'generic/platform=iOS' -derivedDataPath target/ci-device \
  build CODE_SIGNING_ALLOWED=NO -quiet
xcrun simctl bootstatus "$SIMULATOR" -b
mkdir -p target/ci-results
RESULT="$ROOT/target/ci-results/$(python3 -c 'import uuid; print(uuid.uuid4())').xcresult"
xcodebuild -project apple/Rook.xcodeproj -scheme Rook \
  -destination "platform=iOS Simulator,id=$SIMULATOR" \
  -derivedDataPath target/ci-apple -resultBundlePath "$RESULT" \
  -collect-test-diagnostics never -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 \
  test -quiet
xcrun xcresulttool get test-results summary --path "$RESULT" --compact \
  | python3 scripts/ci-policy.py native-result
