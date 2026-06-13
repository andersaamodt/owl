#!/bin/sh

set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin${PATH:+:$PATH}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
# shellcheck disable=SC1091
. "$SCRIPT_DIR/stellar-runtime-common.sh"

action=${1-}
payload_path=${2-}
[ -n "$action" ] || {
  printf '%s\n' "usage: stellar-runtime-action.sh ACTION PAYLOAD_JSON" >&2
  exit 2
}
[ -n "$payload_path" ] || {
  printf '%s\n' "usage: stellar-runtime-action.sh ACTION PAYLOAD_JSON" >&2
  exit 2
}
[ -f "$payload_path" ] || {
  jq -cn --arg error "payload file not found: $payload_path" '{success:false,error:$error}'
  exit 0
}

backend=$(stellar_runtime_backend)
root=$(stellar_runtime_payload_root "$payload_path")
tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-runtime-action.XXXXXX")
tmp_op=$(mktemp "${TMPDIR:-/tmp}/stellar-runtime-operation.XXXXXX")
trap 'rm -f "$tmp" "$tmp_op"' EXIT HUP INT TERM

operations_dir=$(stellar_runtime_operations_dir)
history_file=$(stellar_runtime_history_file)
mkdir -p "$operations_dir"
mkdir -p "$(dirname "$history_file")"

payload_value() {
  jq -r "$1 // \"\"" "$payload_path" 2>/dev/null || printf ''
}

record_operation() {
  op_id=$1
  op_action=$2
  op_status=$3
  jq -cn \
    --arg schema "theurgy-operation-status/v1" \
    --arg id "$op_id" \
    --arg action "$op_action" \
    --arg status "$op_status" \
    --arg generatedAt "$(stellar_runtime_now_utc)" \
    --arg mailRoot "$root" \
    --slurpfile result "$tmp" \
    '{
      schema:$schema,
      id:$id,
      action:$action,
      status:$status,
      generatedAt:$generatedAt,
      mail_root:$mailRoot,
      result:$result[0]
    }' >"$tmp_op"
  cp "$tmp_op" "$operations_dir/$op_id.json"
  cat "$tmp_op" >>"$history_file"
  printf '\n' >>"$history_file"
}

run_backend_json() {
  "$backend" "$@" >"$tmp"
}

run_backend_operation() {
  op_id="op-$(date -u +%Y%m%dT%H%M%SZ)-$$-$(printf '%s' "$action" | tr '_' '-')"
  run_backend_json "$@"
  record_operation "$op_id" "$action" "completed"
  jq -cn \
    --slurpfile result "$tmp" \
    --arg operationId "$op_id" \
    '{
      success:true,
      operation:{id:$operationId,status:"completed"},
      data:$result[0]
    }'
}

case "$action" in
  refresh_state)
    run_backend_json snapshot "$root"
    jq -cn --slurpfile result "$tmp" '{success:true,data:$result[0]}'
    ;;
  get_overview)
    run_backend_json overview "$root"
    jq -cn --slurpfile result "$tmp" '{success:true,data:$result[0]}'
    ;;
  get_settings_controls|open_settings)
    run_backend_json settings-controls "$root"
    jq -cn --slurpfile result "$tmp" '{success:true,data:$result[0]}'
    ;;
  settings_set_test_recipient)
    run_backend_json settings-set-test-recipient "$root" "$(payload_value '.address')"
    jq -cn --slurpfile result "$tmp" '{success:true,data:$result[0]}'
    ;;
  settings_verify_domain)
    run_backend_operation settings-verify-domain "$root" "$(payload_value '.domain')"
    ;;
  settings_set_domain)
    run_backend_json settings-set-domain "$root" "$(payload_value '.domain')"
    jq -cn --slurpfile result "$tmp" '{success:true,data:$result[0]}'
    ;;
  settings_remote_set_target)
    run_backend_operation settings-remote-set-target "$root" "$(payload_value '.host')" "$(payload_value '.ssh_key_path')" "$(payload_value '.ssh_port')"
    ;;
  settings_remote_set_auth)
    run_backend_operation settings-remote-set-auth "$root" "$(payload_value '.ssh_key_has_password')" "$(payload_value '.ssh_key_save_choice')" "$(payload_value '.ssh_key_password')" "$(payload_value '.host')" "$(payload_value '.ssh_key_path')" "$(payload_value '.ssh_port')"
    ;;
  settings_remote_deploy)
    run_backend_operation settings-remote-deploy "$root" "$(payload_value '.host')" "$(payload_value '.ssh_key_path')" "$(payload_value '.ssh_key_password')" "$(payload_value '.ssh_port')"
    ;;
  settings_remote_verify)
    run_backend_operation settings-remote-verify "$root" "$(payload_value '.host')" "$(payload_value '.ssh_key_path')" "$(payload_value '.ssh_key_password')" "$(payload_value '.ssh_port')"
    ;;
  settings_remote_send_test)
    run_backend_operation settings-remote-send-test "$root" "$(payload_value '.host')" "$(payload_value '.ssh_key_path')" "$(payload_value '.ssh_key_password')" "$(payload_value '.ssh_port')"
    ;;
  settings_remote_sync)
    run_backend_operation settings-remote-sync "$root" "$(payload_value '.host')" "$(payload_value '.ssh_key_path')" "$(payload_value '.ssh_key_password')" "$(payload_value '.ssh_port')"
    ;;
  install_simplex_cli)
    run_backend_operation install-simplex-cli "$root"
    ;;
  provision_simplex_identity)
    run_backend_operation provision-simplex-identity "$root" "$(payload_value '.identity')" "$(payload_value '.display_name')" "$(payload_value '.full_name')"
    ;;
  configure_simplex_local_transport)
    run_backend_operation configure-simplex-local-transport "$root" "$(payload_value '.identity')"
    ;;
  configure_secure_chat_transport)
    run_backend_operation configure-secure-chat-transport "$root" "$(payload_value '.identity')" "$(payload_value '.ssh_host')" "$(payload_value '.export_command')" "$(payload_value '.send_command')"
    ;;
  simplex_transport_status)
    run_backend_json simplex-transport-status "$root" "$(payload_value '.identity')"
    jq -cn --slurpfile result "$tmp" '{success:true,data:$result[0]}'
    ;;
  tick_simplex)
    run_backend_operation tick-simplex "$root"
    ;;
  *)
    jq -cn --arg error "unsupported runtime action: $action" '{success:false,error:$error}'
    ;;
esac
