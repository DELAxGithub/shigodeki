#!/bin/bash
set -euo pipefail

# Firebase configuration copy script (Xcode 16 User Script Sandboxing compliant)
# - Reads only declared input files
# - Writes only to SCRIPT_OUTPUT_FILE_* destinations

if [ "${CONFIGURATION}" = "Debug" ]; then
  SRC="${SRCROOT}/Firebase/Config/GoogleService-Info-Dev.plist"
  echo "Using Firebase configuration for Development"
else
  SRC="${SRCROOT}/Firebase/Config/GoogleService-Info-Prod.plist"
  echo "Using Firebase configuration for Production"
fi

copy_to() {
  local dest="${1:-}"
  # If the output slot isn't defined, skip silently
  [ -z "${dest}" ] && return 0
  mkdir -p "$(dirname "${dest}")"
  cp "${SRC}" "${dest}"
  echo "Copied Firebase config to ${dest}"
}

# Write to the outputs declared in the Run Script build phase
copy_to "${SCRIPT_OUTPUT_FILE_0:-}"
copy_to "${SCRIPT_OUTPUT_FILE_1:-}"
