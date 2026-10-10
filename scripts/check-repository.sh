#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
export PATH="$PWD/target/ci-tools/bin:$PATH"
actionlint .github/workflows/*.yml
shellcheck scripts/*.sh
python3 -m unittest discover -s scripts/tests
npm run lint:markdown
