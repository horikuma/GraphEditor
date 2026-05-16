#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Debug}"
APP_PATH="${REPO_ROOT}/.build/Build/Products/${CONFIGURATION}/GraphEditor.app"
BUNDLE_IDENTIFIER="com.example.GraphEditor"

if [[ ! -d "${APP_PATH}" ]]; then
  "${SCRIPT_DIR}/build.sh" -configuration "${CONFIGURATION}" build
fi

if pgrep -x GraphEditor >/dev/null; then
  osascript -e "tell application id \"${BUNDLE_IDENTIFIER}\" to quit" >/dev/null 2>&1 || true

  while pgrep -x GraphEditor >/dev/null; do
    sleep 0.1
  done
fi

open "${APP_PATH}" --args "$@"
