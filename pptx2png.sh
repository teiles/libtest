#!/usr/bin/env bash
# Render a PPTX to per-slide PNGs using the pptx2png Docker image.
# Builds the image on first use.
set -euo pipefail

usage() {
    echo "usage: $0 <deck.pptx> [outdir] [dpi]" >&2
    echo "  outdir defaults to ./out, dpi defaults to 150" >&2
    exit 1
}

[[ $# -ge 1 ]] || usage
pptx="$1"
outdir="${2:-./out}"
dpi="${3:-150}"

[[ -f "$pptx" ]] || { echo "error: file not found: $pptx" >&2; exit 1; }

script_dir="$(cd "$(dirname "$0")" && pwd)"
image=pptx2png

if ! docker image inspect "$image" >/dev/null 2>&1; then
    docker build -t "$image" "$script_dir"
fi

mkdir -p "$outdir"
pptx_abs="$(cd "$(dirname "$pptx")" && pwd)/$(basename "$pptx")"
out_abs="$(cd "$outdir" && pwd)"
name="$(basename "$pptx")"

docker run --rm \
    -v "$pptx_abs:/in/$name:ro" \
    -v "$out_abs:/out" \
    "$image" "/in/$name" "$dpi"
