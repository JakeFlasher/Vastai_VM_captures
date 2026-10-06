#!/usr/bin/env bash
set -euo pipefail

BINARY=""
OUT=""
while (($#)); do
  case "$1" in
    --binary) BINARY="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "usage: $0 --binary PATH --out DIR" >&2; exit 2 ;;
  esac
done
[[ -f "$BINARY" && -n "$OUT" ]] || { echo '--binary and --out are required' >&2; exit 2; }
mkdir -p "$OUT"
cuobjdump --dump-elf "$BINARY" > "$OUT/cuobjdump-elf.txt"
cuobjdump --dump-sass "$BINARY" > "$OUT/cuobjdump-sass.txt"
if command -v nvdisasm >/dev/null; then
  echo 'nvdisasm requires a cubin path; use cuobjdump output above or pass a cubin explicitly.' > "$OUT/nvdisasm-note.txt"
fi
