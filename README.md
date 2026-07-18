# pptx2png

Render each slide of a PPTX as a PNG using LibreOffice headless in a
Chainguard Wolfi container.

Pipeline: `soffice --headless` converts the deck to PDF (LibreOffice's direct
PNG export only renders the first slide), then poppler's `pdftoppm`
rasterizes each page.

## Usage

```bash
./pptx2png.sh deck.pptx            # PNGs land in ./out at 150 dpi
./pptx2png.sh deck.pptx slides 300 # custom output dir and dpi
```

The wrapper builds the `pptx2png` image on first run, then invokes the
container with the deck mounted read-only at `/in` and the output dir at
`/out`. The entrypoint is `convert.py` (Python 3.13), which drives the
conversion synchronously — exit 0 means every slide rendered.

## Fonts

The image bundles metric-compatible substitutes for the common PowerPoint
fonts (Carlito→Calibri, Caladea→Cambria, Liberation→Arial/Times/Courier)
plus Noto, Noto Emoji, and DejaVu. If a deck renders with shifted layout,
a missing font is the first suspect:

```bash
docker run --rm --entrypoint fc-match pptx2png "Calibri"
```

Add more fonts by appending Wolfi `font-*` packages to the `apk add` list
in the Dockerfile.
