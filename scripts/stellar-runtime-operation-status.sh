#!/bin/sh

set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin${PATH:+:$PATH}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
# shellcheck disable=SC1091
. "$SCRIPT_DIR/stellar-runtime-common.sh"

operation_id=${1-}
[ -n "$operation_id" ] || {
  printf '%s\n' "usage: stellar-runtime-operation-status.sh OPERATION_ID" >&2
  exit 2
}

operation_path="$(stellar_runtime_operations_dir)/$operation_id.json"
[ -f "$operation_path" ] || {
  jq -cn --arg error "unknown operation id: $operation_id" '{success:false,error:$error}'
  exit 0
}

jq -cn --slurpfile op "$operation_path" '{success:true,data:$op[0]}'
