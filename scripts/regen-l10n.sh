#!/usr/bin/env bash
# regen-l10n.sh — Regenerate L10n.swift from Localizable.xcstrings via SwiftGen.
# Run after editing HappySpeech/Resources/Localizable.xcstrings.
#
# Usage:
#   ./scripts/regen-l10n.sh
#
# Requirements:
#   brew install swiftgen
#
# Output:
#   HappySpeech/Generated/L10n.swift  (overwritten in place)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCSTRINGS="${REPO_ROOT}/HappySpeech/Resources/Localizable.xcstrings"
OUTPUT_DIR="${REPO_ROOT}/HappySpeech/Generated"

if ! command -v swiftgen &>/dev/null; then
  echo "swiftgen not found — install with: brew install swiftgen" >&2
  exit 1
fi

if [[ ! -f "${XCSTRINGS}" ]]; then
  echo "Localizable.xcstrings not found at ${XCSTRINGS}" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

swiftgen run xcstrings \
  --input "${XCSTRINGS}" \
  --output "${OUTPUT_DIR}/L10n.swift" \
  --param enumName=L10n \
  --param publicAccess=false

echo "L10n.swift regenerated at ${OUTPUT_DIR}/L10n.swift"
