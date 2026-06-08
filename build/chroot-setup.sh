#!/bin/sh
# chroot-setup.sh — runs inside the debootstrap chroot during ISO build
# configures: locale, hostname, s6-linux-init, apt sources, auto-setup trigger

set -e

die() { echo "chroot-setup: $1" >&2; exit 1; }

# ── apt sources ───────────────────────────────────────────────────────────────

cat > /etc/apt/sources.list <<EOF
deb https://deb.devuan.org/merged excalibur main contrib non-free non-free-firmware
deb https://deb.devuan.org/merged excalibur-security main contrib non-free non-free-firmware
deb https://deb.devuan.org/merged excalibur-updates main contrib non-free non-free-firmware
EOF

apt-get update -qq

# ── locale ────────────────────────────────────────────────────────────────────

echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

# ── hostname ──────────────────────────────────────────────────────────────────

echo "devysix" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
127.0.1.1   devysix
::1         localhost ip6-localhost ip6-loopback
EOF

# ── s6-linux-init ─────────────────────────────────────────────────────────────

s6-linux-init-maker \
    -1 /etc/s6-linux-init/scripts/rc.init \
    -2 /etc/s6-linux-init/scripts/rc.shutdown \
    -3 /etc/s6-linux-init/scripts/rc.final \
    /etc/s6-linux-init \
    || die "s6-linux-init-maker failed"

ln -sf /etc/s6-linux-init/bin/init /sbin/init

# ── remove conflicting inits ──────────────────────────────────────────────────

# make sure sysvinit-core doesn't fight s6
dpkg --purge sysvinit-core sysv-rc 2>/dev/null || true

# ── sudo ──────────────────────────────────────────────────────────────────────

echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# ── live user (for ISO live session) ─────────────────────────────────────────

useradd -m -s /bin/bash -G audio,video,input,plugdev,netdev,wheel,sudo live
echo "live:live" | chpasswd

# ── auto-run devysix-setup on first login ─────────────────────────────────────

cat >> /etc/skel/.profile <<'EOF'

# devysix: apply active color theme
[ -f ~/.config/devysix/theme.sh ] && . ~/.config/devysix/theme.sh

# devysix: show system info
command -v fastfetch >/dev/null 2>&1 && fastfetch
EOF

# trigger devysix-setup for the live user's first login
cat >> /home/live/.profile <<'EOF'

# first-boot setup
if [ ! -f /etc/devysix/.setup-done ]; then
    exec sudo /usr/local/sbin/devysix-setup
fi
EOF
chown live:live /home/live/.profile

# ── set rhizome as default theme ─────────────────────────────────────────────

su - live -c "DEVYSIX_LIB=/usr/lib/devysix \
    DEVYSIX_CONFIG=/etc/devysix/devysix.toml \
    DEVYSIX_THEMES=/usr/lib/devysix/themes \
    /usr/lib/devysix/commands/theme rhizome" 2>/dev/null || true

# ── apt cleanup ───────────────────────────────────────────────────────────────

apt-get clean
rm -rf /var/lib/apt/lists/*
