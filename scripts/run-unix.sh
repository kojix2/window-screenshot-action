#!/usr/bin/env bash
set -euo pipefail
ACTION_PATH=${ACTION_PATH:-$(cd "$(dirname "$0")/.." && pwd)}
export ACTION_PATH
# shellcheck source=scripts/inputs.sh
source "$ACTION_PATH/scripts/inputs.sh"
# shellcheck source=scripts/common.sh
source "$ACTION_PATH/scripts/common.sh"
export WINDOW_TIMEOUT CAPTURE_DELAY

case "$REQUESTED_OS" in
  ubuntu)
    for command in xvfb-run Xvfb xauth openbox wmctrl import; do require_command "$command"; done
    xvfb-run -e /dev/stderr -a -s '-screen 0 1280x800x24' bash "$ACTION_PATH/scripts/linux-session.sh"
    ;;
  macos)
    require_command swiftc
    require_command screencapture
    helper_dir=$(mktemp -d)
    trap 'rm -rf "$helper_dir"' EXIT
    swiftc "$ACTION_PATH/scripts/window.swift" -o "$helper_dir/window"
    for i in "${!apps[@]}"; do
      bash "$ACTION_PATH/scripts/macos.sh" "${apps[$i]}" "${outputs[$i]}" "$helper_dir/window"
    done
    ;;
  *) fail "Unsupported OS: $REQUESTED_OS" ;;
esac
publish_outputs "${outputs[@]}"
