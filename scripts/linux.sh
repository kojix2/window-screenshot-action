#!/usr/bin/env bash
set -euo pipefail

app=${1:?executable path is required}
output=${2:?output path is required}
"./$app" &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT

window=
for _ in {1..30}; do
  window=$(wmctrl -lp 2>/dev/null | awk -v pid="$pid" '$3 == pid && !found++ { print $1 }' || true)
  [ -n "$window" ] && break
  kill -0 "$pid" 2>/dev/null || break
  sleep 0.5
done

if [ -z "$window" ]; then
  echo "No window found for $app (PID $pid)" >&2
  exit 1
fi

wmctrl -i -a "$window" || true
sleep 1
mkdir -p "$(dirname "$output")"
import -frame -window "$window" "png:$output"
test -s "$output"
