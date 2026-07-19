# Stage 1 (has apk): resolve the full package closure into /rootfs so the
# runtime stage can ship without a package manager.
FROM cgr.dev/chainguard/wolfi-base:latest AS builder

# LibreOffice renders the PPTX to PDF; poppler's pdftoppm rasterizes each page.
# Carlito/Caladea/Liberation are metric-compatible with Calibri/Cambria/Arial,
# so slides authored in PowerPoint keep their layout.
RUN apk add --no-cache fontconfig \
    && mkdir -p /rootfs \
    # busybox first: package post-install scripts (gtk's among them) run
    # chrooted in /rootfs and need /bin/sh to exist there already.
    && apk add --root /rootfs --initdb --no-cache \
        --keys-dir /etc/apk/keys --repositories-file /etc/apk/repositories \
        busybox \
    && apk add --root /rootfs --no-cache \
        --keys-dir /etc/apk/keys --repositories-file /etc/apk/repositories \
        libreoffice-25.8 \
        python-3.13 \
        poppler-utils \
        fontconfig \
        font-liberation \
        font-crosextra-carlito \
        font-crosextra-caladea \
        ttf-dejavu \
        font-noto \
        font-noto-emoji \
    # apk triggers (fc-cache) can't chroot into the shell-less rootfs,
    # so build the font cache from outside instead.
    && fc-cache --sysroot /rootfs -f \
    && mkdir -p /rootfs/tmp /rootfs/in /rootfs/out \
    && chmod 1777 /rootfs/tmp

COPY convert.py /rootfs/usr/local/bin/convert.py

# Stage 2: Chainguard distroless runtime — no package manager (apk-tools is
# not in the closure; busybox is included only because LibreOffice's soffice
# launcher is a /bin/sh script).
FROM cgr.dev/chainguard/glibc-dynamic:latest
COPY --from=builder /rootfs /

ENV PATH=/usr/bin:/bin HOME=/tmp

ENTRYPOINT ["python3", "/usr/local/bin/convert.py"]
