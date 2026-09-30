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

case "${PUSH_URLS[0]}" in
  *://*)
    URL_AFTER_SCHEME=${PUSH_URLS[0]#*://}
    URL_AUTHORITY=${URL_AFTER_SCHEME%%/*}
    URL_SCHEME=${PUSH_URLS[0]%%://*}
    URL_USERINFO=""
    case "$URL_AUTHORITY" in
      *@*) URL_USERINFO=${URL_AUTHORITY%@*} ;;
    esac

    case "$URL_SCHEME" in
      [Hh][Tt][Tt][Pp] | [Hh][Tt][Tt][Pp][Ss] | [Ss][Ss][Hh] | [Gg][Ii][Tt] | [Ff][Ii][Ll][Ee]) ;;
      [Ff][Tt][Pp] | [Ff][Tt][Pp][Ss] | [Gg][Ii][Tt]+[Ss][Ss][Hh] | [Ss][Ss][Hh]+[Gg][Ii][Tt]) ;;
      *)
        echo "Remote 'origin' push URL uses an unsupported transport; use a standard HTTPS, SSH, Git, FTP, or file URL instead." >&2
        exit 1
        ;;
    esac

    case "$URL_SCHEME" in
      [Hh][Tt][Tt][Pp] | [Hh][Tt][Tt][Pp][Ss])
        if [ -n "$URL_USERINFO" ]; then
          echo "Remote 'origin' push URL must not contain inline HTTP credentials; use a credential manager or SSH instead." >&2
          exit 1
        fi
        ;;
    esac
    if [[ "$URL_USERINFO" == *:* ]] || [[ "$URL_AFTER_SCHEME" == *\?* ]] || [[ "$URL_AFTER_SCHEME" == *\#* ]]; then
      echo "Remote 'origin' push URL contains credential-bearing data that cannot be retained safely; use a credential manager or SSH instead." >&2
      exit 1
    fi
    ;;
  *::*)
    echo "Remote 'origin' push URL must not use executable Git remote-helper syntax; use a standard HTTPS, SSH, Git, FTP, file, or local-path endpoint instead." >&2
    exit 1
    ;;
esac

printf 'ORIGIN_PUSH_URL=%q\n' "${PUSH_URLS[0]}"
