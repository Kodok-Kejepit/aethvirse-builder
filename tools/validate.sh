#!/usr/bin/env bash
# Project validation (CLAUDE.md §13): import, strict script check, smoke run, unit tests.
# Usage: tools/validate.sh            Exit code != 0 on any error or GDScript warning.
set -uo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$ROOT/.godot_log.txt"
cd "$ROOT"

cleanup() { rm -f "$ROOT/override.cfg"; }
trap cleanup EXIT

fail=0
step() { printf '\n== %s\n' "$1"; }
# Lines that indicate a real problem in Godot output.
scan() { grep -E 'SCRIPT ERROR|^ERROR|Parse Error|WARNING' "$1" | grep -v 'res://addons/' || true; }

step "import"
"$GODOT" --headless --path . --import >"$LOG.import" 2>&1
issues="$(scan "$LOG.import")"; [[ -n "$issues" ]] && { echo "$issues"; fail=1; }

step "strict script check (warnings = errors)"
"$GODOT" --headless --path . -s res://tools/dump_strict_warnings.gd >/dev/null 2>&1
timeout 300 "$GODOT" --headless --path . -s res://tools/check_resources.gd >"$LOG.check" 2>&1 || fail=1
issues="$(scan "$LOG.check")"; [[ -n "$issues" ]] && { echo "$issues"; fail=1; }
grep 'check_resources:' "$LOG.check"

step "smoke run (120 frames)"
"$GODOT" --headless --path . --quit-after 120 >"$LOG" 2>&1
issues="$(scan "$LOG")"; [[ -n "$issues" ]] && { echo "$issues"; fail=1; }
for scene in scenes/test/*.tscn scenes/main/*.tscn scenes/world/gates/gate_dungeon.tscn scenes/world/gates/penalty_zone.tscn scenes/world/regions/*.tscn; do
	[[ -f "$scene" ]] || continue
	"$GODOT" --headless --path . --quit-after 120 "res://$scene" >"$LOG.scene" 2>&1
	issues="$(scan "$LOG.scene")"
	if [[ -n "$issues" ]]; then echo "[$scene]"; echo "$issues"; fail=1; else echo "ok $scene"; fi
done
rm -f "$LOG.scene"
cleanup

step "unit tests (GUT)"
run_gut() { "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit >"$LOG.gut" 2>&1; }
if ! run_gut; then
	# Known rare engine crash during shutdown AFTER all tests passed: retry once, report it.
	if grep -q "All tests passed" "$LOG.gut"; then
		echo "note: engine crashed at exit after all tests passed (known flaky shutdown crash), retrying once"
		run_gut || fail=1
	else
		fail=1
	fi
fi
grep -E 'Tests |Passing Tests|Failing Tests|Pending|Asserts' "$LOG.gut" | sed 's/\x1b\[[0-9;]*m//g'
issues="$(scan "$LOG.gut")"; [[ -n "$issues" ]] && { echo "$issues"; fail=1; }

rm -f "$LOG.import" "$LOG.check" "$LOG.gut"
if [[ $fail -ne 0 ]]; then echo -e "\nVALIDATION FAILED"; exit 1; fi
echo -e "\nVALIDATION OK"
