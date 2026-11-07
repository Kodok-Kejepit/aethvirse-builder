#!/usr/bin/env bash
# Import world models: put <id>.glb files in ~/Unduhan/assets (or pass a folder), then run
#   tools/import_props.sh [folder] [only_id]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/.local/bin/godot}"
"$GODOT" --headless --path . -s tools/import_props.gd -- "${1:-$HOME/Unduhan/assets}" "${2:-}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
