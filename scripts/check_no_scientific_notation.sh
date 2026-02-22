#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${ROOT_DIR}/Effects"
PATTERN='(?<![A-Za-z_0-9])[-+]?(?:\d+(?:\.\d*)?|\.\d+)[eE][-+]?\d+(?![A-Za-z_0-9])'

if ! command -v rg >/dev/null 2>&1; then
  echo "error: ripgrep (rg) is required for this check."
  exit 2
fi

if rg -n --pcre2 "${PATTERN}" "${TARGET_DIR}" >/tmp/jsfx_sci_notation_matches.txt; then
  echo "error: scientific-notation numeric literals are not allowed in Effects/."
  echo
  cat /tmp/jsfx_sci_notation_matches.txt
  rm -f /tmp/jsfx_sci_notation_matches.txt
  exit 1
fi

rm -f /tmp/jsfx_sci_notation_matches.txt
echo "ok: no scientific-notation numeric literals found in Effects/."
