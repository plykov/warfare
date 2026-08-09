#!/usr/bin/env bash
# M17 — bash equivalent of smoke_windows.ps1, parameterized by the exported
# artifact path. macOS exports as a .zip containing a .app bundle, so this
# unzips first and resolves the executable inside Contents/MacOS/.
set -euo pipefail

ARTIFACT="$1"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/build/logs"
mkdir -p "$LOG_DIR"

if [[ "$ARTIFACT" = /* ]]; then
	ARTIFACT_PATH="$ARTIFACT"
else
	ARTIFACT_PATH="$PROJECT_ROOT/$ARTIFACT"
fi

if [ ! -e "$ARTIFACT_PATH" ]; then
	echo "Exported artifact not found at $ARTIFACT_PATH." >&2
	exit 1
fi

EXECUTABLE="$ARTIFACT_PATH"
if [[ "$ARTIFACT_PATH" == *.zip ]]; then
	EXTRACT_DIR="$(dirname "$ARTIFACT_PATH")/macos-extracted"
	rm -rf "$EXTRACT_DIR"
	mkdir -p "$EXTRACT_DIR"
	unzip -q "$ARTIFACT_PATH" -d "$EXTRACT_DIR"
	APP_BUNDLE="$(find "$EXTRACT_DIR" -maxdepth 1 -name '*.app' | head -n 1)"
	if [ -z "$APP_BUNDLE" ]; then
		echo "No .app bundle found inside $ARTIFACT_PATH." >&2
		exit 1
	fi
	EXECUTABLE="$(find "$APP_BUNDLE/Contents/MacOS" -maxdepth 1 -type f | head -n 1)"
	chmod +x "$EXECUTABLE"
else
	chmod +x "$EXECUTABLE"
fi

declare -a NAMES=("exported-gameplay-smoke" "exported-campaign-smoke" "exported-balance-sim")
declare -a SCENES=(
	"res://tests/smoke_game.tscn"
	"res://tests/campaign_smoke.tscn"
	"res://tests/balance_sim.tscn"
)
declare -a MARKERS=(
	"GARDEN RECLAIMED SMOKE: gameplay ran 300 frames"
	"GARDEN RECLAIMED CAMPAIGN SMOKE: final commission mixed encounter ran 360 frames"
	"GARDEN RECLAIMED BALANCE SIM: 12 commissions x 3 profiles passed"
)

for i in "${!NAMES[@]}"; do
	name="${NAMES[$i]}"
	scene="${SCENES[$i]}"
	marker="${MARKERS[$i]}"
	log_path="$LOG_DIR/$name.log"
	echo "Running $name..."
	run_status=0
	"$EXECUTABLE" --headless --log-file "$log_path" --quit-after 1200 "$scene" || run_status=$?
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

echo "Exported build passed all smoke checks."
