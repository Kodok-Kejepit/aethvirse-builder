#!/usr/bin/env bash
# Headless screenshot of the game on an invisible virtual display (Xvfb), so it never
# touches the desktop. Works for the editor project (Linux) and the Windows build (Wine).
#
# Usage: tools/screenshot.sh [linux|windows] [WIDTHxHEIGHT] [delay_s] [out.png] [--overlay] [--mobile-ui]
#   SCENE=res://scenes/test/test_movement.tscn tools/screenshot.sh linux ...   (linux only)
#   tools/screenshot.sh linux 1920x1080 7 shots/opening.png
#   tools/screenshot.sh windows 2400x1080 7 shots/opening_win.png --overlay
# Windows mode needs `tools/build.sh windows` first. Rendering uses llvmpipe (CPU),
# so FPS in these shots is not representative.
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-linux}"
RES="${2:-1920x1080}"
DELAY="${3:-7}"
OUT="$(realpath -m "${4:-$ROOT/build/screenshots/${TARGET}_${RES}.png}")"
EXTRA=()
for flag in "${@:5}"; do
	case "$flag" in
		--overlay) EXTRA+=(--capture-overlay) ;;
		--mobile-ui) EXTRA+=(--mobile-ui) ;;
	esac
done
SCENE_ARG=()
[[ -n "${SCENE:-}" ]] && SCENE_ARG=("$SCENE")
mkdir -p "$(dirname "$OUT")"
# Keep Godot from importing/exporting build output.
mkdir -p "$ROOT/build" && touch "$ROOT/build/.gdignore"
rm -f "$OUT"
SCREEN="-screen 0 ${RES}x24"

case "$TARGET" in
	linux)
		timeout 180 xvfb-run -a -s "$SCREEN" "$GODOT" --display-driver x11 --audio-driver Dummy --path "$ROOT" \
			--resolution "$RES" --position 0,0 "${SCENE_ARG[@]}" -- "--capture=$OUT" "--capture-delay=$DELAY" "${EXTRA[@]}"
		;;
	windows)
		EXE="$ROOT/build/windows/ASCENDANT.console.exe"
		[[ -f "$EXE" ]] || { echo "Missing $EXE, run tools/build.sh windows" >&2; exit 1; }
		WIN_OUT="$(winepath -w "$OUT")"
		timeout 300 env WINEDEBUG=-all xvfb-run -a -s "$SCREEN" wine "$EXE" \
			--resolution "$RES" --position 0,0 -- "--capture=$WIN_OUT" "--capture-delay=$DELAY" "${EXTRA[@]}"
		;;
	*) echo "Unknown target: $TARGET (linux|windows)" >&2; exit 2 ;;
esac

[[ -s "$OUT" ]] || { echo "Screenshot failed" >&2; exit 1; }
echo "Saved $OUT"
