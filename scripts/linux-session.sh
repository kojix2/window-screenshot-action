#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/inputs.sh
source "$ACTION_PATH/scripts/inputs.sh"
# shellcheck source=scripts/common.sh
source "$ACTION_PATH/scripts/common.sh"
export NO_AT_BRIDGE=1 GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb
openbox &
wm_pid=$!
trap 'stop_process "$wm_pid"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
ready=false
for _ in {1..50}; do
  kill -0 "$wm_pid" 2>/dev/null || { echo 'Openbox exited before becoming ready' >&2; exit 1; }
  if wmctrl -m >/dev/null 2>&1; then ready=true; break; fi
  sleep 0.1
done
[ "$ready" = true ] || { echo 'Openbox did not become ready' >&2; exit 1; }
for i in "${!apps[@]}"; do
  bash "$ACTION_PATH/scripts/linux.sh" "${apps[$i]}" "${outputs[$i]}"
done
