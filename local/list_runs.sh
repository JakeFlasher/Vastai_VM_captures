#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-${SM120_CAPTURE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
printf '%s\n' "workspace=$ROOT"
for kind in captures profiles metadata logs; do
  dir="$ROOT/$kind"
  if [[ -d "$dir" ]]; then
    printf '\n[%s]\n' "$kind"
    find "$dir" -type f -printf '%s\t%p\n' | sort -k2
  fi
done
