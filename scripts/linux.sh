#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"
app=${1:?executable path is required}
output=${2:?output path is required}
timeout=${WINDOW_TIMEOUT:-15}
delay=${CAPTURE_DELAY:-1}
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
window=
# wmctrl -lp lists windows with their owner PIDs; titles are never evaluated.
deadline=$((SECONDS + timeout))
while [ "$SECONDS" -lt "$deadline" ]; do
  window=$(wmctrl -lp | awk -v pid="$pid" '$3 == pid && !found++ { print $1 }')
  [ -n "$window" ] && break
  kill -0 "$pid" 2>/dev/null || break
  sleep 0.2
done
[ -n "$window" ] || { printf 'No window found for %s (PID %s) within %ss\n' "$app" "$pid" "$timeout" >&2; exit 1; }
wmctrl -i -a "$window" || true
sleep "$delay"
kill -0 "$pid" 2>/dev/null || { echo "Application exited before capture: $app" >&2; exit 1; }
import -frame -window "$window" "png:$temp_dir/capture.png"
test -s "$temp_dir/capture.png"
mv -f "$temp_dir/capture.png" "./$output"
printf 'Saved window screenshot: %s\n' "$output"
