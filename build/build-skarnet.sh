#!/bin/sh
# build-skarnet.sh — compile s6-rc and s6-linux-init from skarnet.org
# run this on the target system before dev switch, or called by devysix-setup

S6RC_VERSION="0.5.5.0"
S6LI_VERSION="1.1.2.0"
BUILD_DIR="$(mktemp -d)"
PREFIX="/usr"

die()  { echo "build-skarnet: $1" >&2; rm -rf "$BUILD_DIR"; exit 1; }
info() { echo "  ==> $1"; }

[ "$(id -u)" -eq 0 ] || die "must be run as root"

# build deps
info "installing build dependencies..."
apt-get install -y gcc make curl skalibs-dev || die "build deps failed"

cd "$BUILD_DIR" || die "cannot enter build dir"

# ── s6-rc ─────────────────────────────────────────────────────────────────────

if ! command -v s6-rc >/dev/null 2>&1; then
    info "building s6-rc $S6RC_VERSION..."
    curl -fsSL "https://skarnet.org/software/s6-rc/s6-rc-${S6RC_VERSION}.tar.gz" \
        -o s6-rc.tar.gz || die "download s6-rc failed"
    tar xf s6-rc.tar.gz
    cd "s6-rc-${S6RC_VERSION}" || die "s6-rc dir not found"
    ./configure --prefix="$PREFIX" || die "s6-rc configure failed"
    make -j"$(nproc)" && make install || die "s6-rc build failed"
    cd "$BUILD_DIR"
    info "s6-rc installed"
else
    info "s6-rc already present, skipping"
fi

# ── s6-linux-init ─────────────────────────────────────────────────────────────

if ! command -v s6-linux-init-maker >/dev/null 2>&1; then
    info "building s6-linux-init $S6LI_VERSION..."
    curl -fsSL "https://skarnet.org/software/s6-linux-init/s6-linux-init-${S6LI_VERSION}.tar.gz" \
        -o s6-linux-init.tar.gz || die "download s6-linux-init failed"
    tar xf s6-linux-init.tar.gz
    cd "s6-linux-init-${S6LI_VERSION}" || die "s6-linux-init dir not found"
    ./configure --prefix="$PREFIX" || die "s6-linux-init configure failed"
    make -j"$(nproc)" && make install || die "s6-linux-init build failed"
    cd "$BUILD_DIR"
    info "s6-linux-init installed"
else
    info "s6-linux-init already present, skipping"
fi

rm -rf "$BUILD_DIR"
info "skarnet tools ready"
