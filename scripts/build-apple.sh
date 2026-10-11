#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-all}"
case "$MODE" in
  simulator|device|all) ;;
  *) printf 'Usage: bash scripts/build-apple.sh [simulator|device|all]\n' >&2; exit 2 ;;
esac

cd "$ROOT"
# Match RookKit's host-test floor for Rust and bundled SQLCipher/OpenSSL objects.
export MACOSX_DEPLOYMENT_TARGET=14.0
export IPHONEOS_DEPLOYMENT_TARGET=17.0
if [[ "$(uname -s)" != Darwin || "$(uname -m)" != arm64 ]]; then
  printf 'Rook Apple builds currently require Apple Silicon macOS.\n' >&2
  exit 1
fi
XCODEGEN_VERSION="$(python3 -c 'import json; print(json.load(open("scripts/tool-versions.json"))["tools"]["xcodegen"]["version"])')"
if [[ "$(xcodegen --version)" != "Version: $XCODEGEN_VERSION" ]]; then
  printf 'XcodeGen %s is required. Run: python3 scripts/install-tools.py xcodegen\n' "$XCODEGEN_VERSION" >&2
  exit 1
fi
swift scripts/generate-icon.swift
cargo build --locked --release -p rook-ffi
mkdir -p target/apple-ffi/macos
cp target/release/librook_ffi.a target/apple-ffi/macos/
mkdir -p apple/RookKit/Sources/RookKit/Generated apple/RookKit/Sources/RookFFI
cargo run --locked --quiet -p rook-ffi --features bindgen --bin uniffi-bindgen -- \
  generate target/release/librook_ffi.dylib --language swift \
  --out-dir apple/RookKit/Sources/RookKit/Generated
cp apple/RookKit/Sources/RookKit/Generated/RookFFI.h apple/RookKit/Sources/RookFFI/
cp apple/RookKit/Sources/RookKit/Generated/RookFFI.modulemap apple/RookKit/Sources/RookFFI/module.modulemap

if [[ "$MODE" == simulator || "$MODE" == all ]]; then
  cargo build --locked --release -p rook-ffi --target aarch64-apple-ios-sim
  mkdir -p target/apple-ffi/ios-simulator
  cp target/aarch64-apple-ios-sim/release/librook_ffi.a target/apple-ffi/ios-simulator/
fi
if [[ "$MODE" == device || "$MODE" == all ]]; then
  cargo build --locked --release -p rook-ffi --target aarch64-apple-ios
  mkdir -p target/apple-ffi/ios-device
  cp target/aarch64-apple-ios/release/librook_ffi.a target/apple-ffi/ios-device/
fi
cd apple
xcodegen generate --quiet
printf '\nRook bindings and Xcode project generated. Open apple/Rook.xcodeproj.\n'
