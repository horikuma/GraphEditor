#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

uv run ruff check --fix .
uv run ruff format .
swiftlint lint --strict

xcodebuild \
  -project "${REPO_ROOT}/GraphEditor.xcodeproj" \
  -scheme GraphEditor \
  -derivedDataPath "${REPO_ROOT}/.build" \
  "$@"
