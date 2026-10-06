#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-${SM120_CAPTURE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
errors=0
for dir in "$ROOT/captures" "$ROOT/profiles" "$ROOT/metadata"; do
  [[ -d "$dir" ]] || { echo "missing directory: $dir" >&2; errors=$((errors+1)); continue; }
done
find "$ROOT/captures" -type f -name dynamic_trace.pb -print 2>/dev/null | while read -r trace; do
  printf 'trace %s bytes=%s\n' "$trace" "$(stat -c %s "$trace")"
done
find "$ROOT/profiles" -type f -name '*.ncu-rep' -print 2>/dev/null | while read -r report; do
  printf 'ncu-report %s bytes=%s\n' "$report" "$(stat -c %s "$report")"
done
(( errors == 0 ))
