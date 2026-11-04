#!/usr/bin/env bash

BM_FILE="$HOME/.config/yazi/bookmarks.txt"
mkdir -p "$(dirname "$BM_FILE")"
touch "$BM_FILE"

# Grab the first argument passed by Yazi ($@), fallback to PWD if empty
TARGET="${1:-$PWD}"

# If the cursor is on a file, resolve to its parent directory
if [ -f "$TARGET" ]; then
    TARGET="$(dirname "$TARGET")"
fi

# Replace home directory with ~ for clean formatting
CLEAN_TARGET="${TARGET/#$HOME/\~}"

# Helper function for notifications
notify_user() {
    local title="$1"
    local content="$2"
    if [ -n "$YAZI_ID" ]; then
        ya emit notify --title "$title" --content "$content" --level info --timeout 2
    elif command -v notify-send &>/dev/null; then
        notify-send "$title" "$content"
    else
        echo "$title: $content"
    fi
}

# Check if target already exists in bookmarks
if grep -qF "|$CLEAN_TARGET" "$BM_FILE"; then
    grep -vF "|$CLEAN_TARGET" "$BM_FILE" > "${BM_FILE}.tmp" && mv "${BM_FILE}.tmp" "$BM_FILE"
    notify_user "Places" "Removed: $(basename "$TARGET")"
else
    DEFAULT_NAME="$(basename "$TARGET")"
    read -rp "Bookmark name [$DEFAULT_NAME]: " NAME
    NAME="${NAME:-$DEFAULT_NAME}"

    echo "${NAME}|${CLEAN_TARGET}" >> "$BM_FILE"
    notify_user "Places" "Added: $NAME"
fi
