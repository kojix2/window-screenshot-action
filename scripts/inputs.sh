#!/usr/bin/env bash

read -r -a apps <<< "$APP_NAMES"
read -r -a outputs <<< "$OUTPUT_FILES"
if [ "${#apps[@]}" -eq 0 ]; then
  echo 'app-names must be nonempty' >&2
  exit 1
fi

if [ "${#outputs[@]}" -eq 0 ]; then
  for app in "${apps[@]}"; do
    name=${app##*/}
    name=${name%.exe}
    output=${OUTPUT_PATTERN//\{name\}/$name}
    output=${output//\{os\}/$REQUESTED_OS}
    outputs+=("$output")
  done
fi

if [ "${#apps[@]}" -ne "${#outputs[@]}" ]; then
  echo 'app-names and output-files must have the same length' >&2
  exit 1
fi

for i in "${!outputs[@]}"; do
  if [ -z "${outputs[$i]}" ]; then
    echo 'Output paths must be nonempty' >&2
    exit 1
  fi
  for j in "${!outputs[@]}"; do
    if [ "$j" -lt "$i" ] && [ "${outputs[$j]}" = "${outputs[$i]}" ]; then
      echo "Duplicate output path: ${outputs[$i]}" >&2
      exit 1
    fi
  done
done
