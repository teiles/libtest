#!/usr/bin/env python3
"""Container entrypoint: render a PPTX to per-slide PNGs in /out.

Drives LibreOffice headless to produce a PDF, then pdftoppm to
rasterize each page.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

SOFFICE = "/usr/lib/libreoffice/program/soffice"


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: convert.py /in/deck.pptx [dpi]", file=sys.stderr)
        return 1

    src = Path(sys.argv[1])
    dpi = sys.argv[2] if len(sys.argv) > 2 else "150"

    with tempfile.TemporaryDirectory() as tmp:
        # UserInstallation gives LibreOffice a writable profile dir so
        # headless runs work regardless of the container user/HOME.
        subprocess.run(
            [
                SOFFICE,
                "--headless",
                f"-env:UserInstallation=file://{tmp}/profile",
                "--convert-to", "pdf",
                "--outdir", tmp,
                str(src),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
        )

        pdf = Path(tmp) / f"{src.stem}.pdf"
        if not pdf.exists():
            print(f"error: LibreOffice produced no PDF for {src}", file=sys.stderr)
            return 1

        subprocess.run(
            ["pdftoppm", "-png", "-r", dpi, str(pdf), f"/out/{src.stem}"],
            check=True,
        )

    pages = sorted(Path("/out").glob(f"{src.stem}-*.png"))
    print(f"wrote {len(pages)} slide image(s) to /out ({src.stem}-*.png)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
