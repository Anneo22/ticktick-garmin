#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if rg -n --hidden \
    --glob '!.git/**' \
    --glob '!relay/node_modules/**' \
    --glob '!build/**' \
    --glob '!dist/**' \
    '(/Users/[A-Za-z0-9._-]+/|/home/[A-Za-z0-9._-]+/|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})' \
    "$project_root"; then
    echo "public leak check: personal path or email found" >&2
    exit 1
fi

echo "public leak check: passed"
