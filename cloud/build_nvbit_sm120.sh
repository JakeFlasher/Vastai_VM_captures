#!/usr/bin/env bash
set -euo pipefail

ROOT="${SM120_CAPTURE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$ROOT/../GPU_simulator_rebase" 2>/dev/null && pwd || true)}"
if [[ -z "$REPO_ROOT" || ! -d "$REPO_ROOT/tools/nvbit_tracer" ]]; then
  echo "set REPO_ROOT to a GPU_simulator_rebase checkout" >&2
  exit 2
fi

CUDA_INSTALL_PATH="${CUDA_INSTALL_PATH:-/usr/local/cuda}"
NVCC_CCBIN="${NVCC_CCBIN:-${CXX:-g++}}"
PROTOC="${PROTOC:-$REPO_ROOT/.toolchain/pb/bin/protoc}"
PB_PREFIX="${PB_PREFIX:-$REPO_ROOT/.toolchain/pb}"

make -C "$REPO_ROOT/tools/nvbit_tracer" \
  CUDA_INSTALL_PATH="$CUDA_INSTALL_PATH" \
  NVCC_CCBIN="$NVCC_CCBIN" \
  PROTOC="$PROTOC" PB_PREFIX="$PB_PREFIX" ARCH=sm_120 -j"${JOBS:-$(nproc)}"

make -C "$REPO_ROOT/tools/nvbit_tracer/metric_extractor" \
  CUDA_INSTALL_PATH="$CUDA_INSTALL_PATH" \
  NVCC_CCBIN="$NVCC_CCBIN" ARCH=sm_120 -j"${JOBS:-$(nproc)}"

printf 'SM120 NVBit build completed under %s\n' "$REPO_ROOT/tools/nvbit_tracer"
