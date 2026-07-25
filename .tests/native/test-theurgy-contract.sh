#!/bin/sh

set -eu

test_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
repo_dir=$(CDPATH= cd -- "$test_dir/../.." && pwd -P)
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/stellar-theurgy-test.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

fake_backend="$tmpdir/fake-stellar-backend.sh"
cat >"$fake_backend" <<'SH'
#!/bin/sh
set -eu
action=${1-}
root=${2-}
shift 2 >/dev/null 2>&1 || true
case "$action" in
  snapshot)
    jq -n --arg root "$root" '{ok:true,mailboxes:[{id:"inbox",count:2}],threads:[{id:"alice"}],messages:[{id:"msg-1"}],drafts:[{id:"draft-1"}],events:[{id:"evt-1"}],settings:{domain:"example.org"},root:$root}'
    ;;
  overview)
    jq -n --arg root "$root" '{ok:true,counts:{inbox_messages:2,new_messages:1,archive_messages:3,drafts:1},root:$root}'
    ;;
  settings-controls)
    jq -n '{ok:true,domain:"example.org",test_recipient:"test@example.org"}'
    ;;
  simplex-transport-status)
    jq -n '{ok:true,identity:"default",installed:true}'
    ;;
  settings-set-domain)
    jq -n --arg domain "${1-}" '{ok:true,domain:$domain}'
    ;;
  settings-remote-sync)
    jq -n --arg host "${1-}" '{ok:true,action:"remote-sync",host:$host}'
    ;;
  *)
    jq -n --arg action "$action" --arg a1 "${1-}" --arg a2 "${2-}" --arg a3 "${3-}" --arg a4 "${4-}" '{ok:true,action:$action,args:[$a1,$a2,$a3,$a4]}'
    ;;
esac
SH
chmod +x "$fake_backend"

product_ir="$repo_dir/app-blueprint/product.ir.json"
desktop_surface_ir="$repo_dir/app-blueprint/desktop.surface.ir.json"
runtime_manifest="$repo_dir/app-blueprint/runtime.manifest.json"

jq -e '
  .version == "theurgy-product-ir/v1" and
  .app.id == "stellar" and
  .state.snapshotSchema == "stellar-state/v1" and
  (.state.command == ["scripts/stellar-runtime-state.sh"]) and
  (.state.statusCommand == ["scripts/stellar-runtime-status.sh"]) and
  (.actions | map(.id) | index("settings_remote_sync")) and
  (.actions | map(.id) | index("address_publish")) and
  ([.actions[] | select(.longRunning == true)] | length) > 0 and
  (.persistence.history == "append-only-operation-logs")
' "$product_ir" >/dev/null

jq -e '
  .version == "theurgy-desktop-surface-ir/v1" and
  (.actions | index("settings_remote_sync")) and
  (.actions | index("address_save")) and
  (.capabilities | index("single-user-address-routing")) and
  (.capabilities | index("transport-operation-history"))
' "$desktop_surface_ir" >/dev/null

jq -e '
  .version == "theurgy-runtime-manifest/v1" and
  .runtime.stateCommand == ["scripts/stellar-runtime-state.sh"] and
  .runtime.actionCommand == ["scripts/stellar-runtime-action.sh"] and
  .runtime.operationStatusCommand == ["scripts/stellar-runtime-operation-status.sh"] and
  .runtime.historyCommand == ["scripts/stellar-runtime-history.sh"]
' "$runtime_manifest" >/dev/null

state_json=$(HOME="$tmpdir/home" XDG_STATE_HOME="$tmpdir/state" STELLAR_RUNTIME_BACKEND="$fake_backend" sh "$repo_dir/scripts/stellar-runtime-state.sh" "/tmp/stellar mail")
printf '%s\n' "$state_json" | jq -e '
  .success == true and
  .data.schema == "theurgy-state-snapshot/v1" and
  .data.data.schema == "stellar-state/v1" and
  .data.data.mail_root == "/tmp/stellar mail"
' >/dev/null

status_json=$(HOME="$tmpdir/home" XDG_STATE_HOME="$tmpdir/state" STELLAR_RUNTIME_BACKEND="$fake_backend" sh "$repo_dir/scripts/stellar-runtime-status.sh" "/tmp/stellar mail")
printf '%s\n' "$status_json" | jq -e '
  .success == true and
  .data.schema == "theurgy-runtime-status/v1" and
  .data.inbox_messages == 2 and
  .data.transport.installed == true
' >/dev/null

payload="$tmpdir/payload.json"
printf '%s\n' '{"mail_root":"/tmp/stellar mail","host":"mail.example.org"}' >"$payload"
action_json=$(HOME="$tmpdir/home" XDG_STATE_HOME="$tmpdir/state" STELLAR_RUNTIME_BACKEND="$fake_backend" sh "$repo_dir/scripts/stellar-runtime-action.sh" settings_remote_sync "$payload")
printf '%s\n' "$action_json" | jq -e '
  .success == true and
  .operation.status == "completed" and
  .data.action == "remote-sync" and
  .data.host == "mail.example.org"
' >/dev/null

printf '%s\n' '{"mail_root":"/tmp/stellar mail","local_part":"receipts","label":"Receipts","forwards":"archive@example.net","enabled":true}' >"$payload"
address_json=$(HOME="$tmpdir/home" XDG_STATE_HOME="$tmpdir/state" STELLAR_RUNTIME_BACKEND="$fake_backend" sh "$repo_dir/scripts/stellar-runtime-action.sh" address_save "$payload")
printf '%s\n' "$address_json" | jq -e '
  .success == true and
  .data.action == "address-save" and
  .data.args == ["receipts","Receipts","archive@example.net","on"]
' >/dev/null

op_id=$(printf '%s\n' "$action_json" | jq -r '.operation.id')
op_json=$(HOME="$tmpdir/home" XDG_STATE_HOME="$tmpdir/state" sh "$repo_dir/scripts/stellar-runtime-operation-status.sh" "$op_id")
printf '%s\n' "$op_json" | jq -e '
  .success == true and
  .data.schema == "theurgy-operation-status/v1" and
  .data.id == "'"$op_id"'" and
  .data.status == "completed"
' >/dev/null

history_json=$(HOME="$tmpdir/home" XDG_STATE_HOME="$tmpdir/state" sh "$repo_dir/scripts/stellar-runtime-history.sh" 10)
printf '%s\n' "$history_json" | jq -e '
  .success == true and
  .data.schema == "theurgy-operation-history/v1" and
  (.data.items | length) >= 1
' >/dev/null

printf '%s\n' "stellar theurgy contract tests passed"
