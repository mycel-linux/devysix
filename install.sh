#!/bin/sh
# install devysix tooling onto a running Devuan system

die() { echo "install: $1" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "must be run as root"

REPO_DIR="$(dirname "$(realpath "$0")")"

echo "devysix: installing system tooling..."

install -dm755 /usr/lib/devysix
install -dm755 /usr/lib/devysix/build
install -dm755 /usr/lib/devysix/services
install -dm755 /usr/lib/devysix/desktops
install -dm755 /usr/lib/devysix/themes
install -dm755 /usr/lib/devysix/commands
install -dm755 /usr/lib/devysix/assets
install -dm755 /etc/skel/.config/fastfetch
install -dm755 /etc/devysix
install -dm755 /var/lib/devysix/generations
install -dm755 /etc/s6-linux-init/scripts
install -dm755 /etc/s6-rc/source

# libraries
install -m644 "$REPO_DIR/lib/toml.sh"        /usr/lib/devysix/toml.sh
install -m644 "$REPO_DIR/lib/generations.sh"  /usr/lib/devysix/generations.sh

# CLI
install -m755 "$REPO_DIR/cli/dev"  /usr/local/bin/dev
for cmd in "$REPO_DIR/cli/commands/"*; do
    install -m755 "$cmd" /usr/lib/devysix/commands/
done

# build helpers
install -m755 "$REPO_DIR/build/build-skarnet.sh" /usr/lib/devysix/build/build-skarnet.sh

# service definitions, desktop profiles, themes, assets
install -m644 "$REPO_DIR/services/"*.toml    /usr/lib/devysix/services/
install -m644 "$REPO_DIR/desktops/"*.toml    /usr/lib/devysix/desktops/
install -m644 "$REPO_DIR/themes/"*.toml      /usr/lib/devysix/themes/
install -m644 "$REPO_DIR/assets/logo.txt"    /usr/lib/devysix/assets/logo.txt

# fastfetch config — installed to /etc/skel so new users get it
install -m644 "$REPO_DIR/config/fastfetch.jsonc" \
    /etc/skel/.config/fastfetch/config.jsonc

# s6-linux-init scripts
install -m755 "$REPO_DIR/s6-linux-init/scripts/rc.init"     /etc/s6-linux-init/scripts/rc.init
install -m755 "$REPO_DIR/s6-linux-init/scripts/rc.shutdown" /etc/s6-linux-init/scripts/rc.shutdown
install -m755 "$REPO_DIR/s6-linux-init/scripts/rc.final"    /etc/s6-linux-init/scripts/rc.final

# default config (only if not already present)
if [ ! -f /etc/devysix/devysix.toml ]; then
    install -m644 "$REPO_DIR/config/devysix.toml" /etc/devysix/devysix.toml
fi

echo "devysix: installed"
