#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUFF="${REPO_ROOT}/.venv/bin/ruff"
DEBUG_OUTPUT=0
XCODEBUILD_ARGS=()

for arg in "$@"; do
  case "${arg}" in
    --debug | debug)
      DEBUG_OUTPUT=1
      ;;
    *)
      XCODEBUILD_ARGS+=("${arg}")
      ;;
  esac
done

cd "${REPO_ROOT}"

run_xcodebuild() {
  xcodebuild \
    -project "${REPO_ROOT}/GraphEditor.xcodeproj" \
    -scheme GraphEditor \
    -destination "platform=macOS,arch=arm64" \
    -derivedDataPath "${REPO_ROOT}/.build" \
    "${XCODEBUILD_ARGS[@]+"${XCODEBUILD_ARGS[@]}"}"
}

"${RUFF}" check --fix .
"${RUFF}" format .
swiftlint lint --strict --quiet

if [[ "${DEBUG_OUTPUT}" -eq 1 ]]; then
  run_xcodebuild
else
  run_xcodebuild > /dev/null
fi
