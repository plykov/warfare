#!/usr/bin/env bash
# M17 — bash equivalent of build_windows.ps1, parameterized by export preset
# so the same script serves both the Linux and macOS CI legs.
set -euo pipefail

PRESET="$1"
OUTPUT="$2"
GODOT="${3:-godot}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "$OUTPUT" = /* ]]; then
	OUTPUT_PATH="$OUTPUT"
else
	OUTPUT_PATH="$PROJECT_ROOT/$OUTPUT"
fi
OUTPUT_DIR="$(dirname "$OUTPUT_PATH")"
LOG_PATH="$OUTPUT_DIR/$(basename "$PRESET" | tr ' ' '-')-export.log"

mkdir -p "$OUTPUT_DIR"

export_status=0
"$GODOT" --headless --path "$PROJECT_ROOT" --log-file "$LOG_PATH" --export-release "$PRESET" "$OUTPUT_PATH" || export_status=$?

if [ "$export_status" -ne 0 ] || [ ! -e "$OUTPUT_PATH" ]; then
	if [ -f "$LOG_PATH" ]; then
		tail -n 200 "$LOG_PATH"
	fi
	echo "$PRESET export failed. Install the matching Godot 4.4.1 export templates and inspect $LOG_PATH." >&2
	exit 1
fi

echo "$PRESET build created at $OUTPUT_PATH."
