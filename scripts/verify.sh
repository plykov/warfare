#!/usr/bin/env bash
# M17 — bash equivalent of verify.ps1 for the Linux CI leg (and for manual
# macOS builds, though CI no longer runs macOS).
# PowerShell's Start-Process -WindowStyle Hidden only works on Windows, so
# the non-Windows jobs run this instead. Keep the check list and pass
# markers identical to verify.ps1's.
set -euo pipefail

GODOT="${1:-godot}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/build/logs"
mkdir -p "$LOG_DIR"

IMPORT_LOG="$LOG_DIR/import.log"
echo "Importing project metadata..."
import_status=0
"$GODOT" --headless --path "$PROJECT_ROOT" --log-file "$IMPORT_LOG" --import || import_status=$?
if [ "$import_status" -ne 0 ] || [ ! -f "$PROJECT_ROOT/.godot/global_script_class_cache.cfg" ]; then
	tail -n 200 "$IMPORT_LOG" || true
	echo "Godot project import failed to create the global script class cache." >&2
	exit 1
fi

declare -a NAMES=("unit" "gameplay-smoke" "campaign-smoke" "balance-sim")
declare -a SCENES=(
	"res://tests/test_runner.tscn"
	"res://tests/smoke_game.tscn"
	"res://tests/campaign_smoke.tscn"
	"res://tests/balance_sim.tscn"
)
declare -a MARKERS=(
	"GARDEN RECLAIMED TESTS: 43 passed"
	"GARDEN RECLAIMED SMOKE: gameplay ran 300 frames"
	"GARDEN RECLAIMED CAMPAIGN SMOKE: final commission mixed encounter ran 360 frames"
	"GARDEN RECLAIMED BALANCE SIM: 16 commissions x 3 profiles passed"
)

for i in "${!NAMES[@]}"; do
	name="${NAMES[$i]}"
	scene="${SCENES[$i]}"
	marker="${MARKERS[$i]}"
	log_path="$LOG_DIR/$name.log"
	echo "Running $name..."
	run_status=0
	"$GODOT" --headless --path "$PROJECT_ROOT" --log-file "$log_path" --quit-after 1200 "$scene" || run_status=$?
	cat "$log_path" || true
	if [ "$run_status" -ne 0 ]; then
		echo "$name failed with exit code $run_status. See $log_path." >&2
		exit 1
	fi
	if ! grep -qF "$marker" "$log_path"; then
		echo "$name exited without its pass marker. See $log_path." >&2
		exit 1
	fi
done

echo "All Garden Reclaimed checks passed."
