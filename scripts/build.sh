#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUFF="${REPO_ROOT}/.venv/bin/ruff"

cd "${REPO_ROOT}"

"${RUFF}" check --fix .
"${RUFF}" format .
swiftlint lint --strict --quiet

xcodebuild \
  -project "${REPO_ROOT}/GraphEditor.xcodeproj" \
  -scheme GraphEditor \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "${REPO_ROOT}/.build" \
  "$@" \
  > /dev/null
