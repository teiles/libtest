#!/usr/bin/env python3
"""Container entrypoint: render a PPTX to per-slide PNGs in /out.

Drives LibreOffice headless to produce a PDF, then pdftoppm to
rasterize each page.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

# soffice.bin directly: the soffice launcher is a shell script and the
# runtime image has no shell.
SOFFICE = "/usr/lib/libreoffice/program/soffice.bin"


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: convert.py /in/deck.pptx [dpi]", file=sys.stderr)
        return 1

    src = Path(sys.argv[1])
    dpi = sys.argv[2] if len(sys.argv) > 2 else "150"

    with tempfile.TemporaryDirectory() as tmp:
        # UserInstallation gives LibreOffice a writable profile dir so
        # headless runs work regardless of the container user/HOME.
        cmd = [
            SOFFICE,
            "--headless",
            f"-env:UserInstallation=file://{tmp}/profile",
            "--convert-to", "pdf",
            "--outdir", tmp,
            str(src),
        ]
        result = subprocess.run(cmd, stdout=subprocess.DEVNULL)
        if result.returncode == 81:
            # soffice.bin exits 81 after first-run profile init, expecting
            # a relaunch (normally done by the soffice shell wrapper).
            result = subprocess.run(cmd, stdout=subprocess.DEVNULL)
        if result.returncode != 0:
            print(f"error: soffice exited {result.returncode}", file=sys.stderr)
            return 1

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
