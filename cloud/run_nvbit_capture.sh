#!/usr/bin/env bash
set -euo pipefail

ROOT="${SM120_CAPTURE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$ROOT/../GPU_simulator_rebase" 2>/dev/null && pwd || true)}"
NAME=""
OUT=""
TIMEOUT_S="${CAPTURE_TIMEOUT_S:-900}"
while (($#)); do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --timeout) TIMEOUT_S="$2"; shift 2 ;;
    --) shift; break ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$NAME" ]] || { echo "--name is required" >&2; exit 2; }
(( $# > 0 )) || { echo "a workload command is required after --" >&2; exit 2; }
[[ -n "$OUT" ]] || OUT="$ROOT/captures/$NAME/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT"
TRACER_SO="${CUDA_INJECTION64_PATH:-$REPO_ROOT/tools/nvbit_tracer/tracer_tool/tracer_tool.so}"
[[ -f "$TRACER_SO" ]] || { echo "missing tracer: $TRACER_SO" >&2; exit 2; }

printf '%q ' "$@" > "$OUT/command.txt"
printf '\n' >> "$OUT/command.txt"
date -u +%Y-%m-%dT%H:%M:%SZ > "$OUT/captured_at_utc.txt"
export CUDA_INJECTION64_PATH="$TRACER_SO"
export USER_DEFINED_FOLDERS=1
export TRACES_FOLDER="$OUT"
if [[ -d "$REPO_ROOT/.toolchain/pb/lib" ]]; then
  export LD_LIBRARY_PATH="$REPO_ROOT/.toolchain/pb/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

set +e
timeout --signal=TERM --kill-after=20s "$TIMEOUT_S" \
  "$@" >"$OUT/program.stdout" 2>"$OUT/program.stderr"
RC=$?
set -e
printf '%s\n' "$RC" > "$OUT/exit_code.txt"
printf 'NVBit capture name=%s exit=%s output=%s\n' "$NAME" "$RC" "$OUT"
exit "$RC"
