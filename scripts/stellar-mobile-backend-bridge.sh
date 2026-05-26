#!/bin/sh

# CGI-compatible JSON bridge for Stellar mobile native clients.
# It accepts {action, root, args[]} and dispatches the same allowlisted backend actions.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
backend=${STELLAR_NATIVE_BACKEND:-"$repo_dir/scripts/stellar-backend.sh"}

emit_json() {
  code=$1
  body=$2
  if [ -n "${REQUEST_METHOD-}" ]; then
    printf 'Status: %s\r\n' "$code"
    printf 'Content-Type: application/json\r\n'
    printf '\r\n'
  fi
  printf '%s\n' "$body"
}

decode_base64() {
  if decoded=$(base64 --decode 2>/dev/null); then
    printf '%s' "$decoded"
    return 0
  fi
  base64 -d
}

body=$(cat)

if [ -z "$body" ]; then
  emit_json "400 Bad Request" '{"ok":false,"message":"empty request body"}'
  exit 0
fi

if ! printf '%s' "$body" | jq -e . >/dev/null 2>&1; then
  emit_json "400 Bad Request" '{"ok":false,"message":"request body must be JSON"}'
  exit 0
fi

action=$(printf '%s' "$body" | jq -r '.action // ""')
root=$(printf '%s' "$body" | jq -r '.root // ""')
[ -n "$root" ] || root=${STELLAR_MOBILE_BRIDGE_ROOT:-"$HOME/mail"}

case "$action" in
  settings-remote-set-target|settings-remote-set-auth|settings-remote-deploy|settings-remote-verify|settings-remote-send-test|settings-remote-sync|settings-setup-ssl)
    ;;
  *)
    error=$(jq -n --arg action "$action" '{ok:false,message:"unsupported mobile backend action",action:$action}')
    emit_json "400 Bad Request" "$error"
    exit 0
    ;;
esac

args_tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-mobile-bridge-args.XXXXXX")
err_tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-mobile-bridge-err.XXXXXX")
trap 'rm -f "$args_tmp" "$err_tmp"' EXIT HUP INT TERM

if ! printf '%s' "$body" | jq -r '.args // [] | .[] | tostring | @base64' >"$args_tmp"; then
  emit_json "400 Bad Request" '{"ok":false,"message":"args must be an array"}'
  exit 0
fi

set -- "$action" "$root"
while IFS= read -r encoded_arg; do
  decoded_arg=$(printf '%s' "$encoded_arg" | decode_base64)
  set -- "$@" "$decoded_arg"
done <"$args_tmp"

if output=$("$backend" "$@" 2>"$err_tmp"); then
  if printf '%s' "$output" | jq -e . >/dev/null 2>&1; then
    emit_json "200 OK" "$output"
  else
    wrapped=$(jq -n --arg output "$output" '{ok:true,output:$output}')
    emit_json "200 OK" "$wrapped"
  fi
else
  rc=$?
  stderr_text=$(cat "$err_tmp")
  error=$(jq -n --arg action "$action" --arg message "$stderr_text" --argjson exit_code "$rc" '{ok:false,action:$action,exit_code:$exit_code,message:$message}')
  emit_json "500 Internal Server Error" "$error"
fi
