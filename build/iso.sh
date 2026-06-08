#!/bin/sh
# iso.sh — build a bootable Devysix ISO from scratch
# called by build.sh, do not run directly
#
# produces: out/devysix-<VERSION>.iso
# requires: debootstrap mksquashfs xorriso grub-mkrescue

VERSION="${1:-$(date +%Y%m%d)}"
OUT_DIR="${2:-$(dirname "$(realpath "$0")")/out}"
REPO_DIR="${3:-$(dirname "$(realpath "$0")")/..}"

WORK="$OUT_DIR/work"
ROOTFS="$WORK/rootfs"
ISO_STAGE="$WORK/iso"

die()  { echo "iso: error: $1" >&2; exit 1; }
info() { echo "  ==> $1"; }

# ── clean previous work ───────────────────────────────────────────────────────

rm -rf "$WORK"
mkdir -p "$ROOTFS" "$ISO_STAGE/boot/grub" "$ISO_STAGE/live"

# ── debootstrap Devuan base ───────────────────────────────────────────────────

echo "iso: bootstrapping Devuan excalibur..."
debootstrap \
    --arch=amd64 \
    --include=linux-image-amd64,live-boot,systemd-sysv,s6,s6-rc,s6-linux-init,\
s6-linux-init-utils,fastfetch,apt,dbus,elogind,udev,NetworkManager,\
policykit-1,sudo,bash,curl,ca-certificates \
    --exclude=systemd \
    excalibur \
    "$ROOTFS" \
    https://deb.devuan.org/merged \
    || die "debootstrap failed"

# ── copy devysix tooling into rootfs ─────────────────────────────────────────

echo "iso: installing devysix tooling..."

install -dm755 "$ROOTFS/usr/lib/devysix/commands"
install -dm755 "$ROOTFS/usr/lib/devysix/services"
install -dm755 "$ROOTFS/usr/lib/devysix/desktops"
install -dm755 "$ROOTFS/usr/lib/devysix/themes"
install -dm755 "$ROOTFS/usr/lib/devysix/assets"
install -dm755 "$ROOTFS/etc/devysix"
install -dm755 "$ROOTFS/etc/s6-linux-init/scripts"
install -dm755 "$ROOTFS/etc/skel/.config/fastfetch"
install -dm755 "$ROOTFS/var/lib/devysix/generations"

install -m755 "$REPO_DIR/cli/dev"               "$ROOTFS/usr/local/bin/dev"
install -m755 "$REPO_DIR/cli/commands/"*         "$ROOTFS/usr/lib/devysix/commands/"
install -m644 "$REPO_DIR/lib/toml.sh"            "$ROOTFS/usr/lib/devysix/toml.sh"
install -m644 "$REPO_DIR/lib/generations.sh"     "$ROOTFS/usr/lib/devysix/generations.sh"
install -m644 "$REPO_DIR/services/"*.toml        "$ROOTFS/usr/lib/devysix/services/"
install -m644 "$REPO_DIR/desktops/"*.toml        "$ROOTFS/usr/lib/devysix/desktops/"
install -m644 "$REPO_DIR/themes/"*.toml          "$ROOTFS/usr/lib/devysix/themes/"
install -m644 "$REPO_DIR/assets/logo.txt"        "$ROOTFS/usr/lib/devysix/assets/logo.txt"
install -m644 "$REPO_DIR/config/devysix.toml"    "$ROOTFS/etc/devysix/devysix.toml"
install -m644 "$REPO_DIR/config/fastfetch.jsonc" "$ROOTFS/etc/skel/.config/fastfetch/config.jsonc"
install -m755 "$REPO_DIR/s6-linux-init/scripts/rc.init"     "$ROOTFS/etc/s6-linux-init/scripts/rc.init"
install -m755 "$REPO_DIR/s6-linux-init/scripts/rc.shutdown" "$ROOTFS/etc/s6-linux-init/scripts/rc.shutdown"
install -m755 "$REPO_DIR/s6-linux-init/scripts/rc.final"    "$ROOTFS/etc/s6-linux-init/scripts/rc.final"
install -m755 "$REPO_DIR/installer/devysix-setup" "$ROOTFS/usr/local/sbin/devysix-setup"

# ── chroot configuration ──────────────────────────────────────────────────────

echo "iso: configuring system in chroot..."

mount --bind /proc "$ROOTFS/proc"
mount --bind /sys  "$ROOTFS/sys"
mount --bind /dev  "$ROOTFS/dev"

cp "$REPO_DIR/build/chroot-setup.sh" "$ROOTFS/tmp/chroot-setup.sh"
chmod +x "$ROOTFS/tmp/chroot-setup.sh"
chroot "$ROOTFS" /tmp/chroot-setup.sh
rm "$ROOTFS/tmp/chroot-setup.sh"

umount "$ROOTFS/dev"
umount "$ROOTFS/sys"
umount "$ROOTFS/proc"

# ── copy kernel + initrd into ISO staging area ────────────────────────────────

echo "iso: staging kernel and initrd..."
cp "$ROOTFS/boot/vmlinuz"   "$ISO_STAGE/boot/vmlinuz" 2>/dev/null \
    || cp "$ROOTFS/boot/vmlinuz-"* "$ISO_STAGE/boot/vmlinuz"
cp "$ROOTFS/boot/initrd.img" "$ISO_STAGE/boot/initrd.img" 2>/dev/null \
    || cp "$ROOTFS/boot/initrd.img-"* "$ISO_STAGE/boot/initrd.img"

# ── squashfs ──────────────────────────────────────────────────────────────────

echo "iso: creating squashfs..."
mksquashfs "$ROOTFS" "$ISO_STAGE/live/filesystem.squashfs" \
    -comp xz -e boot \
    || die "mksquashfs failed"

info "squashfs size: $(du -sh "$ISO_STAGE/live/filesystem.squashfs" | cut -f1)"

# ── GRUB config ───────────────────────────────────────────────────────────────

cat > "$ISO_STAGE/boot/grub/grub.cfg" <<EOF
set default=0
set timeout=5

menuentry "Devysix $VERSION" {
    linux  /boot/vmlinuz boot=live quiet splash
    initrd /boot/initrd.img
}

menuentry "Devysix $VERSION (verbose)" {
    linux  /boot/vmlinuz boot=live
    initrd /boot/initrd.img
}
EOF

# ── assemble ISO ──────────────────────────────────────────────────────────────

echo "iso: assembling ISO..."
grub-mkrescue -o "$OUT_DIR/devysix-$VERSION.iso" "$ISO_STAGE" \
    -- -volid "DEVYSIX_$VERSION" \
    || die "grub-mkrescue failed"

info "ISO: $OUT_DIR/devysix-$VERSION.iso"
ls -lh "$OUT_DIR/devysix-$VERSION.iso"
