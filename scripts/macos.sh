#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:?app binary name is required}"
OUTPUT_FILE="${2:?output filename is required}"
WINDOW_HELPER="${3:?window helper path is required}"

echo "Starting macOS window screenshot process for $APP_NAME"

APP_PID=
trap 'if [ -n "$APP_PID" ]; then kill "$APP_PID" 2>/dev/null || true; fi' EXIT

# Launch the application directly so its PID owns the window.
echo "Launching application: ./$APP_NAME"
"./$APP_NAME" &
APP_PID=$!
echo "Application launched with PID: $APP_PID"

# Find the on-screen window id used by screencapture -l.
echo "Waiting for window to appear..."
WINDOW_ID=$("$WINDOW_HELPER" "$APP_PID") || {
  echo "$WINDOW_ID"
  exit 1
}
echo "Window id: $WINDOW_ID"
echo "Capturing with screencapture -l $WINDOW_ID -> $OUTPUT_FILE"
mkdir -p "$(dirname "$OUTPUT_FILE")"
sleep 1
screencapture -x -o -t png -l"$WINDOW_ID" "$OUTPUT_FILE"
test -s "$OUTPUT_FILE"

echo "macOS window screenshot process completed successfully"
