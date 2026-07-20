#!/usr/bin/env bash
# End-to-end test: render the fixture deck and verify every slide
# comes out as a valid PNG.
set -euo pipefail
cd "$(dirname "$0")"

deck=Test-Project-Stakeholders.pptx
expected=8

outdir=$(mktemp -d)
trap 'rm -rf "$outdir"' EXIT

./pptx2png.sh "$deck" "$outdir"

count=$(find "$outdir" -name '*.png' | wc -l | tr -d ' ')
if [ "$count" -ne "$expected" ]; then
    echo "FAIL: expected $expected PNGs, got $count" >&2
    exit 1
fi

for f in "$outdir"/*.png; do
    if [ "$(head -c 8 "$f" | xxd -p)" != "89504e470d0a1a0a" ]; then
        echo "FAIL: $f is not a valid PNG" >&2
        exit 1
    fi
done

echo "PASS: $count/$expected slides rendered as valid PNGs"
