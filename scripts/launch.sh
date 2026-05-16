#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Debug}"
APP_PATH="${REPO_ROOT}/.build/Build/Products/${CONFIGURATION}/GraphEditor.app"

if [[ ! -d "${APP_PATH}" ]]; then
  "${SCRIPT_DIR}/build.sh" -configuration "${CONFIGURATION}" build
fi

open "${APP_PATH}" --args "$@"
