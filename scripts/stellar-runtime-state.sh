#!/bin/sh

set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin${PATH:+:$PATH}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
# shellcheck disable=SC1091
. "$SCRIPT_DIR/stellar-runtime-common.sh"

root=$(stellar_runtime_mail_root "${1-}")
tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-runtime-state.XXXXXX")
trap 'rm -f "$tmp"' EXIT HUP INT TERM

backend=$(stellar_runtime_backend)
"$backend" snapshot "$root" >"$tmp"

jq -cn \
  --arg app "stellar" \
  --arg generatedAt "$(stellar_runtime_now_utc)" \
  --arg mailRoot "$root" \
  --slurpfile snapshot "$tmp" \
  '{
    success: true,
    data: {
      schema: "theurgy-state-snapshot/v1",
      app: $app,
      generatedAt: $generatedAt,
      data: ($snapshot[0] + {schema:"stellar-state/v1", mail_root:$mailRoot})
    }
  }'
