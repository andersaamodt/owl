#!/bin/sh

case "${1-}" in
--help|--usage|-h|help)
  cat <<'USAGE'
Usage: stellar-backend.sh ACTION [ROOT] [ARGS...]

Actions:
  doctor [ROOT]
  prepare ROOT
  get-paths ROOT
  get-ui-prefs ROOT
  set-ui-pref ROOT KEY VALUE
  snapshot ROOT
  snapshot-lines ROOT
  overview ROOT
  settings-controls ROOT
  settings-browse-root ROOT [START_PATH]
  settings-set-test-recipient ROOT ADDRESS
  settings-verify-domain ROOT DOMAIN
  settings-set-domain ROOT DOMAIN
  settings-ssl-prereq-status ROOT
  settings-ssl-wizard-status ROOT
  settings-setup-ssl ROOT [MODE] [HOST] [SSH_KEY_PATH] [SSH_KEY_PASSWORD] [SSH_PORT]
  settings-set-daemon-installed ROOT on|off
  settings-set-daemon-running ROOT on|off
  settings-set-daemon-startup ROOT on|off
  settings-setup-folders ROOT
  settings-remote-set-target ROOT HOST SSH_KEY_PATH [SSH_PORT]
  settings-remote-set-auth ROOT SSH_KEY_HAS_PASSWORD SSH_KEY_SAVE_CHOICE SSH_KEY_PASSWORD [HOST] [SSH_KEY_PATH] [SSH_PORT]
  settings-remote-deploy ROOT [HOST] [SSH_KEY_PATH] [SSH_KEY_PASSWORD] [SSH_PORT]
  settings-remote-verify ROOT [HOST] [SSH_KEY_PATH] [SSH_KEY_PASSWORD] [SSH_PORT]
  settings-remote-send-test ROOT [HOST] [SSH_KEY_PATH] [SSH_KEY_PASSWORD] [SSH_PORT]
  settings-remote-sync ROOT [HOST] [SSH_KEY_PATH] [SSH_KEY_PASSWORD] [SSH_PORT]
  settings-llm-controls ROOT
  settings-llm-set ROOT ENABLED AUTO_INSTALL MODEL
  settings-llm-install-ollama ROOT
  settings-llm-set-daemon ROOT on|off
  settings-llm-install-model ROOT MODEL
  settings-llm-uninstall-model ROOT MODEL
  spam-classify ROOT [LIST] [SENDER] [LIMIT] [ALLOW_INSTALL]
  event-feed ROOT [LIMIT]
  bind-contact ROOT THREAD_ID NAME KIND EMAIL SIMPLEX_ADDRESS FAVORITE
  contact-get ROOT IDENTITY [FALLBACK_LABEL] [CONTACT_KEY]
  contact-save ROOT IDENTITY CONTACT_KEY NAME EMAIL PHONE ADDRESS URL NOTE
  set-temporal-distance ROOT THREAD_ID SECONDS|auto
  import-simplex ROOT THREAD_ID BODY_B64 [FROM_SELF] [IN_INBOX] [SUBJECT]
  mark-inbox ROOT MESSAGE_ID in|out
  mark-read ROOT MESSAGE_ID true|false
  mark-seen ROOT MESSAGE_ID...
  send-message ROOT THREAD_ID simplex|email SUBJECT BODY_B64
  send-attachment ROOT THREAD_ID simplex SUBJECT BODY_B64 FILE_PATH
  message-detail ROOT MESSAGE_ID
  archive-message ROOT MESSAGE_ID
  message-trash-files ROOT MESSAGE_ID
  delete-message ROOT MESSAGE_ID
  toggle-star ROOT MESSAGE_ID true|false
  list-senders ROOT LIST
  list-archive-bundle ROOT
  list-inbox-bundle-fast ROOT
  list-messages-fast ROOT LIST [SENDER]
  list-messages ROOT LIST [SENDER]
  get-message ROOT MESSAGE_ID
  get-message ROOT LIST SENDER ULID
  set-flag ROOT LIST SENDER ULID FIELD VALUE
  move-message ROOT FROM TO SENDER ULID
  move-sender ROOT FROM TO SENDER
  draft-list ROOT
  draft-get ROOT ULID
  draft-save ROOT ULID FROM TO_CSV CC_CSV BCC_CSV SUBJECT REPLY_TO BODY_B64
  draft-delete ROOT ULID
  draft-send ROOT ULID
  bootstrap-status ROOT [IDENTITY]
  install-simplex-cli ROOT
  provision-simplex-identity ROOT [IDENTITY] [DISPLAY_NAME] [FULL_NAME]
  configure-simplex-local-transport ROOT [IDENTITY]
  configure-secure-chat-transport ROOT [IDENTITY] [SSH_HOST] [EXPORT_COMMAND] [SEND_COMMAND]
  set-simplex-transport-hook ROOT IDENTITY HOOK_PATH
  simplex-transport-status ROOT [IDENTITY]
  tick-simplex ROOT

Stellar uses the shared mail root. ROOT defaults to ~/mail.
USAGE
  exit 0
  ;;
esac

set -eu

action=${1-}
root_arg=${2-}
shift 2 >/dev/null 2>&1 || true

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
home=${HOME:?}
nl='
'
cr=$(printf '\r')

fail() {
  printf '%s\n' "stellar-backend: $*" >&2
  exit 1
}

usage_error() {
  printf '%s\n' "stellar-backend: $*" >&2
  exit 2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool not found: $1"
}

base64_one_line() {
  if base64 --help 2>/dev/null | grep -q -- '-w'; then
    base64 -w 0
    return
  fi
  base64 | tr -d '\n'
}

simplex_web_attachment_json() {
  attachment_file_path=$1
  [ -f "$attachment_file_path" ] || usage_error "attachment file not found"
  attachment_name=${attachment_file_path##*/}
  attachment_size=$(wc -c <"$attachment_file_path" | tr -d ' ')
  attachment_mime=application/octet-stream
  if command -v file >/dev/null 2>&1; then
    attachment_mime=$(file -b --mime-type "$attachment_file_path" 2>/dev/null || printf 'application/octet-stream')
  fi
  if [ "$attachment_mime" = "application/octet-stream" ]; then
    attachment_mime=$(mime_from_name "$attachment_name")
  fi
  attachment_data=$(base64_one_line <"$attachment_file_path")
  jq -cn \
    --arg name "$attachment_name" \
    --arg mime "$attachment_mime" \
    --argjson size "$attachment_size" \
    --arg data_url "data:$attachment_mime;base64,$attachment_data" \
    '{name:$name,mime:$mime,size:$size,data_url:$data_url}'
}

mime_from_name() {
  case "$(printf '%s' "${1-}" | tr '[:upper:]' '[:lower:]')" in
    *.apng) printf 'image/apng\n' ;;
    *.avif) printf 'image/avif\n' ;;
    *.gif) printf 'image/gif\n' ;;
    *.jpg|*.jpeg) printf 'image/jpeg\n' ;;
    *.png) printf 'image/png\n' ;;
    *.webp) printf 'image/webp\n' ;;
    *.m4a) printf 'audio/mp4\n' ;;
    *.mp3) printf 'audio/mpeg\n' ;;
    *.ogg|*.oga) printf 'audio/ogg\n' ;;
    *.wav) printf 'audio/wav\n' ;;
    *.m4v|*.mp4) printf 'video/mp4\n' ;;
    *.webm) printf 'video/webm\n' ;;
    *.txt|*.md) printf 'text/plain\n' ;;
    *) printf 'application/octet-stream\n' ;;
  esac
}

normalize_simplex_attachment_json() {
  attachment_json_value=${1:-null}
  [ "$attachment_json_value" != null ] || {
    printf 'null\n'
    return 0
  }
  attachment_name=$(printf '%s\n' "$attachment_json_value" | jq -r '.name // ""' 2>/dev/null || printf '')
  attachment_mime=$(printf '%s\n' "$attachment_json_value" | jq -r '.mime // ""' 2>/dev/null || printf '')
  if [ -z "$attachment_mime" ]; then
    attachment_mime=$(mime_from_name "$attachment_name")
  fi
  printf '%s\n' "$attachment_json_value" | jq -c --arg mime "$attachment_mime" '.mime = $mime'
}

safe_output_value() {
  case "${1-}" in
    *"$nl"*|*"$cr"*)
      fail "unsafe output value"
      ;;
  esac
}

normalize_path() {
  input=${1-}
  if [ -z "$input" ]; then
    printf '%s\n' "$home/mail"
    return 0
  fi
  case "$input" in
    "~")
      printf '%s\n' "$home"
      ;;
    "~/"*)
      printf '%s\n' "$home/${input#\~/}"
      ;;
    /*)
      printf '%s\n' "$input"
      ;;
    *)
      printf '%s\n' "$(pwd -P)/$input"
      ;;
  esac
}

ROOT=$(normalize_path "$root_arg")
safe_output_value "$ROOT"

metadata_root() {
  printf '%s\n' "$ROOT/.stellar"
}

ui_config_dir() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps/stellar"
}

ui_prefs_file() {
  printf '%s\n' "$(ui_config_dir)/prefs.conf"
}

native_contacts_dir() {
  printf '%s\n' "$(metadata_root)/contacts"
}

simplex_state_root() {
  printf '%s\n' "$(metadata_root)/simplex"
}

simplex_threads_dir() {
  printf '%s\n' "$(simplex_state_root)/threads"
}

simplex_incoming_dir() {
  printf '%s\n' "$(simplex_state_root)/incoming"
}

simplex_outbox_dir() {
  printf '%s\n' "$(simplex_state_root)/outbox"
}

simplex_processed_dir() {
  printf '%s\n' "$(simplex_state_root)/processed"
}

simplex_trash_staging_dir() {
  printf '%s\n' "$(simplex_state_root)/trash-staging"
}

simplex_system_root() {
  printf '%s\n' "$ROOT/.system/simplex"
}

simplex_install_file() {
  printf '%s\n' "$(simplex_system_root)/install.conf"
}

simplex_releases_dir() {
  printf '%s\n' "$(simplex_system_root)/releases"
}

simplex_current_dir() {
  printf '%s\n' "$(simplex_system_root)/current"
}

simplex_current_binary() {
  printf '%s\n' "$(simplex_current_dir)/simplex-chat"
}

wizardry_simplex_root() {
  if [ -n "${STELLAR_WIZARDRY_SIMPLEX_ROOT-}" ]; then
    printf '%s\n' "$STELLAR_WIZARDRY_SIMPLEX_ROOT"
    return 0
  fi
  if [ -n "${WIZARDRY_SIMPLEX_ROOT-}" ]; then
    printf '%s\n' "$WIZARDRY_SIMPLEX_ROOT"
    return 0
  fi
  printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/wizardry/simplex"
}

wizardry_simplex_install_file() {
  printf '%s\n' "$(wizardry_simplex_root)/install.conf"
}

wizardry_simplex_current_binary() {
  printf '%s\n' "$(wizardry_simplex_root)/current/simplex-chat"
}

simplex_user_bin_path() {
  printf '%s\n' "${XDG_BIN_HOME:-$HOME/.local/bin}/simplex-chat"
}

simplex_transport_root() {
  printf '%s\n' "$ROOT/.transport/simplex"
}

simplex_identity_dir() {
  ident=$(safe_slug "${1:-default}")
  printf '%s\n' "$(simplex_transport_root)/$ident"
}

simplex_profile_prefix() {
  printf '%s\n' "$(simplex_identity_dir "${1:-default}")/profile"
}

simplex_profile_conf() {
  printf '%s\n' "$(simplex_identity_dir "${1:-default}")/profile.conf"
}

default_simplex_transport_hook() {
  printf '%s\n' "$script_dir/stellar-simplex-local-hook.sh"
}

secure_chat_transport_hook() {
  printf '%s\n' "$script_dir/stellar-secure-chat-hook.sh"
}

ensure_roots() {
  mkdir -p "$ROOT" "$(metadata_root)" "$(native_contacts_dir)"
  mkdir -p "$(simplex_threads_dir)" "$(simplex_incoming_dir)" "$(simplex_outbox_dir)" "$(simplex_processed_dir)"
  mkdir -p "$ROOT/quarantine" "$ROOT/accepted" "$ROOT/spam" "$ROOT/banned"
  mkdir -p "$ROOT/archive" "$ROOT/trash" "$ROOT/drafts" "$ROOT/outbox" "$ROOT/sent" "$ROOT/logs"
}

local_mail_folders_ready() {
  for dir in quarantine accepted spam banned archive trash drafts outbox sent logs; do
    [ -d "$ROOT/$dir" ] || {
      printf 'false\n'
      return
    }
  done
  printf 'true\n'
}

safe_slug() {
  raw=${1-}
  cleaned=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._@-' '-')
  cleaned=$(printf '%s' "$cleaned" | sed 's/^-*//; s/-*$//; s/--*/-/g')
  if [ -z "$cleaned" ]; then
    cleaned=unknown
  fi
  printf '%s\n' "$cleaned"
}

now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

message_id() {
  rand=$(od -An -tx1 -N8 /dev/urandom 2>/dev/null | tr -d ' \n')
  [ -n "$rand" ] || rand=$$
  printf 'm-%s-%s\n' "$(date -u +%Y%m%dT%H%M%SZ)" "$rand"
}

config_get() {
  file=$1
  key=$2
  [ -f "$file" ] || return 1
  awk -F= -v wanted="$key" '
    $1 == wanted {
      print substr($0, index($0, "=") + 1)
      found = 1
    }
    END { exit found ? 0 : 1 }
  ' "$file"
}

config_set() {
  file=$1
  key=$2
  value=${3-}
  case "$key" in
    ''|*[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-]*)
      usage_error "invalid config key: $key"
      ;;
  esac
  case "$value" in
    *"$nl"*|*"$cr"*)
      usage_error "config value for $key must be a single line"
      ;;
  esac
  mkdir -p "$(dirname "$file")"
  tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-conf.XXXXXX")
  if [ -f "$file" ]; then
    awk -F= -v wanted="$key" '$1 != wanted' "$file" >"$tmp"
  fi
  printf '%s=%s\n' "$key" "$value" >>"$tmp"
  mv "$tmp" "$file"
}

ui_pref_value() {
  key=$1
  case "$key" in
    mail_root)
      config_get "$(ui_prefs_file)" mail_root 2>/dev/null || printf '%s\n' "$ROOT"
      ;;
    selected_route)
      config_get "$(ui_prefs_file)" selected_route 2>/dev/null || printf '%s\n' new
      ;;
    bubble_self_simplex)
      config_get "$(ui_prefs_file)" bubble_self_simplex 2>/dev/null || printf '%s\n' '#DDF4E3'
      ;;
    bubble_self_email)
      config_get "$(ui_prefs_file)" bubble_self_email 2>/dev/null || printf '%s\n' '#F7DADA'
      ;;
    bubble_other_simplex)
      config_get "$(ui_prefs_file)" bubble_other_simplex 2>/dev/null || printf '%s\n' '#EDF7F0'
      ;;
    bubble_other_email)
      config_get "$(ui_prefs_file)" bubble_other_email 2>/dev/null || printf '%s\n' '#F5ECEC'
      ;;
    mark_read_when_seen)
      config_get "$(ui_prefs_file)" mark_read_when_seen 2>/dev/null || printf '%s\n' true
      ;;
    mark_earlier_seen)
      config_get "$(ui_prefs_file)" mark_earlier_seen 2>/dev/null || printf '%s\n' true
      ;;
    show_temporal_distance)
      config_get "$(ui_prefs_file)" show_temporal_distance 2>/dev/null || printf '%s\n' true
      ;;
    detect_temporal_distance)
      config_get "$(ui_prefs_file)" detect_temporal_distance 2>/dev/null || printf '%s\n' true
      ;;
    *)
      return 1
      ;;
  esac
}

ui_prefs_action() {
  jq -n \
    --arg mail_root "$(ui_pref_value mail_root)" \
    --arg selected_route "$(ui_pref_value selected_route)" \
    --arg bubble_self_simplex "$(ui_pref_value bubble_self_simplex)" \
    --arg bubble_self_email "$(ui_pref_value bubble_self_email)" \
    --arg bubble_other_simplex "$(ui_pref_value bubble_other_simplex)" \
    --arg bubble_other_email "$(ui_pref_value bubble_other_email)" \
    --arg mark_read_when_seen "$(ui_pref_value mark_read_when_seen)" \
    --arg mark_earlier_seen "$(ui_pref_value mark_earlier_seen)" \
    --arg show_temporal_distance "$(ui_pref_value show_temporal_distance)" \
    --arg detect_temporal_distance "$(ui_pref_value detect_temporal_distance)" \
    '{ok:true,mail_root:$mail_root,selected_route:$selected_route,bubble_self_simplex:$bubble_self_simplex,bubble_self_email:$bubble_self_email,bubble_other_simplex:$bubble_other_simplex,bubble_other_email:$bubble_other_email,mark_read_when_seen:$mark_read_when_seen,mark_earlier_seen:$mark_earlier_seen,show_temporal_distance:$show_temporal_distance,detect_temporal_distance:$detect_temporal_distance}'
}

set_ui_pref_action() {
  key=${1-}
  value=${2-}
  case "$key" in
    mail_root|selected_route|bubble_self_simplex|bubble_self_email|bubble_other_simplex|bubble_other_email|mark_read_when_seen|mark_earlier_seen|show_temporal_distance|detect_temporal_distance) ;;
    *) usage_error "unsupported UI preference: $key" ;;
  esac
  case "$value" in
    *"$nl"*|*"$cr"*) usage_error "UI preference values must be single-line" ;;
  esac
  config_set "$(ui_prefs_file)" "$key" "$value"
  ui_prefs_action
}

decode_b64_to_file() {
  payload=${1-}
  output=$2
  if printf '%s' "$payload" | base64 --decode >"$output" 2>/dev/null; then
    return 0
  fi
  if printf '%s' "$payload" | base64 -D >"$output" 2>/dev/null; then
    return 0
  fi
  return 1
}

resolve_mail_backend_script() {
  if [ -n "${STELLAR_MAIL_BACKEND-}" ] && [ -f "$STELLAR_MAIL_BACKEND" ]; then
    printf '%s\n' "$STELLAR_MAIL_BACKEND"
    return 0
  fi
  for candidate in \
    "$repo_dir/scripts/stellar-mail-backend.sh" \
    "$repo_dir/libexec/stellar-mail-backend.sh"
  do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

mail_backend_status_json() {
  backend_path=$(resolve_mail_backend_script || true)
  if [ -n "$backend_path" ]; then
    case "$backend_path" in
      "$repo_dir"/*) backend_source=bundled ;;
      *) backend_source=override ;;
    esac
    backend_health=$(mail_backend_json health 2>/dev/null || true)
    if [ -n "$backend_health" ] &&
      printf '%s\n' "$backend_health" | jq -e '.ok == true' >/dev/null 2>&1; then
      jq -n \
        --arg path "$backend_path" \
        --arg source "$backend_source" \
        '{available:true,configured:true,path:$path,source:$source,message:""}'
    else
      jq -n \
        --arg path "$backend_path" \
        --arg source "$backend_source" \
        '{available:false,configured:true,path:$path,source:$source,message:"The configured mail engine did not pass its health check."}'
    fi
    return
  fi
  jq -n \
    '{available:false,configured:false,path:"",source:"missing",message:"Email receiving and server administration require a mail engine that is not included in this build."}'
}

mail_backend_timeout_seconds() {
  case "$stellar_action" in
    list-messages|list-messages-fast|list-inbox-bundle-fast|list-archive-bundle)
      printf '%s\n' "${STELLAR_MAIL_LIST_TIMEOUT_SECONDS:-15}"
      ;;
    settings-remote-deploy)
      printf '%s\n' "${STELLAR_REMOTE_DEPLOY_TIMEOUT_SECONDS:-1800}"
      ;;
    settings-setup-ssl)
      printf '%s\n' "${STELLAR_REMOTE_TLS_TIMEOUT_SECONDS:-900}"
      ;;
    settings-remote-verify|settings-remote-send-test|settings-remote-sync)
      printf '%s\n' "${STELLAR_REMOTE_ACTION_TIMEOUT_SECONDS:-60}"
      ;;
    settings-llm-install-ollama|settings-llm-install-model|settings-llm-uninstall-model)
      printf '%s\n' "${STELLAR_LLM_ACTION_TIMEOUT_SECONDS:-900}"
      ;;
    *)
      printf '%s\n' "${STELLAR_MAIL_BACKEND_TIMEOUT_SECONDS:-5}"
      ;;
  esac
}

terminate_process_tree() {
  process_root=$1
  descendants=$(
    ps -eo pid=,ppid= 2>/dev/null |
      awk -v root="$process_root" '
        { parent[$1] = $2 }
        END {
          for (pid in parent) {
            current = pid
            while (current in parent) {
              if (parent[current] == root) {
                print pid
                break
              }
              current = parent[current]
            }
          }
        }
      '
  )
  if [ -n "$descendants" ]; then
    kill $descendants 2>/dev/null || true
  fi
  kill "$process_root" 2>/dev/null || true
}

mail_backend_json() {
  stellar_action=$1
  shift || true
  script=$(resolve_mail_backend_script || true)
  if [ -z "$script" ]; then
    printf '%s\n' "stellar-backend: email action '$stellar_action' is unavailable: no mail engine is installed" >&2
    return 127
  fi
  timeout_seconds=$(mail_backend_timeout_seconds)
  case "$timeout_seconds" in ''|*[!0123456789]*) timeout_seconds=1 ;; esac
  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_seconds" sh "$script" "$stellar_action" "$ROOT" "$@"
    return $?
  fi
  tmp_out=$(mktemp "${TMPDIR:-/tmp}/stellar-mail-backend-out.XXXXXX")
  tmp_err=$(mktemp "${TMPDIR:-/tmp}/stellar-mail-backend-err.XXXXXX")
  sh "$script" "$stellar_action" "$ROOT" "$@" >"$tmp_out" 2>"$tmp_err" &
  backend_pid=$!
  timeout_ticks=$((timeout_seconds * 10))
  elapsed_ticks=0
  backend_timed_out=false
  while kill -0 "$backend_pid" 2>/dev/null; do
    if [ "$elapsed_ticks" -ge "$timeout_ticks" ]; then
      backend_timed_out=true
      terminate_process_tree "$backend_pid"
      break
    fi
    sleep 0.1
    elapsed_ticks=$((elapsed_ticks + 1))
  done
  if wait "$backend_pid"; then
    backend_status=0
  else
    backend_status=$?
  fi
  cat "$tmp_out"
  cat "$tmp_err" >&2
  if [ "$backend_timed_out" = true ]; then
    backend_status=124
  fi
  rm -f "$tmp_out" "$tmp_err"
  return "$backend_status"
}

mail_backend_json_or_empty() {
  out=$(mail_backend_json "$@" 2>/dev/null || true)
  if [ -n "$out" ] && printf '%s\n' "$out" | jq -e . >/dev/null 2>&1; then
    printf '%s\n' "$out"
  else
    jq -n \
      '{ok:false,unavailable:true,message:"Email receiving and server administration require a mail engine that is not included in this build."}'
  fi
}

mail_backend_array_field_or_empty() {
  field=$1
  shift
  out=$(mail_backend_json "$@" 2>/dev/null || true)
  array=
  if [ -n "$out" ]; then
    array=$(printf '%s\n' "$out" | jq -c --arg field "$field" '.[$field] // []' 2>/dev/null || true)
  fi
  if [ -n "$array" ]; then
    printf '%s\n' "$array"
  else
    printf '[]\n'
  fi
}

native_contact_file() {
  thread_id=$(safe_slug "$1")
  printf '%s/%s.conf\n' "$(native_contacts_dir)" "$thread_id"
}

contact_conf_to_json() {
  file=$1
  [ -f "$file" ] || return 0
  id=$(config_get "$file" id 2>/dev/null || basename "$file" .conf)
  name=$(config_get "$file" name 2>/dev/null || printf '')
  kind=$(config_get "$file" kind 2>/dev/null || printf person)
  email=$(config_get "$file" email 2>/dev/null || printf '')
  simplex=$(config_get "$file" simplex_address 2>/dev/null || printf '')
  favorite=$(config_get "$file" favorite 2>/dev/null || printf no)
  group=$(config_get "$file" group 2>/dev/null || printf '')
  temporal_distance=$(config_get "$file" temporal_distance_seconds 2>/dev/null || printf '')
  jq -cn \
    --arg id "$id" \
    --arg name "$name" \
    --arg kind "$kind" \
    --arg email "$email" \
    --arg simplex_address "$simplex" \
    --arg favorite "$favorite" \
    --arg group "$group" \
    --arg temporal_distance_seconds "$temporal_distance" \
    '{id:$id,name:$name,kind:(if $kind == "group" then "group" else "person" end),email:$email,simplex_address:$simplex_address,favorite:($favorite=="yes" or $favorite=="true" or $favorite=="1"),group:$group,temporal_distance_seconds:(if $temporal_distance_seconds == "" then null else ($temporal_distance_seconds | tonumber? // null) end)}'
}

contacts_json_array() {
  tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-contacts.XXXXXX")
  dir=$(native_contacts_dir)
  if [ -d "$dir" ]; then
    for file in "$dir"/*.conf; do
      [ -f "$file" ] || continue
      contact_conf_to_json "$file" >>"$tmp"
    done
  fi
  jq -s '.' "$tmp"
  rm -f "$tmp"
}

save_contact_binding() {
  thread_id=$(safe_slug "${1-}")
  name=${2-}
  kind=${3-person}
  email=${4-}
  simplex=${5-}
  favorite=${6-no}
  case "$thread_id$name$kind$email$simplex$favorite" in
    *"$nl"*|*"$cr"*) usage_error "contact fields must be single-line values" ;;
  esac
  case "$kind" in
    group) ;;
    *) kind=person ;;
  esac
  case "$favorite" in
    yes|true|1|on) favorite=yes ;;
    *) favorite=no ;;
  esac
  [ -n "$thread_id" ] || usage_error "bind-contact requires THREAD_ID"
  file=$(native_contact_file "$thread_id")
  config_set "$file" id "$thread_id"
  config_set "$file" name "$name"
  config_set "$file" kind "$kind"
  config_set "$file" email "$email"
  config_set "$file" simplex_address "$simplex"
  config_set "$file" favorite "$favorite"
  contact_conf_to_json "$file"
}

set_temporal_distance_action() {
  thread_id=$(safe_slug "${1-}")
  value=${2-}
  [ -n "$thread_id" ] || usage_error "set-temporal-distance requires THREAD_ID"
  case "$value" in
    ''|auto|clear|none)
      seconds=''
      ;;
    *[!0123456789]*)
      usage_error "temporal distance must be seconds or auto"
      ;;
    *)
      seconds=$value
      [ "$seconds" -ge 0 ] 2>/dev/null || usage_error "temporal distance must be seconds or auto"
      if [ "$seconds" -eq 0 ]; then
        seconds=''
      fi
      ;;
  esac
  file=$(native_contact_file "$thread_id")
  if [ ! -f "$file" ]; then
    config_set "$file" id "$thread_id"
    config_set "$file" name "$thread_id"
    config_set "$file" kind person
    config_set "$file" email ""
    config_set "$file" simplex_address ""
    config_set "$file" favorite no
  fi
  config_set "$file" temporal_distance_seconds "$seconds"
  contact_conf_to_json "$file"
}

simplex_thread_file() {
  thread_id=$(safe_slug "$1")
  printf '%s/%s.jsonl\n' "$(simplex_threads_dir)" "$thread_id"
}

legacy_secure_chat_thread_for_address() {
  case "${1-}" in
    secure-chat:[0-9]*)
      printf 'secure-chat-contact-%s\n' "${1#secure-chat:}"
      ;;
  esac
}

migrate_simplex_thread_messages() {
  from_thread=$(safe_slug "${1-}")
  to_thread=$(safe_slug "${2-}")
  [ -n "$from_thread" ] && [ -n "$to_thread" ] || return 0
  [ "$from_thread" != "$to_thread" ] || return 0
  from_file=$(simplex_thread_file "$from_thread")
  [ -f "$from_file" ] || return 0
  to_file=$(simplex_thread_file "$to_thread")
  mkdir -p "$(dirname "$to_file")"
  tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-simplex-merge.XXXXXX")
  {
    [ -f "$to_file" ] && cat "$to_file"
    jq -c --arg thread_id "$to_thread" '.thread_id = $thread_id' "$from_file"
  } | jq -cs '
    reduce .[] as $message ({order:[], by_key:{}}; 
      (($message.remote_id // "") | tostring) as $remote
      | (($message.id // "") | tostring) as $id
      | (if $remote != "" then "remote:" + $remote else "id:" + $id end) as $key
      | if (.by_key[$key] // null) == null then .order += [$key] else . end
      | .by_key[$key] = $message
    )
    | .order[] as $key
    | .by_key[$key]
  ' >"$tmp"
  mv "$tmp" "$to_file"
  rm -f "$from_file"
  rm -f "$(native_contact_file "$from_thread")"
}

append_simplex_message() {
  thread_id=$(safe_slug "$1")
  body=${2-}
  from_self=${3-false}
  in_inbox=${4-false}
  subject=${5-}
  at=${6-}
  remote_id=${7-}
  attachments=${8-0}
  attachment_json=${9:-null}
  [ -n "$at" ] || at=$(now_iso)
  case "$from_self" in true|1|yes|on) from_self=true ;; *) from_self=false ;; esac
  case "$in_inbox" in true|1|yes|on|in) in_inbox=true ;; *) in_inbox=false ;; esac
  attachment_json=$(normalize_simplex_attachment_json "$attachment_json")
  id="simplex:$(message_id)"
  file=$(simplex_thread_file "$thread_id")
  mkdir -p "$(dirname "$file")"
  jq -cn \
    --arg id "$id" \
    --arg thread_id "$thread_id" \
    --arg subject "$subject" \
    --arg body "$body" \
    --arg received_at "$at" \
    --arg remote_id "$remote_id" \
    --argjson attachments "$attachments" \
    --argjson attachment "$attachment_json" \
    --argjson from_self "$from_self" \
    --argjson in_inbox "$in_inbox" \
    '{schema:1,id:$id,thread_id:$thread_id,transport:"simplex",subject:$subject,body:$body,received_at:$received_at,from_self:$from_self,in_inbox:$in_inbox,read:false,status:"queued",attachments:$attachments} + (if $attachment == null then {} else {attachment:$attachment} end) + (if $remote_id != "" then {remote_id:$remote_id} else {} end)' >>"$file"
  jq -cn --arg id "$id" --arg thread_id "$thread_id" '{ok:true,id:$id,thread_id:$thread_id}'
}

simplex_duplicate_message_exists() {
  thread_id=$(safe_slug "$1")
  body=${2-}
  from_self=${3-false}
  remote_id=${4-}
  case "$from_self" in true|1|yes|on) from_self=true ;; *) from_self=false ;; esac
  file=$(simplex_thread_file "$thread_id")
  [ -f "$file" ] || return 1
  if [ -n "$remote_id" ]; then
    jq -e --arg remote_id "$remote_id" '
      select((.remote_id // "") == $remote_id)
    ' "$file" >/dev/null 2>&1
    return $?
  fi
  jq -e --arg body "$body" --argjson from_self "$from_self" '
    select((.body // "") == $body and ((.from_self // false) == $from_self))
  ' "$file" >/dev/null 2>&1
}

collect_simplex_messages_jsonl() {
  dir=$(simplex_threads_dir)
  [ -d "$dir" ] || return 0
  for file in "$dir"/*.jsonl; do
    [ -f "$file" ] || continue
    jq -c 'select(type == "object")' "$file" 2>/dev/null || true
  done
}

rewrite_simplex_message_field() {
  message_id_value=$1
  field=$2
  value=$3
  dir=$(simplex_threads_dir)
  [ -d "$dir" ] || return 1
  found=0
  for file in "$dir"/*.jsonl; do
    [ -f "$file" ] || continue
    if jq -e --arg id "$message_id_value" 'select(.id == $id)' "$file" >/dev/null 2>&1; then
      tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-simplex.XXXXXX")
      case "$field" in
        in_inbox|read)
          jq -c --arg id "$message_id_value" --arg field "$field" --argjson value "$value" \
            'if .id == $id then .[$field] = $value else . end' "$file" >"$tmp"
          ;;
        status)
          jq -c --arg id "$message_id_value" --arg value "$value" \
            'if .id == $id then .status = $value else . end' "$file" >"$tmp"
          ;;
        *)
          rm -f "$tmp"
          usage_error "unsupported SimpleX field: $field"
          ;;
      esac
      mv "$tmp" "$file"
      found=1
    fi
  done
  [ "$found" -eq 1 ]
}

collect_email_lists_json() {
  tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/stellar-email-lists.XXXXXX")
  for list in accepted quarantine spam banned archive sent outbox trash; do
    local_mail_sidecar_records "$list" "$tmp_dir/$list.index"
  done
  cat "$tmp_dir/spam.index" "$tmp_dir/banned.index" 2>/dev/null >"$tmp_dir/spam-review.index" || true
  : >"$tmp_dir/lists.jsonl"
  for list in accepted quarantine spam banned archive sent outbox trash spam-review; do
    messages=$(json_array_from_record_index "$tmp_dir/$list.index")
    jq -cn --arg id "$list" --argjson messages "$messages" '{id:$id,messages:$messages}' >>"$tmp_dir/lists.jsonl"
  done
  jq -s '.' "$tmp_dir/lists.jsonl"
  rm -rf "$tmp_dir"
}

mailbox_summary_json() {
  jq -c '
    def title($id):
      {
        accepted:"Accepted",
        quarantine:"Quarantine",
        spam:"Spam",
        banned:"Banned",
        archive:"Archive",
        sent:"Sent",
        outbox:"Outbox",
        trash:"Trash",
        "spam-review":"Spam Review"
      }[$id] // $id;
    map({
      id:.id,
      title:title(.id),
      count:((.messages // []) | length),
      unread:((.messages // []) | map(select((.read // false) | not)) | length)
    })'
}

collect_email_messages_from_lists_jsonl() {
  jq -c '.[] | .id as $list | (.messages // [])[] | . + {native_source_list:$list}'
}

overview_from_email_lists() {
  drafts=$1
  jq -c \
    --arg root "$ROOT" \
    --argjson drafts "$drafts" '
      def messages($id): first(.[] | select(.id == $id) | .messages) // [];
      def senders($id): messages($id) | map(.sender) | map(select(length > 0)) | unique | length;
      {
        ok:true,
        root:$root,
        counts:{
          new_senders:senders("quarantine"),
          new_messages:(messages("quarantine") | length),
          inbox_messages:(messages("accepted") | length),
          spam_senders:(senders("spam") + senders("banned")),
          spam_messages:((messages("spam") | length) + (messages("banned") | length)),
          archive_messages:(messages("archive") | length),
          trash_messages:(messages("trash") | length),
          drafts:($drafts | length),
          outbox:(messages("outbox") | length),
          sent:(messages("sent") | length)
        }
      }
    '
}

snapshot_action() {
  contacts_json=$(contacts_json_array)
  email_lists_json=$(collect_email_lists_json)
  mailboxes_json=$(printf '%s\n' "$email_lists_json" | mailbox_summary_json)
  drafts_json=$(mail_backend_array_field_or_empty drafts draft-list)
  events_json=$(mail_backend_array_field_or_empty events event-feed 80)
  settings_json=$(mail_backend_json_or_empty settings-controls)
  mail_backend_json_value=$(mail_backend_status_json)
  folders_ready=$(local_mail_folders_ready)
  settings_json=$(printf '%s\n' "$settings_json" |
    jq -c \
      --argjson mail_backend "$mail_backend_json_value" \
      --argjson folders_ready "$folders_ready" \
      '. + {mail_backend:$mail_backend,folders_ready:$folders_ready}')
  overview_json=$(printf '%s\n' "$email_lists_json" | overview_from_email_lists "$drafts_json")
  prefs_json=$(ui_prefs_action)
  tmp_email=$(mktemp "${TMPDIR:-/tmp}/stellar-email.XXXXXX")
  tmp_simplex=$(mktemp "${TMPDIR:-/tmp}/stellar-simplex.XXXXXX")
  printf '%s\n' "$email_lists_json" | collect_email_messages_from_lists_jsonl >"$tmp_email"
  collect_simplex_messages_jsonl >"$tmp_simplex"
  jq -n \
    --arg root "$ROOT" \
    --argjson contacts "$contacts_json" \
    --argjson overview "$overview_json" \
    --argjson mailboxes "$mailboxes_json" \
    --argjson drafts "$drafts_json" \
    --argjson events "$events_json" \
    --argjson settings "$settings_json" \
    --argjson prefs "$prefs_json" \
    --arg simplex_install_state "$(simplex_install_state)" \
    --slurpfile email_raw "$tmp_email" \
    --slurpfile simplex_raw "$tmp_simplex" '
    def clean_email:
      tostring as $raw
      | (try ($raw | capture("(?<addr>[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+)").addr) catch $raw)
      | ascii_downcase;
    def compact($s): ($s // "" | tostring | gsub("[\\r\\n\\t]+"; " ") | gsub("  +"; " ") | .[0:220]);
    def slug:
      tostring | ascii_downcase | gsub("[^a-z0-9._@-]+"; "-") | gsub("^-+"; "") | gsub("-+$"; "") | if length == 0 then "unknown" else . end;
    def name_from_email($email):
      ($email | split("@")[0] | gsub("[._-]+"; " ") | split(" ") | map(if length > 0 then (.[0:1]|ascii_upcase) + .[1:] else . end) | join(" "));
    def contact_for_email($email):
      first($contacts[]? | select((.email | ascii_downcase) == ($email | ascii_downcase))) // null;
    def contact_for_thread($thread):
      first($contacts[]? | select(.id == $thread)) // null;
    def contact_for_simplex($addr):
      first($contacts[]? | select((.simplex_address | ascii_downcase) == ($addr | ascii_downcase))) // null;
    def email_msg:
      . as $m
      | (($m.list // $m.native_source_list // "") | tostring) as $list
      | (if $list == "sent" then (($m.to // $m.sender // $m.from // "") | clean_email) else (($m.sender // $m.from // $m.to // "") | clean_email) end) as $email
      | (contact_for_email($email)) as $contact
      | (($contact.id // ("person-" + ($email | slug)))) as $thread_id
      | {
          id: ("email:" + $list + ":" + (($m.sender // "") | tostring | slug) + ":" + (($m.ulid // "") | tostring)),
          backend_kind: "email",
          transport: "email",
          lock: "open",
          thread_id: $thread_id,
          contact_name: ($contact.name // name_from_email($email)),
          contact_kind: ($contact.kind // "person"),
          email: ($contact.email // $email),
          simplex_address: ($contact.simplex_address // ""),
          favorite: ($contact.favorite // false),
          group: ($contact.group // ""),
          temporal_distance_seconds: ($contact.temporal_distance_seconds // null),
          list: $list,
          sender: (($m.sender // "") | tostring),
          ulid: (($m.ulid // "") | tostring),
          subject: (($m.subject // "") | tostring),
          body: compact($m.preview),
          preview: compact($m.preview),
          received_at: (($m.received_at // "") | tostring),
          from_self: ($list == "sent"),
          in_inbox: ($list == "accepted" or $list == "quarantine"),
          read: (($m.read // false) == true),
          starred: (($m.starred // false) == true),
          attachments: (($m.attachments // 0) | tonumber? // 0),
          status: $list,
          llm_spam_category: (($m.llm_spam_category // "") | tostring),
          llm_spam_source: (($m.llm_spam_source // "") | tostring)
        };
    def simplex_msg:
      . as $m
      | (($m.thread_id // "") | tostring | slug) as $seed_thread
      | (contact_for_thread($seed_thread)) as $thread_contact
      | (contact_for_simplex(($m.simplex_address // "") | tostring)) as $simplex_contact
      | (($thread_contact // $simplex_contact // {})) as $contact
      | (($contact.id // $seed_thread)) as $thread_id
      | {
          id: (($m.id // ("simplex:" + $thread_id + ":" + ($m.received_at // ""))) | tostring),
          remote_id: (($m.remote_id // "") | tostring),
          backend_kind: "simplex",
          transport: "simplex",
          lock: "closed",
          thread_id: $thread_id,
          contact_name: ($contact.name // ($m.contact_name // $thread_id)),
          contact_kind: ($contact.kind // ($m.kind // "person")),
          email: ($contact.email // ""),
          simplex_address: ($contact.simplex_address // ($m.simplex_address // "")),
          favorite: ($contact.favorite // false),
          group: ($contact.group // ""),
          temporal_distance_seconds: ($contact.temporal_distance_seconds // null),
          list: "simplex",
          sender: (($m.sender // "") | tostring),
          ulid: "",
          subject: (($m.subject // "") | tostring),
          body: (($m.body // "") | tostring),
          preview: compact($m.body),
          received_at: (($m.received_at // "") | tostring),
          from_self: (($m.from_self // false) == true),
          in_inbox: (($m.in_inbox // false) == true),
          read: (($m.read // false) == true),
          starred: false,
          attachments: (($m.attachments // 0) | tonumber? // 0),
          attachment: ($m.attachment // null),
          status: (($m.status // "queued") | tostring),
          llm_spam_category: (($m.llm_spam_category // "") | tostring),
          llm_spam_source: (($m.llm_spam_source // "") | tostring)
        };
    def thread_from_contact:
      {
        id: .id,
        kind: .kind,
        name: (if (.name // "") != "" then .name else (.email // .simplex_address // .id) end),
        email: (.email // ""),
          simplex_address: (.simplex_address // ""),
          favorite: (.favorite // false),
          group: (.group // ""),
          temporal_distance_seconds: (.temporal_distance_seconds // null),
          unread_count: 0,
          latest_at: "",
          messages: []
      };
    (($email_raw | map(email_msg)) + ($simplex_raw | map(select((.status // "") != "deleted") | simplex_msg))) as $messages
    | ($contacts | map(thread_from_contact)) as $contact_threads
    | ($messages | group_by(.thread_id) | map({
        id: .[0].thread_id,
        kind: (.[0].contact_kind // "person"),
        name: (.[0].contact_name // .[0].thread_id),
        email: (.[0].email // ""),
        simplex_address: (.[0].simplex_address // ""),
        favorite: (.[0].favorite // false),
        group: (.[0].group // ""),
        temporal_distance_seconds: (.[0].temporal_distance_seconds // null),
        unread_count: (map(select(.in_inbox and (.read | not))) | length),
        latest_at: (map(.received_at) | max // ""),
        messages: (sort_by(.received_at))
      })) as $message_threads
    | (($contact_threads + $message_threads)
       | group_by(.id)
       | map(reduce .[] as $item ({}; . * $item | .messages = ((.messages // []) + ($item.messages // []))))
       | map(.messages = (.messages | unique_by(.id) | sort_by(.received_at)))
       | map(.latest_at = ((.messages | map(.received_at) | max) // .latest_at // ""))
       | map(.unread_count = ((.messages | map(select(.in_inbox and (.read | not))) | length) // 0))
      ) as $threads
    | {
        ok: true,
        root: $root,
        prefs: $prefs,
        overview: $overview,
        settings: $settings,
        mailboxes: $mailboxes,
        drafts: $drafts,
        events: $events,
        simplex: {
          install_state: $simplex_install_state,
          system_root: ($root + "/.system/simplex"),
          incoming_dir: ($root + "/.stellar/simplex/incoming"),
          outbox_dir: ($root + "/.stellar/simplex/outbox")
        },
        inbox: ($messages | map(select(.in_inbox)) | sort_by(.received_at) | reverse),
        favorites: ($threads | map(select(.favorite)) | sort_by(.name)),
        individuals: ($threads | map(select(.kind != "group")) | sort_by(.name)),
        groups: ($threads | map(select(.kind == "group")) | sort_by(.name)),
        threads: ($threads | sort_by(.latest_at) | reverse),
        messages: ($messages | sort_by(.received_at))
      }'
  rm -f "$tmp_email" "$tmp_simplex"
}

snapshot_lines_action() {
  snapshot_action | jq -r '
    def clean: tostring | gsub("[\r\n\t]+"; " ") | gsub("  +"; " ");
    . as $snapshot
    | (["root", ($snapshot.root | clean)] | @tsv),
      ($snapshot.mailboxes[]? | ["mailbox", (.id | clean), (.title | clean), ((.count // 0) | tostring), ((.unread // 0) | tostring)] | @tsv),
      ($snapshot.inbox[]? | ["inbox", (.id | clean), (.contact_name | clean), (.transport | clean), (.subject | clean), (.preview | clean), (.received_at | clean)] | @tsv),
      ($snapshot.threads[]? | ["thread", (.id | clean), (.name | clean), (.kind | clean), ((.unread_count // 0) | tostring), (.latest_at | clean), (if (.simplex_address // "") != "" then "simplex" else "" end), (if (.email // "") != "" then "email" else "" end)] | @tsv),
      ($snapshot.drafts[]? | ["draft", (.ulid | clean), (.to | clean), (.subject | clean), (.updated_at | clean)] | @tsv),
      ($snapshot.events[]? | ["event", (.id | clean), ((.kind // .label // "event") | clean), (.message | clean), ((.created_at // .at // "") | clean)] | @tsv)
  '
}

send_message_action() {
  thread_id=$(safe_slug "${1-}")
  transport=${2-}
  subject=${3-}
  body_b64=${4-}
  [ -n "$thread_id" ] || usage_error "send-message requires THREAD_ID"
  case "$transport" in
    simplex|email) ;;
    *) usage_error "send-message transport must be simplex or email" ;;
  esac
  body_tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-body.XXXXXX")
  decode_b64_to_file "$body_b64" "$body_tmp" || {
    rm -f "$body_tmp"
    usage_error "invalid base64 body payload"
  }
  body=$(cat "$body_tmp")
  rm -f "$body_tmp"

  contact_file=$(native_contact_file "$thread_id")
  email=$(config_get "$contact_file" email 2>/dev/null || printf '')
  simplex=$(config_get "$contact_file" simplex_address 2>/dev/null || printf '')
  name=$(config_get "$contact_file" name 2>/dev/null || printf "$thread_id")

  if [ "$transport" = "simplex" ]; then
    [ -n "$simplex" ] || usage_error "SimpleX transport selected but no SimpleX path is bound for $name"
    result=$(append_simplex_message "$thread_id" "$body" true false "$subject")
    outbox_file="$(simplex_outbox_dir)/$(printf '%s\n' "$result" | jq -r '.id').json"
    mkdir -p "$(dirname "$outbox_file")"
    printf '%s\n' "$result" | jq \
      --arg thread_id "$thread_id" \
      --arg simplex_address "$simplex" \
      --arg subject "$subject" \
      --arg body "$body" \
      '. + {transport:"simplex",thread_id:$thread_id,simplex_address:$simplex_address,subject:$subject,body:$body,queued_at:(now|todateiso8601)}' >"$outbox_file"
    printf '%s\n' "$result" | jq --arg outbox_path "$outbox_file" '. + {transport:"simplex",outbox_path:$outbox_path}'
    return 0
  fi

  [ -n "$email" ] || usage_error "Email transport selected but no email address is bound for $name"
  # Email is intentionally explicit. The SimpleX path never falls back here.
  saved=$(mail_backend_json draft-save new "Stellar <stellar@example.org>" "$email" "" "" "$subject" "" "$body_b64") || fail "could not save Stellar draft for email transport"
  ulid=$(printf '%s\n' "$saved" | jq -r '.ulid // ""')
  [ -n "$ulid" ] || fail "Stellar draft-save did not return a draft id"
  sent=$(mail_backend_json draft-send "$ulid") || fail "could not send Stellar draft"
  jq -n --arg transport email --arg ulid "$ulid" --argjson draft "$saved" --argjson send "$sent" '{ok:true,transport:$transport,ulid:$ulid,draft:$draft,send:$send}'
}

send_simplex_payload_action() {
  thread_id=$(safe_slug "${1-}")
  subject=${2-}
  display_body=${3-}
  wire_body=${4-}
  attachments=${5-0}
  attachment_json=${6:-null}
  attachment_path=${7-}
  [ -n "$thread_id" ] || usage_error "send-message requires THREAD_ID"
  case "$attachments" in ''|*[!0123456789]*) attachments=0 ;; esac
  contact_file=$(native_contact_file "$thread_id")
  simplex=$(config_get "$contact_file" simplex_address 2>/dev/null || printf '')
  name=$(config_get "$contact_file" name 2>/dev/null || printf "$thread_id")
  [ -n "$simplex" ] || usage_error "SimpleX transport selected but no SimpleX path is bound for $name"
  result=$(append_simplex_message "$thread_id" "$display_body" true false "$subject" "" "" "$attachments" "$attachment_json")
  attachment_json=$(normalize_simplex_attachment_json "$attachment_json")
  outbox_file="$(simplex_outbox_dir)/$(printf '%s\n' "$result" | jq -r '.id').json"
  mkdir -p "$(dirname "$outbox_file")"
  printf '%s\n' "$result" | jq \
    --arg thread_id "$thread_id" \
    --arg simplex_address "$simplex" \
    --arg subject "$subject" \
    --arg body "$wire_body" \
    --arg attachment_path "$attachment_path" \
    --argjson attachment "$attachment_json" \
    '. + {transport:"simplex",thread_id:$thread_id,simplex_address:$simplex_address,subject:$subject,body:$body,queued_at:(now|todateiso8601)} + (if $attachment == null then {} else {attachment:$attachment} end) + (if $attachment_path == "" then {} else {attachment_path:$attachment_path} end)' >"$outbox_file"
  printf '%s\n' "$result" | jq --arg outbox_path "$outbox_file" '. + {transport:"simplex",outbox_path:$outbox_path}'
}

email_message_parts_from_id() {
  message_id_value=$1
  case "$message_id_value" in
    email:*)
      rest=${message_id_value#email:}
      list=${rest%%:*}
      rest=${rest#*:}
      sender_slug=${rest%%:*}
      ulid=${rest#*:}
      printf '%s\n%s\n%s\n' "$list" "$sender_slug" "$ulid"
      return 0
      ;;
  esac
  return 1
}

email_message_lookup() {
  message_id_value=$1
  parts=$(email_message_parts_from_id "$message_id_value" || true)
  list=$(printf '%s\n' "$parts" | sed -n '1p')
  ulid=$(printf '%s\n' "$parts" | sed -n '3p')
  [ -n "$list" ] && [ -n "$ulid" ] || return 1
  sidecar=$(email_sidecar_path "$message_id_value" || true)
  [ -n "$sidecar" ] || return 1
  sender=$(yaml_section_scalar_light "$sidecar" headers_cache from)
  [ -n "$sender" ] || sender=$(basename "$(dirname "$sidecar")")
  printf '%s\t%s\t%s\n' "$list" "$sender" "$ulid"
}

simplex_message_lookup() {
  message_id_value=$1
  dir=$(simplex_threads_dir)
  [ -d "$dir" ] || return 1
  for file in "$dir"/*.jsonl; do
    [ -f "$file" ] || continue
    row=$(jq -c --arg id "$message_id_value" 'select(.id == $id)' "$file" 2>/dev/null | head -n 1)
    if [ -n "$row" ]; then
      printf '%s\n' "$row"
      return 0
    fi
  done
  return 1
}

message_detail_action() {
  id=${1-}
  [ -n "$id" ] || usage_error "message-detail requires MESSAGE_ID"
  case "$id" in
    simplex:*)
      row=$(simplex_message_lookup "$id" || true)
      [ -n "$row" ] || usage_error "SimpleX message not found: $id"
      printf '%s\n' "$row" | jq --arg id "$id" '. + {ok:true,id:$id,transport:"simplex"}'
      ;;
    email:*)
      email_message_detail_json "$id"
      ;;
    *)
      usage_error "unsupported message id: $id"
      ;;
  esac
}

yaml_scalar_light() {
  file=$1
  key=$2
  awk -F: -v wanted="$key" '
    $1 == wanted {
      value = substr($0, index($0, ":") + 1)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      if (value ~ /^".*"$/ || value ~ /^'\''.*'\''$/) {
        value = substr(value, 2, length(value) - 2)
      }
      print value
      exit
    }
  ' "$file"
}

yaml_section_scalar_light() {
  file=$1
  section_name=$2
  key=$3
  awk -v wanted_section="$section_name" -v wanted_key="$key" '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    function unquote(value) {
      if (value ~ /^".*"$/ || value ~ /^'\''.*'\''$/) {
        return substr(value, 2, length(value) - 2)
      }
      return value
    }
    {
      line = $0
      sub(/\r$/, "", line)
      if (line ~ /^[[:space:]]*#/ || line ~ /^[[:space:]]*$/) {
        next
      }
      if (line !~ /^[ \t]/) {
        in_section = 0
        split(line, parts, ":")
        heading = trim(parts[1])
        if (heading == wanted_section) {
          in_section = 1
        }
        next
      }
      if (!in_section) {
        next
      }
      stripped = line
      sub(/^[ \t]+/, "", stripped)
      split(stripped, parts, ":")
      nested_key = trim(parts[1])
      if (nested_key != wanted_key) {
        next
      }
      value = substr(stripped, index(stripped, ":") + 1)
      value = trim(value)
      print unquote(value)
      exit
    }
  ' "$file"
}

yaml_bool_light() {
  value=$(yaml_scalar_light "$1" "$2")
  case $(printf '%s' "$value" | tr '[:upper:]' '[:lower:]') in
    true|yes|1|on) printf 'true\n' ;;
    *) printf 'false\n' ;;
  esac
}

yaml_attachment_count_light() {
  raw=$(yaml_scalar_light "$1" "$2")
  raw=$(printf '%s' "$raw" | tr -d '\r')
  case "$raw" in
    ''|'[]') printf '0\n' ;;
    \[*\]) printf '1\n' ;;
    *) printf '1\n' ;;
  esac
}

local_mail_sidecar_records() {
  list=$1
  index_file=$2
  list_dir="$ROOT/$list"
  [ -d "$list_dir" ] || return 0
  records_dir=$(dirname "$index_file")
  record_count=0
  for sidecar in "$list_dir"/.*.yml "$list_dir"/*.yml "$list_dir"/*/.*.yml "$list_dir"/*/*.yml; do
    [ -f "$sidecar" ] || continue
    [ ! -L "$sidecar" ] || continue
    parent_dir=$(dirname "$sidecar")
    sender_slug=
    if [ "$parent_dir" != "$list_dir" ]; then
      [ ! -L "$parent_dir" ] || continue
      sender_slug=$(basename "$parent_dir")
      [ "$sender_slug" != attachments ] || continue
    fi
    from_value=$(yaml_section_scalar_light "$sidecar" headers_cache from)
    sender_value=${sender_slug:-$from_value}
    subject_value=$(yaml_section_scalar_light "$sidecar" headers_cache subject)
    [ -n "$subject_value" ] || subject_value=$(yaml_scalar_light "$sidecar" subject)
    received_at=$(yaml_scalar_light "$sidecar" received_at)
    [ -n "$received_at" ] || received_at=$(yaml_section_scalar_light "$sidecar" headers_cache date)
    preview_value=$(email_body_from_sidecar "$sidecar" | head -c 2000 | tr '\r\n\t' '   ' | sed 's/  */ /g; s/^ //; s/ $//' | cut -c 1-220)
    record_count=$((record_count + 1))
    record_file="$records_dir/${list}-$(printf '%04d' "$record_count").json"
    jq -cn \
      --arg list "$list" \
      --arg sender "$sender_value" \
      --arg ulid "$(yaml_scalar_light "$sidecar" ulid)" \
      --arg subject "$subject_value" \
      --arg from "$from_value" \
      --arg to "$(yaml_section_scalar_light "$sidecar" headers_cache to)" \
      --arg received_at "$received_at" \
      --arg status "$(yaml_scalar_light "$sidecar" status_shadow)" \
      --arg read "$(yaml_bool_light "$sidecar" read)" \
      --arg starred "$(yaml_bool_light "$sidecar" starred)" \
      --arg pinned "$(yaml_bool_light "$sidecar" pinned)" \
      --arg attachments "$(yaml_attachment_count_light "$sidecar" attachments)" \
      --arg rspamd_score "$(yaml_scalar_light "$sidecar" rspamd_score)" \
      --arg llm_spam_probability "$(yaml_scalar_light "$sidecar" llm_spam_probability)" \
      --arg llm_spam_category "$(yaml_scalar_light "$sidecar" llm_spam_category)" \
      --arg llm_spam_reason "$(yaml_scalar_light "$sidecar" llm_spam_reason)" \
      --arg llm_spam_source "$(yaml_scalar_light "$sidecar" llm_spam_source)" \
      --arg llm_spam_model "$(yaml_scalar_light "$sidecar" llm_spam_model)" \
      --arg html_path "$(yaml_section_scalar_light "$sidecar" render html)" \
      --arg plain_path "$(yaml_section_scalar_light "$sidecar" render plain)" \
      --arg preview "$preview_value" \
      '{
        list:$list,
        sender:$sender,
        ulid:$ulid,
        subject:$subject,
        from:$from,
        to:$to,
        received_at:$received_at,
        status:($status | if . == "" then $list else . end),
        read:($read == "true"),
        starred:($starred == "true"),
        pinned:($pinned == "true"),
        attachments:($attachments | tonumber),
        rspamd_score:$rspamd_score,
        llm_spam_probability:($llm_spam_probability | if test("^[0-9]+$") then tonumber else null end),
        llm_spam_category:$llm_spam_category,
        llm_spam_reason:$llm_spam_reason,
        llm_spam_source:$llm_spam_source,
        llm_spam_model:$llm_spam_model,
        preview:$preview,
        eml_path:"",
        html_path:$html_path,
        plain_path:$plain_path
      }' >"$record_file"
    printf '%s\t%s\n' "$received_at" "$record_file" >>"$index_file"
  done
}

json_array_from_record_index() {
  index_file=$1
  [ -s "$index_file" ] || {
    printf '[]\n'
    return 0
  }
  sorted_index=$(mktemp "${TMPDIR:-/tmp}/stellar-index.XXXXXX")
  sort -r "$index_file" >"$sorted_index"
  while IFS="$(printf '\t')" read -r _ record_file; do
    cat "$record_file"
    printf '\n'
  done <"$sorted_index" | jq -s '.'
  rm -f "$sorted_index"
}

email_sidecar_path() {
  message_id_value=$1
  parts=$(email_message_parts_from_id "$message_id_value" || true)
  list=$(printf '%s\n' "$parts" | sed -n '1p')
  sender_slug=$(printf '%s\n' "$parts" | sed -n '2p')
  ulid=$(printf '%s\n' "$parts" | sed -n '3p')
  [ -n "$list" ] && [ -n "$ulid" ] || return 1
  case "$list" in
    outbox|sent)
      search_dir="$ROOT/$list"
      ;;
    *)
      search_dir="$ROOT/$list/$sender_slug"
      ;;
  esac
  [ -d "$search_dir" ] && [ ! -L "$search_dir" ] || return 1
  for sidecar in "$search_dir"/.*.yml "$search_dir"/*.yml; do
    [ -f "$sidecar" ] && [ ! -L "$sidecar" ] || continue
    candidate=$(yaml_scalar_light "$sidecar" ulid)
    if [ "$candidate" = "$ulid" ]; then
      printf '%s\n' "$sidecar"
      return 0
    fi
  done
  return 1
}

email_body_from_sidecar() {
  sidecar=$1
  plain_rel=$(yaml_section_scalar_light "$sidecar" render plain)
  [ -n "$plain_rel" ] || plain_rel=$(yaml_scalar_light "$sidecar" plain)
  case "$plain_rel" in
    ''|*/*) plain_rel= ;;
  esac
  if [ -n "$plain_rel" ]; then
    plain_path="$(dirname "$sidecar")/$plain_rel"
    case "$plain_path" in
      "$ROOT"/*)
        if [ -f "$plain_path" ] && [ ! -L "$plain_path" ]; then
          cat "$plain_path"
          return
        fi
        ;;
    esac
  fi
  base=$(basename "$sidecar")
  eml="${base#.}"
  eml="${eml%.yml}.eml"
  eml_path="$(dirname "$sidecar")/$eml"
  if [ -f "$eml_path" ]; then
    awk '
      {
        line = $0
        sub(/\r$/, "", line)
        if (body) {
          print line
        } else if (line ~ /^[[:space:]]*$/) {
          body = 1
        }
      }
    ' "$eml_path"
  fi
}

email_message_detail_json() {
  id=$1
  sidecar=$(email_sidecar_path "$id" || true)
  [ -n "$sidecar" ] || usage_error "email message not found: $id"
  parts=$(email_message_parts_from_id "$id")
  list=$(printf '%s\n' "$parts" | sed -n '1p')
  ulid=$(printf '%s\n' "$parts" | sed -n '3p')
  sender=$(yaml_section_scalar_light "$sidecar" headers_cache from)
  [ -n "$sender" ] || sender=$(basename "$(dirname "$sidecar")")
  body=$(email_body_from_sidecar "$sidecar")
  jq -n \
    --arg id "$id" \
    --arg list "$list" \
    --arg sender "$sender" \
    --arg ulid "$ulid" \
    --arg subject "$(yaml_section_scalar_light "$sidecar" headers_cache subject)" \
    --arg from "$sender" \
    --arg to "$(yaml_section_scalar_light "$sidecar" headers_cache to)" \
    --arg received_at "$(yaml_scalar_light "$sidecar" received_at)" \
    --arg body "$body" \
    '{ok:true,id:$id,transport:"email",list:$list,sender:$sender,ulid:$ulid,subject:$subject,from:$from,to:$to,received_at:$received_at,body:$body}'
}

message_trash_files_action() {
  id=${1-}
  case "$id" in
    email:*)
      sidecar=$(email_sidecar_path "$id" || true)
      [ -n "$sidecar" ] || usage_error "email message not found: $id"
      base=$(basename "$sidecar")
      eml="${base#.}"
      eml="${eml%.yml}.eml"
      eml_path="$(dirname "$sidecar")/$eml"
      html_path=$(sidecar_sibling_path "$sidecar" "$(yaml_scalar_light "$sidecar" html)")
      plain_path=$(sidecar_sibling_path "$sidecar" "$(yaml_scalar_light "$sidecar" plain)")
      paths_tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-trash-paths.XXXXXX")
      for path in "$eml_path" "$html_path" "$plain_path" "$sidecar"; do
        [ -n "$path" ] && [ -e "$path" ] && printf '%s\n' "$path" >>"$paths_tmp"
      done
      paths_json=$(jq -R -s 'split("\n") | map(select(length > 0))' "$paths_tmp")
      rm -f "$paths_tmp"
      jq -n \
        --arg id "$id" \
        --argjson paths "$paths_json" \
        '{ok:true,id:$id,paths:$paths}'
      ;;
    simplex:*)
      row=$(simplex_message_lookup "$id" || true)
      [ -n "$row" ] || usage_error "SimpleX message not found: $id"
      safe_id=$(safe_slug "$id")
      staging_dir=$(simplex_trash_staging_dir)
      mkdir -p "$staging_dir"
      staging_path="$staging_dir/$safe_id.json"
      printf '%s\n' "$row" | jq '.' >"$staging_path"
      chmod 600 "$staging_path" 2>/dev/null || true
      jq -n \
        --arg id "$id" \
        --arg path "$staging_path" \
        '{ok:true,id:$id,paths:[$path],file_backed:true,delete_after_trash:true}'
      ;;
    *)
      usage_error "unsupported message id: $id"
      ;;
  esac
}

archive_message_action() {
  id=${1-}
  case "$id" in
    simplex:*)
      rewrite_simplex_message_field "$id" in_inbox false || usage_error "message not found: $id"
      jq -n --arg id "$id" '{ok:true,id:$id,in_inbox:false}'
      ;;
    email:*)
      row=$(email_message_lookup "$id")
      [ -n "$row" ] || usage_error "email message not found: $id"
      list=$(printf '%s\n' "$row" | awk -F '\t' '{print $1}')
      sender=$(printf '%s\n' "$row" | awk -F '\t' '{print $2}')
      ulid=$(printf '%s\n' "$row" | awk -F '\t' '{print $3}')
      case "$list" in
        accepted|quarantine)
          mail_backend_json move-message "$list" archive "$sender" "$ulid"
          ;;
        *)
          jq -n --arg id "$id" --arg list "$list" '{ok:true,id:$id,list:$list,already_archived:true}'
          ;;
      esac
      ;;
    *)
      usage_error "unsupported message id: $id"
      ;;
  esac
}

mark_read_action() {
  id=${1-}
  value=${2-true}
  case "$value" in true|1|yes|on) value=true ;; *) value=false ;; esac
  case "$id" in
    simplex:*)
      rewrite_simplex_message_field "$id" read "$value" || usage_error "message not found: $id"
      jq -n --arg id "$id" --argjson read "$value" '{ok:true,id:$id,read:$read}'
      ;;
    email:*)
      row=$(email_message_lookup "$id")
      [ -n "$row" ] || usage_error "email message not found: $id"
      list=$(printf '%s\n' "$row" | awk -F '\t' '{print $1}')
      sender=$(printf '%s\n' "$row" | awk -F '\t' '{print $2}')
      ulid=$(printf '%s\n' "$row" | awk -F '\t' '{print $3}')
      mail_backend_json set-flag "$list" "$sender" "$ulid" read "$value"
      ;;
    *)
      usage_error "unsupported message id: $id"
      ;;
  esac
}

mark_seen_action() {
  [ "$#" -gt 0 ] || usage_error "mark-seen requires at least one MESSAGE_ID"
  ids_tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-mark-seen.XXXXXX")
  for id in "$@"; do
    mark_read_action "$id" true >/dev/null
    archive_message_action "$id" >/dev/null
    printf '%s\n' "$id" >>"$ids_tmp"
  done
  ids_json=$(jq -R -s 'split("\n") | map(select(length > 0))' "$ids_tmp")
  rm -f "$ids_tmp"
  jq -n --argjson ids "$ids_json" '{ok:true,ids:$ids}'
}

delete_message_action() {
  id=${1-}
  case "$id" in
    simplex:*)
      rewrite_simplex_message_field "$id" status deleted || usage_error "message not found: $id"
      rewrite_simplex_message_field "$id" in_inbox false || true
      jq -n --arg id "$id" '{ok:true,id:$id,deleted:true}'
      ;;
    email:*)
      row=$(email_message_lookup "$id")
      [ -n "$row" ] || usage_error "email message not found: $id"
      list=$(printf '%s\n' "$row" | awk -F '\t' '{print $1}')
      sender=$(printf '%s\n' "$row" | awk -F '\t' '{print $2}')
      ulid=$(printf '%s\n' "$row" | awk -F '\t' '{print $3}')
      mail_backend_json delete-message "$list" "$sender" "$ulid"
      ;;
    *)
      usage_error "unsupported message id: $id"
      ;;
  esac
}

toggle_star_action() {
  id=${1-}
  value=${2-false}
  case "$value" in true|1|yes|on) value=true ;; *) value=false ;; esac
  case "$id" in
    email:*)
      row=$(email_message_lookup "$id")
      [ -n "$row" ] || usage_error "email message not found: $id"
      list=$(printf '%s\n' "$row" | awk -F '\t' '{print $1}')
      sender=$(printf '%s\n' "$row" | awk -F '\t' '{print $2}')
      ulid=$(printf '%s\n' "$row" | awk -F '\t' '{print $3}')
      mail_backend_json set-flag "$list" "$sender" "$ulid" starred "$value"
      ;;
    *)
      jq -n --arg id "$id" --argjson value "$value" '{ok:true,id:$id,starred:$value,ignored:true}'
      ;;
  esac
}

simplex_release_api_url() {
  printf '%s\n' "${STELLAR_SIMPLEX_RELEASE_API_URL:-https://api.github.com/repos/simplex-chat/simplex-chat/releases/latest}"
}

simplex_platform_os() {
  printf '%s\n' "${STELLAR_SIMPLEX_PLATFORM_OS:-$(uname -s 2>/dev/null || printf unknown)}"
}

simplex_platform_arch() {
  printf '%s\n' "${STELLAR_SIMPLEX_PLATFORM_ARCH:-$(uname -m 2>/dev/null || printf unknown)}"
}

simplex_asset_name() {
  if [ -n "${STELLAR_SIMPLEX_ASSET_NAME-}" ]; then
    printf '%s\n' "$STELLAR_SIMPLEX_ASSET_NAME"
    return 0
  fi
  case "$(simplex_platform_os):$(simplex_platform_arch)" in
    Darwin:arm64|Darwin:aarch64)
      printf '%s\n' simplex-chat-macos-aarch64
      ;;
    Darwin:x86_64|Darwin:amd64)
      printf '%s\n' simplex-chat-macos-x86-64
      ;;
    Linux:x86_64|Linux:amd64)
      printf '%s\n' simplex-chat-ubuntu-22_04-x86_64
      ;;
    Linux:aarch64|Linux:arm64)
      printf '%s\n' simplex-chat-ubuntu-22_04-aarch64
      ;;
    *)
      return 1
      ;;
  esac
}

fetch_url_to_file() {
  url=$1
  output=$2
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$output"
    return
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -qO "$output" "$url"
    return
  fi
  fail "curl or wget is required to download SimpleX CLI"
}

sha256_file() {
  file=$1
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
    return
  fi
  sha256sum "$file" | awk '{print $1}'
}

simplex_binary_candidate() {
  candidate=${1-}
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  return 1
}

simplex_binary_resolved() {
  binary=$(config_get "$(simplex_install_file)" binary_path 2>/dev/null || printf '')
  if simplex_binary_candidate "$binary"; then
    return 0
  fi
  current=$(simplex_current_binary)
  if simplex_binary_candidate "$current"; then
    return 0
  fi
  binary=$(config_get "$(wizardry_simplex_install_file)" binary_path 2>/dev/null || printf '')
  if simplex_binary_candidate "$binary"; then
    return 0
  fi
  current=$(wizardry_simplex_current_binary)
  if simplex_binary_candidate "$current"; then
    return 0
  fi
  if simplex_binary_candidate "$(simplex_user_bin_path)"; then
    return 0
  fi
  path_binary=$(command -v simplex-chat 2>/dev/null || printf '')
  if simplex_binary_candidate "$path_binary"; then
    return 0
  fi
  for candidate in /usr/local/bin/simplex-chat /opt/homebrew/bin/simplex-chat /usr/bin/simplex-chat; do
    if simplex_binary_candidate "$candidate"; then
      return 0
    fi
  done
  return 1
}

simplex_install_file_for_binary() {
  binary=${1-}
  app_file=$(simplex_install_file)
  app_binary=$(config_get "$app_file" binary_path 2>/dev/null || printf '')
  if [ -n "$binary" ] && { [ "$binary" = "$app_binary" ] || [ "$binary" = "$(simplex_current_binary)" ]; }; then
    printf '%s\n' "$app_file"
    return 0
  fi

  wizardry_file=$(wizardry_simplex_install_file)
  wizardry_binary=$(config_get "$wizardry_file" binary_path 2>/dev/null || printf '')
  if [ -n "$binary" ] && { [ "$binary" = "$wizardry_binary" ] || [ "$binary" = "$(wizardry_simplex_current_binary)" ] || [ "$binary" = "$(simplex_user_bin_path)" ]; }; then
    printf '%s\n' "$wizardry_file"
    return 0
  fi

  if [ -f "$app_file" ]; then
    printf '%s\n' "$app_file"
    return 0
  fi
  if [ -f "$wizardry_file" ]; then
    printf '%s\n' "$wizardry_file"
    return 0
  fi
  return 1
}

simplex_validate_binary() {
  binary=$1
  install_conf=$(simplex_install_file)
  tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-simplex-validate.XXXXXX")
  if "$binary" -h >"$tmp" 2>&1; then
    config_set "$install_conf" validation_state ready
    config_set "$install_conf" last_error ''
    rm -f "$tmp"
    return 0
  fi
  error=$(head -n 4 "$tmp" | paste -sd ' ' -)
  config_set "$install_conf" validation_state error
  config_set "$install_conf" last_error "$error"
  rm -f "$tmp"
  return 1
}

simplex_install_state() {
  if ! simplex_asset_name >/dev/null 2>&1; then
    printf '%s\n' unsupported
    return 0
  fi
  if binary=$(simplex_binary_resolved 2>/dev/null); then
    install_file=$(simplex_install_file_for_binary "$binary" 2>/dev/null || printf '')
    validation=$(config_get "$install_file" validation_state 2>/dev/null || printf ready)
    if [ "$validation" = error ]; then
      printf '%s\n' broken
    else
      printf '%s\n' installed
    fi
    return 0
  fi
  if [ -f "$(simplex_install_file)" ] || [ -f "$(wizardry_simplex_install_file)" ]; then
    printf '%s\n' broken
  else
    printf '%s\n' missing
  fi
}

simplex_install_source() {
  install_file=${1-}
  if [ -z "$install_file" ]; then
    printf '%s\n' path
    return 0
  fi
  if [ "$install_file" = "$(simplex_install_file)" ]; then
    printf '%s\n' stellar
    return 0
  fi
  if [ "$install_file" = "$(wizardry_simplex_install_file)" ]; then
    printf '%s\n' wizardry
    return 0
  fi
  printf '%s\n' path
}

append_path_dir() {
  path_dir=${1-}
  [ -d "$path_dir" ] || return 0
  case ":${wizardry_path_prefix-}:" in
    *":$path_dir:"*) return 0 ;;
  esac
  if [ -n "${wizardry_path_prefix-}" ]; then
    wizardry_path_prefix="$wizardry_path_prefix:$path_dir"
  else
    wizardry_path_prefix="$path_dir"
  fi
}

wizardry_command_path() {
  wizardry_dir=${WIZARDRY_DIR:-$HOME/.wizardry}
  wizardry_path_prefix=
  append_path_dir "$wizardry_dir/spells"
  append_path_dir "$wizardry_dir/spells/.imps"
  for path_dir in "$wizardry_dir"/spells/.imps/*; do
    append_path_dir "$path_dir"
    for nested_dir in "$path_dir"/*; do
      append_path_dir "$nested_dir"
    done
  done
  for path_dir in "$wizardry_dir"/spells/.arcana/* "$wizardry_dir"/spells/*; do
    append_path_dir "$path_dir"
  done
  if [ -n "$wizardry_path_prefix" ]; then
    printf '%s:%s\n' "$wizardry_path_prefix" "${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"
  else
    printf '%s\n' "${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"
  fi
}

wizardry_simplex_installer() {
  if [ -n "${STELLAR_SIMPLEX_INSTALLER-}" ] && [ -f "$STELLAR_SIMPLEX_INSTALLER" ]; then
    printf '%s\n' "$STELLAR_SIMPLEX_INSTALLER"
    return 0
  fi
  installer=$(command -v install-simplex-chat 2>/dev/null || printf '')
  if [ -n "$installer" ] && [ -f "$installer" ]; then
    printf '%s\n' "$installer"
    return 0
  fi
  for installer in \
    "${WIZARDRY_DIR:-$HOME/.wizardry}/spells/.arcana/simplex-chat/install-simplex-chat" \
    "$HOME/.wizardry/spells/.arcana/simplex-chat/install-simplex-chat"
  do
    if [ -f "$installer" ]; then
      printf '%s\n' "$installer"
      return 0
    fi
  done
  return 1
}

simplex_profile_ready_prefix() {
  prefix=$1
  if [ -f "${prefix}_v1_chat.db" ] && [ -f "${prefix}_v1_agent.db" ]; then
    return 0
  fi
  [ -f "${prefix}_chat.db" ] && [ -f "${prefix}_agent.db" ]
}

simplex_profile_ready() {
  simplex_profile_ready_prefix "$(simplex_profile_prefix "${1:-default}")"
}

bootstrap_status_action() {
  ident=${1:-default}
  state=$(simplex_install_state)
  asset=$(simplex_asset_name 2>/dev/null || printf '')
  binary=$(simplex_binary_resolved 2>/dev/null || printf '')
  install_file=$(simplex_install_file_for_binary "$binary" 2>/dev/null || printf '')
  version=$(config_get "$install_file" version 2>/dev/null || printf '')
  error=$(config_get "$install_file" last_error 2>/dev/null || printf '')
  source=$(simplex_install_source "$install_file")
  profile_prefix=$(simplex_profile_prefix "$ident")
  if simplex_profile_ready "$ident"; then
    profile_ready=true
  else
    profile_ready=false
  fi
  hook=$(simplex_transport_hook_path "$ident" 2>/dev/null || printf '')
  if [ -n "$hook" ] && [ -x "$hook" ]; then
    hook_ready=true
  else
    hook_ready=false
  fi
  supported=true
  [ -n "$asset" ] || supported=false
  jq -n \
    --arg identity "$ident" \
    --arg install_state "$state" \
    --arg asset_name "$asset" \
    --arg version "$version" \
    --arg binary_path "$binary" \
    --arg install_source "$source" \
    --arg profile_prefix "$profile_prefix" \
    --arg hook_path "$hook" \
    --arg last_error "$error" \
    --arg platform_os "$(simplex_platform_os)" \
    --arg platform_arch "$(simplex_platform_arch)" \
    --argjson supported "$supported" \
    --argjson profile_ready "$profile_ready" \
    --argjson hook_ready "$hook_ready" \
    '{ok:true,identity:$identity,supported:$supported,install_state:$install_state,install_source:$install_source,asset_name:$asset_name,version:$version,binary_path:$binary_path,profile_prefix:$profile_prefix,profile_ready:$profile_ready,hook_path:$hook_path,hook_ready:$hook_ready,last_error:$last_error,platform_os:$platform_os,platform_arch:$platform_arch}'
}

install_simplex_cli_action() {
  require_cmd jq
  wizardry_installer=$(wizardry_simplex_installer 2>/dev/null || printf '')
  if [ -n "$wizardry_installer" ]; then
    install_log=$(mktemp "${TMPDIR:-/tmp}/stellar-simplex-wizardry-install.XXXXXX")
    if PATH=$(wizardry_command_path) sh "$wizardry_installer" >"$install_log" 2>&1; then
      binary=$(simplex_binary_resolved 2>/dev/null || printf '')
      [ -n "$binary" ] || {
        rm -f "$install_log"
        fail "Wizardry SimpleX installer completed without exposing simplex-chat"
      }
      install_file=$(simplex_install_file_for_binary "$binary" 2>/dev/null || printf '')
      version=$(config_get "$install_file" version 2>/dev/null || printf '')
      asset=$(config_get "$install_file" asset_name 2>/dev/null || simplex_asset_name 2>/dev/null || printf '')
      rm -f "$install_log"
      jq -n \
        --arg version "$version" \
        --arg asset_name "$asset" \
        --arg binary_path "$binary" \
        '{ok:true,action:"install-simplex-cli",install_source:"wizardry",version:$version,asset_name:$asset_name,binary_path:$binary_path}'
      return 0
    fi
    error=$(head -n 6 "$install_log" | paste -sd ' ' -)
    rm -f "$install_log"
    fail "Wizardry SimpleX installer failed: $error"
  fi

  asset=$(simplex_asset_name 2>/dev/null || true)
  [ -n "$asset" ] || usage_error "unsupported platform for SimpleX CLI: $(simplex_platform_os)/$(simplex_platform_arch)"
  tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/stellar-simplex-install.XXXXXX")
  release_json="$tmp_dir/release.json"
  fetch_url_to_file "$(simplex_release_api_url)" "$release_json"
  tag=$(jq -r '.tag_name // ""' "$release_json")
  [ -n "$tag" ] || {
    rm -rf "$tmp_dir"
    fail "could not determine latest SimpleX release tag"
  }
  url=$(jq -r --arg asset "$asset" '.assets[]? | select(.name == $asset) | .browser_download_url // ""' "$release_json" | head -n 1)
  digest=$(jq -r --arg asset "$asset" '.assets[]? | select(.name == $asset) | .digest // ""' "$release_json" | head -n 1)
  digest=${digest#sha256:}
  [ -n "$url" ] || {
    rm -rf "$tmp_dir"
    fail "release asset missing for $asset"
  }
  version_dir="$(simplex_releases_dir)/$tag"
  version_file="$version_dir/$asset"
  mkdir -p "$version_dir" "$(simplex_current_dir)"
  if [ ! -f "$version_file" ] || { [ -n "$digest" ] && [ "$(sha256_file "$version_file" 2>/dev/null || printf invalid)" != "$digest" ]; }; then
    download="$tmp_dir/$asset"
    fetch_url_to_file "$url" "$download"
    if [ -n "$digest" ]; then
      actual=$(sha256_file "$download")
      [ "$actual" = "$digest" ] || {
        rm -rf "$tmp_dir"
        fail "sha256 mismatch for $asset"
      }
    fi
    chmod +x "$download" 2>/dev/null || true
    mv "$download" "$version_file"
  fi
  chmod +x "$version_file" 2>/dev/null || true
  current=$(simplex_current_binary)
  rm -f "$current"
  if ! ln -s "../releases/$tag/$asset" "$current" 2>/dev/null; then
    cp "$version_file" "$current"
    chmod +x "$current" 2>/dev/null || true
  fi
  install_conf=$(simplex_install_file)
  config_set "$install_conf" version "$tag"
  config_set "$install_conf" asset_name "$asset"
  config_set "$install_conf" asset_url "$url"
  config_set "$install_conf" sha256 "$digest"
  config_set "$install_conf" platform_os "$(simplex_platform_os)"
  config_set "$install_conf" platform_arch "$(simplex_platform_arch)"
  config_set "$install_conf" binary_path "$current"
  config_set "$install_conf" installed_at "$(now_iso)"
  config_set "$install_conf" validation_state pending
  config_set "$install_conf" last_error ''
  simplex_validate_binary "$current" || true
  rm -rf "$tmp_dir"
  jq -n --arg version "$tag" --arg asset_name "$asset" --arg binary_path "$current" '{ok:true,action:"install-simplex-cli",install_source:"stellar",version:$version,asset_name:$asset_name,binary_path:$binary_path}'
}

simplex_initialize_profile() {
  binary=$1
  prefix=$2
  display_name=${3:-Stellar}
  full_name=${4:-Stellar}
  log_file=$5
  tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/stellar-simplex-init.XXXXXX")
  input="$tmp_dir/input.txt"
  display_name=$(printf '%s' "$display_name" | tr '\r' '\n' | head -n 1)
  full_name=$(printf '%s' "$full_name" | tr '\r' '\n' | head -n 1)
  printf '%s\n%s\n/quit\n' "$display_name" "$full_name" >"$input"
  if "$binary" -d "$prefix" <"$input" >"$log_file" 2>&1; then
    rm -rf "$tmp_dir"
    return 0
  fi
  if simplex_profile_ready_prefix "$prefix"; then
    rm -rf "$tmp_dir"
    return 0
  fi
  if command -v script >/dev/null 2>&1; then
    if script -q "$log_file" "$binary" -d "$prefix" <"$input" >/dev/null 2>&1; then
      rm -rf "$tmp_dir"
      return 0
    fi
    if simplex_profile_ready_prefix "$prefix"; then
      rm -rf "$tmp_dir"
      return 0
    fi
  fi
  rm -rf "$tmp_dir"
  return 1
}

provision_simplex_identity_action() {
  ident=$(safe_slug "${1:-default}")
  display_name=${2:-Stellar}
  full_name=${3:-Stellar}
  binary=$(simplex_binary_resolved 2>/dev/null || true)
  [ -n "$binary" ] || usage_error "SimpleX CLI is not installed"
  simplex_validate_binary "$binary" || true
  dir=$(simplex_identity_dir "$ident")
  prefix=$(simplex_profile_prefix "$ident")
  log_file="$dir/init.log"
  mkdir -p "$dir"
  if ! simplex_profile_ready "$ident"; then
    simplex_initialize_profile "$binary" "$prefix" "$display_name" "$full_name" "$log_file" || fail "failed to initialize SimpleX profile for $ident"
  fi
  config_set "$dir/profile.conf" display_name "$display_name"
  config_set "$dir/profile.conf" full_name "$full_name"
  config_set "$dir/profile.conf" profile_prefix "$prefix"
  config_set "$dir/profile.conf" binary_path "$binary"
  if simplex_profile_ready "$ident"; then ready=true; else ready=false; fi
  jq -n --arg identity "$ident" --arg profile_prefix "$prefix" --arg binary_path "$binary" --argjson profile_ready "$ready" '{ok:true,action:"provision-simplex-identity",identity:$identity,profile_prefix:$profile_prefix,binary_path:$binary_path,profile_ready:$profile_ready}'
}

simplex_transport_hook_path() {
  ident=$(safe_slug "${1:-default}")
  if [ -n "${STELLAR_SIMPLEX_TRANSPORT_HOOK-}" ]; then
    printf '%s\n' "$STELLAR_SIMPLEX_TRANSPORT_HOOK"
    return 0
  fi
  conf=$(simplex_profile_conf "$ident")
  configured_hook=$(config_get "$conf" transport_hook 2>/dev/null || printf '')
  if [ -n "$configured_hook" ] && [ -x "$configured_hook" ]; then
    printf '%s\n' "$configured_hook"
    return 0
  fi
  case "$configured_hook" in
    */stellar-native-secure-chat-hook.sh|*/stellar-secure-chat-hook.sh)
      if config_get "$conf" secure_chat_ssh_host >/dev/null 2>&1; then
        hook=$(secure_chat_transport_hook)
        [ -x "$hook" ] && { printf '%s\n' "$hook"; return 0; }
      fi
      ;;
    */stellar-native-simplex-local-hook.sh|*/stellar-simplex-local-hook.sh)
      hook=$(default_simplex_transport_hook)
      [ -x "$hook" ] && { printf '%s\n' "$hook"; return 0; }
      ;;
  esac
  [ -n "$configured_hook" ] && { printf '%s\n' "$configured_hook"; return 0; }
  return 1
}

set_simplex_transport_hook_action() {
  ident=$(safe_slug "${1:-default}")
  hook_path=${2-}
  case "$hook_path" in
    *"$nl"*|*"$cr"*) usage_error "SimpleX hook path must be a single line" ;;
  esac
  if [ -n "$hook_path" ] && [ ! -x "$hook_path" ]; then
    usage_error "SimpleX hook is not executable: $hook_path"
  fi
  config_set "$(simplex_profile_conf "$ident")" transport_hook "$hook_path"
  simplex_transport_status_action "$ident"
}

configure_simplex_local_transport_action() {
  ident=$(safe_slug "${1:-default}")
  hook_path=$(default_simplex_transport_hook)
  [ -x "$hook_path" ] || fail "bundled SimpleX local transport hook is not executable: $hook_path"
  config_set "$(simplex_profile_conf "$ident")" transport_hook "$hook_path"
  simplex_transport_status_action "$ident"
}

configure_secure_chat_transport_action() {
  ident=$(safe_slug "${1:-default}")
  ssh_host=${2-}
  export_command=${3-}
  send_command=${4-}
  [ -n "$ssh_host" ] || usage_error "Secure Chat SSH host is required"
  [ -n "$export_command" ] || usage_error "Secure Chat export command is required"
  [ -n "$send_command" ] || usage_error "Secure Chat send command is required"
  case "$ssh_host$export_command$send_command" in
    *"$nl"*|*"$cr"*) usage_error "Secure Chat transport settings must be single-line values" ;;
  esac
  case "$export_command" in /*) ;; *) usage_error "Secure Chat export command must be absolute" ;; esac
  case "$send_command" in /*) ;; *) usage_error "Secure Chat send command must be absolute" ;; esac
  hook_path=$(secure_chat_transport_hook)
  [ -x "$hook_path" ] || fail "bundled Secure Chat transport hook is not executable: $hook_path"
  conf=$(simplex_profile_conf "$ident")
  config_set "$conf" transport_hook "$hook_path"
  config_set "$conf" secure_chat_ssh_host "$ssh_host"
  config_set "$conf" secure_chat_export_command "$export_command"
  config_set "$conf" secure_chat_send_command "$send_command"
  simplex_transport_status_action "$ident" | jq \
    --arg ssh_host "$ssh_host" \
    --arg export_command "$export_command" \
    --arg send_command "$send_command" \
    '. + {secure_chat_ssh_host:$ssh_host,secure_chat_export_command:$export_command,secure_chat_send_command:$send_command}'
}

simplex_transport_status_action() {
  ident=$(safe_slug "${1:-default}")
  hook=$(simplex_transport_hook_path "$ident" 2>/dev/null || printf '')
  if [ -n "$hook" ] && [ -x "$hook" ]; then
    hook_ready=true
  else
    hook_ready=false
  fi
  jq -n \
    --arg identity "$ident" \
    --arg hook_path "$hook" \
    --arg incoming_dir "$(simplex_incoming_dir)" \
    --arg outbox_dir "$(simplex_outbox_dir)" \
    --argjson hook_ready "$hook_ready" \
    '{ok:true,identity:$identity,hook_path:$hook_path,hook_ready:$hook_ready,incoming_dir:$incoming_dir,outbox_dir:$outbox_dir}'
}

run_simplex_poll_hook() {
  ident=$(safe_slug "${1:-default}")
  hook=$(simplex_transport_hook_path "$ident" 2>/dev/null || printf '')
  [ -n "$hook" ] && [ -x "$hook" ] || return 0
  "$hook" poll "$ident" "$ROOT" "$(simplex_incoming_dir)"
}

process_simplex_outbox() {
  ident=$(safe_slug "${1:-default}")
  hook=$(simplex_transport_hook_path "$ident" 2>/dev/null || printf '')
  processed_root="$(simplex_processed_dir)/outbox"
  processing_root="$(simplex_processed_dir)/outbox-processing"
  mkdir -p "$processed_root" "$processing_root"
  sent=0
  waiting=0
  failed=0
  for simplex_outbox_file in "$(simplex_outbox_dir)"/*.json; do
    [ -f "$simplex_outbox_file" ] || continue
    outbox_basename=$(basename "$simplex_outbox_file")
    processing_file="$processing_root/$outbox_basename"
    if ! mv "$simplex_outbox_file" "$processing_file" 2>/dev/null; then
      continue
    fi
    id=$(jq -r '.id // ""' "$processing_file" 2>/dev/null | head -n 1)
    [ -n "$id" ] || {
      mv "$processing_file" "$simplex_outbox_file" 2>/dev/null || true
      failed=$((failed + 1))
      continue
    }
    if [ -z "$hook" ] || [ ! -x "$hook" ]; then
      rewrite_simplex_message_field "$id" status waiting-adapter 2>/dev/null || true
      mv "$processing_file" "$simplex_outbox_file" 2>/dev/null || true
      waiting=$((waiting + 1))
      continue
    fi
    if "$hook" send "$ident" "$ROOT" "$processing_file" >"$processed_root/last-send.log" 2>"$processed_root/last-send-error.log"; then
      rewrite_simplex_message_field "$id" status sent 2>/dev/null || true
      mv "$processing_file" "$processed_root/$outbox_basename.sent.$(date -u +%Y%m%dT%H%M%SZ)" 2>/dev/null || rm -f "$processing_file"
      sent=$((sent + 1))
    else
      rewrite_simplex_message_field "$id" status error 2>/dev/null || true
      mv "$processing_file" "$simplex_outbox_file" 2>/dev/null || true
      failed=$((failed + 1))
    fi
  done
  jq -n --argjson sent "$sent" --argjson waiting "$waiting" --argjson failed "$failed" '{sent:$sent,waiting:$waiting,failed:$failed}'
}

tick_simplex_action() {
  ensure_roots
  ident=${1:-default}
  poll_error=
  outbox_json=$(process_simplex_outbox "$ident")
  if ! run_simplex_poll_hook "$ident" >"$(simplex_processed_dir)/last-poll.log" 2>"$(simplex_processed_dir)/last-poll-error.log"; then
    poll_error=$(cat "$(simplex_processed_dir)/last-poll-error.log" 2>/dev/null | head -n 3 | paste -sd ' ' -)
  fi
  imported=0
  for simplex_incoming_file in "$(simplex_incoming_dir)"/*.json "$ROOT/.transport/incoming"/*.json; do
    [ -f "$simplex_incoming_file" ] || continue
    thread_id=$(jq -r '.thread_id // .contact_key // .contact // "unknown"' "$simplex_incoming_file" 2>/dev/null | head -n 1)
    body=$(jq -r '.body // .text // .message // ""' "$simplex_incoming_file" 2>/dev/null | head -n 1)
    subject=$(jq -r '.subject // ""' "$simplex_incoming_file" 2>/dev/null | head -n 1)
    contact_name=$(jq -r '.contact_name // .name // .display_name // ""' "$simplex_incoming_file" 2>/dev/null | head -n 1)
    from_self=$(jq -r '.from_self // false' "$simplex_incoming_file" 2>/dev/null | head -n 1)
    in_inbox=$(jq -r '.in_inbox // true' "$simplex_incoming_file" 2>/dev/null | head -n 1)
    simplex_address=$(jq -r '.simplex_address // ""' "$simplex_incoming_file" 2>/dev/null | head -n 1)
    remote_id=$(jq -r '.remote_id // ""' "$simplex_incoming_file" 2>/dev/null | head -n 1)
    received_at=$(jq -r '.received_at // ""' "$simplex_incoming_file" 2>/dev/null | head -n 1)
    attachments=$(jq -r 'if (.attachments // 0) != 0 then (.attachments // 0) elif (.attachment // null) != null then 1 else 0 end' "$simplex_incoming_file" 2>/dev/null | head -n 1)
    attachment_json=$(jq -c '.attachment // null' "$simplex_incoming_file" 2>/dev/null | head -n 1)
    [ -n "$attachment_json" ] || attachment_json=null
    case "$attachments" in ''|*[!0123456789]*) attachments=0 ;; esac
    [ -n "$body" ] || continue
    [ -n "$contact_name" ] || contact_name=$thread_id
    if [ -n "$simplex_address" ]; then
      contact_file=$(native_contact_file "$thread_id")
      current_name=
      current_simplex=
      current_favorite=no
      if [ -f "$contact_file" ]; then
        current_name=$(config_get "$contact_file" name 2>/dev/null || printf '')
        current_simplex=$(config_get "$contact_file" simplex_address 2>/dev/null || printf '')
        current_favorite=$(config_get "$contact_file" favorite 2>/dev/null || printf no)
      fi
      case "$current_name" in
        ''|"$thread_id"|"$simplex_address"|npub1*|secure-chat-contact-*)
          save_contact_binding "$thread_id" "$contact_name" person "" "$simplex_address" "$current_favorite" >/dev/null
          ;;
        *)
          if [ "$current_simplex" != "$simplex_address" ]; then
            save_contact_binding "$thread_id" "$current_name" person "" "$simplex_address" "$current_favorite" >/dev/null
          fi
          ;;
      esac
      legacy_thread_id=$(legacy_secure_chat_thread_for_address "$simplex_address")
      if [ -n "$legacy_thread_id" ] && [ "$legacy_thread_id" != "$thread_id" ]; then
        migrate_simplex_thread_messages "$legacy_thread_id" "$thread_id"
      fi
    fi
    if simplex_duplicate_message_exists "$thread_id" "$body" "$from_self" "$remote_id"; then
      mkdir -p "$(simplex_processed_dir)"
      mv "$simplex_incoming_file" "$(simplex_processed_dir)/$(basename "$simplex_incoming_file").duplicate.$(date -u +%Y%m%dT%H%M%SZ)" 2>/dev/null || rm -f "$simplex_incoming_file"
      continue
    fi
    append_simplex_message "$thread_id" "$body" "$from_self" "$in_inbox" "$subject" "$received_at" "$remote_id" "$attachments" "$attachment_json" >/dev/null
    mkdir -p "$(simplex_processed_dir)"
    mv "$simplex_incoming_file" "$(simplex_processed_dir)/$(basename "$simplex_incoming_file").$(date -u +%Y%m%dT%H%M%SZ)" 2>/dev/null || rm -f "$simplex_incoming_file"
    imported=$((imported + 1))
  done
  jq -n \
    --arg identity "$ident" \
    --arg poll_error "$poll_error" \
    --argjson imported "$imported" \
    --argjson outbox "$outbox_json" \
    '{ok:true,action:"tick-simplex",identity:$identity,imported:$imported,outbox:$outbox,poll_error:$poll_error}'
}

[ -n "$action" ] || usage_error "ACTION is required"
require_cmd jq

case "$action" in
  doctor)
    jq -n \
      --arg root "$ROOT" \
      --arg repo_root "$repo_dir" \
      --argjson mail_backend "$(mail_backend_status_json)" \
      --arg simplex_state "$(simplex_install_state)" \
      '{ok:true,root:$root,repo_root:$repo_root,mail_backend:$mail_backend,simplex_install_state:$simplex_state}'
    ;;
  prepare)
    ensure_roots
    jq -n --arg root "$ROOT" --arg metadata_root "$(metadata_root)" '{ok:true,root:$root,metadata_root:$metadata_root}'
    ;;
  get-paths)
    jq -n \
      --arg root "$ROOT" \
      --arg metadata_root "$(metadata_root)" \
      --arg native_contacts "$(native_contacts_dir)" \
      --arg simplex_threads "$(simplex_threads_dir)" \
      --arg simplex_incoming "$(simplex_incoming_dir)" \
      --arg simplex_outbox "$(simplex_outbox_dir)" \
      --arg simplex_system "$(simplex_system_root)" \
      '{ok:true,root:$root,metadata_root:$metadata_root,native_contacts:$native_contacts,simplex_threads:$simplex_threads,simplex_incoming:$simplex_incoming,simplex_outbox:$simplex_outbox,simplex_system:$simplex_system}'
    ;;
  get-ui-prefs)
    ui_prefs_action
    ;;
  set-ui-pref)
    set_ui_pref_action "${1-}" "${2-}"
    ;;
  snapshot)
    snapshot_action
    ;;
  snapshot-lines)
    snapshot_lines_action
    ;;
  settings-setup-folders)
    ensure_roots
    jq -n --arg root "$ROOT" '{ok:true,root:$root,folders_ready:true}'
    ;;
  health|overview|settings-controls|settings-browse-root|settings-set-test-recipient|settings-verify-domain|settings-set-domain|settings-ssl-prereq-status|settings-ssl-wizard-status|settings-setup-ssl|settings-set-daemon-installed|settings-set-daemon-running|settings-set-daemon-startup|settings-remote-set-target|settings-remote-set-auth|settings-remote-deploy|settings-remote-verify|settings-remote-send-test|settings-remote-sync|settings-llm-controls|settings-llm-set|settings-llm-install-ollama|settings-llm-set-daemon|settings-llm-install-model|settings-llm-uninstall-model|spam-classify|event-feed|contact-get|contact-save|list-senders|list-archive-bundle|list-inbox-bundle-fast|list-messages-fast|list-messages|set-flag|move-message|move-sender|draft-list|draft-get|draft-save|draft-delete|draft-send)
    mail_backend_json "$action" "$@"
    ;;
  bind-contact)
    ensure_roots
    save_contact_binding "${1-}" "${2-}" "${3-person}" "${4-}" "${5-}" "${6-no}" | jq '{ok:true,contact:.}'
    ;;
  set-temporal-distance)
    ensure_roots
    contact_json=$(set_temporal_distance_action "${1-}" "${2-auto}")
    printf '%s\n' "$contact_json" | jq '{ok:true,contact:.}'
    ;;
  import-simplex)
    ensure_roots
    thread_id=${1-}
    body_b64=${2-}
    from_self=${3-false}
    in_inbox=${4-true}
    subject=${5-}
    body_tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-simplex-body.XXXXXX")
    decode_b64_to_file "$body_b64" "$body_tmp" || {
      rm -f "$body_tmp"
      usage_error "invalid base64 body payload"
    }
    body=$(cat "$body_tmp")
    rm -f "$body_tmp"
    append_simplex_message "$thread_id" "$body" "$from_self" "$in_inbox" "$subject"
    ;;
  mark-inbox)
    id=${1-}
    mode=${2-}
    case "$id" in
      simplex:*)
        case "$mode" in in|true|1|yes|on) value=true ;; out|false|0|no|off) value=false ;; *) usage_error "mark-inbox requires in|out" ;; esac
        rewrite_simplex_message_field "$id" in_inbox "$value" || usage_error "message not found: $id"
        jq -n --arg id "$id" --argjson in_inbox "$value" '{ok:true,id:$id,in_inbox:$in_inbox}'
        ;;
      email:*)
        case "$mode" in
          in)
            jq -n --arg id "$id" '{ok:true,id:$id,note:"Email inbox state is represented by Stellar list membership."}'
            ;;
          out)
            archive_message_action "$id"
            ;;
          *)
            usage_error "mark-inbox requires in|out"
            ;;
        esac
        ;;
      *)
        usage_error "unsupported message id: $id"
        ;;
    esac
    ;;
  mark-read)
    mark_read_action "${1-}" "${2-true}"
    ;;
  mark-seen)
    mark_seen_action "$@"
    ;;
  send-message)
    ensure_roots
    send_message_action "${1-}" "${2-}" "${3-}" "${4-}"
    ;;
  send-attachment)
    ensure_roots
    thread_id=${1-}
    transport=${2-}
    subject=${3-}
    body_b64=${4-}
    attachment_path=${5-}
    [ "$transport" = "simplex" ] || usage_error "send-attachment currently supports simplex"
    body_tmp=$(mktemp "${TMPDIR:-/tmp}/stellar-attachment-body.XXXXXX")
    decode_b64_to_file "$body_b64" "$body_tmp" || {
      rm -f "$body_tmp"
      usage_error "invalid base64 body payload"
    }
    attachment_body=$(cat "$body_tmp")
    rm -f "$body_tmp"
    attachment_json=$(simplex_web_attachment_json "$attachment_path")
    if [ -n "$attachment_body" ]; then
      display_body="$attachment_body
Attachment: ${attachment_path##*/}"
    else
      display_body="Attachment: ${attachment_path##*/}"
    fi
    send_simplex_payload_action "$thread_id" "$subject" "$display_body" "$attachment_body" 1 "$attachment_json" "$attachment_path"
    ;;
  message-detail)
    message_detail_action "${1-}"
    ;;
  archive-message)
    archive_message_action "${1-}"
    ;;
  message-trash-files)
    message_trash_files_action "${1-}"
    ;;
  delete-message)
    if [ "$#" -ge 3 ]; then
      mail_backend_json delete-message "$@"
    else
      delete_message_action "${1-}"
    fi
    ;;
  get-message)
    if [ "$#" -ge 3 ]; then
      mail_backend_json get-message "$@"
    else
      message_detail_action "${1-}"
    fi
    ;;
  toggle-star)
    toggle_star_action "${1-}" "${2-false}"
    ;;
  bootstrap-status)
    bootstrap_status_action "${1:-default}"
    ;;
  install-simplex-cli)
    ensure_roots
    install_simplex_cli_action
    ;;
  provision-simplex-identity)
    ensure_roots
    provision_simplex_identity_action "${1:-default}" "${2:-Stellar}" "${3:-Stellar}"
    ;;
  configure-simplex-local-transport)
    ensure_roots
    configure_simplex_local_transport_action "${1:-default}"
    ;;
  configure-secure-chat-transport)
    ensure_roots
    configure_secure_chat_transport_action "${1:-default}" "${2-}" "${3-}" "${4-}"
    ;;
  set-simplex-transport-hook)
    ensure_roots
    set_simplex_transport_hook_action "${1:-default}" "${2-}"
    ;;
  simplex-transport-status)
    ensure_roots
    simplex_transport_status_action "${1:-default}"
    ;;
  tick-simplex|tick-transport)
    tick_simplex_action "${1:-default}"
    ;;
  *)
    usage_error "unsupported action: $action"
    ;;
esac
