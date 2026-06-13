#!/bin/sh

set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin${PATH:+:$PATH}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
# shellcheck disable=SC1091
. "$SCRIPT_DIR/stellar-runtime-common.sh"

root=$(stellar_runtime_mail_root "${1-}")
tmp_overview=$(mktemp "${TMPDIR:-/tmp}/stellar-runtime-overview.XXXXXX")
tmp_transport=$(mktemp "${TMPDIR:-/tmp}/stellar-runtime-transport.XXXXXX")
trap 'rm -f "$tmp_overview" "$tmp_transport"' EXIT HUP INT TERM

backend=$(stellar_runtime_backend)
"$backend" overview "$root" >"$tmp_overview"
"$backend" simplex-transport-status "$root" default >"$tmp_transport"

jq -cn \
  --arg app "stellar" \
  --arg generatedAt "$(stellar_runtime_now_utc)" \
  --arg mailRoot "$root" \
  --arg backendPath "$backend" \
  --slurpfile overview "$tmp_overview" \
  --slurpfile transport "$tmp_transport" \
  '{
    success: true,
    data: {
      schema: "theurgy-runtime-status/v1",
      app: $app,
      generatedAt: $generatedAt,
      state_ready: true,
      mail_root: $mailRoot,
      backend: $backendPath,
      inbox_messages: ($overview[0].counts.inbox_messages // 0),
      new_messages: ($overview[0].counts.new_messages // 0),
      archive_messages: ($overview[0].counts.archive_messages // 0),
      drafts: ($overview[0].counts.drafts // 0),
      transport: $transport[0]
    }
  }'
