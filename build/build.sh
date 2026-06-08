#!/bin/sh
# build.sh — build devysix artifacts
#
# usage:
#   build.sh tarball       build installable tarball only
#   build.sh iso           build full bootable ISO (requires root)
#   build.sh all           build both

REPO_DIR="$(dirname "$(realpath "$0")")/.."
OUT_DIR="$REPO_DIR/build/out"
VERSION="$(date +%Y%m%d)"

die()  { echo "build: error: $1" >&2; exit 1; }
info() { echo "  ==> $1"; }

mkdir -p "$OUT_DIR"

# ── tarball ───────────────────────────────────────────────────────────────────

build_tarball() {
    echo "build: creating devysix-$VERSION.tar.gz"

    stage="$(mktemp -d)"

    install -dm755 "$stage/usr/lib/devysix/commands"
    install -dm755 "$stage/usr/lib/devysix/services"
    install -dm755 "$stage/usr/lib/devysix/desktops"
    install -dm755 "$stage/usr/lib/devysix/themes"
    install -dm755 "$stage/usr/lib/devysix/assets"
    install -dm755 "$stage/usr/local/bin"
    install -dm755 "$stage/etc/devysix"
    install -dm755 "$stage/etc/s6-linux-init/scripts"
    install -dm755 "$stage/etc/skel/.config/fastfetch"
    install -dm755 "$stage/usr/local/sbin"

    install -m755 "$REPO_DIR/cli/dev"               "$stage/usr/local/bin/dev"
    install -m755 "$REPO_DIR/cli/commands/"*         "$stage/usr/lib/devysix/commands/"
    install -m644 "$REPO_DIR/lib/toml.sh"            "$stage/usr/lib/devysix/toml.sh"
    install -m644 "$REPO_DIR/lib/generations.sh"     "$stage/usr/lib/devysix/generations.sh"
    install -m644 "$REPO_DIR/services/"*.toml        "$stage/usr/lib/devysix/services/"
    install -m644 "$REPO_DIR/desktops/"*.toml        "$stage/usr/lib/devysix/desktops/"
    install -m644 "$REPO_DIR/themes/"*.toml          "$stage/usr/lib/devysix/themes/"
    install -m644 "$REPO_DIR/assets/logo.txt"        "$stage/usr/lib/devysix/assets/logo.txt"
    install -m644 "$REPO_DIR/config/devysix.toml"    "$stage/etc/devysix/devysix.toml"
    install -m644 "$REPO_DIR/config/fastfetch.jsonc" "$stage/etc/skel/.config/fastfetch/config.jsonc"
    install -m755 "$REPO_DIR/s6-linux-init/scripts/rc.init"     "$stage/etc/s6-linux-init/scripts/rc.init"
    install -m755 "$REPO_DIR/s6-linux-init/scripts/rc.shutdown" "$stage/etc/s6-linux-init/scripts/rc.shutdown"
    install -m755 "$REPO_DIR/s6-linux-init/scripts/rc.final"    "$stage/etc/s6-linux-init/scripts/rc.final"
    install -m755 "$REPO_DIR/installer/devysix-setup" "$stage/usr/local/sbin/devysix-setup"

    tar -czf "$OUT_DIR/devysix-$VERSION.tar.gz" -C "$stage" .
    rm -rf "$stage"

    info "tarball: $OUT_DIR/devysix-$VERSION.tar.gz"
    ls -lh "$OUT_DIR/devysix-$VERSION.tar.gz"
}

# ── ISO ───────────────────────────────────────────────────────────────────────

build_iso() {
    [ "$(id -u)" -eq 0 ] || die "ISO build requires root"

    for dep in debootstrap mksquashfs xorriso grub-mkrescue; do
        command -v "$dep" >/dev/null 2>&1 || die "$dep not found — install it first"
    done

    echo "build: creating devysix-$VERSION.iso"
    exec "$REPO_DIR/build/iso.sh" "$VERSION" "$OUT_DIR" "$REPO_DIR"
}

# ── dispatch ──────────────────────────────────────────────────────────────────

case "${1:-all}" in
    tarball) build_tarball ;;
    iso)     build_iso ;;
    all)     build_tarball; build_iso ;;
    *)       die "usage: build.sh [tarball|iso|all]" ;;
esac
