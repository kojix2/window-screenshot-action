#!/usr/bin/env bash
# Sourced by the entry point; compatible with macOS Bash 3.2.

fail() { printf '%s\n' "$*" >&2; exit 1; }

validate_integer() {
  local value=$1 minimum=$2 maximum=$3 label=$4
  [[ "$value" =~ ^(0|[1-9][0-9]{0,2})$ ]] || fail "$label must be an integer from $minimum to $maximum"
  [ "$value" -ge "$minimum" ] && [ "$value" -le "$maximum" ] || fail "$label must be an integer from $minimum to $maximum"
}

# Normalize aliases before checking duplicates. Paths are workspace-relative.
normalize_path() {
  local path=$1 part result='' old_ifs=$IFS
  case "$path" in ''|/*|*:*|*\\*) fail "Use a nonempty workspace-relative path with forward slashes: $path" ;; esac
  [[ ! "$path" =~ [[:cntrl:]] ]] || fail 'Paths must not contain control characters'
  case "$path" in */|*/.|.|..|*/../*|../*|*/..) fail "Invalid file path: $path" ;; esac
  IFS=/
  # Intentional splitting on / only, with glob expansion disabled.
  set -f
  for part in $path; do
    case "$part" in ''|.) continue ;; esac
    result=${result:+$result/}$part
  done
  set +f
  IFS=$old_ifs
  [ -n "$result" ] || fail 'File path must be nonempty'
  printf '%s\n' "$result"
}

WINDOW_TIMEOUT=${WINDOW_TIMEOUT:-15}
CAPTURE_DELAY=${CAPTURE_DELAY:-1}
validate_integer "$WINDOW_TIMEOUT" 1 300 window-timeout
validate_integer "$CAPTURE_DELAY" 0 60 capture-delay

# read -a consumes one line only. Flatten newlines first, without eval.
flat_apps=${APP_NAMES//$'\n'/ }
flat_apps=${flat_apps//$'\r'/ }
flat_outputs=${OUTPUT_FILES//$'\n'/ }
flat_outputs=${flat_outputs//$'\r'/ }
apps=() outputs=()
IFS=$' \t' read -r -a apps <<< "$flat_apps"
IFS=$' \t' read -r -a outputs <<< "$flat_outputs"
[ "${apps[0]:-}" ] || fail 'app-names must be nonempty'

for i in "${!apps[@]}"; do
  apps[i]=$(normalize_path "${apps[$i]}")
  [ -f "./${apps[$i]}" ] && [ -x "./${apps[$i]}" ] || fail "Executable not found or not executable: ${apps[$i]}"
done

if [ -z "${outputs[0]:-}" ]; then
  for app in "${apps[@]}"; do
    name=${app##*/}
    case "$name" in *.[eE][xX][eE]) name=${name%.*} ;; esac
    output=${OUTPUT_PATTERN//\{name\}/"$name"}
    output=${output//\{os\}/"$REQUESTED_OS"}
    outputs+=("$output")
  done
fi
[ "${#apps[@]}" -eq "${#outputs[@]}" ] || fail 'app-names and output-files must have the same length'

for i in "${!outputs[@]}"; do
  outputs[i]=$(normalize_path "${outputs[$i]}")
  output=${outputs[$i]}
  case "$output" in *.[pP][nN][gG]) ;; *) fail "Output must have a .png extension: $output" ;; esac
  case "$output" in *'{'*|*'}'*) fail "Unknown placeholder in output path: $output" ;; esac
  [ ! -d "./$output" ] || fail "Output is a directory: $output"
  for app in "${apps[@]}"; do
    [ "$output" != "$app" ] || fail "Output would overwrite an executable: $output"
    if [ -e "./$output" ] && [ "./$output" -ef "./$app" ]; then
      fail "Output aliases an executable: $output"
    fi
  done
  for j in "${!outputs[@]}"; do
    if [ "$j" -lt "$i" ]; then
      # Default macOS volumes compare paths without case sensitivity.
      a=$output b=${outputs[$j]}
      if [ "$REQUESTED_OS" = macos ]; then
        a=$(printf '%s' "$a" | tr '[:upper:]' '[:lower:]')
        b=$(printf '%s' "$b" | tr '[:upper:]' '[:lower:]')
      fi
      [ "$a" != "$b" ] || fail "Duplicate output path: $output"
      if [ -e "./$output" ] && [ -e "./${outputs[$j]}" ] && [ "./$output" -ef "./${outputs[$j]}" ]; then
        fail "Duplicate output file: $output"
      fi
    fi
  done
done
