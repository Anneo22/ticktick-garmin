#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

node "$project_root/contracts/test-contract.mjs"

if rg -n '(client_secret|access_token|Bearer [A-Za-z0-9_-]{16,})' "$project_root/watch" "$project_root/contracts" --glob '!*.md'; then
    echo "source: possible embedded secret found" >&2
    exit 1
fi

if [ -d "$project_root/relay" ]; then
    npm --prefix "$project_root/relay" run verify
fi

echo "source: checks passed"
