#!/usr/bin/env bash
# Layering / purity rules (docs/council/04-plan.md sections 2.4, 2.10 and M0-A).
# Fails on:
#   1. lib/core, lib/domain: imports/exports other than dart:* (minus dart:io/ui/html/js*/ffi/isolate),
#      package:uuid, package:crypto, package:archive, and package:attendance_alamin/{core,domain}/.
#   2. DateTime.now( anywhere in lib/ except lib/core/time/clock.dart.
#   3. Colour literals (Color(0x, Color.fromARGB, Color.fromRGBO, Color.from(, Colors.<x> other than
#      Colors.transparent) outside lib/app/theme/.
#   4. import 'package:attendance_alamin/data/db...' under lib/features/.
#   5. package:flutter_local_notifications / package:timezone outside lib/data/notifications/.
#   6. dart:io under lib/ except lib/data/db/connection/*_native.dart.
# Generated code (*.g.dart, lib/l10n/generated/) and comment-only lines are ignored.
# Needs GNU grep with -P (ubuntu runners; Git Bash also works).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ ! -d lib ]; then
  echo "check_domain_purity: no lib/ directory" >&2
  exit 1
fi

violations=0

report() { # file:line:text  rule
  local loc="$1" rule="$2"
  local file="${loc%%:*}" rest="${loc#*:}"
  local line="${rest%%:*}" text="${rest#*:}"
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    echo "::error file=${file},line=${line},title=purity::${rule}"
  fi
  echo "PURITY ${file}:${line}: ${rule}: $(echo "$text" | sed 's/^[[:space:]]*//')"
  violations=$((violations + 1))
}

# All hand-written Dart files under the given roots (generated code excluded).
dart_files() {
  local root
  for root in "$@"; do
    [ -d "$root" ] || continue
    find "$root" -type f -name '*.dart' \
      ! -name '*.g.dart' \
      ! -path 'lib/l10n/generated/*'
  done | sort
}

# scan RULE PCRE FILES... : report lines matching PCRE that are not // comments.
scan() {
  local rule="$1" pattern="$2"
  shift 2
  [ "$#" -gt 0 ] || return 0
  local hit
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    report "$hit" "$rule"
  done < <(grep -HnP -- "$pattern" "$@" 2>/dev/null | grep -vP '^[^:]+:[0-9]+:\s*(//|\*|/\*)' || true)
}

mapfile -t ALL < <(dart_files lib)
mapfile -t PURE < <(dart_files lib/core lib/domain)

# 1. core/domain imports
if [ "${#PURE[@]}" -gt 0 ]; then
  allowed="dart:(?!io\b|ui\b|html\b|js\b|js_interop\b|js_util\b|ffi\b|isolate\b|mirrors\b)[a-z_]+|package:(uuid|crypto|archive)/|package:attendance_alamin/(core|domain)/"
  scan "core/domain may only import dart:* (no io/ui/html/js/ffi/isolate), uuid, crypto, archive and core/domain" \
    "^\s*(import|export)\s+['\"](?!(${allowed}))" "${PURE[@]}"
fi

# 2. DateTime.now( only in clock.dart
mapfile -t NOT_CLOCK < <(printf '%s\n' "${ALL[@]}" | grep -vx 'lib/core/time/clock.dart' || true)
scan "DateTime.now() is only allowed in lib/core/time/clock.dart (use Clock / todayProvider)" \
  'DateTime\s*\.\s*now\s*\(' "${NOT_CLOCK[@]}"

# 3. colour literals outside lib/app/theme/
mapfile -t NOT_THEME < <(printf '%s\n' "${ALL[@]}" | grep -v '^lib/app/theme/' || true)
scan "colour literal outside lib/app/theme/ (use context.aurora / severity / attendance tokens)" \
  '\bColor\s*\(\s*0x|\bColor\s*\.\s*(fromARGB|fromRGBO|from)\s*\(|\bColors\s*\.\s*(?!transparent\b)[A-Za-z]' \
  "${NOT_THEME[@]}"

# 4. features never import data/db
mapfile -t FEATURES < <(dart_files lib/features)
scan "features must not import data/db (use repository interfaces / *_providers.dart)" \
  "^\s*(import|export)\s+['\"]package:attendance_alamin/data/db" "${FEATURES[@]}"

# 5. notifications packages only in data/notifications
mapfile -t NOT_NOTIF < <(printf '%s\n' "${ALL[@]}" | grep -v '^lib/data/notifications/' || true)
scan "flutter_local_notifications/timezone may only be imported in lib/data/notifications/" \
  "^\s*(import|export)\s+['\"]package:(flutter_local_notifications|timezone)/" "${NOT_NOTIF[@]}"

# 6. dart:io only in lib/data/db/connection/*_native.dart
mapfile -t NOT_NATIVE < <(printf '%s\n' "${ALL[@]}" | grep -vP '^lib/data/db/connection/[^/]+_native\.dart$' || true)
scan "dart:io is only allowed in lib/data/db/connection/*_native.dart (web build)" \
  "^\s*(import|export)\s+['\"]dart:io['\"]" "${NOT_NATIVE[@]}"

# Multi-line imports: `import` on one line and the URI on the next are not used in this codebase;
# dart format keeps the URI on the import line.

if [ "$violations" -gt 0 ]; then
  echo "check_domain_purity: ${violations} violation(s)" >&2
  exit 1
fi
echo "check_domain_purity: OK (${#ALL[@]} files scanned, ${#PURE[@]} in core/domain)"
