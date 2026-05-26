#!/bin/sh

set -eu

usage() {
  cat <<'USAGE'
Usage:
  stellar-simplex-local-hook.sh send IDENTITY ROOT OUTBOX_FILE
  stellar-simplex-local-hook.sh poll IDENTITY ROOT INCOMING_DIR

Filesystem SimpleX adapter for Stellar. It records outbound SimpleX
messages under ROOT/.transport/simplex/IDENTITY/local-wire/sent and imports
inbound adapter drops from ROOT/.transport/simplex/IDENTITY/local-wire/incoming.
USAGE
}

case "${1-}" in
--help|-h|help)
  usage
  exit 0
  ;;
esac

action=${1-}
identity=${2-}
root=${3-}
arg4=${4-}

[ -n "$action" ] || { usage >&2; exit 2; }
[ -n "$identity" ] || { printf '%s\n' 'stellar-simplex-local-hook: IDENTITY is required' >&2; exit 2; }
[ -n "$root" ] || { printf '%s\n' 'stellar-simplex-local-hook: ROOT is required' >&2; exit 2; }

require_jq() {
  command -v jq >/dev/null 2>&1 || {
    printf '%s\n' 'stellar-simplex-local-hook: jq is required' >&2
    exit 1
  }
}

safe_slug() {
  raw=${1-}
  cleaned=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._@-' '-')
  cleaned=$(printf '%s' "$cleaned" | sed 's/^-*//; s/-*$//; s/--*/-/g')
  [ -n "$cleaned" ] || cleaned=unknown
  printf '%s\n' "$cleaned"
}

now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

message_id() {
  rand=$(od -An -tx1 -N8 /dev/urandom 2>/dev/null | tr -d ' \n')
  [ -n "$rand" ] || rand=$$
  printf 'local-%s-%s\n' "$(date -u +%Y%m%dT%H%M%SZ)" "$rand"
}

identity=$(safe_slug "$identity")
wire_root=${STELLAR_SIMPLEX_LOCAL_WIRE_ROOT:-"$root/.transport/simplex/$identity/local-wire"}
wire_incoming="$wire_root/incoming"
wire_sent="$wire_root/sent"

send_message() {
  outbox_file=$1
  [ -f "$outbox_file" ] || {
    printf '%s\n' "stellar-simplex-local-hook: outbox file not found: $outbox_file" >&2
    return 1
  }
  mkdir -p "$wire_sent"
  remote_id=$(message_id)
  sent_file="$wire_sent/$remote_id.json"
  jq -c --arg sent_at "$(now_iso)" --arg remote_id "$remote_id" \
    '. + {adapter:"stellar-simplex-local", remote_id:$remote_id, sent_at:$sent_at}' \
    "$outbox_file" >"$sent_file"
  printf '%s\n' 'transport=stellar-simplex-local'
  printf '%s\n' "remote_id=$remote_id"
  printf '%s\n' "message=queued in local SimpleX filesystem adapter"
}

poll_messages() {
  incoming_dir=$1
  mkdir -p "$wire_incoming" "$incoming_dir"
  moved=0
  for file in "$wire_incoming"/*.json; do
    [ -f "$file" ] || continue
    target="$incoming_dir/$(basename "$file")"
    if [ -e "$target" ]; then
      target="$incoming_dir/$(message_id).json"
    fi
    mv "$file" "$target"
    moved=$((moved + 1))
  done
  printf '%s\n' 'transport=stellar-simplex-local'
  printf '%s\n' "imported=$moved"
}

require_jq

case "$action" in
send)
  [ -n "$arg4" ] || {
    printf '%s\n' 'stellar-simplex-local-hook: OUTBOX_FILE is required for send' >&2
    exit 2
  }
  send_message "$arg4"
  ;;
poll)
  [ -n "$arg4" ] || {
    printf '%s\n' 'stellar-simplex-local-hook: INCOMING_DIR is required for poll' >&2
    exit 2
  }
  poll_messages "$arg4"
  ;;
*)
  printf '%s\n' "stellar-simplex-local-hook: unsupported action: $action" >&2
  exit 2
  ;;
esac
