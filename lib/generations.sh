#!/bin/sh
# lib/generations.sh — generation snapshot helpers

DEVYSIX_GEN_DIR="${DEVYSIX_GEN_DIR:-/var/lib/devysix/generations}"

# gen_save <config-file>
# snapshot current config as a new generation, prints the new generation id
gen_save() {
    config="$1"
    mkdir -p "$DEVYSIX_GEN_DIR"

    # find next id
    last="$(ls "$DEVYSIX_GEN_DIR" 2>/dev/null | grep -E '^[0-9]+$' | sort -n | tail -1)"
    id="$(( ${last:-0} + 1 ))"

    dir="$DEVYSIX_GEN_DIR/$id"
    mkdir -p "$dir"

    cp "$config" "$dir/devysix.toml"
    dpkg --get-selections 2>/dev/null | awk '$2=="install"{print $1}' > "$dir/packages.txt"
    date -Iseconds > "$dir/timestamp"
    echo "$id" > "$dir/id"

    echo "$id"
}

# gen_list
# print all generations newest-first: id  timestamp  hostname
gen_list() {
    for dir in $(ls -rd "$DEVYSIX_GEN_DIR"/[0-9]* 2>/dev/null); do
        id="$(cat "$dir/id" 2>/dev/null)"
        ts="$(cat "$dir/timestamp" 2>/dev/null)"
        host="$(grep '^hostname' "$dir/devysix.toml" 2>/dev/null | head -1 | sed 's/.*= *"\(.*\)"/\1/')"
        printf "  %3s  %s  %s\n" "$id" "$ts" "$host"
    done
}

# gen_path <id>
# print the directory for generation id
gen_path() {
    echo "$DEVYSIX_GEN_DIR/$1"
}

# gen_current
# print the id of the last applied generation
gen_current() {
    cat "$DEVYSIX_GEN_DIR/current" 2>/dev/null || echo "none"
}

# gen_set_current <id>
gen_set_current() {
    echo "$1" > "$DEVYSIX_GEN_DIR/current"
}
