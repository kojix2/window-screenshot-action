#!/usr/bin/env bash
set -euo pipefail

app=${1:?executable path is required}
output=${2:?output path is required}
"./$app" &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT

window=
for _ in {1..30}; do
  pids=" $pid $(pgrep -P "$pid" 2>/dev/null | tr '\n' ' ' || true) "
  window=$(wmctrl -lp 2>/dev/null | awk -v pids="$pids" '$3 ~ /^[0-9]+$/ && index(pids, " " $3 " ") { print $1; exit }' || true)
  if [ -z "$window" ]; then
    for id in $(wmctrl -l 2>/dev/null | awk '{print $1}'); do
      owner=$(xprop -id "$id" _NET_WM_PID 2>/dev/null | awk '{print $3}' || true)
      if [ -n "$owner" ] && [[ "$pids" == *" $owner "* ]]; then
        window=$id
        break
      fi
    done
  fi
  [ -n "$window" ] && break
  sleep 0.5
done

if [ -z "$window" ]; then
  echo "No window found for $app (PID $pid)" >&2
  exit 1
fi

wmctrl -i -a "$window" || true
sleep 1
mkdir -p "$(dirname "$output")"
import -frame -window "$window" "$output"
test -s "$output"
