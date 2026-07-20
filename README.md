# pptx2png

Render each slide of a PPTX as a PNG using LibreOffice headless in a
Chainguard container. Two-stage build: a wolfi-base builder resolves the
package closure with apk; the runtime image (glibc-dynamic) ships without
a package manager.

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

## Why LibreOffice-on-distroless works here

The usual advice is that putting LibreOffice in a distroless image is
painful, and for the hand-rolled approach it is: `COPY` its install dir,
then chase shared libraries with `ldd` until it stops crashing. That
fails on LibreOffice because it dlopens filters and plugins at runtime
that `ldd` can't see, and the file list changes every release. Guides
that mix distros (Debian's LibreOffice on `gcr.io/distroless`) add
glibc/layout mismatches on top.

This build never curates files by hand. The builder stage runs
`apk add --root /rootfs`, which makes apk resolve the entire dependency
closure from package metadata into a directory; the runtime stage copies
that one directory onto `glibc-dynamic`. Same Wolfi package universe on
both sides, so nothing mismatches — the same idea Chainguard's apko
tooling uses, done with stock apk in a Dockerfile.

The distroless sharp edges that remain (each already handled in this
repo, listed for the next change):

- **Chrooted post-install scripts**: apk runs package scripts chrooted
  in `/rootfs`; gtk's need `/bin/sh` there. Hence busybox installs
  first and is `apk del`'d after — don't "simplify" that away.
- **Triggers don't run**: the fontconfig cache is built from the
  builder via `fc-cache --sysroot /rootfs`. New font packages get
  picked up by that same line.
- **`soffice` is a shell script**: the runtime has no shell, so
  `convert.py` execs `soffice.bin` directly. That bypasses the normal
  launch chain — `soffice` (sh) → `oosplash` (ELF) → `soffice.bin`.
- **Exit code 81**: `EXITHELPER_NORMAL_RESTART` — benign. soffice.bin
  exits 81 after initializing its user profile and expects a relaunch,
  which oosplash normally performs. This no longer occurs in practice:
  the build stage pre-runs that bootstrap (chrooted into `/rootfs`) and
  bakes the initialized profile into the image at `/opt/lo-profile`, and
  `convert.py` copies it into a fresh throwaway profile per run (what
  makes concurrent runs safe) — so every conversion is a single soffice
  launch. `convert.py` still handles 81 with one relaunch purely as a
  fallback, e.g. if a LibreOffice upgrade invalidates the relocated
  profile template.
- **No shell for anything else either**: runtime work must be direct
  binary execs — no `shell=True`, no shell-script entrypoints, and
  `docker exec` debugging won't work. Debug in the builder stage
  instead.

## Fonts

The image bundles metric-compatible substitutes for the common PowerPoint
fonts (Carlito→Calibri, Caladea→Cambria, Liberation→Arial/Times/Courier)
plus Noto, Noto Emoji, and DejaVu. If a deck renders with shifted layout,
a missing font is the first suspect:

```bash
docker run --rm --entrypoint fc-match pptx2png "Calibri"
```

Add more fonts by appending Wolfi `font-*` packages to the builder stage's
`apk add --root` list in the Dockerfile.
