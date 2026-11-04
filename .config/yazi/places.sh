#!/usr/bin/env bash

BM_FILE="$HOME/.config/yazi/bookmarks.txt"
TMP_TARGET="/tmp/yazi_places_target"
rm -f "$TMP_TARGET"

[ ! -s "$BM_FILE" ] && exit 0

export BM_FILE

shift_bookmark() {
    local direction="$1"
    local name="$2"
    python3 - "$BM_FILE" "$direction" "$name" << 'EOF'
import sys
path, direction, name = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, "r") as f:
    lines = [l.strip() for l in f if l.strip()]

idx = next((i for i, l in enumerate(lines) if l.split("|")[0] == name), -1)
if idx != -1:
    if direction == "up" and idx > 0:
        lines[idx], lines[idx-1] = lines[idx-1], lines[idx]
    elif direction == "down" and idx < len(lines) - 1:
        lines[idx], lines[idx+1] = lines[idx+1], lines[idx]
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
EOF
}

export -f shift_bookmark

# Run fzf with Ctrl-Up/Down bound to jump 4 items at a time
selection=$(cut -d'|' -f1 "$BM_FILE" | fzf \
    --prompt="󰉋 Places > " \
    --header="-- BOOKMARKS (Enter: cd, Ctrl-D: del, Ctrl-Q: quit, Ctrl-K/J: move, Ctrl-↑/↓: jump) --" \
    --height=100% \
    --layout=reverse \
    --track \
    --id-nth=1 \
    --expect="ctrl-d,ctrl-q" \
    --bind="ctrl-k:execute-silent(shift_bookmark up {1})+reload(cut -d'|' -f1 \"$BM_FILE\")" \
    --bind="ctrl-j:execute-silent(shift_bookmark down {1})+reload(cut -d'|' -f1 \"$BM_FILE\")" \
    --bind="ctrl-up:up+up+up+up" \
    --bind="ctrl-down:down+down+down+down")

key=$(echo "$selection" | head -n1)
chosen_name=$(echo "$selection" | tail -n +2)

if [ "$key" = "ctrl-q" ] || [ -z "$chosen_name" ]; then
    exit 0
fi

raw_path=$(awk -F'|' -v name="$chosen_name" '$1 == name {print $2}' "$BM_FILE" | head -n1)

if [ "$key" = "ctrl-d" ]; then
    escaped_name=$(printf '%s\n' "$chosen_name" | sed -e 's/[]\/$*.^[]/\\&/g')
    sed -i "/^${escaped_name}|/d" "$BM_FILE"
    notify-send "Places" "Deleted: $chosen_name"
    exit 0
fi

target="${raw_path/#\~/$HOME}"
echo "$target" > "$TMP_TARGET"
