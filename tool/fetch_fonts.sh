#!/usr/bin/env bash
# Ensure the Hind Siliguri fonts are present and match tool/fonts.sha256.
#
# The TTFs and OFL.txt are COMMITTED under assets/fonts/hind_siliguri/, so normally this
# only verifies them. A missing or mismatching file is (re)downloaded from the pinned
# fork commit and verified; anything that still mismatches fails the script.
# Provenance: https://github.com/bdeshi/Hind-Siliguri (fixes the malformed ১ glyph).
#   TTF/HindSiliguri-<Weight>.ttf   -> assets/fonts/hind_siliguri/HindSiliguri-<Weight>.ttf
#   LICENSE.md (SIL OFL 1.1)        -> assets/fonts/hind_siliguri/OFL.txt
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

COMMIT="247a09fb574ba113068300e7118baab0daa2ad21"
RAW="https://raw.githubusercontent.com/bdeshi/Hind-Siliguri/${COMMIT}"
LIST="tool/fonts.sha256"

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

source_url() {
  case "$(basename "$1")" in
    OFL.txt) echo "${RAW}/LICENSE.md" ;;
    *.ttf)   echo "${RAW}/TTF/$(basename "$1")" ;;
    *) echo "fetch_fonts.sh: no source known for $1" >&2; return 1 ;;
  esac
}

[ -f "$LIST" ] || { echo "::error::$LIST not found" >&2; exit 1; }

fail=0
while read -r want path; do
  [ -z "${want:-}" ] && continue
  case "$want" in \#*) continue ;; esac
  path="${path#\*}"            # tolerate binary-mode marker
  path="${path%$'\r'}"
  if [ -f "$path" ] && [ "$(sha256_of "$path")" = "$want" ]; then
    echo "ok           $path"
    continue
  fi
  mkdir -p "$(dirname "$path")"
  url="$(source_url "$path")"
  echo "download     $url"
  curl -fsSL --retry 4 --retry-delay 3 -o "${path}.part" "$url"
  got="$(sha256_of "${path}.part")"
  if [ "$got" != "$want" ]; then
    rm -f "${path}.part"
    echo "::error::checksum mismatch for ${path}: got ${got}, want ${want}" >&2
    fail=1
    continue
  fi
  mv -f "${path}.part" "$path"
  echo "ok (fetched) $path"
done < "$LIST"

exit "$fail"
