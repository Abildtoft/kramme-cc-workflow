#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
	echo "Usage: validate-branch-name.sh <branch-name>" >&2
	exit 2
fi

branch_name=$1

if [[ ! "$branch_name" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]]; then
	echo "Unsafe branch name: expected only ASCII letters, digits, '.', '_', '/', or '-' and an alphanumeric first character." >&2
	exit 1
fi

if ! git check-ref-format --branch "$branch_name" >/dev/null 2>&1; then
	echo "Invalid Git branch name." >&2
	exit 1
fi

printf '%s\n' "$branch_name"
