#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"
app=${1:?executable path is required}
output=${2:?output path is required}
helper=${3:?window helper path is required}
pid='' temp_dir=''
cleanup() {
  stop_process "$pid"
  [ -z "$temp_dir" ] || rm -rf "$temp_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "./$(dirname "$output")"
temp_dir=$(mktemp -d "./$(dirname "$output")/.window-screenshot.XXXXXX")
"./$app" &
pid=$!
window=$("$helper" "$pid" "${WINDOW_TIMEOUT:-15}")
sleep "${CAPTURE_DELAY:-1}"
kill -0 "$pid" 2>/dev/null || { echo "Application exited before capture: $app" >&2; exit 1; }
screencapture -x -o -t png -l"$window" "$temp_dir/capture.png"
test -s "$temp_dir/capture.png"
mv -f "$temp_dir/capture.png" "./$output"
printf 'Saved window screenshot: %s\n' "$output"
