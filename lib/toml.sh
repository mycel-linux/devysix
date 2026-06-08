#!/bin/sh
# lib/toml.sh — devysix TOML parser
# handles: [sections], key = "string", key = ["array", "items"]
# source this file: . /usr/lib/devysix/toml.sh

# toml_get <file> <section> <key>
# prints the unquoted scalar value, or empty string if not found
toml_get() {
    awk -v sec="[$2]" -v key="$3" '
        $0 == sec           { in_sec=1; next }
        in_sec && /^\[/     { exit }
        in_sec {
            # strip leading whitespace and comments
            line = $0
            sub(/^[[:space:]]+/, "", line)
            sub(/[[:space:]]*#.*$/, "", line)
            if (line ~ "^" key "[[:space:]]*=") {
                sub(/^[^=]*=[[:space:]]*/, "", line)
                # strip surrounding quotes
                gsub(/^["'"'"']|["'"'"']$/, "", line)
                print line
                exit
            }
        }
    ' "$1"
}

# toml_get_array <file> <section> <key>
# prints each array element on its own line, unquoted
toml_get_array() {
    awk -v sec="[$2]" -v key="$3" '
        $0 == sec               { in_sec=1; next }
        in_sec && /^\[/ && !/=/ { exit }
        in_sec {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            sub(/[[:space:]]*#.*$/, "", line)

            if (!collecting && line ~ "^" key "[[:space:]]*=") {
                sub(/^[^=]*=[[:space:]]*/, "", line)
                collecting=1
            }

            if (collecting) {
                # extract all "quoted" items from this line
                while (match(line, /"[^"]*"/)) {
                    item = substr(line, RSTART+1, RLENGTH-2)
                    print item
                    line = substr(line, RSTART+RLENGTH)
                }
                # stop collecting when we hit the closing ]
                if (line ~ /\]/) exit
            }
        }
    ' "$1"
}

# toml_set <file> <section> <key> <value>
# updates an existing scalar; adds it if missing from section
toml_set() {
    file="$1" section="$2" key="$3" value="$4"
    tmp="$(mktemp)"

    awk -v sec="[$section]" -v key="$key" -v val="$value" '
        $0 == sec           { in_sec=1; print; next }
        in_sec && /^\[/     { in_sec=0 }
        in_sec {
            line = $0
            stripped = line
            sub(/^[[:space:]]+/, "", stripped)
            if (stripped ~ "^" key "[[:space:]]*=") {
                print key " = \"" val "\""
                found=1
                next
            }
        }
        { print }
        END {
            if (!found) {
                print "# key not found: " key " in " sec > "/dev/stderr"
            }
        }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# toml_array_add <file> <section> <key> <value>
# appends value to the array if not already present
toml_array_add() {
    file="$1" section="$2" key="$3" value="$4"

    toml_array_contains "$file" "$section" "$key" "$value" && return 0

    tmp="$(mktemp)"
    awk -v sec="[$section]" -v key="$key" -v val="$value" '
        $0 == sec           { in_sec=1; print; next }
        in_sec && /^\[/ && !/=/ { in_sec=0 }
        in_sec {
            line = $0
            stripped = line
            sub(/^[[:space:]]+/, "", stripped)
            if (!collecting && stripped ~ "^" key "[[:space:]]*=") {
                collecting=1
            }
            if (collecting && $0 ~ /\]/) {
                # insert before closing bracket line
                sub(/\]/, "    \"" val "\",\n]", $0)
                collecting=0
            }
        }
        { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# toml_array_remove <file> <section> <key> <value>
# removes value from the array
toml_array_remove() {
    file="$1" section="$2" key="$3" value="$4"
    tmp="$(mktemp)"

    awk -v sec="[$section]" -v key="$key" -v val="$value" '
        $0 == sec               { in_sec=1; print; next }
        in_sec && /^\[/ && !/=/ { in_sec=0 }
        in_sec {
            stripped = $0
            sub(/^[[:space:]]+/, "", stripped)
            if (!collecting && stripped ~ "^" key "[[:space:]]*=") {
                collecting=1
            }
            if (collecting) {
                # skip lines that contain only this value
                line = $0
                sub(/^[[:space:]]*"/ , "", line)
                sub(/"[[:space:]]*,?[[:space:]]*$/, "", line)
                if (line == val) next
                if ($0 ~ /\]/) collecting=0
            }
        }
        { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# toml_array_contains <file> <section> <key> <value>
# returns 0 if value is in array, 1 otherwise
toml_array_contains() {
    toml_get_array "$1" "$2" "$3" | grep -qxF "$4"
}
