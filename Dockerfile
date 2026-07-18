FROM cgr.dev/chainguard/wolfi-base:latest

# LibreOffice renders the PPTX to PDF; poppler's pdftoppm rasterizes each page.
# Carlito/Caladea/Liberation are metric-compatible with Calibri/Cambria/Arial,
# so slides authored in PowerPoint keep their layout.
RUN apk add --no-cache \
    libreoffice-25.8 \
    python-3.13 \
    poppler-utils \
    fontconfig \
    font-liberation \
    font-crosextra-carlito \
    font-crosextra-caladea \
    ttf-dejavu \
    font-noto \
    font-noto-emoji

COPY convert.py /usr/local/bin/convert.py

ENTRYPOINT ["python3", "/usr/local/bin/convert.py"]
