#!/bin/sh

set -eu

test_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
repo_dir=$(CDPATH= cd -- "$test_dir/../.." && pwd -P)
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/owl-backend-test.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

failures=0

run_case() {
  name=$1
  shift
  if "$@"; then
    printf 'ok - %s\n' "$name"
  else
    printf 'not ok - %s\n' "$name" >&2
    failures=$((failures + 1))
  fi
}

backend() {
  HOME="$tmpdir/home" \
  XDG_STATE_HOME="$tmpdir/state" \
  XDG_CONFIG_HOME="$tmpdir/config" \
  sh "$repo_dir/scripts/owl-backend.sh" "$@"
}

backend_with_owl() {
  owl_backend=$1
  shift
  HOME="$tmpdir/home" \
  XDG_STATE_HOME="$tmpdir/state" \
  XDG_CONFIG_HOME="$tmpdir/config" \
  OWL_DESKTOP_BACKEND="$owl_backend" \
  sh "$repo_dir/scripts/owl-backend.sh" "$@"
}

b64() {
  printf '%s' "$1" | base64 | tr -d '\n'
}

write_fake_simplex_binary() {
  binary=$1
  cat >"$binary" <<'SH'
#!/bin/sh
[ "${1-}" = "-h" ] && exit 0
exit 0
SH
  chmod +x "$binary"
}

write_fake_owl_backend() {
  script=$1
  cat >"$script" <<'SH'
#!/bin/sh
set -eu
action=${1-}
root=${2-}
shift 2 >/dev/null 2>&1 || true
case "$action" in
  overview)
    jq -n --arg root "$root" '{ok:true,root:$root,counts:{inbox_messages:1,new_messages:1,archive_messages:1,trash_messages:1,drafts:1,outbox:1,sent:1}}'
    ;;
  settings-controls)
    jq -n '{ok:true,domain:"example.org",test_recipient:"test@example.org",daemon:{installed:false,running:false},llm:{enabled:false}}'
    ;;
  event-feed)
    jq -n '{ok:true,events:[{id:"evt-1",kind:"test",message:"fake event"}]}'
    ;;
  draft-list)
    jq -n '{ok:true,drafts:[{ulid:"draft-1",to:"alice@example.org",subject:"Draft note"}]}'
    ;;
  list-messages|list-messages-fast)
    list=${1-}
    case "$list" in
      accepted)
        jq -n --arg list "$list" '{ok:true,list:$list,messages:[{list:$list,sender:"Alice <alice@example.org>",ulid:"msg-1",subject:"Hello",preview:"Email preview",received_at:"2026-04-20T10:00:00Z",read:false,starred:true,attachments:1}]}'
        ;;
      archive)
        jq -n --arg list "$list" '{ok:true,list:$list,messages:[{list:$list,sender:"Bob <bob@example.org>",ulid:"msg-2",subject:"Archived",preview:"Archived preview",received_at:"2026-04-19T10:00:00Z",read:true}]}'
        ;;
      *)
        jq -n --arg list "$list" '{ok:true,list:$list,messages:[]}'
        ;;
    esac
    ;;
  get-message)
    list=${1-}
    sender=${2-}
    ulid=${3-}
    jq -n --arg list "$list" --arg sender "$sender" --arg ulid "$ulid" '{ok:true,list:$list,sender:$sender,ulid:$ulid,body:"Full fake body"}'
    ;;
  settings-set-domain)
    jq -n --arg domain "${1-}" '{ok:true,domain:$domain}'
    ;;
  *)
    jq -n --arg action "$action" --argjson argc "$#" '{ok:true,action:$action,argc:$argc}'
    ;;
esac
SH
  chmod +x "$script"
}

doctor_is_read_only() {
  root="$tmpdir/doctor/mail"
  mkdir -p "$tmpdir/home"
  output=$(backend doctor "$root")
  printf '%s\n' "$output" | jq -e '.ok == true and .root == "'"$root"'"' >/dev/null
  [ ! -e "$root" ]
}

prepare_creates_shared_roots() {
  root="$tmpdir/prepare/mail"
  mkdir -p "$tmpdir/home"
  backend prepare "$root" >/dev/null
  [ -d "$root/accepted" ] &&
    [ -d "$root/archive" ] &&
    [ -d "$root/.owl/simplex/threads" ] &&
    [ -d "$root/.owl/simplex/incoming" ] &&
    [ -d "$root/.owl/simplex/outbox" ]
}

simplex_messages_share_one_timeline_and_inbox() {
  root="$tmpdir/timeline/mail"
  mkdir -p "$tmpdir/home"
  backend prepare "$root" >/dev/null
  backend bind-contact "$root" alice "Alice Ledger" person alice@example.org simplex://alice yes >/dev/null
  backend import-simplex "$root" alice "$(b64 'Encrypted hello')" false true "SimpleX hello" >/dev/null
  snapshot=$(backend snapshot "$root")
  printf '%s\n' "$snapshot" | jq -e '
    .ok == true and
    (.inbox | length) == 1 and
    .inbox[0].transport == "simplex" and
    .inbox[0].lock == "closed" and
    .inbox[0].in_inbox == true and
    (.individuals | length) == 1 and
    .individuals[0].id == "alice" and
    .individuals[0].favorite == true and
    (.individuals[0].messages | length) == 1
  ' >/dev/null
}

simplex_send_queues_without_email_fallback() {
  root="$tmpdir/send/mail"
  mkdir -p "$tmpdir/home"
  backend prepare "$root" >/dev/null
  backend bind-contact "$root" bob "Bob Mail" person bob@example.org "" no >/dev/null
  if backend send-message "$root" bob simplex "No path" "$(b64 'do not fall back')" >"$tmpdir/send-no-simplex.out" 2>"$tmpdir/send-no-simplex.err"; then
    return 1
  fi
  grep -q 'no SimpleX path' "$tmpdir/send-no-simplex.err"
  ! find "$root/drafts" -type f -name '*.md' 2>/dev/null | grep -q .

  backend bind-contact "$root" bob "Bob Mail" person bob@example.org simplex://bob no >/dev/null
  send=$(backend send-message "$root" bob simplex "Secure path" "$(b64 'simplex first')")
  printf '%s\n' "$send" | jq -e '.ok == true and .transport == "simplex" and (.outbox_path | length > 0)' >/dev/null
  [ -f "$(printf '%s\n' "$send" | jq -r '.outbox_path')" ]
  snapshot=$(backend snapshot "$root")
  printf '%s\n' "$snapshot" | jq -e '
    [.threads[] | select(.id == "bob")][0].messages
    | map(select(.transport == "simplex" and .from_self == true and .in_inbox == false))
    | length == 1
  ' >/dev/null
}

simplex_inbox_state_is_metadata_not_thread_movement() {
  root="$tmpdir/inbox-state/mail"
  mkdir -p "$tmpdir/home"
  backend prepare "$root" >/dev/null
  backend bind-contact "$root" river "River Stone" group "" simplex://river yes >/dev/null
  backend import-simplex "$root" river "$(b64 'group update')" false true "" >/dev/null
  id=$(backend snapshot "$root" | jq -r '.inbox[0].id')
  backend mark-inbox "$root" "$id" out >/dev/null
  snapshot=$(backend snapshot "$root")
  printf '%s\n' "$snapshot" | jq -e '
    (.inbox | length) == 0 and
    ([.groups[] | select(.id == "river")][0].messages | length) == 1 and
    ([.groups[] | select(.id == "river")][0].messages[0].in_inbox == false)
  ' >/dev/null
}

simplex_trash_stages_file_for_system_trash() {
  root="$tmpdir/simplex-trash/mail"
  mkdir -p "$tmpdir/home"
  backend prepare "$root" >/dev/null
  backend bind-contact "$root" river "River Stone" person "" simplex://river no >/dev/null
  backend import-simplex "$root" river "$(b64 'trash me')" false true "SimpleX trash" >/dev/null
  id=$(backend snapshot "$root" | jq -r '.inbox[] | select(.transport == "simplex") | .id' | head -n 1)
  trash=$(backend message-trash-files "$root" "$id")
  path=$(printf '%s\n' "$trash" | jq -r '.paths[0] // ""')
  printf '%s\n' "$trash" | jq -e '.ok == true and .delete_after_trash == true and (.paths | length) == 1' >/dev/null
  [ -f "$path" ] || return 1
  jq -e --arg id "$id" '.id == $id and .body == "trash me"' "$path" >/dev/null
}

bootstrap_status_is_structured() {
  root="$tmpdir/bootstrap/mail"
  mkdir -p "$tmpdir/home"
  backend prepare "$root" >/dev/null
  output=$(backend bootstrap-status "$root" default)
  printf '%s\n' "$output" | jq -e '.ok == true and (.install_state | type) == "string" and (.profile_prefix | contains("/.transport/simplex/default/profile"))' >/dev/null
}

bootstrap_status_detects_wizardry_simplex_install() {
  root="$tmpdir/bootstrap-wizardry/mail"
  global="$tmpdir/state/wizardry/simplex"
  mkdir -p "$tmpdir/home" "$global/current"
  write_fake_simplex_binary "$global/current/simplex-chat"
  cat >"$global/install.conf" <<EOF
version=vtest
asset_name=test-asset
binary_path=$global/current/simplex-chat
validation_state=ready
last_error=
EOF
  output=$(backend bootstrap-status "$root" default)
  printf '%s\n' "$output" | jq -e \
    --arg binary "$global/current/simplex-chat" \
    '.ok == true and .install_state == "installed" and .install_source == "wizardry" and .version == "vtest" and .binary_path == $binary' >/dev/null
}

snapshot_includes_owl_mailboxes_drafts_events_settings() {
  root="$tmpdir/snapshot-mail/mail"
  fake="$tmpdir/fake-owl-backend.sh"
  mkdir -p "$tmpdir/home"
  write_fake_owl_backend "$fake"
  backend_with_owl "$fake" prepare "$root" >/dev/null
  snapshot=$(backend_with_owl "$fake" snapshot "$root")
  printf '%s\n' "$snapshot" | jq -e '
    .ok == true and
    ([.mailboxes[] | select(.id == "accepted")][0].count == 1) and
    ([.mailboxes[] | select(.id == "archive")][0].count == 1) and
    (.drafts | length) == 1 and
    (.events | length) == 1 and
    .settings.domain == "example.org" and
    (.messages | map(select(.transport == "email")) | length) == 2
  ' >/dev/null
}

snapshot_reads_mail_sidecars_locally() {
  root="$tmpdir/snapshot-sidecars/mail"
  mkdir -p "$tmpdir/home" "$root/accepted/alice@example.org" "$root/archive/bob@example.org"
  cat >"$root/accepted/alice@example.org/.Hello (01A).yml" <<'YAML'
schema: 1
ulid: 01A
status_shadow: accepted
read: false
starred: true
received_at: 2026-05-25T07:00:00Z
headers_cache:
  from: Alice <alice@example.org>
  subject: Hello
YAML
  cat >"$root/archive/bob@example.org/.Archived (01B).yml" <<'YAML'
schema: 1
ulid: 01B
status_shadow: archive
read: true
received_at: 2026-05-24T07:00:00Z
headers_cache:
  from: Bob <bob@example.org>
  subject: Archived
YAML
  snapshot=$(backend snapshot "$root")
  printf '%s\n' "$snapshot" | jq -e '
    ([.mailboxes[] | select(.id == "accepted")][0].count == 1) and
    ([.mailboxes[] | select(.id == "archive")][0].count == 1) and
    (.messages | map(select(.transport == "email")) | length) == 2 and
    (.inbox | length) == 1
  ' >/dev/null
}

snapshot_lines_exposes_native_gtk_feed() {
  root="$tmpdir/snapshot-lines/mail"
  fake="$tmpdir/fake-owl-lines.sh"
  mkdir -p "$tmpdir/home"
  write_fake_owl_backend "$fake"
  backend_with_owl "$fake" prepare "$root" >/dev/null
  lines=$(backend_with_owl "$fake" snapshot-lines "$root")
  printf '%s\n' "$lines" | grep -q '^mailbox	accepted	Accepted	1	1$' &&
    printf '%s\n' "$lines" | grep -q '^inbox	.*	Alice	email	Hello	Email preview	2026-04-20T10:00:00Z$' &&
    printf '%s\n' "$lines" | grep -q '^draft	draft-1	alice@example.org	Draft note'
}

owl_actions_are_hard_allowlisted_and_passthrough() {
  root="$tmpdir/passthrough/mail"
  fake="$tmpdir/fake-owl-passthrough.sh"
  mkdir -p "$tmpdir/home"
  write_fake_owl_backend "$fake"
  output=$(backend_with_owl "$fake" settings-set-domain "$root" example.org)
  printf '%s\n' "$output" | jq -e '.ok == true and .domain == "example.org"' >/dev/null
  output=$(backend_with_owl "$fake" settings-remote-set-auth "$root" 1 0 "secret" user@example.org "$tmpdir/id_ed25519" 2222)
  printf '%s\n' "$output" | jq -e '.ok == true and .action == "settings-remote-set-auth" and .argc == 6' >/dev/null
  output=$(backend_with_owl "$fake" settings-remote-deploy "$root" user@example.org "$tmpdir/id_ed25519" "secret" 2222)
  printf '%s\n' "$output" | jq -e '.ok == true and .action == "settings-remote-deploy" and .argc == 4' >/dev/null
  output=$(backend_with_owl "$fake" settings-remote-send-test "$root" user@example.org "$tmpdir/id_ed25519" "secret" 2222)
  printf '%s\n' "$output" | jq -e '.ok == true and .action == "settings-remote-send-test" and .argc == 4' >/dev/null
  if backend_with_owl "$fake" arbitrary-shell "$root" >"$tmpdir/arbitrary.out" 2>"$tmpdir/arbitrary.err"; then
    return 1
  fi
  grep -q 'unsupported action' "$tmpdir/arbitrary.err"
}

ui_prefs_are_plaintext_xdg_state() {
  root="$tmpdir/prefs/mail"
  next_root="$tmpdir/prefs/other-mail"
  mkdir -p "$tmpdir/home"
  output=$(backend get-ui-prefs "$root")
  printf '%s\n' "$output" | jq -e --arg root "$root" '.ok == true and .mail_root == $root and .selected_route == "new"' >/dev/null
  backend set-ui-pref "$root" mail_root "$next_root" >/dev/null
  backend set-ui-pref "$root" selected_route "thread:alice" >/dev/null
  output=$(backend get-ui-prefs "$root")
  printf '%s\n' "$output" | jq -e --arg root "$next_root" '.mail_root == $root and .selected_route == "thread:alice"' >/dev/null
  grep -q "mail_root=$next_root" "$tmpdir/config/wizardry-apps/owl/prefs.conf"
}

message_detail_returns_simplex_and_email_messages() {
  root="$tmpdir/detail/mail"
  fake="$tmpdir/fake-owl-detail.sh"
  mkdir -p "$tmpdir/home"
  write_fake_owl_backend "$fake"
  backend_with_owl "$fake" prepare "$root" >/dev/null
  backend_with_owl "$fake" bind-contact "$root" alice "Alice Ledger" person alice@example.org simplex://alice yes >/dev/null
  backend_with_owl "$fake" import-simplex "$root" alice "$(b64 'Encrypted detail')" false true "SimpleX detail" >/dev/null
  simplex_id=$(backend_with_owl "$fake" snapshot "$root" | jq -r '.inbox[] | select(.transport == "simplex") | .id' | head -n 1)
  email_id=$(backend_with_owl "$fake" snapshot "$root" | jq -r '.inbox[] | select(.transport == "email") | .id' | head -n 1)
  backend_with_owl "$fake" message-detail "$root" "$simplex_id" | jq -e '.ok == true and .transport == "simplex" and .body == "Encrypted detail"' >/dev/null
  backend_with_owl "$fake" get-message "$root" "$email_id" | jq -e '.ok == true and .transport == "email" and .body == "Full fake body"' >/dev/null
}

simplex_tick_uses_transport_hook_for_poll_and_send() {
  root="$tmpdir/simplex-hook/mail"
  hook="$tmpdir/simplex-hook.sh"
  mkdir -p "$tmpdir/home"
  cat >"$hook" <<'SH'
#!/bin/sh
set -eu
mode=${1-}
identity=${2-}
root=${3-}
case "$mode" in
  poll)
    incoming=${4-}
    mkdir -p "$incoming"
    jq -n '{thread_id:"carol",body:"hook incoming",subject:"Hook",from_self:false,in_inbox:true}' >"$incoming/hook-message.json"
    ;;
  send)
    outbox_file=${4-}
    mkdir -p "$root/.hook-sent"
    cp "$outbox_file" "$root/.hook-sent/$identity.json"
    ;;
  *)
    exit 64
    ;;
esac
SH
  chmod +x "$hook"
  backend prepare "$root" >/dev/null
  backend bind-contact "$root" carol "Carol Cipher" person carol@example.org simplex://carol yes >/dev/null
  backend send-message "$root" carol simplex "Outbound" "$(b64 'hook outbound')" >/dev/null
  backend set-simplex-transport-hook "$root" default "$hook" | jq -e '.hook_ready == true' >/dev/null
  tick=$(backend tick-simplex "$root" default)
  printf '%s\n' "$tick" | jq -e '.ok == true and .imported == 1 and .outbox.sent == 1 and .outbox.failed == 0' >/dev/null
  [ -f "$root/.hook-sent/default.json" ] || return 1
  snapshot=$(backend snapshot "$root")
  printf '%s\n' "$snapshot" | jq -e '
    ([.threads[] | select(.id == "carol")][0].messages | map(select(.status == "sent")) | length) == 1 and
    ([.threads[] | select(.id == "carol")][0].messages | map(select(.body == "hook incoming" and .in_inbox == true)) | length) == 1
  ' >/dev/null
}

simplex_tick_sends_before_polling() {
  root="$tmpdir/simplex-hook-order/mail"
  hook="$tmpdir/simplex-hook-order.sh"
  mkdir -p "$tmpdir/home"
  cat >"$hook" <<'SH'
#!/bin/sh
set -eu
mode=${1-}
root=${3-}
case "$mode" in
  poll)
    [ -f "$root/.hook-order/sent-before-poll" ] || {
      printf '%s\n' 'poll ran before send' >&2
      exit 23
    }
    ;;
  send)
    mkdir -p "$root/.hook-order"
    printf '%s\n' sent >"$root/.hook-order/sent-before-poll"
    ;;
  *)
    exit 64
    ;;
esac
SH
  chmod +x "$hook"
  backend prepare "$root" >/dev/null
  backend bind-contact "$root" carol "Carol Cipher" person carol@example.org simplex://carol yes >/dev/null
  backend send-message "$root" carol simplex "Outbound" "$(b64 'hook outbound')" >/dev/null
  backend set-simplex-transport-hook "$root" default "$hook" | jq -e '.hook_ready == true' >/dev/null
  tick=$(backend tick-simplex "$root" default)
  printf '%s\n' "$tick" | jq -e '.ok == true and .outbox.sent == 1 and .outbox.failed == 0 and .poll_error == ""' >/dev/null
}

simplex_tick_dedupes_by_remote_id_not_body() {
  root="$tmpdir/simplex-remote-id-dedupe/mail"
  hook="$tmpdir/simplex-remote-id-dedupe.sh"
  mkdir -p "$tmpdir/home"
  cat >"$hook" <<'SH'
#!/bin/sh
set -eu
mode=${1-}
root=${3-}
case "$mode" in
  poll)
    incoming=${4-}
    mkdir -p "$incoming"
    jq -n '{thread_id:"carol",body:"repeatable text",subject:"Hook",from_self:false,in_inbox:true,remote_id:"simplex-owner-direct:1",received_at:"2026-05-05T08:00:00Z"}' >"$incoming/one.json"
    jq -n '{thread_id:"carol",body:"repeatable text",subject:"Hook",from_self:false,in_inbox:true,remote_id:"simplex-owner-direct:2",received_at:"2026-05-05T08:01:00Z"}' >"$incoming/two.json"
    ;;
  send)
    ;;
  *)
    exit 64
    ;;
esac
SH
  chmod +x "$hook"
  backend prepare "$root" >/dev/null
  backend bind-contact "$root" carol "Carol Cipher" person carol@example.org simplex://carol yes >/dev/null
  backend set-simplex-transport-hook "$root" default "$hook" | jq -e '.hook_ready == true' >/dev/null
  tick=$(backend tick-simplex "$root" default)
  printf '%s\n' "$tick" | jq -e '.ok == true and .imported == 2' >/dev/null
  snapshot=$(backend snapshot "$root")
  printf '%s\n' "$snapshot" | jq -e '
    ([.threads[] | select(.id == "carol")][0].messages | map(select(.body == "repeatable text")) | length) == 2 and
    ([.threads[] | select(.id == "carol")][0].messages | map(.remote_id // "") | index("simplex-owner-direct:1")) != null and
    ([.threads[] | select(.id == "carol")][0].messages | map(.remote_id // "") | index("simplex-owner-direct:2")) != null
  ' >/dev/null
}

bundled_simplex_local_transport_is_end_to_end() {
  root="$tmpdir/simplex-local/mail"
  wire_in="$root/.transport/simplex/default/local-wire/incoming"
  mkdir -p "$tmpdir/home"
  backend prepare "$root" >/dev/null
  backend bind-contact "$root" dana "Dana Local" person dana@example.org simplex://dana yes >/dev/null
  backend configure-simplex-local-transport "$root" default | jq -e '.hook_ready == true and (.hook_path | endswith("owl-simplex-local-hook.sh"))' >/dev/null
  backend bootstrap-status "$root" default | jq -e '.hook_ready == true and (.hook_path | length > 0)' >/dev/null
  backend send-message "$root" dana simplex "Local outbound" "$(b64 'local outbound body')" >/dev/null
  mkdir -p "$wire_in"
  jq -n '{thread_id:"dana",body:"local inbound body",subject:"Local inbound",from_self:false,in_inbox:true}' >"$wire_in/inbound.json"
  tick=$(backend tick-simplex "$root" default)
  printf '%s\n' "$tick" | jq -e '.ok == true and .imported == 1 and .outbox.sent == 1 and .outbox.waiting == 0 and .outbox.failed == 0' >/dev/null
  [ -n "$(find "$root/.transport/simplex/default/local-wire/sent" -type f -name '*.json' -print -quit 2>/dev/null)" ] || return 1
  [ -z "$(find "$root/.owl/simplex/outbox" -type f -name '*.json' -print -quit 2>/dev/null)" ] || return 1
  snapshot=$(backend snapshot "$root")
  printf '%s\n' "$snapshot" | jq -e '
    ([.threads[] | select(.id == "dana")][0].messages | map(select(.body == "local outbound body" and .status == "sent")) | length) == 1 and
    ([.threads[] | select(.id == "dana")][0].messages | map(select(.body == "local inbound body" and .in_inbox == true)) | length) == 1 and
    (.inbox | map(select(.transport == "simplex" and .body == "local inbound body")) | length) == 1
  ' >/dev/null
}

secure_chat_transport_imports_and_replies_over_ssh_hook() {
  root="$tmpdir/secure-chat-hook/mail"
  fakebin="$tmpdir/secure-chat-hook/bin"
  ssh_log="$tmpdir/secure-chat-hook/ssh.log"
  mkdir -p "$tmpdir/home" "$fakebin"
  cat >"$fakebin/ssh" <<'SH'
#!/bin/sh
set -eu
while [ "${1-}" = "-o" ]; do
  shift 2
done
host=${1-}
shift || true
cmd=${1-}
shift || true
arg1=${1-}
arg2=${2-}
arg5=${5-}
printf '%s\t%s\t%s\t%s\t%s\n' "$host" "$cmd" "$arg1" "$arg2" "$arg5" >>"${OWL_TEST_SSH_LOG:?}"
case "$cmd" in
  */blog-secure-chat-owl-export)
    if [ "$arg1" = "9" ]; then
      jq -n '{success:true,cursor_seq:9,messages:[]}'
      exit 0
    fi
    if [ "$arg1" = "7" ]; then
      jq -n '{
        success:true,
        cursor_seq:9,
        messages:[{
          id:"simplex-owner-direct:27:9",
          seq:9,
          npub:"npub1visitor",
          thread_id:"npub1visitor",
          contact_name:"Nostr Username",
          body:"hello again from same identity",
          subject:"Website Secure Chat",
          from_self:false,
          in_inbox:true,
          simplex_address:"secure-chat:27",
          source:"simplex-owner-direct",
          created_at:"2026-05-05T08:02:00Z"
        }]
      }'
      exit 0
    fi
    jq -n --arg since "$arg1" '{
      success:true,
      cursor_seq:7,
      messages:[{
        id:"nostr-blog-secure-chat:npub1visitor:7",
        seq:7,
        npub:"npub1visitor",
        thread_id:"npub1visitor",
        contact_name:"Nostr Username",
        body:"hello from website 🦉",
        subject:"Website Secure Chat",
        from_self:false,
        in_inbox:true,
        simplex_address:"secure-chat:26",
        attachment:{name:"probe-😀.txt",mime:"text/plain",size:7},
        created_at:"2026-05-05T08:00:00Z"
      },{
        id:"simplex-owner-direct:26:8",
        seq:8,
        thread_id:"npub1visitor",
        body:"owner reply should not echo",
        subject:"Website Secure Chat",
        from_self:true,
        in_inbox:true,
        simplex_address:"secure-chat:26",
        source:"simplex-owner-direct",
        created_at:"2026-05-05T08:01:00Z"
      }]
    }'
    ;;
  */blog-secure-chat-owl-send)
    [ "$arg1" = "secure-chat:27" ] || exit 1
    printf '%s\n' "$arg2" | base64 -d >>"${OWL_TEST_SSH_LOG:?}.decoded"
    printf '\n' >>"${OWL_TEST_SSH_LOG:?}.decoded"
    jq -n '{success:true,npub:"npub1visitor"}'
    ;;
  *)
    exit 64
    ;;
esac
SH
  chmod +x "$fakebin/ssh"
  backend prepare "$root" >/dev/null
  backend configure-secure-chat-transport "$root" default test-host /remote/blog-secure-chat-owl-export /remote/blog-secure-chat-owl-send | jq -e '.hook_ready == true and .secure_chat_ssh_host == "test-host"' >/dev/null
  tick=$(
    PATH="$fakebin:$PATH" \
    OWL_TEST_SSH_LOG="$ssh_log" \
    HOME="$tmpdir/home" \
    XDG_STATE_HOME="$tmpdir/state" \
    XDG_CONFIG_HOME="$tmpdir/config" \
    sh "$repo_dir/scripts/owl-backend.sh" tick-simplex "$root" default
  )
  printf '%s\n' "$tick" | jq -e '.ok == true and .imported == 1 and .outbox.failed == 0' >/dev/null
  snapshot=$(backend snapshot "$root")
  printf '%s\n' "$snapshot" | jq -e '
    ([.threads[] | select(.id == "npub1visitor")][0].simplex_address == "secure-chat:26") and
    ([.threads[] | select(.id == "npub1visitor")][0].contact_name == "Nostr Username") and
    (.inbox | map(select(.thread_id == "npub1visitor" and .body == "hello from website 🦉" and .attachments == 1 and .attachment.name == "probe-😀.txt")) | length) == 1 and
    (.messages | map(select(.body == "owner reply should not echo")) | length) == 0
  ' >/dev/null
  backend bind-contact "$root" secure-chat-contact-27 "Legacy Contact" person "" secure-chat:27 no >/dev/null
  backend import-simplex "$root" secure-chat-contact-27 "$(b64 'legacy duplicate thread')" false true "Website Secure Chat" >/dev/null
  PATH="$fakebin:$PATH" \
    OWL_TEST_SSH_LOG="$ssh_log" \
    HOME="$tmpdir/home" \
    XDG_STATE_HOME="$tmpdir/state" \
    XDG_CONFIG_HOME="$tmpdir/config" \
    sh "$repo_dir/scripts/owl-backend.sh" tick-simplex "$root" default >/dev/null
  snapshot=$(backend snapshot "$root")
  printf '%s\n' "$snapshot" | jq -e '
    ([.threads[] | select(.id == "npub1visitor")] | length) == 1 and
    ([.threads[] | select(.id == "secure-chat-contact-27")] | length) == 0 and
    ([.threads[] | select(.id == "npub1visitor")][0].simplex_address == "secure-chat:27") and
    (.messages | map(select(.thread_id == "npub1visitor" and .body == "legacy duplicate thread")) | length) == 1 and
    (.inbox | map(select(.thread_id == "npub1visitor" and .body == "hello again from same identity")) | length) == 1
  ' >/dev/null
  backend send-message "$root" npub1visitor simplex "Reply" "$(b64 'reply body 😀')" >/dev/null
  PATH="$fakebin:$PATH" \
    OWL_TEST_SSH_LOG="$ssh_log" \
    HOME="$tmpdir/home" \
    XDG_STATE_HOME="$tmpdir/state" \
    XDG_CONFIG_HOME="$tmpdir/config" \
    sh "$repo_dir/scripts/owl-backend.sh" tick-simplex "$root" default >/dev/null
  grep -q '/remote/blog-secure-chat-owl-send	secure-chat:27' "$ssh_log"
  grep -q 'simplex:' "$ssh_log"
  grep -q 'reply body 😀' "$ssh_log.decoded"
  attachment_file="$tmpdir/secure-chat-hook/probe.txt"
  printf '%s\n' 'attachment payload 😀' >"$attachment_file"
  backend send-attachment "$root" npub1visitor simplex "Attachment" "$(b64 'attachment reply 😀')" "$attachment_file" >/dev/null
  PATH="$fakebin:$PATH" \
    OWL_TEST_SSH_LOG="$ssh_log" \
    HOME="$tmpdir/home" \
    XDG_STATE_HOME="$tmpdir/state" \
    XDG_CONFIG_HOME="$tmpdir/config" \
  sh "$repo_dir/scripts/owl-backend.sh" tick-simplex "$root" default >/dev/null
  grep -q 'attachment reply 😀' "$ssh_log.decoded"
  snapshot=$(backend snapshot "$root")
  printf '%s\n' "$snapshot" | jq -e '
    (.messages | map(select(.thread_id == "npub1visitor" and .body == "attachment reply 😀\nAttachment: probe.txt" and .attachments == 1 and .attachment.name == "probe.txt" and (.attachment.data_url | startswith("data:text/plain;base64,")))) | length) == 1
  ' >/dev/null
}

stale_bundled_secure_chat_hook_path_resolves_to_current_hook() {
  root="$tmpdir/stale-secure-chat-hook/mail"
  backend prepare "$root" >/dev/null
  conf="$root/.transport/simplex/default/profile.conf"
  mkdir -p "$(dirname "$conf")"
  {
    printf '%s\n' 'transport_hook=/Users/example/git/owl-native/scripts/owl-native-secure-chat-hook.sh'
    printf '%s\n' 'secure_chat_ssh_host=test-host'
    printf '%s\n' 'secure_chat_export_command=/remote/blog-secure-chat-owl-export'
    printf '%s\n' 'secure_chat_send_command=/remote/blog-secure-chat-owl-send'
  } >"$conf"
  backend simplex-transport-status "$root" default | jq -e \
    --arg hook "$repo_dir/scripts/owl-secure-chat-hook.sh" \
    '.hook_ready == true and .hook_path == $hook' >/dev/null
}

install_simplex_cli_delegates_to_wizardry_installer() {
  root="$tmpdir/install-wizardry/mail"
  fake_dir="$tmpdir/fake-wizardry"
  mkdir -p "$tmpdir/home" "$fake_dir"
  installer="$fake_dir/install-simplex-chat"
  cat >"$installer" <<'SH'
#!/bin/sh
set -eu
root="${WIZARDRY_SIMPLEX_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/wizardry/simplex}"
mkdir -p "$root/current"
cat >"$root/current/simplex-chat" <<'BIN'
#!/bin/sh
[ "${1-}" = "-h" ] && exit 0
exit 0
BIN
chmod +x "$root/current/simplex-chat"
cat >"$root/install.conf" <<EOF
version=vtest
asset_name=test-asset
binary_path=$root/current/simplex-chat
validation_state=ready
last_error=
EOF
printf '%s\n' "installed fake SimpleX"
SH
  chmod +x "$installer"
  output=$(
    HOME="$tmpdir/home" \
    XDG_STATE_HOME="$tmpdir/state" \
    XDG_CONFIG_HOME="$tmpdir/config" \
    OWL_SIMPLEX_INSTALLER="$installer" \
    sh "$repo_dir/scripts/owl-backend.sh" install-simplex-cli "$root"
  )
  printf '%s\n' "$output" | jq -e \
    --arg binary "$tmpdir/state/wizardry/simplex/current/simplex-chat" \
    '.ok == true and .install_source == "wizardry" and .version == "vtest" and .binary_path == $binary' >/dev/null
}

invalid_action_fails() {
  root="$tmpdir/invalid/mail"
  mkdir -p "$tmpdir/home"
  if backend unknown "$root" >"$tmpdir/unknown.out" 2>"$tmpdir/unknown.err"; then
    return 1
  fi
  grep -q 'unsupported action' "$tmpdir/unknown.err"
}

run_case "doctor is read-only" doctor_is_read_only
run_case "prepare creates shared roots" prepare_creates_shared_roots
run_case "SimpleX messages share one timeline and inbox" simplex_messages_share_one_timeline_and_inbox
run_case "SimpleX send queues without email fallback" simplex_send_queues_without_email_fallback
run_case "SimpleX inbox state does not move timeline messages" simplex_inbox_state_is_metadata_not_thread_movement
run_case "SimpleX trash stages a file for system Trash" simplex_trash_stages_file_for_system_trash
run_case "bootstrap status is structured" bootstrap_status_is_structured
run_case "bootstrap status detects Wizardry SimpleX install" bootstrap_status_detects_wizardry_simplex_install
run_case "snapshot includes Owl mailboxes, drafts, events, and settings" snapshot_includes_owl_mailboxes_drafts_events_settings
run_case "snapshot reads mail sidecars locally" snapshot_reads_mail_sidecars_locally
run_case "snapshot lines exposes native GTK feed" snapshot_lines_exposes_native_gtk_feed
run_case "Owl actions are hard allowlisted and pass through" owl_actions_are_hard_allowlisted_and_passthrough
run_case "UI prefs are plaintext XDG state" ui_prefs_are_plaintext_xdg_state
run_case "message detail returns SimpleX and email messages" message_detail_returns_simplex_and_email_messages
run_case "SimpleX tick uses transport hook for poll and send" simplex_tick_uses_transport_hook_for_poll_and_send
run_case "SimpleX tick sends queued outbox before polling" simplex_tick_sends_before_polling
run_case "SimpleX tick dedupes by remote id, not repeated body text" simplex_tick_dedupes_by_remote_id_not_body
run_case "bundled SimpleX local transport is end-to-end" bundled_simplex_local_transport_is_end_to_end
run_case "stale bundled Secure Chat hook path resolves to current hook" stale_bundled_secure_chat_hook_path_resolves_to_current_hook
run_case "Secure Chat transport imports and replies over SSH hook" secure_chat_transport_imports_and_replies_over_ssh_hook
run_case "install SimpleX CLI delegates to Wizardry installable" install_simplex_cli_delegates_to_wizardry_installer
run_case "invalid action fails" invalid_action_fails

if [ "$failures" -ne 0 ]; then
  printf '%s\n' "$failures test(s) failed" >&2
  exit 1
fi

printf '%s\n' "19/19 backend contract tests passed"
