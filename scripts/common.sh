#!/usr/bin/env bash

# Reap only the process this action started, with a bounded graceful shutdown.
stop_process() {
  local child=${1:-} _
  [ -n "$child" ] || return 0
  if kill -0 "$child" 2>/dev/null; then
    kill "$child" 2>/dev/null || true
    for _ in {1..20}; do
      kill -0 "$child" 2>/dev/null || break
      sleep 0.1
    done
    kill -KILL "$child" 2>/dev/null || true
  fi
  wait "$child" 2>/dev/null || true
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || { printf 'Required command not found: %s. See README prerequisites.\n' "$1" >&2; exit 1; }
}

publish_outputs() {
  [ -n "${GITHUB_OUTPUT:-}" ] || return 0
  # The delimiter cannot equal a validated path ending in .png.
  {
    printf 'files<<WINDOW_SCREENSHOT_FILES\n'
    printf '%s\n' "$@"
    printf 'WINDOW_SCREENSHOT_FILES\ncount=%s\n' "$#"
  } >> "$GITHUB_OUTPUT"
}
