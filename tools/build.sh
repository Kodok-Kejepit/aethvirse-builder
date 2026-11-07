#!/usr/bin/env bash
# Export ASCENDANT from Linux via the Godot CLI.
#
# Usage:
#   tools/build.sh [windows|android|aab|share|all] [debug|release]
#   share = small release APK signed with the local debug key, for sending to a phone
#           (no debug overlay). Output: build/android/ascendant-share.apk
#
# Defaults: all debug. Output goes to build/<platform>/.
# Requirements (machine-local, not in the repo):
#   - Godot 4.7.2 on PATH as `godot` (or set GODOT=/path/to/godot)
#   - Matching export templates in ~/.local/share/godot/export_templates/4.7.2.stable
#   - Android: SDK path, JDK 17-21 path and debug keystore in Godot editor settings
#     (export/android/*). Release keystore via env vars:
#     GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD. Never commit it.
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-all}"
MODE="${2:-debug}"

case "$MODE" in
	debug) EXPORT_FLAG="--export-debug" ;;
	release) EXPORT_FLAG="--export-release" ;;
	*) echo "Unknown mode: $MODE (use debug|release)" >&2; exit 2 ;;
esac

cd "$ROOT"
# Keep Godot from importing/exporting build output.
mkdir -p "$ROOT/build" && touch "$ROOT/build/.gdignore"

# Gradle refuses to build when ANDROID_SDK_ROOT and the SDK path from Godot's editor
# settings (passed as ANDROID_HOME) disagree. Godot's editor setting is the source of truth.
unset ANDROID_SDK_ROOT

GODOT_VERSION="$("$GODOT" --version | cut -d. -f1-3)"
GRADLE_FILE="$ROOT/android/build/build.gradle"
PATCH_MARKER="// ascendant: compress dex"

# Installs the Android build template only when missing / outdated (Godot reinstalls it on
# every export that passes --install-android-build-template, which would drop our patch).
needs_android_template() {
	[[ ! -f "$ROOT/android/.build_version" ]] || [[ "$(cat "$ROOT/android/.build_version")" != "$GODOT_VERSION"* ]]
}

# Store classes.dex compressed (AGP keeps it uncompressed for minSdk >= 28): ~3 MB smaller APK.
patch_android_template() {
	[[ -f "$GRADLE_FILE" ]] || return 1
	grep -q "$PATCH_MARKER" "$GRADLE_FILE" && return 1
	sed -i "s#^    packagingOptions {#    packagingOptions {\n        $PATCH_MARKER\n        dex { useLegacyPackaging true }#" "$GRADLE_FILE"
	echo "Patched Android build template ($PATCH_MARKER)"
	return 0
}

export_preset() {
	local preset="$1" out="$2" extra=()
	if [[ "$preset" == Android* ]] && needs_android_template; then
		extra=(--install-android-build-template)
	fi
	mkdir -p "$(dirname "$out")"
	echo "== Exporting '$preset' ($MODE) -> $out"
	"$GODOT" --headless --path . "${extra[@]}" "$EXPORT_FLAG" "$preset" "$out"
	if [[ "$preset" == Android* ]] && patch_android_template; then
		echo "== Re-exporting '$preset' with the patched template"
		"$GODOT" --headless --path . "$EXPORT_FLAG" "$preset" "$out"
	fi
	if [[ ! -s "$out" ]]; then
		echo "Export failed: $out was not produced" >&2
		exit 1
	fi
	ls -lh "$out"
}

# Make sure imports are up to date before exporting.
"$GODOT" --headless --path . --import >/dev/null 2>&1

case "$TARGET" in
	windows) export_preset "Windows Desktop" "build/windows/ASCENDANT.exe" ;;
	android) export_preset "Android APK" "build/android/ascendant-$MODE.apk" ;;
	aab) export_preset "Android AAB" "build/android/ascendant-$MODE.aab" ;;
	share)
		EXPORT_FLAG="--export-release"
		export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-$HOME/.android/debug.keystore}"
		export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-androiddebugkey}"
		export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:-android}"
		export_preset "Android APK" "build/android/ascendant-share.apk"
		;;
	all)
		export_preset "Windows Desktop" "build/windows/ASCENDANT.exe"
		export_preset "Android APK" "build/android/ascendant-$MODE.apk"
		export_preset "Android AAB" "build/android/ascendant-$MODE.aab"
		;;
	*) echo "Unknown target: $TARGET (use windows|android|aab|share|all)" >&2; exit 2 ;;
esac

echo "Build done."
