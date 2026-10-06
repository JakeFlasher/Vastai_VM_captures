#!/usr/bin/env bash
set -euo pipefail

ROOT="${SM120_CAPTURE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NAME=""
OUT=""
KERNEL_NAME=""
LAUNCH_COUNT="${NCU_LAUNCH_COUNT:-1}"
PROFILE_FROM_START="${NCU_PROFILE_FROM_START:-on}"
while (($#)); do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --kernel-name) KERNEL_NAME="$2"; shift 2 ;;
    --launch-count) LAUNCH_COUNT="$2"; shift 2 ;;
    --profile-from-start) PROFILE_FROM_START="$2"; shift 2 ;;
    --) shift; break ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$NAME" ]] || { echo "--name is required" >&2; exit 2; }
(( $# > 0 )) || { echo "a workload command is required after --" >&2; exit 2; }
[[ -n "$OUT" ]] || OUT="$ROOT/profiles/$NAME/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT"
REPORT="$OUT/ncu-report.ncu-rep"
ARGS=(--set full --target-processes all --profile-from-start "$PROFILE_FROM_START" --launch-skip 0 --export "$REPORT" --force-overwrite)
if [[ -n "$LAUNCH_COUNT" ]]; then ARGS+=(--launch-count "$LAUNCH_COUNT"); fi
if [[ -n "$KERNEL_NAME" ]]; then ARGS+=(--kernel-name "$KERNEL_NAME"); fi

{
  printf 'ncu '
  printf '%q ' "${ARGS[@]}"
  printf '%q ' "$@"
  printf '\n'
} > "$OUT/command.txt"
date -u +%Y-%m-%dT%H:%M:%SZ > "$OUT/profiled_at_utc.txt"
set +e
ncu "${ARGS[@]}" "$@" >"$OUT/ncu.stdout" 2>"$OUT/ncu.stderr"
RC=$?
set -e
printf '%s\n' "$RC" > "$OUT/exit_code.txt"
if [[ -f "$REPORT" ]]; then
  ncu --import "$REPORT" --page raw --csv > "$OUT/raw.csv" 2> "$OUT/raw_export.stderr" || true
fi
printf 'NCU profile name=%s exit=%s output=%s\n' "$NAME" "$RC" "$OUT"
exit "$RC"
