#!/usr/bin/env bash
# One-command playtest on this laptop.
#
#   tools/play.sh              Play from the Godot project (Linux, latest code, no build needed)
#   tools/play.sh windows      Build (if code changed) and play the Windows .exe through Wine
#   tools/play.sh android      Build (if code changed) and install + launch on a USB-connected phone
#   tools/play.sh editor       Open the Godot editor
#
# Extra flags after the mode are passed to the game, e.g.:
#   tools/play.sh linux --mobile-ui     (show the touch controls on PC)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-linux}"
shift || true
GAME_ARGS=("$@")
EXE="$ROOT/build/windows/ASCENDANT.exe"
APK="$ROOT/build/android/ascendant-debug.apk"
PACKAGE="com.kodokkejepit.ascendant"
ADB="${ADB:-$HOME/Android/Sdk/platform-tools/adb}"

# True if any project file is newer than the given build output.
needs_rebuild() {
	local out="$1"
	[[ ! -f "$out" ]] && return 0
	[[ -n "$(find "$ROOT" \( -path "$ROOT/.git" -o -path "$ROOT/.godot" -o -path "$ROOT/build" -o -path "$ROOT/android" \) -prune \
		-o -type f -newer "$out" -print -quit)" ]]
}

case "$MODE" in
	linux)
		exec "$GODOT" --path "$ROOT" -- "${GAME_ARGS[@]}"
		;;
	editor)
		exec "$GODOT" --path "$ROOT" --editor
		;;
	windows)
		command -v wine >/dev/null || { echo "Wine is not installed: sudo apt install wine" >&2; exit 1; }
		if needs_rebuild "$EXE"; then
			echo "Code changed since the last Windows build, rebuilding..."
			"$ROOT/tools/build.sh" windows
		fi
		echo "Starting ASCENDANT.exe in Wine (close the window or press Alt+F4 to quit)..."
		cd "$(dirname "$EXE")"
		WINEDEBUG=-all exec wine "$EXE" -- "${GAME_ARGS[@]}"
		;;
	android)
		if needs_rebuild "$APK"; then
			echo "Code changed since the last APK build, rebuilding..."
			"$ROOT/tools/build.sh" android
		fi
		if ! "$ADB" get-state >/dev/null 2>&1; then
			echo "No phone found. Enable USB debugging, plug it in, accept the prompt, then retry." >&2
			echo "APK is at: $APK" >&2
			exit 1
		fi
		"$ADB" install -r "$APK"
		"$ADB" shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null
		echo "Launched on the phone."
		;;
	*)
		echo "Usage: tools/play.sh [linux|windows|android|editor] [game args...]" >&2
		exit 2
		;;
esac
