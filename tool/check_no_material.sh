#!/usr/bin/env bash
# "No visible Material" check for the Bhor design system
# (docs/council/10-design-system-bhor.md, Enforcement; migration rules in
# docs/council/11-ds-migration-guide.md).
#
# Scans lib/app/** and lib/features/** (generated code and // comments
# ignored) for:
#   W. Material widget / API uses: ElevatedButton, FilledButton, TextButton, OutlinedButton,
#      IconButton, FloatingActionButton, TextField, TextFormField, Card, Chip, FilterChip,
#      ChoiceChip, InputChip, AppBar, NavigationBar, NavigationRail, BottomNavigationBar,
#      Scaffold, AlertDialog, Dialog, showDialog, showModalBottomSheet, SnackBar,
#      ScaffoldMessenger, showDatePicker, showTimePicker, Switch, Checkbox, Radio, ListTile,
#      TabBar, InkWell, Material(, DropdownButton, PopupMenuButton, Tooltip,
#      CircularProgressIndicator, LinearProgressIndicator.
#   I. Full `import 'package:flutter/material.dart';` (without `show`). Non-visual types
#      (Icons, ThemeMode, ...) must be imported with `show`; prefer package:flutter/widgets.dart.
#
# Prints violation counts per area (lib/features/<feature>, lib/app/<dir>) and the total.
# Exit 1 when anything is found (a blocking CI step). Needs GNU grep with -P.
# Usage: bash tool/check_no_material.sh [--list]   (--list prints every hit)
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

list=0
for arg in "$@"; do
  case "$arg" in
    --list) list=1 ;;
    *) echo "check_no_material.sh: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

WIDGETS='\b(ElevatedButton|FilledButton|TextButton|OutlinedButton|IconButton|FloatingActionButton|TextField|TextFormField|Card|Chip|FilterChip|ChoiceChip|InputChip|AppBar|NavigationBar|NavigationRail|BottomNavigationBar|Scaffold|AlertDialog|Dialog|SnackBar|Switch|Checkbox|Radio|ListTile|TabBar|InkWell|Material|DropdownButton|PopupMenuButton|Tooltip|CircularProgressIndicator|LinearProgressIndicator)\b\s*(\(|<|\.[a-z]\w*\s*\()|\b(showDialog|showModalBottomSheet|showDatePicker|showTimePicker)\s*(<[^>]*>)?\s*\(|\bScaffoldMessenger\s*\.'
FULL_IMPORT="^\s*import\s+['\"]package:flutter/material\.dart['\"]\s*;"

mapfile -t FILES < <(
  for root in lib/app lib/features; do
    [ -d "$root" ] || continue
    find "$root" -type f -name '*.dart' ! -name '*.g.dart'
  done | sort
)

declare -A per_area=()
total=0

area_of() { # lib/features/x/... -> lib/features/x ; lib/app/x/... -> lib/app/x ; lib/app/f.dart -> lib/app
  local f="$1"
  case "$f" in
    lib/features/*) echo "$f" | cut -d/ -f1-3 ;;
    lib/app/*/*) echo "$f" | cut -d/ -f1-3 ;;
    *) echo "lib/app" ;;
  esac
}

hits() { # PCRE FILE : matching non-comment lines as file:line:text
  grep -HnP -- "$1" "$2" 2>/dev/null | grep -vP '^[^:]+:[0-9]+:\s*(//|\*|/\*)' || true
}

for f in "${FILES[@]}"; do
  n=0
  w="$(hits "$WIDGETS" "$f")"
  i="$(hits "$FULL_IMPORT" "$f")"
  for block in "$w" "$i"; do
    [ -n "$block" ] || continue
    c=$(printf '%s\n' "$block" | wc -l)
    n=$((n + c))
    if [ "$list" -eq 1 ]; then printf '%s\n' "$block"; fi
  done
  if [ "$n" -gt 0 ]; then
    a="$(area_of "$f")"
    per_area[$a]=$(( ${per_area[$a]:-0} + n ))
    total=$((total + n))
  fi
done

summary="$(
  echo "| area | Material uses |"
  echo "|---|---|"
  for a in $(printf '%s\n' "${!per_area[@]}" | sort); do
    echo "| \`$a\` | ${per_area[$a]} |"
  done
  echo "| **total** | **$total** |"
)"

echo "check_no_material: ${#FILES[@]} files scanned"
printf '%s\n' "$summary"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### No visible Material (Bhor)"
    printf '%s\n' "$summary"
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [ "$total" -gt 0 ]; then
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    echo "::error title=no-material::${total} Material widget use(s) left in lib/app and lib/features (see job summary)"
  fi
  exit 1
fi
echo "check_no_material: OK"
