#!/usr/bin/env bash
# Compare the live drift schema with the committed dump (docs/council/02-architecture.md section 7.2).
#   - no lib/data/db/app_database.dart yet         -> notice, pass
#   - no committed drift_schemas/drift_schema_v*.json -> warning, pass (dispatch commit-generated.yml)
#   - current schemaVersion N has no committed dump  -> warning, pass (new version; commit it)
#   - committed vN differs from the live vN dump    -> FAIL (schema changed without a schemaVersion bump)
# Requires a prepared checkout (tool/ci_prepare.sh: pub get + build_runner).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

DB_FILE="lib/data/db/app_database.dart"
SCHEMA_DIR="drift_schemas"

PY=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 \
     && "$candidate" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1; then
    PY="$candidate"; break
  fi
done
[ -n "$PY" ] || { echo "::error::check_schema_dump.sh: python3 not found" >&2; exit 1; }

if [ ! -f "$DB_FILE" ]; then
  echo "::notice title=schema dump::${DB_FILE} does not exist yet; schema check skipped."
  exit 0
fi

shopt -s nullglob
committed=("$SCHEMA_DIR"/drift_schema_v*.json)
shopt -u nullglob
if [ "${#committed[@]}" -eq 0 ]; then
  echo "::warning title=schema dump::No committed ${SCHEMA_DIR}/drift_schema_v*.json. Dispatch commit-generated.yml on main."
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

dart run drift_dev schema dump "$DB_FILE" "$tmp/"

shopt -s nullglob
live=("$tmp"/drift_schema_v*.json)
shopt -u nullglob
if [ "${#live[@]}" -ne 1 ]; then
  echo "::error::drift_dev schema dump produced ${#live[@]} files in $tmp (expected exactly 1)" >&2
  ls -la "$tmp" >&2
  exit 1
fi

live_file="${live[0]}"
name="$(basename "$live_file")"
target="$SCHEMA_DIR/$name"

if [ ! -f "$target" ]; then
  echo "::warning title=schema dump::${name} is not committed yet (schemaVersion was bumped). Dispatch commit-generated.yml after merging, and add the migration step + migration test."
  exit 0
fi

# Semantic JSON comparison (formatting differences are ignored).
if "$PY" - "$target" "$live_file" <<'PYEOF'
import json, sys
a = json.load(open(sys.argv[1], encoding="utf-8"))
b = json.load(open(sys.argv[2], encoding="utf-8"))
sys.exit(0 if a == b else 1)
PYEOF
then
  echo "check_schema_dump: ${name} matches the committed dump."
else
  echo "::error title=schema dump::The drift schema changed but schemaVersion did not: ${target} differs from the live dump. Bump schemaVersion, add an additive migration step (Arch 7.2), then dispatch commit-generated.yml." >&2
  diff -u <("$PY" -m json.tool --sort-keys "$target") <("$PY" -m json.tool --sort-keys "$live_file") | head -200 >&2 || true
  exit 1
fi
