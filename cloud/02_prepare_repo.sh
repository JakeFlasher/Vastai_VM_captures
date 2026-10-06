#!/usr/bin/env bash
set -euo pipefail

ROOT="${SM120_CAPTURE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$ROOT/../GPU_simulator_rebase" 2>/dev/null && pwd || true)}"
[[ -d "$REPO_ROOT/tools/nvbit_tracer" ]] || { echo "set REPO_ROOT" >&2; exit 2; }
mkdir -p "$ROOT/metadata" "$ROOT/captures" "$ROOT/profiles" "$ROOT/logs"
python3 -m py_compile "$REPO_ROOT/tools/sol_baselines_harness/arch_resolver.py"
if command -v uv >/dev/null && [[ -f "$REPO_ROOT/tools/sol_execbench/pyproject.toml" ]]; then
  echo 'uv is available; run `uv sync --project tools/sol_execbench` only if SOLBench execution is planned.'
else
  echo 'uv/SOLBench environment not installed; SimBench micro-probes can still be built.'
fi
printf 'repository preparation completed: %s\n' "$REPO_ROOT"
