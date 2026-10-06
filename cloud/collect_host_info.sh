#!/usr/bin/env bash
set -euo pipefail

ROOT="${SM120_CAPTURE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUT="${1:-$ROOT/metadata/host_$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$OUT"

command -v nvidia-smi >/dev/null || { echo "nvidia-smi is required" >&2; exit 2; }
command -v nvcc >/dev/null || { echo "nvcc is required" >&2; exit 2; }
command -v ncu >/dev/null || { echo "ncu is required" >&2; exit 2; }

date -u +%Y-%m-%dT%H:%M:%SZ > "$OUT/captured_at_utc.txt"
nvidia-smi -L > "$OUT/nvidia-smi-L.txt"
nvidia-smi --query-gpu=name,uuid,compute_cap,driver_version,pstate,clocks.sm,clocks.mem,power.draw,temperature.gpu,persistence_mode --format=csv > "$OUT/nvidia-smi-query.csv"
nvidia-smi -q > "$OUT/nvidia-smi-q.txt"
nvcc --version > "$OUT/nvcc-version.txt" 2>&1
ncu --version > "$OUT/ncu-version.txt" 2>&1
ncu --list-chips > "$OUT/ncu-chips.txt" 2>&1 || true
ncu --query-metrics --query-metrics-mode suffix > "$OUT/ncu-metrics.txt" 2>&1 || true

if command -v git >/dev/null && [[ -n "${REPO_ROOT:-}" && -d "$REPO_ROOT/.git" ]]; then
  git -C "$REPO_ROOT" rev-parse --short HEAD > "$OUT/repo_revision.txt"
fi

cat > "$OUT/README.txt" <<META
This directory contains ordinary host/run metadata captured before an SM120
session. It is descriptive only; no file here is an execution gate.
Target workspace: $ROOT
META
printf 'host metadata written to %s\n' "$OUT"
