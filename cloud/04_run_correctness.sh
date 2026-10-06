#!/usr/bin/env bash
set -euo pipefail

ROOT="${SM120_CAPTURE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NAME=""
OUT=""
TIMEOUT_S="${CORRECTNESS_TIMEOUT_S:-600}"
while (($#)); do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --timeout) TIMEOUT_S="$2"; shift 2 ;;
    --) shift; break ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$NAME" ]] || { echo '--name is required' >&2; exit 2; }
(( $# > 0 )) || { echo 'command required after --' >&2; exit 2; }
OUT="${OUT:-$ROOT/logs/$NAME/$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$OUT"
printf '%q ' "$@" > "$OUT/command.txt"; printf '\n' >> "$OUT/command.txt"
set +e
timeout --signal=TERM --kill-after=10s "$TIMEOUT_S" "$@" >"$OUT/stdout" 2>"$OUT/stderr"
RC=$?
set -e
printf '%s\n' "$RC" > "$OUT/exit_code.txt"
exit "$RC"
