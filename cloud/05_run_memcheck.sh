#!/usr/bin/env bash
set -euo pipefail

ROOT="${SM120_CAPTURE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NAME=""
while (($#)); do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --) shift; break ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$NAME" ]] || { echo '--name is required' >&2; exit 2; }
(( $# > 0 )) || { echo 'command required after --' >&2; exit 2; }
OUT="$ROOT/logs/$NAME/memcheck_$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT"
printf '%q ' "$@" > "$OUT/command.txt"; printf '\n' >> "$OUT/command.txt"
compute-sanitizer --tool memcheck --error-exitcode 1 -- "$@" >"$OUT/stdout" 2>"$OUT/stderr"
printf 'memcheck output: %s\n' "$OUT"
