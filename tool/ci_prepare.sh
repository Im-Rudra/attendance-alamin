#!/usr/bin/env bash
# Prepare a checkout for analyze/test/build (every CI job; ubuntu and windows-latest via `shell: bash`).
#   1. merge ARB fragments  (before pub get: `generate: true` may run gen-l10n during pub get)
#   2. flutter pub get
#   3. flutter gen-l10n
#   4. dart run build_runner build --delete-conflicting-outputs   (skip with --no-codegen)
# Usage: bash tool/ci_prepare.sh [--no-codegen]
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

codegen=1
for arg in "$@"; do
  case "$arg" in
    --no-codegen) codegen=0 ;;
    *) echo "ci_prepare.sh: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# python3 on Linux; on Windows runners `python3` may be the Microsoft Store stub, so probe it.
PY=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 \
     && "$candidate" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1; then
    PY="$candidate"
    break
  fi
done
if [ -z "$PY" ]; then
  echo "::error::ci_prepare.sh: no working python3/python (>= 3.8) on PATH" >&2
  exit 1
fi

echo "::group::merge ARB fragments ($PY)"
"$PY" tool/merge_arb.py
echo "::endgroup::"

echo "::group::flutter pub get"
flutter pub get
echo "::endgroup::"

echo "::group::flutter gen-l10n"
flutter gen-l10n
echo "::endgroup::"

if [ "$codegen" -eq 1 ]; then
  echo "::group::build_runner"
  dart run build_runner build --delete-conflicting-outputs
  echo "::endgroup::"
else
  echo "ci_prepare.sh: --no-codegen, build_runner skipped"
fi
