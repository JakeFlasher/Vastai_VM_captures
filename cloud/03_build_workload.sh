#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REPO_ROOT:?set REPO_ROOT to the repository checkout}"
WORKLOAD_DIR=""
ARCH_GATE="sm_120"
while (($#)); do
  case "$1" in
    --dir) WORKLOAD_DIR="$2"; shift 2 ;;
    --arch-gate) ARCH_GATE="$2"; shift 2 ;;
    *) echo "usage: $0 --dir PATH [--arch-gate sm_120|sm_120f|sm_120a]" >&2; exit 2 ;;
  esac
done
[[ -n "$WORKLOAD_DIR" && -f "$WORKLOAD_DIR/Makefile" ]] || { echo 'workload Makefile is required' >&2; exit 2; }
make -C "$WORKLOAD_DIR" ARCH_GATE="$ARCH_GATE" clean all
