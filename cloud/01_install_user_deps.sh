#!/usr/bin/env bash
set -euo pipefail

# This script is intentionally opt-in. It never installs NVIDIA drivers,
# CUDA, Nsight, or changes GPU state. Run with --apply only on a disposable
# Ubuntu VM where the operator wants the listed user-space build packages.
if [[ "${1:-}" != "--apply" ]]; then
  cat <<'CMD'
Would install (Ubuntu/Debian user-space prerequisites only):
  build-essential git pkg-config protobuf-compiler libprotobuf-dev
  python3-venv python3-pip rsync jq

Run explicitly if desired:
  sudo apt-get update
  sudo apt-get install -y build-essential git pkg-config protobuf-compiler \
    libprotobuf-dev python3-venv python3-pip rsync jq

CUDA toolkit, NVIDIA driver, Nsight Compute, and PyTorch are managed by the
cloud image/operator and are deliberately not installed by this script.
CMD
  exit 0
fi
sudo apt-get update
sudo apt-get install -y build-essential git pkg-config protobuf-compiler \
  libprotobuf-dev python3-venv python3-pip rsync jq
