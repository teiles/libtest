# Stage 1 (has apk): resolve the full package closure into /rootfs so the
# runtime stage can ship without a package manager.
FROM cgr.dev/chainguard/wolfi-base:latest AS builder

# LibreOffice renders the PPTX to PDF; poppler's pdftoppm rasterizes each page.
# Carlito/Caladea/Liberation are metric-compatible with Calibri/Cambria/Arial,
# so slides authored in PowerPoint keep their layout.
RUN apk add --no-cache fontconfig \
    && mkdir -p /rootfs \
    # busybox first: package post-install scripts (gtk's among them) run
    # chrooted in /rootfs and need /bin/sh there. Removed again below —
    # the runtime ships with no shell.
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
    # Pre-warm the LibreOffice profile. soffice.bin's first launch runs a
    # one-time bootstrap (user profile creation, service registry sync) and
    # then exits 81 (EXITHELPER_NORMAL_RESTART, "init done — relaunch me").
    # Doing that here bakes an initialized profile template into the image
    # at /opt/lo-profile; convert.py copies it per run, so the runtime
    # skips the init-and-relaunch and every conversion is a single launch.
    # Must run chrooted in /rootfs (the builder has no LibreOffice), which
    # works because busybox is still present at this point. Exit 81 is
    # success here; --terminate_after_init asks it to stop after bootstrap.
    # LD_LIBRARY_PATH: in the bare chroot the loader can't resolve
    # soffice.bin's sibling libs (libuno_sal & co.) the way it does in the
    # finished image, so point it at the program dir explicitly.
    && (chroot /rootfs /usr/bin/env HOME=/tmp \
        LD_LIBRARY_PATH=/usr/lib/libreoffice/program \
        /usr/lib/libreoffice/program/soffice.bin --headless \
        -env:UserInstallation=file:///opt/lo-profile \
        --terminate_after_init \
        || [ "$?" -eq 81 ]) \
    # soffice creates the profile 0700 root-owned; the runtime user is
    # nonroot and only needs to read it (convert.py copies it per run).
    && chmod -R a+rX /rootfs/opt/lo-profile \
    && apk del --root /rootfs --no-cache busybox \
    && mkdir -p /rootfs/tmp /rootfs/in /rootfs/out \
    && chmod 1777 /rootfs/tmp

COPY convert.py /rootfs/usr/local/bin/convert.py

# Stage 2: Chainguard distroless runtime — no package manager, no shell.
# convert.py execs soffice.bin directly since the soffice launcher is a
# /bin/sh script.
FROM cgr.dev/chainguard/glibc-dynamic:latest
COPY --from=builder /rootfs /

ENV PATH=/usr/bin:/bin HOME=/tmp

ENTRYPOINT ["python3", "/usr/local/bin/convert.py"]
