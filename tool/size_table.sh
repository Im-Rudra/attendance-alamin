#!/usr/bin/env bash
# Print a markdown size table. Each argument: "label|before|after"
#   before/after = a file or directory path, a plain byte count, or "-" (not measured).
# Used by CI jobs to append before/after sizes to $GITHUB_STEP_SUMMARY.
set -uo pipefail

bytes() {
  local v="$1"
  if [ "$v" = "-" ] || [ -z "$v" ]; then echo "-"; return; fi
  if [[ "$v" =~ ^[0-9]+$ ]]; then echo "$v"; return; fi
  if [ -d "$v" ]; then
    find "$v" -type f -printf '%s\n' 2>/dev/null | awk '{s+=$1} END{printf "%d", s}'
  elif [ -f "$v" ]; then
    stat -c%s "$v" 2>/dev/null || wc -c < "$v"
  else
    echo "-"
  fi
}
mb() { if [ "$1" = "-" ]; then echo "-"; else awk -v b="$1" 'BEGIN{printf "%.2f MB", b/1048576}'; fi; }

echo "| Artifact | Before | After | Change |"
echo "|---|---:|---:|---:|"
for row in "$@"; do
  IFS='|' read -r label before after <<< "$row"
  b="$(bytes "$before")"; a="$(bytes "$after")"
  if [ "$b" != "-" ] && [ "$a" != "-" ] && [ "$b" -gt 0 ]; then
    d="$(awk -v b="$b" -v a="$a" 'BEGIN{printf "%+.1f%%", (a-b)*100/b}')"
  else
    d="-"
  fi
  echo "| $label | $(mb "$b") | $(mb "$a") | $d |"
done
