#!/usr/bin/env bash
# Download drift's web assets into web/ and verify them (docs/council/02-architecture.md section 1.6).
# Fails if pubspec.lock does not resolve drift to DRIFT_VERSION or if a checksum differs.
# Bumping drift = update DRIFT_VERSION, both hashes and pubspec.yaml in one PR.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

DRIFT_VERSION="2.35.4"
BASE_URL="https://github.com/simolus3/drift/releases/download/drift-${DRIFT_VERSION}"
ASSETS=(
  "sqlite3.wasm e7451780e78c56ff864fe9317a0fbcd6aeb2e8de3beba7f5efd963202f7ec3d9"
  "drift_worker.js 48c950cd8e3bc3cddb34816c860e228be8832bef07a297c27e9907c057ff8162"
)

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

if [ ! -f pubspec.lock ]; then
  echo "::error::pubspec.lock not found. Run bootstrap.yml (it commits pubspec.lock) and flutter pub get first." >&2
  exit 1
fi

# pubspec.lock entry:   "  drift:" ... "    version: \"2.35.4\""
locked="$(awk '
  /^  drift:[[:space:]]*$/ { in_drift = 1; next }
  in_drift && /^  [^ ]/   { in_drift = 0 }
  in_drift && /^    version:/ { gsub(/[" ]/, "", $2); print $2; exit }
' FS=':' pubspec.lock)"

if [ "$locked" != "$DRIFT_VERSION" ]; then
  echo "::error::pubspec.lock resolves drift to '${locked:-<none>}', but web assets are pinned to ${DRIFT_VERSION}." >&2
  exit 1
fi

if [ ! -d web ]; then
  echo "::error::web/ does not exist. Run bootstrap.yml first." >&2
  exit 1
fi

for entry in "${ASSETS[@]}"; do
  name="${entry%% *}"
  want="${entry##* }"
  dest="web/${name}"
  if [ -f "$dest" ] && [ "$(sha256_of "$dest")" = "$want" ]; then
    echo "ok (cached)  $dest"
    continue
  fi
  curl -fsSL --retry 4 --retry-delay 3 -o "${dest}.part" "${BASE_URL}/${name}"
  got="$(sha256_of "${dest}.part")"
  if [ "$got" != "$want" ]; then
    rm -f "${dest}.part"
    echo "::error::checksum mismatch for ${name}: got ${got}, want ${want}" >&2
    exit 1
  fi
  mv -f "${dest}.part" "$dest"
  echo "ok           $dest  ($want)"
done
