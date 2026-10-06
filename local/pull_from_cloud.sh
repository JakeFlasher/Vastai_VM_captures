#!/usr/bin/env bash
set -euo pipefail

(( $# == 2 )) || { echo "usage: $0 user@cloud:/path/to/workspace/ /local/destination/" >&2; exit 2; }
SRC="$1"
DST="$2"
mkdir -p "$DST"
# No --delete: a pull must not remove local captures or unrelated files.
rsync -a --info=progress2 "$SRC" "$DST"
printf 'pulled %s into %s\n' "$SRC" "$DST"
