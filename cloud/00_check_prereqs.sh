#!/usr/bin/env bash
set -euo pipefail

ROOT="${SM120_CAPTURE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$ROOT/../GPU_simulator_rebase" 2>/dev/null && pwd || true)}"
for tool in nvidia-smi nvcc ncu make python3; do
  if command -v "$tool" >/dev/null; then
    printf 'OK %-14s %s\n' "$tool" "$(command -v "$tool")"
  else
    printf 'MISSING %-10s\n' "$tool"
  fi
done
if [[ -n "$REPO_ROOT" && -d "$REPO_ROOT" ]]; then
  printf 'REPO_ROOT=%s\n' "$REPO_ROOT"
else
  echo 'REPO_ROOT is not set to a repository checkout' >&2
fi
if command -v nvidia-smi >/dev/null; then
  nvidia-smi --query-gpu=name,uuid,compute_cap,driver_version --format=csv || true
  GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1)
  if ! printf '%s' "$GPU_NAME" | grep -qi 'RTX PRO 6000'; then
    echo "ERROR: active SM120 campaign requires RTX PRO 6000 Workstation; detected $GPU_NAME" >&2
    exit 3
  fi
  if printf '%s' "$GPU_NAME" | grep -qi 'MIG'; then
    echo 'ERROR: MIG/partitioned devices are not accepted for the full-card campaign.' >&2
    exit 3
  fi
  echo 'TARGET: RTX PRO 6000 Workstation detected.'
fi
if command -v nvcc >/dev/null; then nvcc --version | tail -n 4; fi
if command -v ncu >/dev/null; then ncu --version | head -n 3; fi
