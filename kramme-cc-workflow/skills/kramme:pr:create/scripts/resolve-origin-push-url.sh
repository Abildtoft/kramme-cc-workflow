#!/usr/bin/env bash

set -euo pipefail

PUSH_URLS_OUTPUT=""
if ! PUSH_URLS_OUTPUT=$(git remote get-url --push --all -- origin 2> /dev/null); then
  echo "Remote 'origin' must have one readable push URL before publishing an existing branch." >&2
  exit 1
fi

PUSH_URLS=()
while IFS= read -r push_url; do
  [ -n "$push_url" ] || continue
  PUSH_URLS[${#PUSH_URLS[@]}]="$push_url"
done <<< "$PUSH_URLS_OUTPUT"

if [ "${#PUSH_URLS[@]}" -ne 1 ]; then
  echo "Remote 'origin' must resolve to exactly one push URL before publishing an existing branch." >&2
  exit 1
fi

printf 'ORIGIN_PUSH_URL=%q\n' "${PUSH_URLS[0]}"
