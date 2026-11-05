#!/usr/bin/env bash
# Check that GitHub can anchor an inline review comment at each head-side
# path:line. A line can take a comment when it is an added or context line of a
# -U3 hunk in the Pull Request diff, which runs from the merge base of the base
# and head commits to the head, like `git diff <base>...<head>`.
#
# Usage: check-comment-anchors.sh <repo> <base-oid> <head-oid> <path:line>...
#
# <base-oid> may be the PR's base commit or the merge base itself. Prints one
# line per anchor: "<status> <path:line> <head line text>". The status is ok,
# NOT-IN-DIFF (the line exists at the head but is not a diff line), or NO-LINE
# (the path or line does not exist at the head). Exits 0 when every anchor is
# ok, 1 when any is not, and 2 on usage or Git errors.

set -euo pipefail

# Git lets this variable override -U on the command line.
unset GIT_DIFF_OPTS

usage() {
  echo "Usage: check-comment-anchors.sh <repo> <base-oid> <head-oid> <path:line>..." >&2
  exit 2
}

[ "$#" -ge 4 ] || usage
repo=$1
base_oid=$2
head_oid=$3
shift 3

# Full object IDs only: a branch name or HEAD can resolve to a local checkout
# that lags the Pull Request head.
for oid in "$base_oid" "$head_oid"; do
  if [[ ! "$oid" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]]; then
    echo "Expected a full commit object ID, got '$oid'." >&2
    exit 2
  fi
  if ! git -C "$repo" rev-parse --verify --quiet "$oid^{commit}" > /dev/null; then
    echo "Commit $oid is not available in $repo." >&2
    exit 2
  fi
done

# One "path<TAB>first line<TAB>line count" row per hunk, head side only. The
# explicit options override local diff settings that would move hunks. A "+++ "
# line is a file header only between "diff --git" and the file's first hunk;
# inside a hunk it is an added line that starts with "++ ". Keep Git-quoted
# headers escaped in these rows so tabs and newlines in paths cannot split them.
if ! hunks=$(git -C "$repo" -c core.quotePath=false diff --no-color --no-ext-diff --no-textconv \
  --diff-algorithm=myers --indent-heuristic --src-prefix=a/ --dst-prefix=b/ \
  -M -U3 --inter-hunk-context=0 "$base_oid...$head_oid" \
  | awk '
    /^diff --git / { in_header = 1; path = ""; next }
    in_header && /^\+\+\+ / {
      path = (substr($0, 5) == "/dev/null") ? "" : substr($0, 5)
      sub(/\t$/, "", path)
      next
    }
    /^@@ / {
      in_header = 0
      if (path == "" || !match($0, /\+[0-9]+(,[0-9]+)?/)) next
      split(substr($0, RSTART + 1, RLENGTH - 1), range, ",")
      print path "\t" range[1] "\t" ((2 in range) ? range[2] : 1)
    }
  '); then
  echo "Could not diff $base_oid...$head_oid in $repo." >&2
  exit 2
fi

status=0
for anchor in "$@"; do
  path=${anchor%:*}
  line=${anchor##*:}
  if [ "$path" = "$anchor" ] || [ -z "$path" ] || [[ ! "$line" =~ ^[1-9][0-9]*$ ]]; then
    echo "Expected <path:line> with a positive line number, got '$anchor'." >&2
    exit 2
  fi

  if ! text=$(git -C "$repo" cat-file blob "$head_oid:$path" 2> /dev/null \
    | awk -v n="$line" 'NR == n { print; found = 1 } END { exit !found }'); then
    printf 'NO-LINE %s\n' "$anchor"
    status=1
    continue
  fi

  if printf '%s\n' "$hunks" | ANCHOR_PATH=$path awk -F '\t' -v n="$line" '
    # core.quotePath=false still quotes special characters. Decode the C-style
    # escapes only when comparing, then remove the decoded b/ prefix.
    function head_path(value, result, i, c, code, j, escape) {
      if (substr(value, 1, 1) == "\"") {
        value = substr(value, 2, length(value) - 2)
        result = ""
        for (i = 1; i <= length(value); i++) {
          c = substr(value, i, 1)
          if (c == "\\") {
            c = substr(value, ++i, 1)
            if (c ~ /^[0-7]$/) {
              code = 0
              for (j = 0; j < 3; j++) code = code * 8 + substr(value, i + j, 1)
              c = sprintf("%c", code)
              i += 2
            } else if ((escape = index("abtnvfr", c)) > 0) {
              c = sprintf("%c", escape + 6)
            }
          }
          result = result c
        }
        value = result
      }
      return substr(value, 3)
    }
    head_path($1) == ENVIRON["ANCHOR_PATH"] && n >= $2 && n < $2 + $3 { found = 1 }
    END { exit !found }
  '; then
    printf 'ok %s %s\n' "$anchor" "$text"
  else
    printf 'NOT-IN-DIFF %s %s\n' "$anchor" "$text"
    status=1
  fi
done

exit "$status"
