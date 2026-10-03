#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
env_file="$script_dir/../.env"

if [ ! -f "$env_file" ]; then
    printf '%s\n' "Missing $env_file. Copy .env.example to .env and set required secrets." >&2
    exit 1
fi

set -a
. "$env_file"
set +a

cd "$script_dir"
exec ansible-playbook "$@"
