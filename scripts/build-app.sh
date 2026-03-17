#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="${ROOT_DIR}/.deriveddata"
DIST_DIR="${ROOT_DIR}/dist"
APP_PATH="${DERIVED_DATA_DIR}/Build/Products/Release/YabaiBar.app"
PROJECT_PATH="${ROOT_DIR}/YabaiBar.xcodeproj"

cd "${ROOT_DIR}"

if [[ ! -d "${PROJECT_PATH}" ]]; then
  if ! command -v xcodegen >/dev/null 2>&1; then
    printf 'Missing YabaiBar.xcodeproj and xcodegen is not installed.\n' >&2
    exit 1
  fi

  xcodegen generate
fi

rm -rf "${DERIVED_DATA_DIR}" "${DIST_DIR}"

xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme YabaiBar \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "${DERIVED_DATA_DIR}" \
  build

mkdir -p "${DIST_DIR}"
cp -R "${APP_PATH}" "${DIST_DIR}/YabaiBar.app"

printf 'Built app: %s\n' "${DIST_DIR}/YabaiBar.app"
