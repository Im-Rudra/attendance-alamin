#!/usr/bin/env bash
# Container rule check (docs/council/16-windows-rebuild-plan.md W1-A, G1).
#
# Features never pick a container themselves: they call showBhorPanel (with a
# BhorPanelKind), showBhorConfirm or showBhorMenu, and the design system
# decides sheet / side panel / dialog / popover per window. This scans
# lib/features/** (generated code and // comments ignored) for direct calls
# of showBhorSheet( and showBhorDialog(.
#
# tool/containers_allowlist.txt lists the offenders that existed when the
# rule landed, one "<file> <function> <count>" line each. Wave-2 builders
# remove their lines as they migrate; the list must reach zero.
#   - a call not covered by the allowlist (new file, or more calls than the
#     listed count) fails;
#   - an allowlist line whose file now has fewer calls fails too (lower the
#     count or delete the line), so the list only ever shrinks.
# Exit 1 on any problem (a blocking CI step). Needs GNU grep with -P.
# Usage: bash tool/check_containers.sh [--list] [--write]
#   --list   print every call found
#   --write  rewrite the allowlist from the current calls (only when adding
#            the rule or after removing calls; never to hide a new call)
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

ALLOW=tool/containers_allowlist.txt
list=0
write=0
for arg in "$@"; do
  case "$arg" in
    --list) list=1 ;;
    --write) write=1 ;;
    *) echo "check_containers.sh: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

FN='\bshowBhor(Sheet|Dialog)(?=\s*(<[^;()]*>)?\s*\()'

# "<file> <function>" once per call (non-comment lines).
calls() {
  local f line
  while IFS= read -r f; do
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      if [ "$list" -eq 1 ]; then printf '%s\n' "$line" >&2; fi
      printf '%s\n' "${line#*:*:}" | grep -oP -- "$FN" | sed "s#^#$f #"
    done < <(grep -HnP -- "$FN" "$f" 2>/dev/null | grep -vP '^[^:]+:[0-9]+:\s*(//|\*|/\*)' || true)
  done < <(find lib/features -type f -name '*.dart' ! -name '*.g.dart' 2>/dev/null | sort)
}

# "<file> <function> <count>", sorted.
current="$(calls | sort | uniq -c | awk '{print $2" "$3" "$1}')"

if [ "$write" -eq 1 ]; then
  {
    echo "# Direct showBhorSheet / showBhorDialog calls in lib/features (tool/check_containers.sh)."
    echo "# <file> <function> <count>. Wave 2 removes lines as features move to"
    echo "# showBhorPanel / showBhorConfirm / showBhorMenu. Target: empty."
    if [ -n "$current" ]; then printf '%s\n' "$current"; fi
  } > "$ALLOW"
  echo "check_containers: wrote $ALLOW"
  exit 0
fi

declare -A allowed=()
if [ -f "$ALLOW" ]; then
  while read -r file fn count; do
    case "${file:-}" in ''|'#'*) continue ;; esac
    allowed["$file $fn"]="$count"
  done < "$ALLOW"
fi

declare -A seen=()
problems=0
total=0
while read -r file fn count; do
  [ -n "${file:-}" ] || continue
  total=$((total + count))
  seen["$file $fn"]="$count"
  max="${allowed["$file $fn"]:-0}"
  if [ "$count" -gt "$max" ]; then
    msg="$file: $count direct $fn call(s), allowlist permits $max. Use showBhorPanel (with a BhorPanelKind), showBhorConfirm or showBhorMenu."
    echo "ERROR $msg"
    if [ "${GITHUB_ACTIONS:-}" = "true" ]; then echo "::error file=$file,title=container-rule::$msg"; fi
    problems=$((problems + 1))
  fi
done <<< "$current"

left=0
for key in "${!allowed[@]}"; do
  left=$((left + allowed[$key]))
  have="${seen[$key]:-0}"
  if [ "$have" -lt "${allowed[$key]}" ]; then
    msg="$ALLOW: '$key ${allowed[$key]}' but the file now has $have. Lower the count or delete the line."
    echo "ERROR $msg"
    if [ "${GITHUB_ACTIONS:-}" = "true" ]; then echo "::error file=$ALLOW,title=container-rule::$msg"; fi
    problems=$((problems + 1))
  fi
done

summary="check_containers: $total direct sheet/dialog call(s) in lib/features; allowlist holds $left (target 0)"
echo "$summary"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Container rule"
    echo "$summary"
  } >> "$GITHUB_STEP_SUMMARY"
fi
if [ "$problems" -gt 0 ]; then
  exit 1
fi
echo "check_containers: OK"
