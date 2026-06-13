#!/bin/sh

set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin${PATH:+:$PATH}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
# shellcheck disable=SC1091
. "$SCRIPT_DIR/stellar-runtime-common.sh"

limit=${1:-40}
case "$limit" in
  ''|*[!0-9]*)
    limit=40
    ;;
esac

history_file=$(stellar_runtime_history_file)
if [ ! -f "$history_file" ]; then
  jq -cn '{success:true,data:{schema:"theurgy-operation-history/v1",items:[]}}'
  exit 0
fi

tail -n "$limit" "$history_file" | jq -s '{success:true,data:{schema:"theurgy-operation-history/v1",items:.}}'
