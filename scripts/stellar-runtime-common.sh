#!/bin/sh
# Shared helpers for Stellar Theurgy runtime bridge scripts.

set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin${PATH:+:$PATH}

stellar_runtime_repo_root() {
  script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
  CDPATH= cd -- "$script_dir/.." && pwd -P
}

stellar_runtime_backend() {
  if [ -n "${STELLAR_RUNTIME_BACKEND:-}" ]; then
    printf '%s\n' "$STELLAR_RUNTIME_BACKEND"
    return 0
  fi
  if [ -n "${STELLAR_NATIVE_BACKEND:-}" ]; then
    printf '%s\n' "$STELLAR_NATIVE_BACKEND"
    return 0
  fi
  printf '%s/scripts/stellar-backend.sh\n' "$(stellar_runtime_repo_root)"
}

stellar_runtime_mail_root() {
  value=${1-}
  case "$value" in
    "")
      printf '%s\n' "${HOME:?}/mail"
      ;;
    "~")
      printf '%s\n' "${HOME:?}"
      ;;
    "~/"*)
      printf '%s\n' "${HOME:?}/${value#~/}"
      ;;
    *)
      printf '%s\n' "$value"
      ;;
  esac
}

stellar_runtime_state_root() {
  if [ -n "${STELLAR_THEURGY_STATE_DIR:-}" ]; then
    printf '%s\n' "$STELLAR_THEURGY_STATE_DIR"
    return 0
  fi
  printf '%s/stellar/theurgy-runtime\n' "${XDG_STATE_HOME:-$HOME/.local/state}"
}

stellar_runtime_operations_dir() {
  printf '%s/operations\n' "$(stellar_runtime_state_root)"
}

stellar_runtime_history_file() {
  printf '%s/history.jsonl\n' "$(stellar_runtime_state_root)"
}

stellar_runtime_now_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

stellar_runtime_json_string() {
  printf '%s' "${1-}" | jq -R .
}

stellar_runtime_payload_root() {
  payload_path=${1-}
  if [ -n "$payload_path" ] && [ -f "$payload_path" ]; then
    payload_root=$(jq -r '.mail_root // .root // ""' "$payload_path" 2>/dev/null || printf '')
    stellar_runtime_mail_root "$payload_root"
    return 0
  fi
  stellar_runtime_mail_root ""
}

stellar_runtime_backend_json() {
  backend_path=$(stellar_runtime_backend)
  root=$1
  shift
  "$backend_path" "$@" "$root"
}

stellar_runtime_wrap_success() {
  payload_file=$1
  jq -cn \
    --arg generatedAt "$(stellar_runtime_now_utc)" \
    --argfile data "$payload_file" \
    '{success:true,data:{generatedAt:$generatedAt,result:$data}}'
}

stellar_runtime_wrap_error() {
  message=${1:-Runtime action failed.}
  jq -cn --arg error "$message" '{success:false,error:$error}'
}
