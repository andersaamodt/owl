#!/bin/sh

# Owl desktop bridge adapter for Wizardry host RPC.
# All commands emit JSON on stdout and non-zero exit with human-readable stderr on failure.

set -eu

SSH_CONNECT_TIMEOUT_SECS=8
REMOTE_VERIFY_TCP_TIMEOUT_SECS=2
SMTP_SEND_TIMEOUT_SECS=5
SEND_TEST_SYNC_RETRY_ATTEMPTS=2
SEND_TEST_SYNC_RETRY_DELAY_SECS=1
LLM_SPAM_TIMEOUT_SECS=14
SSH_KEYCHAIN_OPTIONS=''
if [ "$(uname -s 2>/dev/null || printf unknown)" = "Darwin" ] &&
  command -v ssh >/dev/null 2>&1 &&
  ssh -o UseKeychain=yes -G localhost >/dev/null 2>&1; then
  SSH_KEYCHAIN_OPTIONS='-o AddKeysToAgent=yes -o UseKeychain=yes'
fi

usage() {
  cat <<'USAGE'
Usage: owl-desktop-backend.sh ACTION [ROOT] [ARGS...]

Actions:
  health ROOT
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
  address-publish ROOT [HOST] [SSH_KEY_PATH] [SSH_KEY_PASSWORD] [SSH_PORT]
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
  contact-get ROOT IDENTITY [FALLBACK_LABEL] [CONTACT_KEY]
  contact-save ROOT IDENTITY CONTACT_KEY NAME EMAIL PHONE ADDRESS URL NOTE
  list-senders ROOT LIST
  list-archive-bundle ROOT
  list-inbox-bundle-fast ROOT
  list-messages-fast ROOT LIST [SENDER]
  list-messages ROOT LIST [SENDER]
  get-message ROOT LIST SENDER ULID
  set-flag ROOT LIST SENDER ULID FIELD VALUE
  move-message ROOT FROM TO SENDER ULID
  move-sender ROOT FROM TO SENDER
  delete-message ROOT LIST SENDER ULID
  draft-list ROOT
  draft-get ROOT ULID
  draft-save ROOT ULID FROM TO_CSV CC_CSV BCC_CSV SUBJECT REPLY_TO BODY_B64
  draft-delete ROOT ULID
  draft-send ROOT ULID

LIST values:
  quarantine | accepted | spam | banned | archive | trash | outbox | sent | spam-review

FIELD values for set-flag:
  read | starred | pinned
USAGE
}

if [ "${1-}" = "--help" ] || [ "${1-}" = "-h" ] || [ "${1-}" = "help" ]; then
  usage
  exit 0
fi

action=${1-}
root_arg=${2-}

if [ -z "$action" ]; then
  usage >&2
  exit 2
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
. "$REPO_ROOT/scripts/owl-paths.sh"

require_cmd() {
  tool=$1
  command -v "$tool" >/dev/null 2>&1 || {
    printf '%s\n' "owl-desktop-backend: required tool not found: $tool" >&2
    exit 1
  }
}

safe_model_name() {
  case "${1-}" in
    *[!A-Za-z0-9_./:-]*|'')
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

wizardry_root_lines() {
  if [ -n "${WIZARDRY_DIR-}" ]; then
    printf '%s\n' "$WIZARDRY_DIR"
  fi
  printf '%s\n' "$HOME/.wizardry"
  if [ -n "${USER_HOME-}" ]; then
    printf '%s\n' "$USER_HOME/.wizardry"
  fi
  if [ -n "${USER-}" ]; then
    printf '/Users/%s/.wizardry\n' "$USER"
    printf '/home/%s/.wizardry\n' "$USER"
  fi
  if [ -n "${LOGNAME-}" ]; then
    printf '/Users/%s/.wizardry\n' "$LOGNAME"
    printf '/home/%s/.wizardry\n' "$LOGNAME"
  fi
}

find_ai_dev_script() {
  script_name=$1
  roots=$(wizardry_root_lines | awk '!seen[$0]++')
  for root in $roots; do
    [ -d "$root/spells/.arcana/ai-dev" ] || continue
    candidate="$root/spells/.arcana/ai-dev/$script_name"
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

run_ai_dev_script() {
  script_name=$1
  shift
  script_path=$(find_ai_dev_script "$script_name" || true)
  if [ -n "$script_path" ] && [ -x "$script_path" ]; then
    "$script_path" "$@"
    return
  fi
  if command -v "$script_name" >/dev/null 2>&1; then
    "$script_name" "$@"
    return
  fi
  printf 'owl-desktop-backend: ai-dev script unavailable: %s\n' "$script_name" >&2
  return 127
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
    return
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return
  fi
  printf '%s\n' "owl-desktop-backend: root privileges required and sudo is not available" >&2
  return 1
}

detect_user_home_dir() {
  env_home=${HOME-}
  os_name=$(uname -s 2>/dev/null || printf '')

  if [ "$os_name" = "Darwin" ] && command -v dscl >/dev/null 2>&1; then
    username=$(id -un 2>/dev/null || printf '')
    if [ -n "$username" ]; then
      dscl_home=$(dscl . -read "/Users/$username" NFSHomeDirectory 2>/dev/null | awk '{print $2}' | head -n 1)
      if [ -n "$dscl_home" ] && [ -d "$dscl_home" ]; then
        printf '%s\n' "$dscl_home"
        return 0
      fi
    fi
  fi

  if [ -n "$env_home" ] && [ -d "$env_home" ]; then
    printf '%s\n' "$env_home"
    return 0
  fi

  if command -v getent >/dev/null 2>&1; then
    username=$(id -un 2>/dev/null || printf '')
    if [ -n "$username" ]; then
      passwd_home=$(getent passwd "$username" 2>/dev/null | awk -F: '{print $6}' | head -n 1)
      if [ -n "$passwd_home" ] && [ -d "$passwd_home" ]; then
        printf '%s\n' "$passwd_home"
        return 0
      fi
    fi
  fi

  printf '%s\n' "${env_home:-/tmp}"
}

USER_HOME=$(detect_user_home_dir)

normalize_path() {
  input=${1-}
  if [ -z "$input" ]; then
    printf '%s\n' "$USER_HOME/mail"
    return 0
  fi
  case "$input" in
    "~")
      printf '%s\n' "$USER_HOME"
      ;;
    "~/"*)
      printf '%s\n' "$USER_HOME/${input#\~/}"
      ;;
    /*)
      printf '%s\n' "$input"
      ;;
    *)
      printf '%s\n' "$(pwd -P)/$input"
      ;;
  esac
}

pick_directory_path() {
  default_dir=${1-}
  prompt=${2-Choose folder}
  os_name=$(uname -s 2>/dev/null || printf '')

  if [ -z "$default_dir" ] || [ ! -d "$default_dir" ]; then
    default_dir=$USER_HOME
  fi

  if [ "$os_name" = "Darwin" ] && command -v osascript >/dev/null 2>&1; then
    osascript - "$default_dir" "$prompt" <<'OSA' 2>/dev/null || true
on run argv
  set defaultDir to POSIX file (item 1 of argv)
  set dialogPrompt to item 2 of argv
  try
    set chosenFolder to choose folder with prompt dialogPrompt default location defaultDir
    return POSIX path of chosenFolder
  on error number -128
    return ""
  end try
end run
OSA
    return 0
  fi

  if [ "$os_name" = "Linux" ]; then
    if command -v zenity >/dev/null 2>&1; then
      zenity --file-selection --directory --filename="$default_dir/" --title="$prompt" 2>/dev/null || true
      return 0
    fi
    if command -v kdialog >/dev/null 2>&1; then
      kdialog --getexistingdirectory "$default_dir" --title "$prompt" 2>/dev/null || true
      return 0
    fi
  fi

  printf '%s\n' "owl-desktop-backend: no folder picker is available on this OS" >&2
  exit 1
}

ROOT=$(normalize_path "$root_arg")
ENV_PATH="$ROOT/.env"

OWL_MODE=none
OWL_BIN_PATH=''

local_debug_owl=$(owl_compiled_binary_path owl debug)
if [ -n "${OWL_BIN-}" ] && [ -x "$OWL_BIN" ]; then
  OWL_MODE=bin
  OWL_BIN_PATH=$OWL_BIN
elif [ -x "$local_debug_owl" ]; then
  OWL_MODE=bin
  OWL_BIN_PATH=$local_debug_owl
elif command -v owl >/dev/null 2>&1; then
  OWL_MODE=bin
  OWL_BIN_PATH=$(command -v owl)
elif command -v cargo >/dev/null 2>&1; then
  OWL_MODE=cargo
fi

run_owl() {
  if [ "$OWL_MODE" = "bin" ]; then
    "$OWL_BIN_PATH" --env "$ENV_PATH" "$@"
    return
  fi
  if [ "$OWL_MODE" = "cargo" ]; then
    (
      cd "$REPO_ROOT"
      sh "$REPO_ROOT/scripts/owl-cargo" run --quiet --bin owl -- --env "$ENV_PATH" "$@"
    )
    return
  fi
  printf '%s\n' "owl-desktop-backend: owl binary not found (set OWL_BIN or build/install owl first)" >&2
  exit 1
}

ensure_mail_dirs() {
  mkdir -p "$ROOT"
  mkdir -p "$ROOT/quarantine" "$ROOT/accepted" "$ROOT/spam" "$ROOT/banned"
  mkdir -p "$ROOT/archive" "$ROOT/trash" "$ROOT/drafts" "$ROOT/outbox" "$ROOT/sent" "$ROOT/logs"
  mkdir -p "$ROOT/accepted/attachments" "$ROOT/spam/attachments" "$ROOT/banned/attachments"
  mkdir -p "$ROOT/archive/attachments" "$ROOT/trash/attachments"
}

folders_ready() {
  for dir in \
    "$ROOT/quarantine" \
    "$ROOT/accepted" \
    "$ROOT/spam" \
    "$ROOT/banned" \
    "$ROOT/archive" \
    "$ROOT/trash" \
    "$ROOT/drafts" \
    "$ROOT/outbox" \
    "$ROOT/sent" \
    "$ROOT/logs" \
    "$ROOT/accepted/attachments" \
    "$ROOT/spam/attachments" \
    "$ROOT/banned/attachments" \
    "$ROOT/archive/attachments" \
    "$ROOT/trash/attachments"
  do
    [ -d "$dir" ] || return 1
  done
  return 0
}

resolve_test_recipient_state_file() {
  printf '%s\n' "${XDG_STATE_HOME:-$USER_HOME/.local/state}/stellar/mail-engine/test-recipient"
}

load_test_recipient_value() {
  state_file=$(resolve_test_recipient_state_file)
  if [ -r "$state_file" ]; then
    head -n 1 "$state_file" | tr -d '\r'
  else
    printf '%s' ''
  fi
}

save_test_recipient_value() {
  next=$(printf '%s' "${1-}" | tr -d '\r\n')
  state_file=$(resolve_test_recipient_state_file)
  if [ -z "$next" ]; then
    rm -f "$state_file"
    return
  fi
  mkdir -p "$(dirname "$state_file")"
  printf '%s\n' "$next" >"$state_file"
}

resolve_remote_state_file() {
  printf '%s\n' "${XDG_STATE_HOME:-$USER_HOME/.local/state}/stellar/mail-engine/remote.json"
}

default_remote_state_json() {
  jq -cn '{
    host: "",
    key_path: "",
    port: "",
    ssh_key_has_password: "0",
    ssh_key_save_choice: "0",
    last_deploy_at: "",
    last_deploy_status: "idle",
    last_deploy_message: "",
    last_verify_at: "",
    last_verify_status: "idle",
    last_verify_message: "",
    last_test_at: "",
    last_test_status: "idle",
    last_test_message: "",
    last_sync_at: "",
    last_sync_status: "idle",
    last_sync_message: ""
  }'
}

load_remote_state_json() {
  state_file=$(resolve_remote_state_file)
  if [ ! -r "$state_file" ]; then
    default_remote_state_json
    return 0
  fi
  if remote_json=$(jq -c '{
      host: (.host // ""),
      key_path: (.key_path // ""),
      port: (.port // ""),
      ssh_key_has_password: (.ssh_key_has_password // "0"),
      ssh_key_save_choice: (.ssh_key_save_choice // "0"),
      last_deploy_at: (.last_deploy_at // ""),
      last_deploy_status: (.last_deploy_status // "idle"),
      last_deploy_message: (.last_deploy_message // ""),
      last_verify_at: (.last_verify_at // ""),
      last_verify_status: (.last_verify_status // "idle"),
      last_verify_message: (.last_verify_message // ""),
      last_test_at: (.last_test_at // ""),
      last_test_status: (.last_test_status // "idle"),
      last_test_message: (.last_test_message // ""),
      last_sync_at: (.last_sync_at // ""),
      last_sync_status: (.last_sync_status // "idle"),
      last_sync_message: (.last_sync_message // "")
    }' "$state_file" 2>/dev/null); then
    printf '%s\n' "$remote_json"
    return 0
  fi
  default_remote_state_json
}

save_remote_state_json() {
  next_json=${1-}
  state_file=$(resolve_remote_state_file)
  mkdir -p "$(dirname "$state_file")"
  printf '%s\n' "$next_json" >"$state_file"
}

run_user_security() {
  if [ -n "$USER_HOME" ] && [ -d "$USER_HOME" ]; then
    HOME="$USER_HOME" security "$@"
    return $?
  fi
  security "$@"
}

keychain_available_for_user() {
  if [ "$(uname -s 2>/dev/null || printf '')" != "Darwin" ]; then
    return 1
  fi
  command -v security >/dev/null 2>&1 || return 1
  run_user_security default-keychain >/dev/null 2>&1 || return 1
  return 0
}

detect_remote_secret_backend() {
  if keychain_available_for_user; then
    printf '%s\n' keychain
    return 0
  fi
  printf '%s\n' none
}

remote_secret_device_label() {
  if [ "$(uname -s 2>/dev/null || printf '')" = "Darwin" ]; then
    printf '%s\n' Mac
    return 0
  fi
  printf '%s\n' computer
}

remote_secret_service() {
  printf '%s\n' "owl.remote_ssh_key_password"
}

remote_secret_account_id() {
  key_path=$1
  if [ -z "$key_path" ]; then
    printf '%s' ''
    return 0
  fi

  if command -v ssh-keygen >/dev/null 2>&1 && [ -r "$key_path" ]; then
    key_fingerprint=$(ssh-keygen -lf "$key_path" 2>/dev/null | awk '{print $2}' | head -n 1 | tr -d '\r\n')
    if [ -n "$key_fingerprint" ]; then
      printf 'keyfp:%s' "$key_fingerprint"
      return 0
    fi
  fi

  printf 'keypath:%s' "$key_path"
}

remote_secret_read_by_account() {
  account_key=$1
  backend=$2
  if [ -z "$account_key" ]; then
    printf '%s' ''
    return 0
  fi
  case "$backend" in
    keychain)
      run_user_security find-generic-password -a "$account_key" -s "$(remote_secret_service)" -w 2>/dev/null || true
      ;;
    *)
      printf '%s' ''
      ;;
  esac
}

remote_secret_read() {
  key_path=$1
  backend=$2
  if [ -z "$key_path" ]; then
    printf '%s' ''
    return 0
  fi
  account_key=$(remote_secret_account_id "$key_path")
  secret_value=$(remote_secret_read_by_account "$account_key" "$backend")
  if [ -n "$secret_value" ]; then
    printf '%s' "$secret_value"
    return 0
  fi
  case "$backend" in
    keychain)
      # Backward-compat for entries stored by literal key path.
      run_user_security find-generic-password -a "$key_path" -s "$(remote_secret_service)" -w 2>/dev/null || true
      ;;
    *)
      printf '%s' ''
      ;;
  esac
}

remote_secret_exists() {
  key_path=$1
  backend=$2
  value=$(remote_secret_read "$key_path" "$backend")
  [ -n "$value" ]
}

remote_secret_store() {
  key_path=$1
  secret_value=$2
  backend=$3
  if [ -z "$key_path" ] || [ -z "$secret_value" ]; then
    return 1
  fi
  account_key=$(remote_secret_account_id "$key_path")
  if [ -z "$account_key" ]; then
    return 1
  fi
  case "$backend" in
    keychain)
      run_user_security add-generic-password -U -a "$account_key" -s "$(remote_secret_service)" -w "$secret_value" >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

remote_secret_delete() {
  key_path=$1
  backend=$2
  if [ -z "$key_path" ]; then
    return 0
  fi
  account_key=$(remote_secret_account_id "$key_path")
  case "$backend" in
    keychain)
      if [ -n "$account_key" ]; then
        run_user_security delete-generic-password -a "$account_key" -s "$(remote_secret_service)" >/dev/null 2>&1 || true
      fi
      # Backward-compat cleanup for entries stored by literal key path.
      run_user_security delete-generic-password -a "$key_path" -s "$(remote_secret_service)" >/dev/null 2>&1 || true
      ;;
    *)
      :
      ;;
  esac
}

remote_auth_state_json() {
  remote_state_json=$1
  backend=$(detect_remote_secret_backend)
  device_label=$(remote_secret_device_label)
  key_path=$(printf '%s\n' "$remote_state_json" | jq -r '.key_path // ""')
  has_password=$(printf '%s\n' "$remote_state_json" | jq -r '.ssh_key_has_password // "0"')
  save_choice=$(printf '%s\n' "$remote_state_json" | jq -r '.ssh_key_save_choice // "0"')

  secrets_supported=false
  saved=false
  if [ "$backend" != "none" ]; then
    secrets_supported=true
  fi
  if [ "$has_password" = "1" ] && [ "$save_choice" = "1" ] && [ "$backend" != "none" ] && [ -n "$key_path" ] && remote_secret_exists "$key_path" "$backend"; then
    saved=true
  fi

  jq -n \
    --arg ssh_key_has_password "$has_password" \
    --arg ssh_key_save_choice "$save_choice" \
    --argjson ssh_key_password_saved "$saved" \
    --arg secret_backend "$backend" \
    --argjson secrets_supported "$secrets_supported" \
    --arg secrets_device_label "$device_label" \
    '{ssh_key_has_password:$ssh_key_has_password,ssh_key_save_choice:$ssh_key_save_choice,ssh_key_password_saved:$ssh_key_password_saved,secret_backend:$secret_backend,secrets_supported:$secrets_supported,secrets_device_label:$secrets_device_label}'
}

normalize_remote_target_input() {
  printf '%s' "${1-}" | tr -d '\r\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

validate_remote_target() {
  target=$1
  case "$target" in
    ''|-*|@*|*@|*@*@*)
      return 1
      ;;
    *[[:space:]]*|*[!A-Za-z0-9._:@\[\]-]*)
      return 1
      ;;
  esac
  return 0
}

normalize_ssh_key_path_input() {
  raw=$(printf '%s' "${1-}" | tr -d '\r\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  if [ -z "$raw" ]; then
    printf '%s' ''
    return 0
  fi
  case "$raw" in
    "~")
      printf '%s' "$USER_HOME"
      ;;
    "~/"*)
      printf '%s' "$USER_HOME/${raw#\~/}"
      ;;
    /*)
      printf '%s' "$raw"
      ;;
    *)
      printf '%s' "$USER_HOME/$raw"
      ;;
  esac
}

validate_ssh_key_path() {
  key_path=$1
  case "$key_path" in
    ''|*[[:space:]]*)
      return 1
      ;;
  esac
  [ -f "$key_path" ] || return 1
  [ -r "$key_path" ] || return 1
  return 0
}

normalize_remote_port_input() {
  raw=$(printf '%s' "${1-}" | tr -d '\r\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  case "$raw" in
    :*)
      raw=${raw#:}
      ;;
  esac
  printf '%s' "$raw"
}

validate_remote_port() {
  port=$1
  if [ -z "$port" ]; then
    return 0
  fi
  case "$port" in
    *[!0-9]*)
      return 1
      ;;
  esac
  if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    return 1
  fi
  return 0
}

normalize_toggle_flag() {
  case "$(printf '%s' "${1-}" | tr '[:upper:]' '[:lower:]')" in
    1|true|on|yes)
      printf '%s' 1
      ;;
    *)
      printf '%s' 0
      ;;
  esac
}

resolve_remote_ssh_key_password() {
  remote_state_json=$1
  key_path=$2
  password_arg=${3-}
  has_password=$(printf '%s\n' "$remote_state_json" | jq -r '.ssh_key_has_password // "0"')
  save_choice=$(printf '%s\n' "$remote_state_json" | jq -r '.ssh_key_save_choice // "0"')
  if [ "$has_password" != "1" ]; then
    printf '%s' ''
    return 0
  fi

  if [ -n "$password_arg" ]; then
    printf '%s' "$password_arg"
    return 0
  fi

  if [ "$save_choice" = "1" ]; then
    backend=$(detect_remote_secret_backend)
    if [ "$backend" = "none" ]; then
      printf '%s\n' "owl-desktop-backend: secure SSH key password storage is unavailable on this platform" >&2
      return 1
    fi
    if [ -z "$key_path" ]; then
      printf '%s\n' "owl-desktop-backend: set an SSH key path before using saved SSH key password" >&2
      return 1
    fi
    saved_password=$(remote_secret_read "$key_path" "$backend")
    if [ -n "$saved_password" ]; then
      printf '%s' "$saved_password"
      return 0
    fi
    printf '%s\n' "owl-desktop-backend: enter SSH key password in Settings or disable secure save" >&2
    return 1
  fi

  printf '%s\n' "owl-desktop-backend: this SSH key needs a password; enter it in Settings before deploy/sync" >&2
  return 1
}

remote_target_host_component() {
  target=$1
  case "$target" in
    *@*)
      printf '%s' "${target#*@}"
      ;;
    *)
      printf '%s' "$target"
      ;;
  esac
}

looks_like_ip_address() {
  host=$1
  case "$host" in
    *:*)
      return 0
      ;;
    [0-9]*.[0-9]*.[0-9]*.[0-9]*)
      return 0
      ;;
  esac
  return 1
}

compact_status_message() {
  printf '%s' "${1-}" \
    | tr '\r\n' '  ' \
    | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//' \
    | awk '{ if (length($0) > 420) print substr($0, length($0) - 419); else print }'
}

current_utc_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

single_quote_for_sh() {
  raw_value=${1-}
  printf "'%s'" "$(printf '%s' "$raw_value" | sed "s/'/'\\\\''/g")"
}

run_with_ssh_askpass() {
  ssh_password=${1-}
  shift
  if [ -z "$ssh_password" ]; then
    "$@"
    return $?
  fi

  askpass_script=$(mktemp "${TMPDIR:-/tmp}/owl-ssh-askpass.XXXXXX")
  trap 'rm -f "$askpass_script"' EXIT INT TERM
  {
    printf '#!/bin/sh\n'
    printf "printf '%%s\\n' %s\n" "$(single_quote_for_sh "$ssh_password")"
  } >"$askpass_script"
  chmod 0700 "$askpass_script"

  DISPLAY=${DISPLAY:-:0} SSH_ASKPASS="$askpass_script" SSH_ASKPASS_REQUIRE=force "$@"
  status=$?
  rm -f "$askpass_script"
  trap - EXIT INT TERM
  return $status
}

ssh_exec() {
  target_host=$1
  key_path=$2
  ssh_key_password=${3-}
  ssh_port=${4-}
  shift 4
  batch_mode=yes
  if [ -n "$ssh_key_password" ]; then
    batch_mode=no
  fi
  if [ -n "$ssh_port" ]; then
    run_with_ssh_askpass "$ssh_key_password" ssh \
      -i "$key_path" \
      $SSH_KEYCHAIN_OPTIONS \
      -o BatchMode="$batch_mode" \
      -o IdentitiesOnly=yes \
      -o PreferredAuthentications=publickey \
      -o ConnectTimeout="$SSH_CONNECT_TIMEOUT_SECS" \
      -o StrictHostKeyChecking=accept-new \
      -p "$ssh_port" \
      "$target_host" \
      "$@"
    return $?
  fi
  run_with_ssh_askpass "$ssh_key_password" ssh \
    -i "$key_path" \
    $SSH_KEYCHAIN_OPTIONS \
    -o BatchMode="$batch_mode" \
    -o IdentitiesOnly=yes \
    -o PreferredAuthentications=publickey \
    -o ConnectTimeout="$SSH_CONNECT_TIMEOUT_SECS" \
    -o StrictHostKeyChecking=accept-new \
    "$target_host" \
    "$@"
}

scp_put_file_remote() {
  target_host=$1
  key_path=$2
  ssh_key_password=${3-}
  ssh_port=${4-}
  batch_mode=$5
  local_file=$6
  remote_path=$7

  if [ -n "$ssh_port" ]; then
    run_with_ssh_askpass "$ssh_key_password" scp \
      -i "$key_path" \
      $SSH_KEYCHAIN_OPTIONS \
      -o BatchMode="$batch_mode" \
      -o IdentitiesOnly=yes \
      -o PreferredAuthentications=publickey \
      -o ConnectTimeout="$SSH_CONNECT_TIMEOUT_SECS" \
      -o StrictHostKeyChecking=accept-new \
      -P "$ssh_port" \
      "$local_file" \
      "$target_host:$remote_path"
    return $?
  fi

  run_with_ssh_askpass "$ssh_key_password" scp \
    -i "$key_path" \
    $SSH_KEYCHAIN_OPTIONS \
    -o BatchMode="$batch_mode" \
    -o IdentitiesOnly=yes \
    -o PreferredAuthentications=publickey \
    -o ConnectTimeout="$SSH_CONNECT_TIMEOUT_SECS" \
    -o StrictHostKeyChecking=accept-new \
    "$local_file" \
    "$target_host:$remote_path"
}

install_bundled_binaries_on_remote() {
  target_host=$1
  key_path=$2
  ssh_key_password=${3-}
  ssh_port=${4-}
  binary_dir=$5
  archive=$(mktemp "${TMPDIR:-/tmp}/stellar-mail-engine-bin.XXXXXX.tar.gz")
  COPYFILE_DISABLE=1 tar -czf "$archive" \
    -C "$binary_dir" owl owl-daemon \
    -C "$REPO_ROOT" scripts/owl-daemon-service scripts/owld

  batch_mode=yes
  if [ -n "$ssh_key_password" ]; then
    batch_mode=no
  fi
  ssh_exec "$target_host" "$key_path" "$ssh_key_password" "$ssh_port" 'mkdir -p "$HOME/.cache" "$HOME/.local/bin"'
  if ! scp_put_file_remote "$target_host" "$key_path" "$ssh_key_password" "$ssh_port" "$batch_mode" "$archive" "~/.cache/.stellar-mail-engine-bin.upload.tgz"; then
    rm -f "$archive"
    return 1
  fi
  rm -f "$archive"

  ssh_exec "$target_host" "$key_path" "$ssh_key_password" "$ssh_port" sh -s <<'REMOTE_BINARY_INSTALL'
set -eu
tmp_dir=$(mktemp -d "$HOME/.cache/stellar-mail-engine-bin.XXXXXX")
cleanup() {
  rm -rf "$tmp_dir"
  rm -f "$HOME/.cache/.stellar-mail-engine-bin.upload.tgz"
}
trap cleanup EXIT INT TERM
tar -xzf "$HOME/.cache/.stellar-mail-engine-bin.upload.tgz" -C "$tmp_dir"
install -m 0755 "$tmp_dir/owl" "$HOME/.local/bin/owl"
install -m 0755 "$tmp_dir/owl-daemon" "$HOME/.local/bin/owl-daemon"
install -m 0755 "$tmp_dir/scripts/owl-daemon-service" "$HOME/.local/bin/owl-daemon-service"
install -m 0755 "$tmp_dir/scripts/owld" "$HOME/.local/bin/owld"
printf '%s\n' "remote_binary_install=ok"
REMOTE_BINARY_INSTALL
}

build_bundled_source_on_remote() {
  target_host=$1
  key_path=$2
  ssh_key_password=${3-}
  ssh_port=${4-}
  archive=$(mktemp "${TMPDIR:-/tmp}/stellar-mail-engine-source.XXXXXX.tar.gz")
  COPYFILE_DISABLE=1 tar -czf "$archive" \
    -C "$REPO_ROOT" \
    Cargo.toml Cargo.lock src \
    scripts/owl-daemon-service scripts/owld

  batch_mode=yes
  if [ -n "$ssh_key_password" ]; then
    batch_mode=no
  fi
  ssh_exec "$target_host" "$key_path" "$ssh_key_password" "$ssh_port" 'mkdir -p "$HOME/.cache" "$HOME/.local/bin"'
  if ! scp_put_file_remote "$target_host" "$key_path" "$ssh_key_password" "$ssh_port" "$batch_mode" "$archive" "~/.cache/.stellar-mail-engine-source.upload.tgz"; then
    rm -f "$archive"
    return 1
  fi
  rm -f "$archive"

  ssh_exec "$target_host" "$key_path" "$ssh_key_password" "$ssh_port" sh -s <<'REMOTE_SOURCE_BUILD'
set -eu

PATH="$HOME/.cargo/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
if ! command -v cargo >/dev/null 2>&1; then
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- https://sh.rustup.rs | sh -s -- -y --profile minimal
  else
    printf '%s\n' "remote source build requires cargo, curl, or wget" >&2
    exit 1
  fi
fi

source_dir="$HOME/.cache/stellar-mail-engine/source"
target_dir="$HOME/.cache/stellar-mail-engine/target"
cleanup() {
  rm -f "$HOME/.cache/.stellar-mail-engine-source.upload.tgz"
}
trap cleanup EXIT INT TERM
rm -rf "$source_dir"
mkdir -p "$source_dir" "$target_dir"
tar -xzf "$HOME/.cache/.stellar-mail-engine-source.upload.tgz" -C "$source_dir"
CARGO_BUILD_JOBS=1 CARGO_TARGET_DIR="$target_dir" cargo build \
  --manifest-path "$source_dir/Cargo.toml" \
  --profile server \
  --locked \
  --bins
install -m 0755 "$target_dir/server/owl" "$HOME/.local/bin/owl"
install -m 0755 "$target_dir/server/owl-daemon" "$HOME/.local/bin/owl-daemon"
install -m 0755 "$source_dir/scripts/owl-daemon-service" "$HOME/.local/bin/owl-daemon-service"
install -m 0755 "$source_dir/scripts/owld" "$HOME/.local/bin/owld"
printf '%s\n' "remote_source_build=ok"
REMOTE_SOURCE_BUILD
}

install_bundled_engine_on_remote() {
  target_host=$1
  key_path=$2
  ssh_key_password=${3-}
  ssh_port=${4-}

  remote_platform=$(ssh_exec "$target_host" "$key_path" "$ssh_key_password" "$ssh_port" 'printf "%s:%s\n" "$(uname -s 2>/dev/null || printf unknown)" "$(uname -m 2>/dev/null || printf unknown)"')
  case "$remote_platform" in
    Linux:x86_64|Linux:amd64) platform_key=x86_64-linux ;;
    Linux:aarch64|Linux:arm64) platform_key=aarch64-linux ;;
    *) platform_key='' ;;
  esac
  binary_root=${STELLAR_REMOTE_ENGINE_BIN_ROOT-}
  binary_dir="$binary_root/$platform_key"
  if [ -n "$binary_root" ] && [ -n "$platform_key" ] &&
    [ -x "$binary_dir/owl" ] && [ -x "$binary_dir/owl-daemon" ]; then
    install_bundled_binaries_on_remote "$target_host" "$key_path" "$ssh_key_password" "$ssh_port" "$binary_dir"
    printf 'bundled_engine_install=prebuilt:%s\n' "$platform_key"
    return 0
  fi

  build_bundled_source_on_remote "$target_host" "$key_path" "$ssh_key_password" "$ssh_port"
  printf '%s\n' "bundled_engine_install=source"
}

remote_deploy_over_ssh() {
  target_host=$1
  key_path=$2
  ssh_key_password=${3-}
  ssh_port=${4-}
  smtp_host=${5-}
  mail_host_hint=${6-}
  address_routes_b64=${7-}

  ssh_exec "$target_host" "$key_path" "$ssh_key_password" "$ssh_port" 'printf %s "remote-connect-ok" >/dev/null'

  ssh_exec "$target_host" "$key_path" "$ssh_key_password" "$ssh_port" sh -s -- "$smtp_host" "$mail_host_hint" "$address_routes_b64" <<'REMOTE_DEPLOY'
set -eu

remote_smtp_host=${1-}
remote_mail_host_hint=${2-}
remote_address_routes_b64=${3-}
remote_root="$HOME/mail"
env_path="$remote_root/.env"
path_prefix="$HOME/.cargo/bin:$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
PATH="$path_prefix"

remote_domain_from_host() {
  host=${1-}
  host=$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]' | tr -d '\r\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  case "$host" in
    smtp.*)
      host=${host#smtp.}
      ;;
  esac
  printf '%s' "$host"
}

remote_looks_like_ip() {
  host=$1
  case "$host" in
    *:*)
      return 0
      ;;
    [0-9]*.[0-9]*.[0-9]*.[0-9]*)
      return 0
      ;;
  esac
  return 1
}

regex_escape_basic() {
  printf '%s' "${1-}" | sed 's/[.]/\\./g'
}

ensure_remote_mail_dirs() {
  mkdir -p "$remote_root"
  mkdir -p "$remote_root/quarantine" "$remote_root/accepted" "$remote_root/spam" "$remote_root/banned"
  mkdir -p "$remote_root/archive" "$remote_root/trash" "$remote_root/drafts" "$remote_root/outbox" "$remote_root/sent" "$remote_root/logs"
  mkdir -p "$remote_root/accepted/attachments" "$remote_root/spam/attachments" "$remote_root/banned/attachments"
  mkdir -p "$remote_root/archive/attachments" "$remote_root/trash/attachments"
}

set_env_key() {
  key=$1
  value=$2
  mkdir -p "$remote_root"
  touch "$env_path"
  tmp=$(mktemp "${TMPDIR:-/tmp}/owl-remote-env.XXXXXX")
  awk -F= -v key="$key" -v value="$value" '
    BEGIN { replaced = 0 }
    {
      line=$0
      clean=line
      gsub(/\r/, "", clean)
      if (clean ~ /^[[:space:]]*#/ || clean ~ /^[[:space:]]*$/) {
        print line
        next
      }
      split(clean, parts, "=")
      k=parts[1]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
      if (tolower(k) == tolower(key)) {
        print key "=" value
        replaced = 1
      } else {
        print line
      }
    }
    END {
      if (!replaced) {
        print key "=" value
      }
    }
  ' "$env_path" >"$tmp"
  mv "$tmp" "$env_path"
}

remote_run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
    return
  fi
  if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    sudo -n "$@"
    return
  fi
  return 1
}

install_postfix_package() {
  if command -v postconf >/dev/null 2>&1 || command -v postfix >/dev/null 2>&1; then
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    remote_run_as_root env DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1 || return 1
    remote_run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y \
      -o Dpkg::Options::=--force-confdef \
      -o Dpkg::Options::=--force-confold \
      postfix >/dev/null 2>&1 || return 1
    remote_run_as_root env DEBIAN_FRONTEND=noninteractive apt-get -f install -y \
      -o Dpkg::Options::=--force-confdef \
      -o Dpkg::Options::=--force-confold \
      >/dev/null 2>&1 || true
    return 0
  fi
  if command -v dnf >/dev/null 2>&1; then
    remote_run_as_root dnf install -y postfix >/dev/null 2>&1 || return 1
    return 0
  fi
  if command -v yum >/dev/null 2>&1; then
    remote_run_as_root yum install -y postfix >/dev/null 2>&1 || return 1
    return 0
  fi
  if command -v pacman >/dev/null 2>&1; then
    remote_run_as_root pacman -Sy --noconfirm postfix >/dev/null 2>&1 || return 1
    return 0
  fi
  return 1
}

ensure_postfix_runtime() {
  if ! command -v postconf >/dev/null 2>&1 && ! command -v postfix >/dev/null 2>&1; then
    if install_postfix_package; then
      append_service_note 'postfix package installed'
    else
      append_service_note 'postfix package missing and auto-install failed'
      return 1
    fi
  fi

  if command -v systemctl >/dev/null 2>&1; then
    if ! remote_run_as_root systemctl enable --now postfix >/dev/null 2>&1; then
      remote_run_as_root systemctl restart postfix >/dev/null 2>&1 || true
    fi
    if ! systemctl is-active postfix >/dev/null 2>&1; then
      append_service_note 'postfix service is not active'
      return 1
    fi
  elif command -v service >/dev/null 2>&1; then
    remote_run_as_root service postfix start >/dev/null 2>&1 || true
  fi

  if command -v postfix >/dev/null 2>&1; then
    remote_run_as_root postfix start >/dev/null 2>&1 || true
  fi

  return 0
}

ensure_remote_smtp_firewall() {
  if ! command -v ufw >/dev/null 2>&1; then
    return 0
  fi

  ufw_status=$(remote_run_as_root ufw status 2>/dev/null || true)
  case "$ufw_status" in
    Status:\ inactive*)
      return 0
      ;;
  esac
  if printf '%s\n' "$ufw_status" | grep -Eq '(^|[[:space:]])25/tcp([[:space:]]|$)'; then
    return 0
  fi
  remote_run_as_root ufw allow 25/tcp >/dev/null 2>&1 || return 1
  append_service_note 'ufw allow 25/tcp applied'
  return 0
}

ensure_postfix_inbound_bridge() {
  domain_host=''
  if [ -n "$remote_smtp_host" ] && [ "$remote_smtp_host" != "127.0.0.1" ] && [ "$remote_smtp_host" != "localhost" ]; then
    domain_host=$remote_smtp_host
  elif [ -n "$remote_mail_host_hint" ] && [ "$remote_mail_host_hint" != "127.0.0.1" ] && [ "$remote_mail_host_hint" != "localhost" ]; then
    domain_host=$remote_mail_host_hint
  fi
  domain_host=$(remote_domain_from_host "$domain_host")
  if [ -z "$domain_host" ] || remote_looks_like_ip "$domain_host"; then
    append_service_note 'postfix inbound bridge skipped (no mail domain configured)'
    return 0
  fi

  remote_user=$(id -un 2>/dev/null || printf 'anders')
  inbound_script="$HOME/.local/bin/owl-postfix-inbound"
  owl_bin="$HOME/.local/bin/owl"
  mail_hostname="$remote_smtp_host"
  if [ -z "$mail_hostname" ] || [ "$mail_hostname" = "127.0.0.1" ] || [ "$mail_hostname" = "localhost" ] || remote_looks_like_ip "$mail_hostname"; then
    mail_hostname="mail.$domain_host"
  fi
  cert_dir="$remote_root/config/letsencrypt/live/$domain_host"
  cert_fullchain="$cert_dir/fullchain.pem"
  cert_privkey="$cert_dir/privkey.pem"
  mkdir -p "$HOME/.local/bin" "$remote_root/logs" "$remote_root/.tmp-postfix"

  if ! PATH="$path_prefix" command -v sanitize-html >/dev/null 2>&1; then
    cat >"$HOME/.local/bin/sanitize-html" <<'EOF'
#!/bin/sh
exec /bin/cat
EOF
    chmod 0755 "$HOME/.local/bin/sanitize-html"
    append_service_note 'installed sanitize-html compatibility wrapper'
  fi
  if ! PATH="$path_prefix" command -v lynx >/dev/null 2>&1; then
    cat >"$HOME/.local/bin/lynx" <<'EOF'
#!/bin/sh
if [ "${1-}" = "-dump" ] && [ "${2-}" = "-stdin" ]; then
  cat
  exit 0
fi
exec /bin/cat
EOF
    chmod 0755 "$HOME/.local/bin/lynx"
    append_service_note 'installed lynx compatibility wrapper'
  fi

  cat >"$inbound_script" <<EOF
#!/bin/sh
set -eu
umask 077
PATH="$path_prefix"
env_path="$env_path"
tmp_dir="$remote_root/.tmp-postfix"
log_file="$remote_root/logs/owl-postfix-inbound.log"
owl_bin="$owl_bin"
original_recipient=\${1-}
mkdir -p "\$tmp_dir"
tmp_msg=\$(mktemp "\$tmp_dir/inbound.XXXXXX.mbox")
cleanup() {
  rm -f "\$tmp_msg"
}
trap cleanup EXIT INT TERM
if [ -n "\$original_recipient" ]; then
  {
    printf 'X-Stellar-Envelope-To: %s\n' "\$original_recipient"
    cat
  } >"\$tmp_msg"
else
  cat >"\$tmp_msg"
fi
if out=\$("\$owl_bin" --env "\$env_path" import "\$tmp_msg" 2>&1); then
  exit 0
fi
{
  printf '%s import-failed %s\n' "\$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "\$out"
} >>"\$log_file" 2>/dev/null || true
exit 75
EOF
  chmod 0755 "$inbound_script"

  remote_run_as_root sh -c "cat > /etc/postfix/transport_owl.regexp <<'EOREGEXP'
/^stellar-inbox@localhost\$/ owlinbound:
EOREGEXP
" || return 1

  master_args="  flags=Rq user=$remote_user argv=$inbound_script \${original_recipient}"
  remote_run_as_root sh -s -- "$master_args" <<'POSTFIX_MASTER' || return 1
set -eu
master_file=/etc/postfix/master.cf
entry='owlinbound unix - n n - - pipe'
args=$1
if ! grep -Eq '^owlinbound[[:space:]]+unix' "$master_file"; then
  printf '\n%s\n%s\n' "$entry" "$args" >>"$master_file"
else
  tmp=$(mktemp)
  awk -v entry="$entry" -v args="$args" '
    BEGIN { replaced = 0; skip = 0 }
    /^owlinbound[[:space:]]+unix/ {
      print entry
      print args
      replaced = 1
      skip = 1
      next
    }
    skip == 1 {
      if ($0 ~ /^[[:space:]]/) {
        next
      }
      skip = 0
    }
    { print }
    END {
      if (!replaced) {
        print entry
        print args
      }
    }
  ' "$master_file" >"$tmp"
  mv "$tmp" "$master_file"
fi
POSTFIX_MASTER

  remote_run_as_root postconf -e "transport_maps=regexp:/etc/postfix/transport_owl.regexp" || return 1
  remote_run_as_root sh -c "printf '%s\n' '$domain_host' >/etc/mailname" || return 1
  remote_run_as_root postconf -e "myhostname=$mail_hostname" || return 1
  remote_run_as_root postconf -e 'myorigin=/etc/mailname' || return 1
  remote_run_as_root postconf -e "mydestination=\$myhostname, localhost, localhost.localdomain" || return 1
  remote_run_as_root postconf -e 'mailbox_transport=' || return 1
  remote_run_as_root postconf -e 'inet_interfaces=all' || return 1
  remote_run_as_root postconf -e 'inet_protocols=all' || return 1
  if [ -f "$cert_fullchain" ] && [ -f "$cert_privkey" ]; then
    remote_run_as_root postconf -e "smtpd_tls_cert_file=$cert_fullchain" || return 1
    remote_run_as_root postconf -e "smtpd_tls_key_file=$cert_privkey" || return 1
    remote_run_as_root postconf -e 'smtpd_tls_security_level=may' || return 1
    append_service_note "postfix TLS configured from $cert_dir"
  fi
  routes_file="$remote_root/.stellar/postfix-virtual-aliases"
  mkdir -p "$(dirname "$routes_file")"
  if [ -z "$remote_address_routes_b64" ]; then
    printf '%s\n' "postmaster@$domain_host stellar-inbox@localhost" >"$routes_file"
  elif ! printf '%s' "$remote_address_routes_b64" | base64 --decode >"$routes_file" 2>/dev/null; then
    printf '%s' "$remote_address_routes_b64" | base64 -d >"$routes_file" 2>/dev/null || return 1
  fi
  chmod 0600 "$routes_file"
  remote_run_as_root cp "$routes_file" /etc/postfix/stellar_virtual_aliases || return 1
  remote_run_as_root chmod 0600 /etc/postfix/stellar_virtual_aliases || return 1
  remote_run_as_root postmap /etc/postfix/stellar_virtual_aliases || return 1
  remote_run_as_root postconf -e "virtual_alias_domains=$domain_host" || return 1
  remote_run_as_root postconf -e 'virtual_alias_maps=hash:/etc/postfix/stellar_virtual_aliases' || return 1
  if command -v systemctl >/dev/null 2>&1; then
    remote_run_as_root systemctl reload postfix >/dev/null 2>&1 || remote_run_as_root systemctl restart postfix >/dev/null 2>&1 || return 1
  elif command -v service >/dev/null 2>&1; then
    remote_run_as_root service postfix reload >/dev/null 2>&1 || remote_run_as_root service postfix restart >/dev/null 2>&1 || return 1
  elif command -v postfix >/dev/null 2>&1; then
    remote_run_as_root postfix reload >/dev/null 2>&1 || return 1
  fi

  accepted_rules="$remote_root/accepted/.rules"
  mkdir -p "$remote_root/accepted"
  if [ ! -f "$accepted_rules" ]; then
    : >"$accepted_rules"
  fi
  domain_rule="@$domain_host"
  if ! grep -Fxq "$domain_rule" "$accepted_rules" 2>/dev/null; then
    printf '%s\n' "$domain_rule" >>"$accepted_rules"
    append_service_note "accepted-list self-domain rule added ($domain_rule)"
  fi

  append_service_note "postfix recipient routes configured for $domain_host as user $remote_user"
  return 0
}

ensure_owl_binaries() {
  if PATH="$path_prefix" command -v owl >/dev/null 2>&1 && (PATH="$path_prefix" command -v owl-daemon >/dev/null 2>&1 || PATH="$path_prefix" command -v owld >/dev/null 2>&1); then
    return 0
  fi
  printf '%s\n' "remote deploy: Stellar's bundled mail binaries were not installed successfully" >&2
  return 1
}

ensure_owl_service_tools() {
  if ! PATH="$path_prefix" command -v owl-daemon-service >/dev/null 2>&1; then
    append_service_note 'bundled owl-daemon-service helper is unavailable'
  fi
  if ! PATH="$path_prefix" command -v owld >/dev/null 2>&1; then
    append_service_note 'bundled owld wrapper is unavailable'
  fi
}

select_daemon_command() {
  if PATH="$path_prefix" command -v owl-daemon >/dev/null 2>&1; then
    printf '%s\n' "owl-daemon"
    return 0
  fi
  if PATH="$path_prefix" command -v owld >/dev/null 2>&1; then
    printf '%s\n' "owld"
    return 0
  fi
  printf '%s' ''
}

daemon_running_now() {
  daemon_cmd=$1
  if command -v pgrep >/dev/null 2>&1; then
    pgrep -f "$daemon_cmd --env $env_path" >/dev/null 2>&1
    return $?
  fi
  ps -ef 2>/dev/null | grep -F "$daemon_cmd --env $env_path" | grep -v grep >/dev/null 2>&1
}

append_service_note() {
  part=$1
  if [ -z "$part" ]; then
    return 0
  fi
  if [ -n "$service_note" ]; then
    service_note="${service_note}; $part"
  else
    service_note=$part
  fi
}

ensure_cron_keepalive() {
  daemon_cmd=$1
  ensure_script="$HOME/.local/bin/owl-remote-keepalive"
  if ! command -v crontab >/dev/null 2>&1; then
    return 1
  fi

  cat >"$ensure_script" <<EOF
#!/bin/sh
set -eu
PATH="$HOME/.local/bin:\$PATH"
env_path="$env_path"
daemon_cmd="$daemon_cmd"

is_running() {
  if command -v pgrep >/dev/null 2>&1; then
    pgrep -f "\$daemon_cmd --env \$env_path" >/dev/null 2>&1
    return \$?
  fi
  ps -ef 2>/dev/null | grep -F "\$daemon_cmd --env \$env_path" | grep -v grep >/dev/null 2>&1
}

if is_running; then
  exit 0
fi

nohup "\$daemon_cmd" --env "\$env_path" >/dev/null 2>&1 &
EOF
  chmod +x "$ensure_script"

  cron_current=$(crontab -l 2>/dev/null || true)
  cron_current=$(printf '%s\n' "$cron_current" | sed "s/^# temporarily disabled during bitcoin sync: //")
  cron_filtered=$(printf '%s\n' "$cron_current" | grep -Fv "$ensure_script >/dev/null 2>&1" || true)
  cron_tmp=$(mktemp "${TMPDIR:-/tmp}/owl-remote-cron.XXXXXX")
  trap 'rm -f "$cron_tmp"' EXIT INT TERM
  if [ -n "$cron_filtered" ]; then
    printf '%s\n' "$cron_filtered" >"$cron_tmp"
  else
    : >"$cron_tmp"
  fi
  printf '%s\n' "@reboot $ensure_script >/dev/null 2>&1" >>"$cron_tmp"
  printf '%s\n' "*/2 * * * * $ensure_script >/dev/null 2>&1" >>"$cron_tmp"
  crontab "$cron_tmp"
  rm -f "$cron_tmp"
  trap - EXIT INT TERM

  "$ensure_script" >/dev/null 2>&1 || :
  return 0
}

ensure_remote_mail_dirs

if [ ! -f "$env_path" ]; then
  cat >"$env_path" <<ENV_SAMPLE
dmarc_policy=none
dkim_selector=mail
letsencrypt_method=http
keep_plus_tags=false

max_size_quarantine=25M
max_size_approved_default=50M

contacts_dir=$HOME/contacts

logging=minimal
render_mode=strict
load_external_per_message=true

retry_backoff=1m,5m,15m,1h
smtp_host=127.0.0.1
smtp_port=25
smtp_starttls=true
ENV_SAMPLE
fi

if [ -n "$remote_smtp_host" ] && [ "$remote_smtp_host" != "127.0.0.1" ] && [ "$remote_smtp_host" != "localhost" ]; then
  set_env_key smtp_host "$remote_smtp_host"
  set_env_key smtp_starttls true
elif [ -n "$remote_mail_host_hint" ] && [ "$remote_mail_host_hint" != "127.0.0.1" ] && [ "$remote_mail_host_hint" != "localhost" ]; then
  set_env_key smtp_host "$remote_mail_host_hint"
  set_env_key smtp_starttls true
fi

service_note=''
ensure_owl_binaries
ensure_owl_service_tools
if ! ensure_postfix_runtime; then
  if [ -n "$service_note" ]; then
    printf 'note=%s\n' "$service_note"
  fi
  printf '%s\n' "remote deploy: unable to ensure postfix is installed and running on remote host" >&2
  exit 1
fi
if ! ensure_remote_smtp_firewall; then
  if [ -n "$service_note" ]; then
    printf 'note=%s\n' "$service_note"
  fi
  printf '%s\n' "remote deploy: unable to open SMTP port in remote firewall" >&2
  exit 1
fi
if ! ensure_postfix_inbound_bridge; then
  if [ -n "$service_note" ]; then
    printf 'note=%s\n' "$service_note"
  fi
  printf '%s\n' "remote deploy: unable to configure postfix inbound bridge to Owl folders" >&2
  exit 1
fi

PATH="$path_prefix" owl --env "$env_path" install >/dev/null 2>&1
PATH="$path_prefix" owl --env "$env_path" update >/dev/null 2>&1 || :

service_status=''
if PATH="$path_prefix" command -v owl-daemon-service >/dev/null 2>&1; then
  if PATH="$path_prefix" owl-daemon-service install >/dev/null 2>&1; then
    if ! PATH="$path_prefix" owl-daemon-service enable-startup >/dev/null 2>&1; then
      append_service_note 'startup enable failed'
    fi
    if ! PATH="$path_prefix" owl-daemon-service start >/dev/null 2>&1; then
      append_service_note 'service start failed'
    fi
  else
    append_service_note 'service install failed'
  fi
  service_status=$(PATH="$path_prefix" owl-daemon-service status 2>/dev/null || true)
else
  append_service_note 'service helper unavailable'
fi
startup_mode='none'
service_running=false
service_startup=false
case "$service_status" in
  *"running=running"*)
    service_running=true
    ;;
esac
case "$service_status" in
  *"startup=enabled"*)
    service_startup=true
    ;;
esac

if [ "$service_running" = true ] && [ "$service_startup" = true ]; then
  startup_mode='service'
else
  daemon_cmd=$(select_daemon_command)
  if [ -z "$daemon_cmd" ]; then
    append_service_note 'daemon binary unavailable for fallback'
  else
    if ensure_cron_keepalive "$daemon_cmd"; then
      if daemon_running_now "$daemon_cmd"; then
        startup_mode='cron'
        append_service_note 'cron keepalive enabled'
      else
        append_service_note 'cron keepalive configured but daemon is not running'
      fi
    else
      append_service_note 'cron keepalive setup failed'
    fi
  fi
fi

if [ "$startup_mode" = 'none' ]; then
  if [ -n "$service_note" ]; then
    printf 'note=%s\n' "$service_note"
  fi
  printf '%s\n' "remote deploy: unable to ensure always-on daemon startup on remote host" >&2
  exit 1
fi

printf 'remote_root=%s\n' "$remote_root"
printf 'env_path=%s\n' "$env_path"
if [ -n "$remote_smtp_host" ]; then
  printf 'smtp_host=%s\n' "$remote_smtp_host"
elif [ -n "$remote_mail_host_hint" ]; then
  printf 'smtp_host=%s\n' "$remote_mail_host_hint"
fi
printf 'startup_mode=%s\n' "$startup_mode"
if [ -n "$service_status" ]; then
  printf 'service=%s\n' "$service_status"
fi
if [ -n "$service_note" ]; then
  printf 'note=%s\n' "$service_note"
fi
printf 'deploy=ok\n'
REMOTE_DEPLOY
}

publish_address_routes_over_ssh() {
  target_host=$1
  key_path=$2
  ssh_key_password=${3-}
  ssh_port=${4-}
  address_routes_b64=${5-}

  [ -n "$address_routes_b64" ] || {
    printf '%s\n' "address publishing requires at least the postmaster route" >&2
    return 1
  }

  ssh_exec "$target_host" "$key_path" "$ssh_key_password" "$ssh_port" sh -s -- "$address_routes_b64" <<'REMOTE_ADDRESS_PUBLISH'
set -eu

routes_b64=$1
routes_file="$HOME/mail/.stellar/postfix-virtual-aliases"
mkdir -p "$(dirname "$routes_file")"
if ! printf '%s' "$routes_b64" | base64 --decode >"$routes_file" 2>/dev/null; then
  printf '%s' "$routes_b64" | base64 -d >"$routes_file" 2>/dev/null
fi
chmod 0600 "$routes_file"

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo -n "$@"
  fi
}

command -v postmap >/dev/null 2>&1 || {
  printf '%s\n' "postfix is not installed on the remote server" >&2
  exit 1
}
as_root cp "$routes_file" /etc/postfix/stellar_virtual_aliases
as_root chmod 0600 /etc/postfix/stellar_virtual_aliases
as_root postmap /etc/postfix/stellar_virtual_aliases
if command -v systemctl >/dev/null 2>&1; then
  as_root systemctl reload postfix
elif command -v service >/dev/null 2>&1; then
  as_root service postfix reload
else
  as_root postfix reload
fi
printf '%s\n' "address_routes=published"
REMOTE_ADDRESS_PUBLISH
}

remote_sync_over_ssh() {
  target_host=$1
  key_path=$2
  ssh_key_password=${3-}
  ssh_port=${4-}
  rsync_batch_mode=yes
  if [ -n "$ssh_key_password" ]; then
    rsync_batch_mode=no
  fi
  rsync_ssh_cmd="ssh -i $(single_quote_for_sh "$key_path") $SSH_KEYCHAIN_OPTIONS -o BatchMode=$rsync_batch_mode -o IdentitiesOnly=yes -o PreferredAuthentications=publickey -o ConnectTimeout=$SSH_CONNECT_TIMEOUT_SECS -o StrictHostKeyChecking=accept-new"
  if [ -n "$ssh_port" ]; then
    rsync_ssh_cmd="$rsync_ssh_cmd -p $(single_quote_for_sh "$ssh_port")"
  fi

  ssh_exec "$target_host" "$key_path" "$ssh_key_password" "$ssh_port" 'mkdir -p "$HOME/mail/quarantine" "$HOME/mail/accepted" "$HOME/mail/spam" "$HOME/mail/banned" "$HOME/mail/archive" "$HOME/mail/trash" "$HOME/mail/drafts" "$HOME/mail/outbox" "$HOME/mail/sent" "$HOME/mail/logs"'
  ensure_mail_dirs

  sync_output=$(run_with_ssh_askpass "$ssh_key_password" rsync -az --ignore-existing --itemize-changes --prune-empty-dirs \
    --include '/quarantine/' --include '/quarantine/***' \
    --include '/accepted/' --include '/accepted/***' \
    --include '/spam/' --include '/spam/***' \
    --include '/banned/' --include '/banned/***' \
    --include '/archive/' --include '/archive/***' \
    --include '/trash/' --include '/trash/***' \
    --include '/drafts/' --include '/drafts/***' \
    --include '/outbox/' --include '/outbox/***' \
    --include '/sent/' --include '/sent/***' \
    --exclude '*' \
    -e "$rsync_ssh_cmd" \
    "$target_host:~/mail/" "$ROOT/" 2>&1) || {
    printf '%s\n' "$sync_output" >&2
    return 1
  }

  total_copied=$(printf '%s\n' "$sync_output" | awk '/^>f/ { count += 1 } END { print count + 0 }')
  printf '%s\n' "$total_copied"
}

remote_setup_ssl_over_ssh() {
  target_host=$1
  key_path=$2
  ssh_key_password=${3-}
  ssh_port=${4-}
  smtp_host=$5
  email_domain=$6

  ssh_exec "$target_host" "$key_path" "$ssh_key_password" "$ssh_port" 'printf %s "remote-connect-ok" >/dev/null'

  ssh_exec "$target_host" "$key_path" "$ssh_key_password" "$ssh_port" sh -s -- "$smtp_host" "$email_domain" <<'REMOTE_SSL_SETUP'
set -eu

remote_smtp_host=${1-}
remote_email_domain=${2-}
remote_root="$HOME/mail"
env_path="$remote_root/.env"
path_prefix="$HOME/.cargo/bin:$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
PATH="$path_prefix"

set_env_key() {
  key=$1
  value=$2
  mkdir -p "$remote_root"
  touch "$env_path"
  tmp=$(mktemp "${TMPDIR:-/tmp}/owl-remote-ssl-env.XXXXXX")
  awk -F= -v key="$key" -v value="$value" '
    BEGIN { replaced = 0 }
    {
      line=$0
      clean=line
      gsub(/\r/, "", clean)
      if (clean ~ /^[[:space:]]*#/ || clean ~ /^[[:space:]]*$/) {
        print line
        next
      }
      split(clean, parts, "=")
      k=parts[1]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
      if (tolower(k) == tolower(key)) {
        print key "=" value
        replaced = 1
      } else {
        print line
      }
    }
    END {
      if (!replaced) {
        print key "=" value
      }
    }
  ' "$env_path" >"$tmp"
  mv "$tmp" "$env_path"
}

remote_run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
    return $?
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return $?
  fi
  printf '%s\n' "remote ssl setup: root privileges required (missing sudo)" >&2
  return 1
}

install_remote_certbot_if_needed() {
  if command -v certbot >/dev/null 2>&1; then
    printf '%s\n' "certbot already installed"
    return 0
  fi
  if command -v apt-get >/dev/null 2>&1; then
    remote_run_as_root env DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1 || return 1
    remote_run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y certbot >/dev/null 2>&1 || return 1
    printf '%s\n' "installed certbot via apt-get"
    return 0
  fi
  if command -v dnf >/dev/null 2>&1; then
    remote_run_as_root dnf install -y certbot >/dev/null 2>&1 || return 1
    printf '%s\n' "installed certbot via dnf"
    return 0
  fi
  if command -v yum >/dev/null 2>&1; then
    remote_run_as_root yum install -y certbot >/dev/null 2>&1 || return 1
    printf '%s\n' "installed certbot via yum"
    return 0
  fi
  if command -v pacman >/dev/null 2>&1; then
    remote_run_as_root pacman -Sy --noconfirm certbot >/dev/null 2>&1 || return 1
    printf '%s\n' "installed certbot via pacman"
    return 0
  fi
  printf '%s\n' "remote ssl setup: unsupported package manager for automatic certbot install" >&2
  return 1
}

tail_remote_certbot_log() {
  logs_dir="$remote_root/config/letsencrypt/logs"
  latest_log=''
  if [ -d "$logs_dir" ]; then
    latest_log=$(ls -1t "$logs_dir"/letsencrypt.log* 2>/dev/null | head -n1 || true)
  fi
  if [ -z "$latest_log" ]; then
    return 0
  fi
  printf '%s\n' "certbot log tail ($latest_log):" >&2
  remote_run_as_root tail -n 80 "$latest_log" >&2 || tail -n 80 "$latest_log" >&2 || true
}

remote_port80_busy() {
  if command -v ss >/dev/null 2>&1; then
    if ss -ltn 2>/dev/null | awk '$4 ~ /:80$/ {found=1} END {exit found ? 0 : 1}'; then
      return 0
    fi
    if remote_run_as_root ss -ltn 2>/dev/null | awk '$4 ~ /:80$/ {found=1} END {exit found ? 0 : 1}'; then
      return 0
    fi
  elif command -v lsof >/dev/null 2>&1; then
    if lsof -nP -iTCP:80 -sTCP:LISTEN >/dev/null 2>&1; then
      return 0
    fi
    if remote_run_as_root lsof -nP -iTCP:80 -sTCP:LISTEN >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

remote_active_http_service_name() {
  if ! command -v systemctl >/dev/null 2>&1; then
    printf '%s' ''
    return 0
  fi
  for svc in nginx apache2 httpd caddy; do
    if remote_run_as_root systemctl is-active --quiet "$svc" >/dev/null 2>&1; then
      printf '%s' "$svc"
      return 0
    fi
  done
  printf '%s' ''
}

run_remote_certbot_http() {
  cert_config_dir="$remote_root/config/letsencrypt"
  cert_work_dir="$cert_config_dir/work"
  cert_logs_dir="$cert_config_dir/logs"
  cert_hook_dir="$cert_config_dir/hooks"
  cert_hook="$cert_hook_dir/reload-postfix.sh"
  cert_email="postmaster@$remote_email_domain"
  owner_group="$(id -un):$(id -gn)"
  stopped_http_service=''
  certbot_failed=false

  mkdir -p "$cert_work_dir" "$cert_logs_dir" "$cert_hook_dir"
  if [ ! -f "$cert_hook" ]; then
    cat >"$cert_hook" <<'HOOK'
#!/bin/sh
systemctl reload postfix >/dev/null 2>&1 || true
HOOK
    chmod +x "$cert_hook"
  fi

  if remote_port80_busy; then
    stopped_http_service=$(remote_active_http_service_name)
    if [ -n "$stopped_http_service" ]; then
      if ! remote_run_as_root systemctl stop "$stopped_http_service" >/dev/null 2>&1; then
        printf '%s\n' "remote ssl setup: failed to stop $stopped_http_service for certbot challenge on port 80" >&2
        return 1
      fi
    fi
  fi

  if certbot_output=$(remote_run_as_root env PATH="$path_prefix" certbot certonly \
    --non-interactive \
    --agree-tos \
    --preferred-challenges http \
    --standalone \
    --config-dir "$cert_config_dir" \
    --work-dir "$cert_work_dir" \
    --logs-dir "$cert_logs_dir" \
    --deploy-hook "$cert_hook" \
    --email "$cert_email" \
    -d "$remote_smtp_host" 2>&1); then
    :
  else
    certbot_failed=true
  fi

  if [ -n "$stopped_http_service" ]; then
    if ! remote_run_as_root systemctl start "$stopped_http_service" >/dev/null 2>&1; then
      printf '%s\n' "remote ssl setup: warning: failed to restart $stopped_http_service after certbot challenge" >&2
    fi
  fi

  if [ "$certbot_failed" = "true" ]; then
    printf '%s\n' "$certbot_output" >&2
    tail_remote_certbot_log
    return 1
  fi

  printf '%s\n' "$certbot_output"
  remote_run_as_root chown -R "$owner_group" "$cert_config_dir" >/dev/null 2>&1 || true
  return 0
}

remote_ssl_days_from_not_after() {
  not_after=$1
  if [ -z "$not_after" ]; then
    return 1
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$not_after" <<'PY'
import datetime
import sys

raw = sys.argv[1].strip()
if not raw:
    sys.exit(1)
try:
    dt = datetime.datetime.strptime(raw, "%b %d %H:%M:%S %Y %Z")
except ValueError:
    sys.exit(1)
now = datetime.datetime.utcnow()
days = int((dt - now).total_seconds() // 86400)
print(days)
PY
    return $?
  fi
  return 1
}

remote_emit_ssl_status() {
  ssl_ready=false
  ssl_expires_at=''
  ssl_days_remaining=''
  ssl_expiring_soon=false
  ssl_cert_path=''

  cert_file=''
  key_file=''
  for host in "$remote_smtp_host" "$remote_email_domain"; do
    [ -n "$host" ] || continue
    for base in \
      "$remote_root/config/letsencrypt/live/$host" \
      "$HOME/mail/config/letsencrypt/live/$host" \
      "$HOME/.config/letsencrypt/live/$host" \
      "/etc/letsencrypt/live/$host"
    do
      cand_cert="$base/fullchain.pem"
      cand_key="$base/privkey.pem"
      if [ -f "$cand_cert" ] && [ -f "$cand_key" ]; then
        cert_file=$cand_cert
        key_file=$cand_key
        break 2
      fi
    done
  done
  if [ -z "$cert_file" ] || [ -z "$key_file" ]; then
    for base in \
      "$remote_root/config/letsencrypt/live" \
      "$HOME/mail/config/letsencrypt/live"
    do
      cand_cert="$base/fullchain.pem"
      cand_key="$base/privkey.pem"
      if [ -f "$cand_cert" ] && [ -f "$cand_key" ]; then
        cert_file=$cand_cert
        key_file=$cand_key
        break
      fi
    done
  fi

  if [ -n "$cert_file" ] && [ -n "$key_file" ]; then
    ssl_ready=true
    ssl_cert_path=$cert_file
    if command -v openssl >/dev/null 2>&1; then
      ssl_expires_at=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | sed 's/^notAfter=//')
      if [ -n "$ssl_expires_at" ]; then
        if days_val=$(remote_ssl_days_from_not_after "$ssl_expires_at" 2>/dev/null); then
          ssl_days_remaining=$days_val
          case "$days_val" in
            ''|*[!0-9-]*)
              ;;
            *)
              if [ "$days_val" -lt 14 ]; then
                ssl_expiring_soon=true
              fi
              ;;
          esac
        fi
      fi
    fi
  fi
}

if [ -z "$remote_smtp_host" ] || [ "$remote_smtp_host" = "127.0.0.1" ] || [ "$remote_smtp_host" = "localhost" ]; then
  printf '%s\n' "remote ssl setup: invalid smtp_host in Owl settings ($remote_smtp_host)" >&2
  exit 1
fi

if [ -z "$remote_email_domain" ] || [ "$remote_email_domain" = "127.0.0.1" ] || [ "$remote_email_domain" = "localhost" ]; then
  printf '%s\n' "remote ssl setup: invalid email domain in Owl settings ($remote_email_domain)" >&2
  exit 1
fi

mkdir -p "$remote_root"
touch "$env_path"
set_env_key smtp_host "$remote_smtp_host"
set_env_key smtp_starttls true

if ! command -v owl >/dev/null 2>&1; then
  printf '%s\n' "remote ssl setup: owl binary not found on remote host (deploy remote server first)" >&2
  exit 1
fi

remote_emit_ssl_status
already_configured=false
install_output=''
certbot_output=''

if [ "$ssl_ready" = "true" ] && [ "$ssl_expiring_soon" != "true" ]; then
  already_configured=true
else
  install_output=$(install_remote_certbot_if_needed 2>&1) || {
    printf '%s\n' "$install_output" >&2
    exit 1
  }
  if certbot_output=$(run_remote_certbot_http 2>&1); then
    :
  else
    printf '%s\n' "$certbot_output" >&2
    exit 1
  fi
  remote_emit_ssl_status
  if [ "$ssl_ready" != "true" ]; then
    printf '%s\n' "remote ssl setup: certbot ran but no certificate was detected under $remote_root/config/letsencrypt/live" >&2
    tail_remote_certbot_log
    exit 1
  fi
fi

if [ -n "$install_output" ]; then
  printf '%s\n' "$install_output"
fi
if [ -n "$certbot_output" ]; then
  printf '%s\n' "$certbot_output"
fi

printf 'owl_ssl_ready=%s\n' "$ssl_ready"
printf 'owl_ssl_expires_at=%s\n' "$ssl_expires_at"
printf 'owl_ssl_days_remaining=%s\n' "$ssl_days_remaining"
printf 'owl_ssl_expiring_soon=%s\n' "$ssl_expiring_soon"
printf 'owl_ssl_already_configured=%s\n' "$already_configured"
printf 'owl_ssl_smtp_host=%s\n' "$remote_smtp_host"
printf 'owl_ssl_email_domain=%s\n' "$remote_email_domain"
printf 'owl_ssl_cert_path=%s\n' "$ssl_cert_path"
REMOTE_SSL_SETUP
}

tcp_port_reachable() {
  host=$1
  port=$2
  timeout_secs=${3-5}
  if [ -z "$host" ] || [ -z "$port" ]; then
    return 1
  fi

  case "$timeout_secs" in
    ''|*[!0-9]*)
      timeout_secs=5
      ;;
  esac
  if [ "$timeout_secs" -lt 1 ]; then
    timeout_secs=1
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$host" "$port" "$timeout_secs" <<'PY' >/dev/null 2>&1
import socket
import sys

host = sys.argv[1]
port = int(sys.argv[2])
timeout = float(sys.argv[3])
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.settimeout(timeout)
try:
    sock.connect((host, port))
except Exception:
    sys.exit(1)
finally:
    try:
        sock.close()
    except Exception:
        pass
sys.exit(0)
PY
    return $?
  fi

  if command -v nc >/dev/null 2>&1; then
    nc -z -w "$timeout_secs" "$host" "$port" >/dev/null 2>&1
    return $?
  fi

  return 1
}

remote_verify_status_json() {
  target_host=$1
  key_path=$2
  ssh_key_password=${3-}
  ssh_port=${4-}
  smtp_host=$5
  email_domain=$6
  domain_configured=$7
  verify_mode=${8-full}

  remote_probe=$(ssh_exec "$target_host" "$key_path" "$ssh_key_password" "$ssh_port" sh -s <<'REMOTE_VERIFY'
set -eu

remote_root="$HOME/mail"
env_path="$remote_root/.env"
remote_smtp_host='127.0.0.1'
PATH="$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

if [ -r "$env_path" ]; then
  extracted_smtp=$(awk -F= '
    BEGIN { found = 0 }
    {
      line=$0
      gsub(/\r/, "", line)
      if (line ~ /^[[:space:]]*#/ || line ~ /^[[:space:]]*$/) {
        next
      }
      split(line, parts, "=")
      key=parts[1]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      if (tolower(key) == "smtp_host") {
        value=substr(line, index(line, "=") + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        print value
        found = 1
        exit
      }
    }
    END {
      if (!found) {
        # no-op
      }
    }
  ' "$env_path" | head -n 1 | tr -d '\r\n')
  if [ -n "$extracted_smtp" ]; then
    remote_smtp_host=$extracted_smtp
  fi
fi

owl_bin_ok=false
if command -v owl >/dev/null 2>&1; then
  owl_bin_ok=true
elif [ -x "$HOME/.local/bin/owl" ]; then
  owl_bin_ok=true
fi

owl_daemon_bin_ok=false
if command -v owl-daemon >/dev/null 2>&1 || command -v owld >/dev/null 2>&1; then
  owl_daemon_bin_ok=true
elif [ -x "$HOME/.local/bin/owl-daemon" ] || [ -x "$HOME/.local/bin/owld" ]; then
  owl_daemon_bin_ok=true
fi

postfix_bridge_ok=false
if command -v postconf >/dev/null 2>&1; then
  transport_maps=$(postconf -h transport_maps 2>/dev/null || printf '')
  mailbox_transport=$(postconf -h mailbox_transport 2>/dev/null || printf '')
  if printf '%s' "$transport_maps" | grep -Fq 'transport_owl.regexp' && printf '%s' "$mailbox_transport" | grep -Eq '^owlinbound:'; then
    postfix_bridge_ok=true
  fi
fi

daemon_running=false
if command -v pgrep >/dev/null 2>&1; then
  if pgrep -f "owl-daemon --env $env_path" >/dev/null 2>&1 || pgrep -f "owld --env $env_path" >/dev/null 2>&1; then
    daemon_running=true
  fi
else
  if ps -ef 2>/dev/null | grep -F -- "owl-daemon --env $env_path" | grep -v grep >/dev/null 2>&1; then
    daemon_running=true
  elif ps -ef 2>/dev/null | grep -F -- "owld --env $env_path" | grep -v grep >/dev/null 2>&1; then
    daemon_running=true
  fi
fi

smtp_listening=false
if command -v ss >/dev/null 2>&1; then
  if ss -ltn 2>/dev/null | grep -Eq ':[[]?25[[:space:]]'; then
    smtp_listening=true
  fi
elif command -v netstat >/dev/null 2>&1; then
  if netstat -ltn 2>/dev/null | grep -Eq '[:.]25[[:space:]]'; then
    smtp_listening=true
  fi
fi

postfix_installed=false
if command -v postconf >/dev/null 2>&1 || command -v postfix >/dev/null 2>&1; then
  postfix_installed=true
fi

postfix_running=false
if command -v systemctl >/dev/null 2>&1; then
  if systemctl is-active postfix >/dev/null 2>&1; then
    postfix_running=true
  fi
elif command -v service >/dev/null 2>&1; then
  if service postfix status >/dev/null 2>&1; then
    postfix_running=true
  fi
fi

mail_dirs_ok=true
for list in quarantine accepted spam banned archive trash drafts outbox sent logs; do
  if [ ! -d "$remote_root/$list" ]; then
    mail_dirs_ok=false
    break
  fi
done

printf 'remote_os=%s\n' "$(uname -s 2>/dev/null || printf unknown)"
printf 'remote_arch=%s\n' "$(uname -m 2>/dev/null || printf unknown)"
printf 'remote_env_smtp_host=%s\n' "$remote_smtp_host"
printf 'remote_owl_bin_ok=%s\n' "$owl_bin_ok"
printf 'remote_owl_daemon_bin_ok=%s\n' "$owl_daemon_bin_ok"
printf 'remote_daemon_running=%s\n' "$daemon_running"
printf 'remote_smtp_listening=%s\n' "$smtp_listening"
printf 'remote_postfix_installed=%s\n' "$postfix_installed"
printf 'remote_postfix_running=%s\n' "$postfix_running"
printf 'remote_postfix_bridge_ok=%s\n' "$postfix_bridge_ok"
printf 'remote_mail_dirs_ok=%s\n' "$mail_dirs_ok"
REMOTE_VERIFY
) || return 1

remote_host_only=$(remote_target_host_component "$target_host")
  probe_host=$remote_host_only
  if [ -n "$smtp_host" ] && [ "$smtp_host" != "127.0.0.1" ] && [ "$smtp_host" != "localhost" ]; then
    probe_host=$smtp_host
  fi
  probe_port=25
  tcp_25_ok=true
  if [ "$verify_mode" = "full" ]; then
    if tcp_port_reachable "$probe_host" "$probe_port" "$REMOTE_VERIFY_TCP_TIMEOUT_SECS"; then
      tcp_25_ok=true
    else
      tcp_25_ok=false
    fi
  fi

  smtp_a_json='[]'
  mx_json='[]'
  expected_target_json='[]'
  mx_target_host_json='[]'
  mx_target_addr_json='[]'
  smtp_a_ok=false
  mx_ok=false
  if [ "$verify_mode" = "full" ] && [ "$domain_configured" = "true" ] && [ -n "$smtp_host" ] && [ -n "$email_domain" ] && [ "$smtp_host" != "127.0.0.1" ] && [ "$smtp_host" != "localhost" ]; then
    expected_target_records=''
    if looks_like_ip_address "$remote_host_only"; then
      expected_target_records=$remote_host_only
    else
      remote_host_a=$(dns_values_for A "$remote_host_only")
      remote_host_aaaa=$(dns_values_for AAAA "$remote_host_only")
      expected_target_records=$(printf '%s\n%s\n' "$remote_host_a" "$remote_host_aaaa" | normalize_unique_lines)
    fi
    smtp_a=$(dns_values_for A "$smtp_host")
    smtp_aaaa=$(dns_values_for AAAA "$smtp_host")
    mx_records=$(dns_values_for MX "$email_domain")
    smtp_target_records=$(printf '%s\n%s\n' "$smtp_a" "$smtp_aaaa" | normalize_unique_lines)
    mx_target_hosts=$(printf '%s\n' "$mx_records" | awk '{print $NF}' | normalize_unique_lines)
    mx_target_addresses=''
    if [ -n "$mx_target_hosts" ]; then
      old_ifs=${IFS-}
      IFS='
'
      for mx_target_host in $mx_target_hosts; do
        if looks_like_ip_address "$mx_target_host"; then
          mx_target_addresses=$(printf '%s\n%s\n' "$mx_target_addresses" "$mx_target_host")
        else
          mx_a=$(dns_values_for A "$mx_target_host")
          mx_aaaa=$(dns_values_for AAAA "$mx_target_host")
          mx_target_addresses=$(printf '%s\n%s\n%s\n' "$mx_target_addresses" "$mx_a" "$mx_aaaa")
        fi
      done
      IFS=$old_ifs
    fi
    mx_target_addresses=$(printf '%s\n' "$mx_target_addresses" | normalize_unique_lines)
    smtp_a_json=$(printf '%s\n' "$smtp_target_records" | json_array_from_lines)
    mx_json=$(printf '%s\n' "$mx_records" | json_array_from_lines)
    expected_target_json=$(printf '%s\n' "$expected_target_records" | json_array_from_lines)
    mx_target_host_json=$(printf '%s\n' "$mx_target_hosts" | json_array_from_lines)
    mx_target_addr_json=$(printf '%s\n' "$mx_target_addresses" | json_array_from_lines)
    if lines_overlap "$expected_target_records" "$smtp_target_records"; then
      smtp_a_ok=true
    fi
    if lines_overlap "$expected_target_records" "$mx_target_addresses"; then
      mx_ok=true
    fi
  fi

remote_os=$(printf '%s\n' "$remote_probe" | awk -F= '/^remote_os=/{print $2; exit}')
remote_arch=$(printf '%s\n' "$remote_probe" | awk -F= '/^remote_arch=/{print $2; exit}')
remote_env_smtp_host=$(printf '%s\n' "$remote_probe" | awk -F= '/^remote_env_smtp_host=/{sub(/^remote_env_smtp_host=/, ""); print; exit}')
remote_owl_bin_ok=$(printf '%s\n' "$remote_probe" | awk -F= '/^remote_owl_bin_ok=/{print $2; exit}')
remote_owl_daemon_bin_ok=$(printf '%s\n' "$remote_probe" | awk -F= '/^remote_owl_daemon_bin_ok=/{print $2; exit}')
remote_daemon_running=$(printf '%s\n' "$remote_probe" | awk -F= '/^remote_daemon_running=/{print $2; exit}')
remote_smtp_listening=$(printf '%s\n' "$remote_probe" | awk -F= '/^remote_smtp_listening=/{print $2; exit}')
remote_postfix_installed=$(printf '%s\n' "$remote_probe" | awk -F= '/^remote_postfix_installed=/{print $2; exit}')
remote_postfix_running=$(printf '%s\n' "$remote_probe" | awk -F= '/^remote_postfix_running=/{print $2; exit}')
remote_postfix_bridge_ok=$(printf '%s\n' "$remote_probe" | awk -F= '/^remote_postfix_bridge_ok=/{print $2; exit}')
remote_mail_dirs_ok=$(printf '%s\n' "$remote_probe" | awk -F= '/^remote_mail_dirs_ok=/{print $2; exit}')

for bool_var in remote_owl_bin_ok remote_owl_daemon_bin_ok remote_daemon_running remote_smtp_listening remote_postfix_installed remote_postfix_running remote_postfix_bridge_ok remote_mail_dirs_ok tcp_25_ok smtp_a_ok mx_ok; do
  eval "val=\${$bool_var-}"
  case "$val" in
    true|false) ;;
    *)
      eval "$bool_var=false"
      ;;
  esac
done

ready=true
verify_message=''
verify_warning=''
append_verify_issue() {
  issue=$1
  if [ -z "$verify_message" ]; then
    verify_message=$issue
  else
    verify_message="$verify_message; $issue"
  fi
  ready=false
}
append_verify_warning() {
  warn=$1
  if [ -z "$warn" ]; then
    return 0
  fi
  if [ -z "$verify_warning" ]; then
    verify_warning=$warn
  else
    verify_warning="$verify_warning; $warn"
  fi
}

if [ "$remote_owl_bin_ok" != "true" ] || [ "$remote_owl_daemon_bin_ok" != "true" ]; then
  append_verify_issue 'remote Owl binaries missing'
fi
if [ "$remote_mail_dirs_ok" != "true" ]; then
  append_verify_issue 'remote mail folders missing'
fi
if [ "$remote_daemon_running" != "true" ]; then
  append_verify_issue 'remote owl-daemon is not running'
fi
if [ "$remote_smtp_listening" != "true" ]; then
  append_verify_issue 'remote SMTP is not listening on port 25'
fi
if [ "$remote_postfix_installed" != "true" ]; then
  append_verify_issue 'postfix is not installed on remote host'
elif [ "$remote_postfix_running" != "true" ]; then
  append_verify_issue 'postfix is installed but not running'
elif [ "$remote_postfix_bridge_ok" != "true" ]; then
  append_verify_issue 'postfix is not routing local mail into Owl folders yet'
fi
if [ "$domain_configured" != "true" ]; then
  append_verify_issue 'domain is not configured in Owl Settings'
elif [ "$verify_mode" = "full" ]; then
  if [ "$smtp_a_ok" != "true" ]; then
    append_verify_issue 'smtp host does not resolve to the deployed server'
  fi
  if [ "$mx_ok" != "true" ]; then
    append_verify_issue 'MX record does not resolve to the deployed server'
  fi
fi
if [ "$verify_mode" = "full" ] && [ "$tcp_25_ok" != "true" ]; then
  append_verify_warning 'SMTP port 25 probe from this machine failed (local network may block outbound port 25)'
fi

if [ "$ready" = "true" ]; then
  verify_status='ok'
  verify_message='Remote server is ready to receive internet email.'
else
  verify_status='bad'
  if [ -z "$verify_message" ]; then
    verify_message='Remote verification failed.'
  fi
fi
if [ -n "$verify_warning" ]; then
  verify_message="$verify_message; $verify_warning"
fi

jq -cn \
  --arg status "$verify_status" \
  --arg message "$(compact_status_message "$verify_message")" \
  --arg probe_host "$probe_host" \
  --arg probe_port "$probe_port" \
  --arg remote_os "$remote_os" \
  --arg remote_arch "$remote_arch" \
  --arg remote_env_smtp_host "$remote_env_smtp_host" \
  --argjson ready "$( [ "$ready" = "true" ] && printf 'true' || printf 'false' )" \
  --argjson domain_configured "$( [ "$domain_configured" = "true" ] && printf 'true' || printf 'false' )" \
  --argjson remote_owl_bin_ok "$remote_owl_bin_ok" \
  --argjson remote_owl_daemon_bin_ok "$remote_owl_daemon_bin_ok" \
  --argjson remote_daemon_running "$remote_daemon_running" \
  --argjson remote_smtp_listening "$remote_smtp_listening" \
  --argjson remote_postfix_installed "$remote_postfix_installed" \
  --argjson remote_postfix_running "$remote_postfix_running" \
  --argjson remote_postfix_bridge_ok "$remote_postfix_bridge_ok" \
  --argjson remote_mail_dirs_ok "$remote_mail_dirs_ok" \
  --argjson tcp_25_ok "$tcp_25_ok" \
  --argjson smtp_a_ok "$smtp_a_ok" \
  --argjson mx_ok "$mx_ok" \
  --argjson smtp_a_records "$smtp_a_json" \
  --argjson mx_records "$mx_json" \
  --argjson expected_target_records "$expected_target_json" \
  --argjson mx_target_hosts "$mx_target_host_json" \
  --argjson mx_target_addresses "$mx_target_addr_json" \
  '{status:$status,message:$message,ready:$ready,probe_host:$probe_host,probe_port:$probe_port,domain_configured:$domain_configured,checks:{remote_owl_bin_ok:$remote_owl_bin_ok,remote_owl_daemon_bin_ok:$remote_owl_daemon_bin_ok,remote_daemon_running:$remote_daemon_running,remote_smtp_listening:$remote_smtp_listening,remote_postfix_installed:$remote_postfix_installed,remote_postfix_running:$remote_postfix_running,remote_postfix_bridge_ok:$remote_postfix_bridge_ok,remote_mail_dirs_ok:$remote_mail_dirs_ok,tcp_25_ok:$tcp_25_ok,smtp_a_ok:$smtp_a_ok,mx_ok:$mx_ok},records:{expected_target:$expected_target_records,smtp_a:$smtp_a_records,mx:$mx_records,mx_target_hosts:$mx_target_hosts,mx_target_addresses:$mx_target_addresses},remote:{os:$remote_os,arch:$remote_arch,env_smtp_host:$remote_env_smtp_host}}'
}

smtp_send_test_message() {
  smtp_host=$1
  recipient=$2
  subject=$3
  sender=$4
  smtp_timeout=${5-5}
  if ! command -v python3 >/dev/null 2>&1; then
    printf '%s\n' "python3 is required to send SMTP test mail" >&2
    return 1
  fi

  python3 - "$smtp_host" "$recipient" "$subject" "$sender" "$smtp_timeout" <<'PY'
import smtplib
import sys
from email.utils import formatdate, make_msgid

host = sys.argv[1]
recipient = sys.argv[2]
subject = sys.argv[3]
sender = sys.argv[4]
timeout = float(sys.argv[5])

body = (
    "This is an Owl remote SMTP receive test.\r\n"
    "If this appears in Inbox after sync, remote receive is working.\r\n"
)
msg = (
    f"From: {sender}\r\n"
    f"To: {recipient}\r\n"
    f"Subject: {subject}\r\n"
    f"Date: {formatdate(localtime=False)}\r\n"
    f"Message-ID: {make_msgid('owl-remote-test')}\r\n"
    "\r\n"
    f"{body}"
)

with smtplib.SMTP(host=host, port=25, timeout=timeout) as smtp:
    smtp.ehlo_or_helo_if_needed()
    smtp.sendmail(sender, [recipient], msg)
PY
}

remote_smtp_send_test_message() {
  target_host=$1
  key_path=$2
  ssh_key_password=${3-}
  ssh_port=${4-}
  recipient=$5
  subject=$6
  sender=$7
  smtp_timeout=${8-5}
  payload_b64=$(printf '%s\n%s\n%s\n%s\n' "$recipient" "$subject" "$sender" "$smtp_timeout" | base64 | tr -d '\r\n')
  ssh_exec "$target_host" "$key_path" "$ssh_key_password" "$ssh_port" sh -s -- "$payload_b64" <<'REMOTE_SMTP_TEST'
set -eu

payload_b64=$1
decoded_payload=''
if decoded_payload=$(printf '%s' "$payload_b64" | base64 --decode 2>/dev/null); then
  :
elif decoded_payload=$(printf '%s' "$payload_b64" | base64 -d 2>/dev/null); then
  :
else
  printf '%s\n' 'remote send-test payload decode failed' >&2
  exit 1
fi
recipient=$(printf '%s\n' "$decoded_payload" | sed -n '1p')
subject=$(printf '%s\n' "$decoded_payload" | sed -n '2p')
sender=$(printf '%s\n' "$decoded_payload" | sed -n '3p')
smtp_timeout=$(printf '%s\n' "$decoded_payload" | sed -n '4p')
case "$smtp_timeout" in
  ''|*[!0-9]*)
    smtp_timeout=5
    ;;
esac

body='This is an Owl remote SMTP receive test.
If this appears in Inbox after sync, remote receive is working.'

if command -v sendmail >/dev/null 2>&1; then
  {
    printf 'From: %s\n' "$sender"
    printf 'To: %s\n' "$recipient"
    printf 'Subject: %s\n' "$subject"
    printf 'Date: %s\n' "$(date -R)"
    printf '\n'
    printf '%s\n' "$body"
  } | sendmail -t
  exit 0
fi

if command -v python3 >/dev/null 2>&1; then
  python3 - "$recipient" "$subject" "$sender" "$smtp_timeout" <<'PY'
import smtplib
import sys
from email.utils import formatdate, make_msgid

recipient = sys.argv[1]
subject = sys.argv[2]
sender = sys.argv[3]
timeout = float(sys.argv[4])

body = (
    "This is an Owl remote SMTP receive test.\r\n"
    "If this appears in Inbox after sync, remote receive is working.\r\n"
)
msg = (
    f"From: {sender}\r\n"
    f"To: {recipient}\r\n"
    f"Subject: {subject}\r\n"
    f"Date: {formatdate(localtime=False)}\r\n"
    f"Message-ID: {make_msgid('owl-remote-test')}\r\n"
    "\r\n"
    f"{body}"
)

with smtplib.SMTP(host='127.0.0.1', port=25, timeout=timeout) as smtp:
    smtp.ehlo_or_helo_if_needed()
    smtp.sendmail(sender, [recipient], msg)
PY
  exit 0
fi

printf '%s\n' 'remote send-test requires sendmail or python3' >&2
exit 1
REMOTE_SMTP_TEST
}

remote_test_subject_seen() {
  target_host=$1
  key_path=$2
  ssh_key_password=${3-}
  ssh_port=${4-}
  subject=$5
  subject_b64=$(printf '%s' "$subject" | base64 | tr -d '\r\n')
  ssh_exec "$target_host" "$key_path" "$ssh_key_password" "$ssh_port" sh -s -- "$subject_b64" <<'REMOTE_TEST_SUBJECT'
set -eu
subject_b64=$1
if subject=$(printf '%s' "$subject_b64" | base64 --decode 2>/dev/null); then
  :
elif subject=$(printf '%s' "$subject_b64" | base64 -d 2>/dev/null); then
  :
else
  printf '%s\n' false
  exit 0
fi

if grep -R -F -- "$subject" "$HOME/mail/accepted" "$HOME/mail/quarantine" "$HOME/mail/spam" "$HOME/mail/banned" >/dev/null 2>&1; then
  printf '%s\n' true
else
  printf '%s\n' false
fi
REMOTE_TEST_SUBJECT
}

local_test_subject_seen() {
  subject=$1
  if grep -R -F -- "$subject" "$ROOT/accepted" "$ROOT/quarantine" "$ROOT/spam" "$ROOT/banned" >/dev/null 2>&1; then
    printf '%s\n' true
  else
    printf '%s\n' false
  fi
}

normalize_domain_input() {
  raw=$(printf '%s' "${1-}" | tr '[:upper:]' '[:lower:]' | tr -d '\r\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  raw=${raw#@}
  case "$raw" in
    smtp.*)
      raw=${raw#smtp.}
      ;;
  esac
  printf '%s' "$raw"
}

validate_domain_name() {
  domain=$1
  case "$domain" in
    ''|.*|*..*|*.-*|*-.|*[!a-z0-9.-]*)
      return 1
      ;;
  esac
  case "$domain" in
    *.*) ;;
    *)
      return 1
      ;;
  esac
  return 0
}

domain_has_live_dns() {
  domain=$1

  if command -v dig >/dev/null 2>&1; then
    if dig +time=2 +tries=1 +short A "$domain" 2>/dev/null | grep -Eq '[^[:space:]]'; then
      return 0
    fi
    if dig +time=2 +tries=1 +short AAAA "$domain" 2>/dev/null | grep -Eq '[^[:space:]]'; then
      return 0
    fi
    if dig +time=2 +tries=1 +short MX "$domain" 2>/dev/null | grep -Eq '[^[:space:]]'; then
      return 0
    fi
    if dig +time=2 +tries=1 +short CNAME "$domain" 2>/dev/null | grep -Eq '[^[:space:]]'; then
      return 0
    fi
  fi

  if command -v host >/dev/null 2>&1; then
    if host -W 2 "$domain" 2>/dev/null | grep -Eiq '(has address|has IPv6 address|mail is handled by|is an alias for)'; then
      return 0
    fi
  fi

  if command -v dscacheutil >/dev/null 2>&1; then
    if dscacheutil -q host -a name "$domain" 2>/dev/null | grep -Eiq '^ip_address:'; then
      return 0
    fi
  fi

  return 1
}

dns_values_for() {
  rrtype=$1
  name=$2
  if command -v dig >/dev/null 2>&1; then
    dig +time=2 +tries=1 +short "$rrtype" "$name" 2>/dev/null | sed 's/[[:space:]]*$//' | awk 'NF'
    return 0
  fi
  if [ "$rrtype" = "A" ] && command -v dscacheutil >/dev/null 2>&1; then
    dscacheutil -q host -a name "$name" 2>/dev/null | awk '/^ip_address:/ {print $2}'
    return 0
  fi
  if command -v host >/dev/null 2>&1; then
    host "$name" 2>/dev/null | awk '
      /has address/ {print $NF}
      /has IPv6 address/ {print $NF}
      /mail is handled by/ {print $(NF-1) " " $NF}
    '
    return 0
  fi
}

json_array_from_lines() {
  jq -R -s 'split("\n") | map(select(length > 0))'
}

normalize_unique_lines() {
  awk '
    {
      line=$0
      gsub(/\r/, "", line)
      sub(/[[:space:]]+$/, "", line)
      sub(/[.]$/, "", line)
      if (line == "") {
        next
      }
      key=tolower(line)
      if (!seen[key]++) {
        print line
      }
    }
  '
}

lines_overlap() {
  left_input=${1-}
  right_input=${2-}
  if [ -z "$left_input" ] || [ -z "$right_input" ]; then
    return 1
  fi
  left_tmp=$(mktemp "${TMPDIR:-/tmp}/owl-lines-left.XXXXXX")
  right_tmp=$(mktemp "${TMPDIR:-/tmp}/owl-lines-right.XXXXXX")
  printf '%s\n' "$left_input" | normalize_unique_lines >"$left_tmp"
  printf '%s\n' "$right_input" | normalize_unique_lines >"$right_tmp"
  if grep -Fxf "$left_tmp" "$right_tmp" >/dev/null 2>&1; then
    rm -f "$left_tmp" "$right_tmp"
    return 0
  fi
  rm -f "$left_tmp" "$right_tmp"
  return 1
}

detect_public_ip() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time 3 https://api.ipify.org 2>/dev/null || true
    return 0
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -qO- --timeout=3 https://api.ipify.org 2>/dev/null || true
    return 0
  fi
  printf '%s' ''
}

smtp_host_from_domain() {
  domain=$1
  printf 'smtp.%s' "$domain"
}

normalize_server_mode() {
  mode=$(printf '%s' "${1-}" | tr '[:upper:]' '[:lower:]' | tr -d '\r\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  case "$mode" in
    remote) printf '%s\n' "remote" ;;
    *) printf '%s\n' "local" ;;
  esac
}

mail_host_from_domain_and_mode() {
  domain=$1
  mode=$(normalize_server_mode "${2-}")
  remote_target=${3-}
  if [ "$mode" = "remote" ]; then
    remote_host=$(remote_target_host_component "$remote_target")
    remote_host=$(printf '%s' "$remote_host" | tr '[:upper:]' '[:lower:]' | tr -d '\r\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    if [ -n "$remote_host" ] && ! looks_like_ip_address "$remote_host" && validate_domain_name "$remote_host"; then
      printf '%s\n' "$remote_host"
      return 0
    fi
  fi
  smtp_host_from_domain "$domain"
}

expected_mail_target_ip() {
  mode=$(normalize_server_mode "${1-}")
  remote_target=${2-}
  if [ "$mode" = "remote" ]; then
    remote_host=$(remote_target_host_component "$remote_target")
    remote_host=$(printf '%s' "$remote_host" | tr '[:upper:]' '[:lower:]' | tr -d '\r\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    if [ -n "$remote_host" ]; then
      if looks_like_ip_address "$remote_host"; then
        printf '%s\n' "$remote_host"
        return 0
      fi
      remote_host_a=$(dns_values_for A "$remote_host")
      remote_host_aaaa=$(dns_values_for AAAA "$remote_host")
      target_records=$(printf '%s\n%s\n' "$remote_host_a" "$remote_host_aaaa" | normalize_unique_lines)
      if [ -n "$target_records" ]; then
        printf '%s\n' "$target_records" | head -n 1
        return 0
      fi
    fi
    printf '%s\n' "(remote server public IP)"
    return 0
  fi
  public_ip=$(detect_public_ip)
  if [ -n "$public_ip" ]; then
    printf '%s\n' "$public_ip"
    return 0
  fi
  printf '%s\n' "(your server public IP)"
}

email_domain_from_smtp_host() {
  host=$(printf '%s' "${1-}" | tr '[:upper:]' '[:lower:]' | tr -d '\r\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  host=${host#smtp.}
  printf '%s' "$host"
}

domain_configured_for_smtp_host() {
  smtp_host=$1
  email_domain=$(email_domain_from_smtp_host "$smtp_host")
  if [ -n "$smtp_host" ] && [ "$smtp_host" != "127.0.0.1" ] && [ "$smtp_host" != "localhost" ] && [ "$email_domain" != "127.0.0.1" ] && [ "$email_domain" != "localhost" ]; then
    printf 'true'
  else
    printf 'false'
  fi
}

settings_env_get() {
  key=$1
  if [ ! -f "$ENV_PATH" ]; then
    printf '%s' ''
    return 0
  fi
  awk -F= -v key="$key" '
    {
      line=$0
      gsub(/\r/, "", line)
      if (line ~ /^[[:space:]]*#/ || line ~ /^[[:space:]]*$/) next
      split(line, parts, "=")
      k=parts[1]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
      if (tolower(k) == tolower(key)) {
        sub(/^[^=]*=/, "", line)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        print line
        exit
      }
    }
  ' "$ENV_PATH"
}

settings_env_set() {
  key=$1
  value=$2
  mkdir -p "$ROOT"
  touch "$ENV_PATH"
  tmp=$(mktemp "${TMPDIR:-/tmp}/owl-desktop-env.XXXXXX")
  awk -F= -v key="$key" -v value="$value" '
    BEGIN { replaced = 0 }
    {
      line=$0
      clean=line
      gsub(/\r/, "", clean)
      if (clean ~ /^[[:space:]]*#/ || clean ~ /^[[:space:]]*$/) {
        print line
        next
      }
      split(clean, parts, "=")
      k=parts[1]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
      if (tolower(k) == tolower(key)) {
        print key "=" value
        replaced = 1
      } else {
        print line
      }
    }
    END {
      if (!replaced) {
        print key "=" value
      }
    }
  ' "$ENV_PATH" >"$tmp"
  mv "$tmp" "$ENV_PATH"
}

llm_recommended_lines() {
  printf '%s\n' "llama3.1:8b|best overall Owl spam classifier (recommended)|4.9|128"
  printf '%s\n' "phi3:mini|fast low-RAM fallback (recommended)|2.2|8"
  printf '%s\n' "mistral:7b|balanced secondary option|4.4|8"
}

llm_available_lines() {
  out=$(run_ai_dev_script list-available-llms 2>/dev/null || true)
  if [ -n "$(printf '%s' "$out" | tr -d '\r\n\t ')" ]; then
    printf '%s\n' "$out"
    return 0
  fi
  llm_recommended_lines
}

llm_installed_lines() {
  ai_dev_out=$(run_ai_dev_script list-installed-llms 2>/dev/null || true)
  ollama_out=$(
    ollama_bin=$(resolve_ollama_bin || true)
    if [ -n "$ollama_bin" ]; then
      "$ollama_bin" list 2>/dev/null | awk 'NR > 1 { print $1 }'
    fi
  )
  {
    printf '%s\n' "$ai_dev_out"
    printf '%s\n' "$ollama_out"
  } | awk '
    {
      line=$0
      gsub(/\r/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line == "") next
      split(line, parts, "|")
      name=parts[1]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      if (name == "") next
      if (!seen[name]++) print name
    }
  '
}

llm_models_json_from_lines() {
  lines=${1-}
  printf '%s\n' "$lines" | jq -R -s '
    split("\n")
    | map(select(length > 0) | split("|"))
    | map({
        name: (.[0] // ""),
        desc: (.[1] // ""),
        size_gb: ((.[2] // "0") | tonumber? // 0),
        context_k: ((.[3] // "0") | tonumber? // 0)
      })
    | map(select(.name | test("^[A-Za-z0-9_./:-]+$")))
    | unique_by(.name)
  '
}

llm_installed_json_from_lines() {
  lines=${1-}
  printf '%s\n' "$lines" | jq -R -s '
    split("\n")
    | map(gsub("\\r"; "") | gsub("^\\s+|\\s+$"; ""))
    | map(select(length > 0) | split("|")[0] | gsub("^\\s+|\\s+$"; ""))
    | map(select(length > 0 and test("^[A-Za-z0-9_./:-]+$")))
    | unique
  '
}

llm_bool_setting() {
  key=$1
  default_value=$2
  value=$(settings_env_get "$key" | tr '[:upper:]' '[:lower:]' | tr -d '\r\n[:space:]')
  case "$value" in
    1|true|yes|on)
      printf '%s' '1'
      ;;
    0|false|no|off)
      printf '%s' '0'
      ;;
    *)
      printf '%s' "$default_value"
      ;;
  esac
}

llm_selected_model_setting() {
  selected=$(settings_env_get spam_llm_model | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  if safe_model_name "$selected"; then
    printf '%s\n' "$selected"
    return 0
  fi
  llm_recommended_lines | awk -F'|' 'NR==1 {print $1; exit}'
}

llm_is_ollama_installed_json() {
  if run_ai_dev_script is-ai-component-installed ollama >/dev/null 2>&1; then
    printf '%s\n' true
    return 0
  fi
  ollama_bin=$(resolve_ollama_bin || true)
  if [ -n "$ollama_bin" ] && [ -x "$ollama_bin" ]; then
    printf '%s\n' true
    return 0
  fi
  installed_lines=$(llm_installed_lines)
  if [ -n "$(printf '%s' "$installed_lines" | tr -d '\r\n[:space:]')" ]; then
    printf '%s\n' true
    return 0
  fi
  printf '%s\n' false
}

llm_is_daemon_running_json() {
  if run_ai_dev_script is-ollama-daemon-running >/dev/null 2>&1; then
    printf '%s\n' true
    return 0
  fi
  ollama_bin=$(resolve_ollama_bin || true)
  if [ -n "$ollama_bin" ] && "$ollama_bin" list >/dev/null 2>&1; then
    printf '%s\n' true
    return 0
  fi
  printf '%s\n' false
}

llm_settings_state_json() {
  available_lines=$(llm_available_lines)
  installed_lines=$(llm_installed_lines)
  recommended_lines=$(llm_recommended_lines)
  available_json=$(llm_models_json_from_lines "$available_lines")
  installed_json=$(llm_installed_json_from_lines "$installed_lines")
  recommended_json=$(llm_models_json_from_lines "$recommended_lines")
  selected_model=$(llm_selected_model_setting)
  enabled_flag=$(llm_bool_setting spam_llm_enabled 1)
  ollama_installed_json=$(llm_is_ollama_installed_json)
  daemon_running_json=$(llm_is_daemon_running_json)

  jq -n \
    --arg selected "$selected_model" \
    --argjson available "$available_json" \
    --argjson installed "$installed_json" \
    --argjson recommended "$recommended_json" \
    --argjson enabled "$(json_bool "$enabled_flag")" \
    --argjson auto_install false \
    --argjson ollama_installed "$ollama_installed_json" \
    --argjson daemon_running "$daemon_running_json" '
      def has_model($list; $name): ($list | index($name)) != null;
      def ensure_installed_visible($available; $installed):
        ($available + ($installed | map({
          name: .,
          desc: "installed locally",
          size_gb: 0,
          context_k: 0
        })))
        | unique_by(.name);
      def first_recommended_installed($recommended; $installed):
        ($recommended | map(.name) | map(select(has_model($installed; .))) | .[0] // "");
      def first_installed($installed): ($installed[0] // "");
      .selected = (if ($selected | test("^[A-Za-z0-9_.:-]+$")) then $selected else ($recommended[0].name // "") end)
      | .recommended_model = ($recommended[0].name // "")
      | .selected_installed = has_model($installed; .selected)
      | .selected as $selected_name
      | .selected_recommended = ($recommended | map(.name) | index($selected_name)) != null
      | .effective_model = (
          if .selected_installed then .selected
          else (first_recommended_installed($recommended; $installed))
          end
        )
      | .effective_model = (if (.effective_model | length) > 0 then .effective_model else first_installed($installed) end)
      | .effective_model = (if (.effective_model | length) > 0 then .effective_model else .selected end)
      | .status_message = (
          if ($enabled | not) then "Spam intelligence is off."
          elif ($ollama_installed | not) then "Install Ollama to enable local LLM scoring."
          elif ($daemon_running | not) then "Start Ollama daemon to run spam scoring."
          elif (has_model($installed; .selected) | not) then (
            if (has_model($installed; .effective_model))
            then ("Selected model " + .selected + " is not installed. Using " + .effective_model + ".")
            else ("Install " + .selected + " to score with the selected model.")
            end
          )
          else ("Ready: scoring with " + .effective_model + ".")
          end
        )
      | {
          enabled: $enabled,
          auto_install: $auto_install,
          selected_model: .selected,
          effective_model: .effective_model,
          selected_installed: .selected_installed,
          selected_recommended: .selected_recommended,
          recommended_model: .recommended_model,
          available_models: ensure_installed_visible($available; $installed),
          installed_models: $installed,
          recommended_models: $recommended,
          ollama_installed: $ollama_installed,
          daemon_running: $daemon_running,
          status_message: .status_message
        }
    '
}

resolve_ollama_bin() {
  if command -v ollama >/dev/null 2>&1; then
    command -v ollama
    return 0
  fi
  if [ -x "$HOME/.local/bin/ollama" ]; then
    printf '%s\n' "$HOME/.local/bin/ollama"
    return 0
  fi
  return 1
}

sanitize_spam_category() {
  raw=${1-}
  cleaned=$(printf '%s' "$raw" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9 _-]//g; s/[[:space:]]\+/ /g; s/^ //; s/ $//')
  if [ -z "$cleaned" ]; then
    cleaned='unknown'
  fi
  printf '%s' "$cleaned" | cut -c1-32
}

sanitize_spam_reason() {
  raw=${1-}
  cleaned=$(printf '%s' "$raw" \
    | tr '\r\n' '  ' \
    | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//; s/[#]/ /g')
  if [ -z "$cleaned" ]; then
    cleaned='No additional details.'
  fi
  printf '%s' "$cleaned" | cut -c1-180
}

spam_probability_from_rspamd_score() {
  score=${1-}
  awk -v s="$score" 'BEGIN {
    if (s !~ /^-?[0-9]+([.][0-9]+)?$/) {
      s = 0
    }
    p = 22
    if (s >= 12) p = 98
    else if (s >= 8) p = 90
    else if (s >= 6) p = 80
    else if (s >= 4) p = 68
    else if (s >= 2.5) p = 56
    else if (s >= 1) p = 44
    else if (s <= -1) p = 10
    if (p < 1) p = 1
    if (p > 99) p = 99
    printf "%d\n", p
  }'
}

spam_category_from_probability() {
  prob=${1-0}
  if [ "$prob" -ge 90 ]; then
    printf '%s' 'high-risk'
  elif [ "$prob" -ge 70 ]; then
    printf '%s' 'likely-spam'
  elif [ "$prob" -ge 45 ]; then
    printf '%s' 'uncertain'
  else
    printf '%s' 'likely-legit'
  fi
}

parse_llm_triplet() {
  raw=${1-}
  printf '%s\n' "$raw" | tr '\r' '\n' | awk -F'|' '
    {
      if (NF < 3) next
      prob=$1
      gsub(/[^0-9]/, "", prob)
      if (prob == "") next
      cat=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", cat)
      reason=$3
      for (i=4; i<=NF; i++) {
        reason=reason "|" $i
      }
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", reason)
      print prob "|" cat "|" reason
      exit
    }
  '
}

classify_spam_triplet() {
  model=${1-}
  from=${2-}
  subject=${3-}
  preview=${4-}
  rspamd_score=${5-}

  fallback_prob=$(spam_probability_from_rspamd_score "$rspamd_score")
  fallback_category=$(spam_category_from_probability "$fallback_prob")
  fallback_reason='Fallback heuristic from existing spam score.'

  if ! safe_model_name "$model"; then
    printf '%s|%s|%s|rspamd|%s\n' "$fallback_prob" "$fallback_category" "$fallback_reason" 'heuristic'
    return 0
  fi

  ollama_bin=$(resolve_ollama_bin || true)
  if [ -z "$ollama_bin" ]; then
    printf '%s|%s|%s|rspamd|%s\n' "$fallback_prob" "$fallback_category" "$fallback_reason" 'heuristic'
    return 0
  fi

  prompt=$(printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
    "You are Owl email spam classifier." \
    "Return exactly one line: <0-100>|<category>|<short reason>." \
    "No markdown. No extra lines." \
    "Category must be lowercase words." \
    "Reason must stay under 90 characters." \
    "" \
    "From: $from" \
    "Subject: $subject" \
    "Preview: $preview" \
    "" \
    "Output only the one-line result." \
    "")

  if command -v timeout >/dev/null 2>&1; then
    llm_out=$(timeout "$LLM_SPAM_TIMEOUT_SECS" "$ollama_bin" run "$model" "$prompt" 2>/dev/null || true)
  else
    llm_out=$("$ollama_bin" run "$model" "$prompt" 2>/dev/null || true)
  fi

  parsed=$(parse_llm_triplet "$llm_out")
  if [ -z "$parsed" ]; then
    printf '%s|%s|%s|rspamd|%s\n' "$fallback_prob" "$fallback_category" "$fallback_reason" 'heuristic'
    return 0
  fi

  prob=$(printf '%s\n' "$parsed" | awk -F'|' '{print $1}' | head -n 1)
  category=$(printf '%s\n' "$parsed" | awk -F'|' '{print $2}' | head -n 1)
  reason=$(printf '%s\n' "$parsed" | awk -F'|' '{print $3}' | head -n 1)
  case "$prob" in
    ''|*[!0-9]*) prob=$fallback_prob ;;
  esac
  if [ "$prob" -gt 100 ]; then
    prob=100
  fi
  if [ "$prob" -lt 0 ]; then
    prob=0
  fi
  category=$(sanitize_spam_category "$category")
  if [ -z "$category" ] || [ "$category" = "unknown" ]; then
    category=$(spam_category_from_probability "$prob")
  fi
  reason=$(sanitize_spam_reason "$reason")
  printf '%s|%s|%s|llm|%s\n' "$prob" "$category" "$reason" "$model"
}

latest_sidecar_for_sender_dir() {
  sender_dir=$1
  latest_ts=''
  latest_sidecar=''
  for sidecar in "$sender_dir"/.*.yml "$sender_dir"/*.yml; do
    [ -f "$sidecar" ] || continue
    ts=$(yaml_scalar "$sidecar" "received_at")
    if [ -z "$latest_ts" ] || [ "$ts" \> "$latest_ts" ]; then
      latest_ts=$ts
      latest_sidecar=$sidecar
    fi
  done
  printf '%s\n' "$latest_sidecar"
}

sidecar_spam_score_json() {
  list=$1
  sender=$2
  sidecar=$3
  model=$4

  ulid=$(yaml_scalar "$sidecar" "ulid")
  subject=$(yaml_scalar "$sidecar" "subject")
  from=$(yaml_scalar "$sidecar" "from")
  rspamd_score=$(yaml_scalar "$sidecar" "score")

  plain_path=$(sidecar_render_path "$sidecar" "plain" || true)
  eml_path=$(sidecar_eml_path "$sidecar")
  preview_src=''
  if [ -n "$plain_path" ] && [ -f "$plain_path" ]; then
    preview_src=$(head -n 8 "$plain_path" 2>/dev/null || true)
  elif [ -f "$eml_path" ]; then
    preview_src=$(extract_eml_body "$eml_path" | head -n 8 2>/dev/null || true)
  fi
  preview=$(compact_preview "$preview_src")

  existing_prob=$(yaml_scalar "$sidecar" "llm_spam_probability")
  existing_model=$(yaml_scalar "$sidecar" "llm_spam_model")
  existing_source=$(yaml_scalar "$sidecar" "llm_spam_source")
  existing_category=$(yaml_scalar "$sidecar" "llm_spam_category")
  existing_reason=$(yaml_scalar "$sidecar" "llm_spam_reason")
  use_cached=0
  if [ -n "$existing_prob" ] && printf '%s' "$existing_prob" | grep -Eq '^[0-9]+$'; then
    if [ "$existing_source" = "llm" ] && [ "$existing_model" = "$model" ] && [ -n "$model" ]; then
      use_cached=1
    elif [ "$existing_source" = "rspamd" ] && [ -z "$model" ]; then
      use_cached=1
    fi
  fi

  if [ "$use_cached" -eq 1 ]; then
    prob=$existing_prob
    category=$(sanitize_spam_category "$existing_category")
    reason=$(sanitize_spam_reason "$existing_reason")
    source=$existing_source
    model_used=$existing_model
    [ -n "$model_used" ] || model_used='heuristic'
  else
    scored=$(classify_spam_triplet "$model" "$from" "$subject" "$preview" "$rspamd_score")
    prob=$(printf '%s\n' "$scored" | awk -F'|' '{print $1}')
    category=$(printf '%s\n' "$scored" | awk -F'|' '{print $2}')
    reason=$(printf '%s\n' "$scored" | awk -F'|' '{print $3}')
    source=$(printf '%s\n' "$scored" | awk -F'|' '{print $4}')
    model_used=$(printf '%s\n' "$scored" | awk -F'|' '{print $5}')
    [ -n "$model_used" ] || model_used='heuristic'

    scored_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%SZ')
    set_yaml_scalar "$sidecar" "llm_spam_probability" "$prob"
    set_yaml_scalar "$sidecar" "llm_spam_category" "$(sanitize_spam_category "$category")"
    set_yaml_scalar "$sidecar" "llm_spam_reason" "$(sanitize_spam_reason "$reason")"
    set_yaml_scalar "$sidecar" "llm_spam_source" "$source"
    set_yaml_scalar "$sidecar" "llm_spam_model" "$model_used"
    set_yaml_scalar "$sidecar" "llm_spam_scored_at" "$scored_at"
  fi

  jq -cn \
    --arg list "$list" \
    --arg sender "$sender" \
    --arg ulid "$ulid" \
    --arg subject "$subject" \
    --arg category "$(sanitize_spam_category "$category")" \
    --arg reason "$(sanitize_spam_reason "$reason")" \
    --arg source "${source:-rspamd}" \
    --arg model "$model_used" \
    --argjson probability "${prob:-0}" \
    '{list:$list,sender:$sender,ulid:$ulid,subject:$subject,spam_probability:$probability,spam_category:$category,spam_reason:$reason,source:$source,model:$model}'
}

ssl_ready_for_smtp_host() {
  smtp_host=$1
  status_json=$(ssl_status_json_for_smtp_host "$smtp_host")
  printf '%s\n' "$status_json" | jq -r '.ready'
}

first_existing_ssl_pair_for_smtp_host() {
  smtp_host=$1
  email_domain=$(email_domain_from_smtp_host "$smtp_host")
  live_root="$ROOT/config/letsencrypt/live"

  for base in \
    "$live_root" \
    "$live_root/$smtp_host" \
    "$live_root/$email_domain"
  do
    cert_file="$base/fullchain.pem"
    key_file="$base/privkey.pem"
    if [ -f "$cert_file" ] && [ -f "$key_file" ]; then
      printf '%s|%s|%s\n' "$cert_file" "$key_file" "$base"
      return 0
    fi
  done
  return 1
}

cert_expiry_epoch() {
  cert_file=$1
  if ! command -v openssl >/dev/null 2>&1; then
    return 1
  fi
  not_after=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | sed 's/^notAfter=//')
  [ -n "$not_after" ] || return 1

  if expiry_epoch=$(date -j -f "%b %e %T %Y %Z" "$not_after" "+%s" 2>/dev/null); then
    printf '%s\n' "$expiry_epoch"
    return 0
  fi
  if expiry_epoch=$(date -d "$not_after" "+%s" 2>/dev/null); then
    printf '%s\n' "$expiry_epoch"
    return 0
  fi
  return 1
}

ssl_status_json_for_smtp_host() {
  smtp_host=$1
  now_epoch=$(date +%s)
  if pair=$(first_existing_ssl_pair_for_smtp_host "$smtp_host"); then
    cert_file=${pair%%|*}
    rest=${pair#*|}
    key_file=${rest%%|*}
    base_dir=${rest#*|}
    expires_epoch=''
    expires_at=''
    days_remaining=''
    expiring_soon=false
    if expires_epoch=$(cert_expiry_epoch "$cert_file"); then
      if expires_at=$(date -r "$expires_epoch" "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null); then
        :
      elif expires_at=$(date -u -d "@$expires_epoch" "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null); then
        :
      else
        expires_at=''
      fi
      days_remaining=$(( (expires_epoch - now_epoch) / 86400 ))
      if [ "$days_remaining" -le 21 ]; then
        expiring_soon=true
      fi
    fi
    jq -cn \
      --arg cert_path "$cert_file" \
      --arg key_path "$key_file" \
      --arg source_dir "$base_dir" \
      --arg expires_at "$expires_at" \
      --argjson days_remaining "${days_remaining:-null}" \
      --argjson expiring_soon "$expiring_soon" \
      '{ready:true,cert_path:$cert_path,key_path:$key_path,source_dir:$source_dir,expires_at:$expires_at,days_remaining:$days_remaining,expiring_soon:$expiring_soon}'
    return 0
  fi

  jq -cn '{ready:false,cert_path:"",key_path:"",source_dir:"",expires_at:"",days_remaining:null,expiring_soon:false}'
}

ensure_ssl_live_links_for_smtp_host() {
  smtp_host=$1
  email_domain=$(email_domain_from_smtp_host "$smtp_host")
  status_json=$(ssl_status_json_for_smtp_host "$smtp_host")
  ready=$(printf '%s\n' "$status_json" | jq -r '.ready')
  [ "$ready" = "true" ] || return 1

  cert_file=$(printf '%s\n' "$status_json" | jq -r '.cert_path')
  key_file=$(printf '%s\n' "$status_json" | jq -r '.key_path')
  source_dir=$(printf '%s\n' "$status_json" | jq -r '.source_dir')
  live_root="$ROOT/config/letsencrypt/live"

  mkdir -p "$live_root"
  if [ "$source_dir" != "$live_root" ]; then
    ln -sfn "$cert_file" "$live_root/fullchain.pem"
    ln -sfn "$key_file" "$live_root/privkey.pem"
  fi
  if [ -n "$smtp_host" ] && [ "$source_dir" != "$live_root/$smtp_host" ]; then
    mkdir -p "$live_root/$smtp_host"
    ln -sfn "$cert_file" "$live_root/$smtp_host/fullchain.pem"
    ln -sfn "$key_file" "$live_root/$smtp_host/privkey.pem"
  fi
  if [ -n "$email_domain" ] && [ "$source_dir" != "$live_root/$email_domain" ]; then
    mkdir -p "$live_root/$email_domain"
    ln -sfn "$cert_file" "$live_root/$email_domain/fullchain.pem"
    ln -sfn "$key_file" "$live_root/$email_domain/privkey.pem"
  fi
  return 0
}

derive_email_local_part() {
  recipient=$1
  if [ -z "$recipient" ]; then
    printf '%s' ''
    return 0
  fi
  case "$recipient" in
    *@*)
      printf '%s' "${recipient%@*}"
      ;;
    *)
      printf '%s' "$recipient"
      ;;
  esac
}

email_domain_from_recipient() {
  recipient=$(printf '%s' "${1-}" | tr '[:upper:]' '[:lower:]' | tr -d '\r\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  case "$recipient" in
    *@*)
      printf '%s' "${recipient#*@}"
      ;;
    *)
      printf '%s' ''
      ;;
  esac
}

validate_test_recipient_email() {
  recipient=$(printf '%s' "${1-}" | tr -d '\r\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  case "$recipient" in
    ''|@*|*@|*@*@*|*[[:space:]]*|*[!A-Za-z0-9._%+@-]*)
      return 1
      ;;
  esac
  case "$recipient" in
    *@*.*)
      return 0
      ;;
  esac
  return 1
}

daemon_manager_name() {
  case "$(uname -s)" in
    Darwin)
      printf 'launchd\n'
      ;;
    Linux)
      if command -v systemctl >/dev/null 2>&1; then
        printf 'systemd\n'
      else
        printf 'none\n'
      fi
      ;;
    *)
      printf 'none\n'
      ;;
  esac
}

DAEMON_SERVICE_SCRIPT="$REPO_ROOT/scripts/owl-daemon-service"
WIZARDRY_MAIL_OPS_INSTALLER="$HOME/.wizardry/spells/system/install-mail-ops-tools"

daemon_service_available() {
  [ -x "$DAEMON_SERVICE_SCRIPT" ] || return 1
  [ "$(daemon_manager_name)" != "none" ] || return 1
  return 0
}

daemon_is_installed() {
  if daemon_service_available && "$DAEMON_SERVICE_SCRIPT" --status-installed >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

daemon_is_running() {
  if daemon_service_available && "$DAEMON_SERVICE_SCRIPT" --status-running >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

daemon_is_enabled() {
  if daemon_service_available && "$DAEMON_SERVICE_SCRIPT" --status-enabled >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

daemon_status_json() {
  manager=$(daemon_manager_name)
  if daemon_service_available; then
    available=true
  else
    available=false
  fi
  installed=false
  running=false
  startup_enabled=false
  if daemon_is_installed; then
    installed=true
  fi
  if daemon_is_running; then
    running=true
  fi
  if daemon_is_enabled; then
    startup_enabled=true
  fi
  jq -cn \
    --arg manager "$manager" \
    --argjson available "$available" \
    --argjson installed "$installed" \
    --argjson running "$running" \
    --argjson startup_enabled "$startup_enabled" \
    '{available:$available,manager:$manager,installed:$installed,running:$running,startup_enabled:$startup_enabled}'
}

daemon_require_available() {
  [ -x "$DAEMON_SERVICE_SCRIPT" ] || {
    printf '%s\n' "owl-desktop-backend: missing daemon service helper: $DAEMON_SERVICE_SCRIPT" >&2
    exit 1
  }
  manager=$(daemon_manager_name)
  [ "$manager" != "none" ] || {
    printf '%s\n' "owl-desktop-backend: daemon service control unsupported on this platform" >&2
    exit 1
  }
}

ensure_wizardry_mail_ops_installer() {
  installer_dir=$(dirname "$WIZARDRY_MAIL_OPS_INSTALLER")
  mkdir -p "$installer_dir"
  if [ -x "$WIZARDRY_MAIL_OPS_INSTALLER" ]; then
    return 0
  fi
  cat >"$WIZARDRY_MAIL_OPS_INSTALLER" <<'EOF'
#!/bin/sh
set -eu
repo_root="${OWL_REPO_ROOT:-}"
if [ -z "$repo_root" ]; then
  printf '%s\n' "install-mail-ops-tools: OWL_REPO_ROOT not set" >&2
  exit 1
fi
script="$repo_root/scripts/install-mail-ops-tools"
if [ ! -x "$script" ]; then
  printf '%s\n' "install-mail-ops-tools: missing script $script" >&2
  exit 1
fi
exec "$script" "$@"
EOF
  chmod +x "$WIZARDRY_MAIL_OPS_INSTALLER"
}

ssl_prereq_status_json() {
  certbot_installed=false
  if command -v certbot >/dev/null 2>&1; then
    certbot_installed=true
  fi
  wizardry_installer=false
  if [ -x "$WIZARDRY_MAIL_OPS_INSTALLER" ]; then
    wizardry_installer=true
  fi
  jq -cn \
    --argjson certbot_installed "$certbot_installed" \
    --argjson wizardry_installer "$wizardry_installer" \
    '{certbot_installed:$certbot_installed,wizardry_installer:$wizardry_installer}'
}

install_ssl_prereqs_if_needed() {
  if command -v certbot >/dev/null 2>&1; then
    printf '%s' "certbot already installed"
    return 0
  fi

  out=''
  if ensure_wizardry_mail_ops_installer && [ -x "$WIZARDRY_MAIL_OPS_INSTALLER" ]; then
    if out=$(OWL_REPO_ROOT="$REPO_ROOT" "$WIZARDRY_MAIL_OPS_INSTALLER" 2>&1); then
      if command -v certbot >/dev/null 2>&1; then
        printf '%s' "$out"
        return 0
      fi
    fi
  fi

  owl_installer="$REPO_ROOT/scripts/install-mail-ops-tools"
  if [ -x "$owl_installer" ]; then
    if out=$("$owl_installer" 2>&1); then
      if command -v certbot >/dev/null 2>&1; then
        printf '%s' "$out"
        return 0
      fi
    fi
  fi

  os_name=$(uname -s)
  if [ "$os_name" = "Darwin" ]; then
    if ! command -v brew >/dev/null 2>&1; then
      printf '%s\n' "Homebrew is required to install certbot automatically on macOS." >&2
      return 1
    fi
    as_root true >/dev/null 2>&1 || {
      printf '%s\n' "Installing certbot needs admin rights. Please run with sudo privileges available." >&2
      return 1
    }
    out=$(brew install certbot 2>&1) || {
      printf '%s\n' "$out" >&2
      return 1
    }
    if command -v certbot >/dev/null 2>&1; then
      printf '%s' "$out"
      return 0
    fi
  fi

  if command -v apt-get >/dev/null 2>&1; then
    as_root apt-get update >/dev/null 2>&1 || return 1
    out=$(as_root apt-get install -y certbot 2>&1) || {
      printf '%s\n' "$out" >&2
      return 1
    }
    if command -v certbot >/dev/null 2>&1; then
      printf '%s' "$out"
      return 0
    fi
  elif command -v dnf >/dev/null 2>&1; then
    out=$(as_root dnf install -y certbot 2>&1) || {
      printf '%s\n' "$out" >&2
      return 1
    }
    if command -v certbot >/dev/null 2>&1; then
      printf '%s' "$out"
      return 0
    fi
  elif command -v pacman >/dev/null 2>&1; then
    out=$(as_root pacman -Sy --noconfirm certbot 2>&1) || {
      printf '%s\n' "$out" >&2
      return 1
    }
    if command -v certbot >/dev/null 2>&1; then
      printf '%s' "$out"
      return 0
    fi
  fi

  printf '%s\n' "Unable to install certbot automatically. Install certbot first, then retry SSL setup." >&2
  return 1
}

is_sender_list() {
  case "$1" in
    quarantine|accepted|spam|banned|archive|trash)
      return 0
      ;;
  esac
  return 1
}

is_flat_list() {
  case "$1" in
    outbox|sent)
      return 0
      ;;
  esac
  return 1
}

strip_yaml_quotes() {
  value=$(printf '%s' "${1-}" | tr -d '\r')
  case "$value" in
    null)
      printf '%s' ''
      return 0
      ;;
    "\""*"\"")
      value=${value#\"}
      value=${value%\"}
      value=$(printf '%s' "$value" | sed 's/\\\"/"/g; s/\\\\/\\/g')
      ;;
    "'"*"'")
      value=${value#\'}
      value=${value%\'}
      value=$(printf '%s' "$value" | sed "s/''/'/g")
      ;;
  esac
  printf '%s' "$value"
}

yaml_scalar_raw() {
  file=$1
  key=$2
  awk -v key="$key" '
    {
      line=$0
      gsub(/\r/, "", line)
      sub(/^[[:space:]]+/, "", line)
      if (line ~ ("^" key ":[[:space:]]*")) {
        sub(/^[^:]+:[[:space:]]*/, "", line)
        print line
        exit
      }
    }
  ' "$file"
}

yaml_scalar() {
  file=$1
  key=$2
  strip_yaml_quotes "$(yaml_scalar_raw "$file" "$key")"
}

yaml_bool() {
  file=$1
  key=$2
  value=$(yaml_scalar "$file" "$key" | tr '[:upper:]' '[:lower:]')
  case "$value" in
    true|1|yes)
      printf '%s' 'true'
      ;;
    *)
      printf '%s' 'false'
      ;;
  esac
}

json_bool() {
  case "${1-}" in
    true|1|yes)
      printf '%s' 'true'
      ;;
    *)
      printf '%s' 'false'
      ;;
  esac
}

sidecar_eml_path() {
  sidecar=$1
  base=$(basename "$sidecar")
  eml=${base#.}
  eml=${eml%.yml}.eml
  printf '%s/%s\n' "$(dirname "$sidecar")" "$eml"
}

sidecar_render_path() {
  sidecar=$1
  key=$2
  rel=$(yaml_scalar "$sidecar" "$key")
  if [ -z "$rel" ]; then
    return 0
  fi
  case "$rel" in
    /*)
      printf '%s\n' "$rel"
      ;;
    *)
      printf '%s/%s\n' "$(dirname "$sidecar")" "$rel"
      ;;
  esac
}

extract_eml_body() {
  eml=$1
  awk '
    BEGIN { body=0 }
    {
      gsub(/\r/, "")
      if (body) {
        print
      } else if ($0 == "") {
        body=1
      }
    }
  ' "$eml"
}

compact_preview() {
  text=${1-}
  printf '%s' "$text" \
    | tr '\n\r\t' '   ' \
    | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//' \
    | cut -c1-220
}

unique_destination_path() {
  candidate=$1
  if [ ! -e "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  dir=$(dirname "$candidate")
  base=$(basename "$candidate")
  ext=''
  stem=$base
  case "$base" in
    *.*)
      ext=".${base##*.}"
      stem=${base%"$ext"}
      ;;
  esac
  i=2
  while :; do
    next="$dir/$stem-$i$ext"
    if [ ! -e "$next" ]; then
      printf '%s\n' "$next"
      return 0
    fi
    i=$((i + 1))
  done
}

sidecar_attachment_count() {
  sidecar=$1
  awk 'BEGIN{c=0} /^[[:space:]]*-[[:space:]]*sha256:/ {c++} END{print c+0}' "$sidecar"
}

count_sidecars_in_dir() {
  dir=$1
  if [ ! -d "$dir" ]; then
    printf '%s\n' 0
    return
  fi
  find "$dir" -maxdepth 1 -type f -name '*.yml' 2>/dev/null | wc -l | tr -d ' '
}

count_messages_for_sender_list() {
  list=$1
  if [ ! -d "$ROOT/$list" ]; then
    printf '%s\n' 0
    return
  fi
  find "$ROOT/$list" -type f -name '*.yml' 2>/dev/null | wc -l | tr -d ' '
}

count_senders_for_list() {
  list=$1
  if [ ! -d "$ROOT/$list" ]; then
    printf '%s\n' 0
    return
  fi
  total=0
  for dir in "$ROOT/$list"/*; do
    [ -d "$dir" ] || continue
    base=$(basename "$dir")
    [ "$base" = "attachments" ] && continue
    count=$(count_sidecars_in_dir "$dir")
    if [ "${count:-0}" -gt 0 ]; then
      total=$((total + 1))
    fi
  done
  printf '%s\n' "$total"
}

count_flat_sidecars() {
  list=$1
  if [ ! -d "$ROOT/$list" ]; then
    printf '%s\n' 0
    return
  fi
  find "$ROOT/$list" -maxdepth 1 -type f -name '*.yml' 2>/dev/null | wc -l | tr -d ' '
}

latest_timestamp_for_sender() {
  sender_dir=$1
  latest=''
  for sidecar in "$sender_dir"/.*.yml "$sender_dir"/*.yml; do
    [ -f "$sidecar" ] || continue
    ts=$(yaml_scalar "$sidecar" "received_at")
    if [ -z "$latest" ] || [ "$ts" \> "$latest" ]; then
      latest=$ts
    fi
  done
  printf '%s' "$latest"
}

emit_sender_json() {
  list=$1
  sender_dir=$2
  sender=$(basename "$sender_dir")
  count=0
  unread=0
  starred=0
  pinned=0
  spam_probability=-1
  spam_category=''
  spam_source=''
  spam_model=''
  for sidecar in "$sender_dir"/.*.yml "$sender_dir"/*.yml; do
    [ -f "$sidecar" ] || continue
    count=$((count + 1))
    if [ "$(yaml_bool "$sidecar" "read")" = "false" ]; then
      unread=$((unread + 1))
    fi
    if [ "$(yaml_bool "$sidecar" "starred")" = "true" ]; then
      starred=$((starred + 1))
    fi
    if [ "$(yaml_bool "$sidecar" "pinned")" = "true" ]; then
      pinned=$((pinned + 1))
    fi
    current_prob=$(yaml_scalar "$sidecar" "llm_spam_probability")
    if [ -n "$current_prob" ] && printf '%s' "$current_prob" | grep -Eq '^[0-9]+$'; then
      if [ "$current_prob" -gt 100 ]; then
        current_prob=100
      fi
      if [ "$current_prob" -lt 0 ]; then
        current_prob=0
      fi
      if [ "$current_prob" -gt "$spam_probability" ]; then
        spam_probability=$current_prob
        spam_category=$(yaml_scalar "$sidecar" "llm_spam_category")
        spam_source=$(yaml_scalar "$sidecar" "llm_spam_source")
        spam_model=$(yaml_scalar "$sidecar" "llm_spam_model")
      fi
    fi
  done
  latest=$(latest_timestamp_for_sender "$sender_dir")
  if [ "$spam_probability" -lt 0 ]; then
    spam_probability='null'
  fi
  jq -cn \
    --arg list "$list" \
    --arg sender "$sender" \
    --arg latest "$latest" \
    --arg spam_category "$spam_category" \
    --arg spam_source "$spam_source" \
    --arg spam_model "$spam_model" \
    --argjson spam_probability "$spam_probability" \
    --argjson count "$count" \
    --argjson unread "$unread" \
    --argjson starred "$starred" \
    --argjson pinned "$pinned" \
    '{list:$list,sender:$sender,count:$count,unread:$unread,starred:$starred,pinned:$pinned,latest:$latest,llm_spam_probability:$spam_probability,llm_spam_category:$spam_category,llm_spam_source:$spam_source,llm_spam_model:$spam_model}'
}

collect_sender_json_for_list() {
  list=$1
  list_dir="$ROOT/$list"
  [ -d "$list_dir" ] || return 0
  for sender_dir in "$list_dir"/*; do
    [ -d "$sender_dir" ] || continue
    base=$(basename "$sender_dir")
    [ "$base" = "attachments" ] && continue
    count=$(count_sidecars_in_dir "$sender_dir")
    [ "$count" -gt 0 ] || continue
    emit_sender_json "$list" "$sender_dir"
  done
}

emit_message_json() {
  list=$1
  sender=$2
  sidecar=$3
  mode=${4-full}
  ulid=$(yaml_scalar "$sidecar" "ulid")
  subject=$(yaml_scalar "$sidecar" "subject")
  from=$(yaml_scalar "$sidecar" "from")
  to=$(yaml_scalar "$sidecar" "to")
  received_at=$(yaml_scalar "$sidecar" "received_at")
  status=$(yaml_scalar "$sidecar" "status_shadow")
  read=$(yaml_bool "$sidecar" "read")
  starred=$(yaml_bool "$sidecar" "starred")
  pinned=$(yaml_bool "$sidecar" "pinned")
  rspamd_score=$(yaml_scalar "$sidecar" "score")
  llm_spam_probability=$(yaml_scalar "$sidecar" "llm_spam_probability")
  llm_spam_category=$(yaml_scalar "$sidecar" "llm_spam_category")
  llm_spam_reason=$(yaml_scalar "$sidecar" "llm_spam_reason")
  llm_spam_source=$(yaml_scalar "$sidecar" "llm_spam_source")
  llm_spam_model=$(yaml_scalar "$sidecar" "llm_spam_model")
  attachments=$(sidecar_attachment_count "$sidecar")
  eml_path=''
  html_path=''
  plain_path=''
  preview=''

  if [ "$mode" = "full" ]; then
    eml_path=$(sidecar_eml_path "$sidecar")
    html_path=$(sidecar_render_path "$sidecar" "html" || true)
    plain_path=$(sidecar_render_path "$sidecar" "plain" || true)
    preview_src=''
    if [ -n "$plain_path" ] && [ -f "$plain_path" ]; then
      preview_src=$(head -n 8 "$plain_path" 2>/dev/null || true)
    elif [ -f "$eml_path" ]; then
      preview_src=$(extract_eml_body "$eml_path" | head -n 8 2>/dev/null || true)
    fi
    preview=$(compact_preview "$preview_src")
    [ -f "$eml_path" ] || eml_path=''
    [ -n "$html_path" ] && [ -f "$html_path" ] || html_path=''
    [ -n "$plain_path" ] && [ -f "$plain_path" ] || plain_path=''
  fi
  llm_spam_probability_json='null'
  if [ -n "$llm_spam_probability" ] && printf '%s' "$llm_spam_probability" | grep -Eq '^[0-9]+$'; then
    if [ "$llm_spam_probability" -gt 100 ]; then
      llm_spam_probability=100
    fi
    if [ "$llm_spam_probability" -lt 0 ]; then
      llm_spam_probability=0
    fi
    llm_spam_probability_json=$llm_spam_probability
  fi

  jq -cn \
    --arg list "$list" \
    --arg sender "$sender" \
    --arg ulid "$ulid" \
    --arg subject "$subject" \
    --arg from "$from" \
    --arg to "$to" \
    --arg received_at "$received_at" \
    --arg status "$status" \
    --arg eml_path "$eml_path" \
    --arg html_path "$html_path" \
    --arg plain_path "$plain_path" \
    --arg preview "$preview" \
    --arg rspamd_score "$rspamd_score" \
    --arg llm_spam_category "$llm_spam_category" \
    --arg llm_spam_reason "$llm_spam_reason" \
    --arg llm_spam_source "$llm_spam_source" \
    --arg llm_spam_model "$llm_spam_model" \
    --argjson llm_spam_probability "$llm_spam_probability_json" \
    --argjson read "$(json_bool "$read")" \
    --argjson starred "$(json_bool "$starred")" \
    --argjson pinned "$(json_bool "$pinned")" \
    --argjson attachments "$attachments" \
    '{list:$list,sender:$sender,ulid:$ulid,subject:$subject,from:$from,to:$to,received_at:$received_at,status:$status,read:$read,starred:$starred,pinned:$pinned,attachments:$attachments,rspamd_score:$rspamd_score,llm_spam_probability:$llm_spam_probability,llm_spam_category:$llm_spam_category,llm_spam_reason:$llm_spam_reason,llm_spam_source:$llm_spam_source,llm_spam_model:$llm_spam_model,preview:$preview,eml_path:$eml_path,html_path:$html_path,plain_path:$plain_path}'
}

collect_messages_sender_list() {
  list=$1
  sender_filter=${2-}
  mode=${3-full}
  list_dir="$ROOT/$list"
  [ -d "$list_dir" ] || return 0

  if [ -n "$sender_filter" ]; then
    sender_dir="$list_dir/$sender_filter"
    [ -d "$sender_dir" ] || return 0
    for sidecar in "$sender_dir"/.*.yml "$sender_dir"/*.yml; do
      [ -f "$sidecar" ] || continue
      emit_message_json "$list" "$sender_filter" "$sidecar" "$mode"
    done
    return 0
  fi

  for sender_dir in "$list_dir"/*; do
    [ -d "$sender_dir" ] || continue
    sender_name=$(basename "$sender_dir")
    [ "$sender_name" = "attachments" ] && continue
    for sidecar in "$sender_dir"/.*.yml "$sender_dir"/*.yml; do
      [ -f "$sidecar" ] || continue
      emit_message_json "$list" "$sender_name" "$sidecar" "$mode"
    done
  done
}

collect_messages_flat_list() {
  list=$1
  mode=${2-full}
  list_dir="$ROOT/$list"
  [ -d "$list_dir" ] || return 0
  for sidecar in "$list_dir"/.*.yml "$list_dir"/*.yml; do
    [ -f "$sidecar" ] || continue
    sender_name=$(yaml_scalar "$sidecar" "from")
    emit_message_json "$list" "$sender_name" "$sidecar" "$mode"
  done
}

find_sidecar_for_message() {
  list=$1
  sender=$2
  ulid=$3

  if is_flat_list "$list"; then
    dir="$ROOT/$list"
    [ -d "$dir" ] || return 1
    for sidecar in "$dir"/.*.yml "$dir"/*.yml; do
      [ -f "$sidecar" ] || continue
      candidate=$(yaml_scalar "$sidecar" "ulid")
      if [ "$candidate" = "$ulid" ]; then
        printf '%s\n' "$sidecar"
        return 0
      fi
    done
    return 1
  fi

  if ! is_sender_list "$list"; then
    return 1
  fi

  dir="$ROOT/$list/$sender"
  [ -d "$dir" ] || return 1
  for sidecar in "$dir"/.*.yml "$dir"/*.yml; do
    [ -f "$sidecar" ] || continue
    candidate=$(yaml_scalar "$sidecar" "ulid")
    if [ "$candidate" = "$ulid" ]; then
      printf '%s\n' "$sidecar"
      return 0
    fi
  done
  return 1
}

set_yaml_scalar() {
  file=$1
  key=$2
  value=$3
  tmp=$(mktemp "${TMPDIR:-/tmp}/owl-desktop-yml.XXXXXX")
  awk -v key="$key" -v value="$value" '
    BEGIN { replaced = 0 }
    {
      line=$0
      stripped=line
      sub(/^[[:space:]]+/, "", stripped)
      if (stripped ~ ("^" key ":[[:space:]]*")) {
        indent=""
        match(line, /^[[:space:]]*/)
        if (RLENGTH > 0) {
          indent=substr(line, 1, RLENGTH)
        }
        print indent key ": " value
        replaced=1
        next
      }
      print line
    }
    END {
      if (!replaced) {
        print key ": " value
      }
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

update_sidecar_status() {
  sidecar=$1
  status=$2
  set_yaml_scalar "$sidecar" "status_shadow" "$status"
}

touch_sidecar_activity() {
  sidecar=$1
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  set_yaml_scalar "$sidecar" "last_activity" "\"$now\""
}

remove_message_files() {
  sidecar=$1
  eml=$(sidecar_eml_path "$sidecar")
  html=$(sidecar_render_path "$sidecar" "html" || true)
  [ -f "$eml" ] && rm -f "$eml"
  [ -n "$html" ] && [ -f "$html" ] && rm -f "$html"
  rm -f "$sidecar"
}

yaml_single_quote() {
  raw=${1-}
  escaped=$(printf '%s' "$raw" | sed "s/'/''/g")
  printf "'%s'" "$escaped"
}

generate_ulid() {
  prefix=$(LC_ALL=C tr -dc '0-7' </dev/urandom | head -c 1)
  suffix=$(LC_ALL=C tr -dc '0-9A-HJKMNP-TV-Z' </dev/urandom | head -c 25)
  printf '%s%s\n' "$prefix" "$suffix"
}

file_mtime_epoch() {
  file=$1
  if stat -f %m "$file" >/dev/null 2>&1; then
    stat -f %m "$file"
  else
    stat -c %Y "$file"
  fi
}

draft_field() {
  file=$1
  key=$2
  awk -v key="$key" '
    BEGIN { in_front = 0 }
    NR == 1 {
      if ($0 == "---") {
        in_front = 1
        next
      }
    }
    in_front == 1 {
      if ($0 == "---") {
        exit
      }
      line = $0
      if (line ~ ("^" key ":[[:space:]]*")) {
        sub(/^[^:]+:[[:space:]]*/, "", line)
        print line
        exit
      }
    }
  ' "$file"
}

draft_first_body_line() {
  file=$1
  awk '
    BEGIN { in_front = 0; front_done = 0 }
    NR == 1 && $0 == "---" {
      in_front = 1
      next
    }
    in_front == 1 {
      if ($0 == "---") {
        in_front = 0
        front_done = 1
      }
      next
    }
    front_done == 1 {
      line=$0
      gsub(/\r/, "", line)
      if (line !~ /^[[:space:]]*$/) {
        print line
        exit
      }
    }
  ' "$file"
}

contacts_vcard_dir() {
  printf '%s\n' "$USER_HOME/.contacts"
}

ensure_contacts_vcard_dir() {
  dir=$(contacts_vcard_dir)
  mkdir -p "$dir"
  printf '%s\n' "$dir"
}

sanitize_contact_filename() {
  raw=${1-}
  cleaned=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._@-' '-')
  cleaned=$(printf '%s' "$cleaned" | sed 's/^-*//; s/-*$//')
  if [ -z "$cleaned" ]; then
    cleaned="contact"
  fi
  printf '%s\n' "$cleaned"
}

vcard_escape_value() {
  raw=${1-}
  escaped=$(printf '%s' "$raw" | awk 'BEGIN{RS=""; ORS=""} {gsub(/\r/, ""); gsub(/\\/, "\\\\"); gsub(/\n/, "\\n"); gsub(/,/, "\\,"); gsub(/;/, "\\;"); print}')
  printf '%s' "$escaped"
}

vcard_unescape_value() {
  raw=${1-}
  printf '%s' "$raw" | sed 's/\\n/ /g; s/\\,/,/g; s/\\;/;/g; s/\\\\/\\/g'
}

contact_vcard_field_raw() {
  file=$1
  wanted=$(printf '%s' "${2-}" | tr '[:upper:]' '[:lower:]')
  awk -v wanted="$wanted" '
    function flush_line() {
      if (line == "") {
        return
      }
      pos = index(line, ":")
      if (pos < 1) {
        line = ""
        return
      }
      left = tolower(substr(line, 1, pos - 1))
      value = substr(line, pos + 1)
      if (left == wanted || index(left, wanted ";") == 1) {
        out = value
      }
      line = ""
    }
    {
      if ($0 ~ /^[ \t]/) {
        sub(/^[ \t]+/, "", $0)
        line = line $0
        next
      }
      flush_line()
      line = $0
    }
    END {
      flush_line()
      printf "%s", out
    }
  ' "$file"
}

contact_vcard_field() {
  raw=$(contact_vcard_field_raw "$1" "$2")
  vcard_unescape_value "$raw"
}

contact_file_matches_identity() {
  file=$1
  identity=${2-}
  if [ -z "$identity" ] || [ ! -f "$file" ]; then
    return 1
  fi
  target=$(printf '%s' "$identity" | tr '[:upper:]' '[:lower:]')
  email_val=$(contact_vcard_field_raw "$file" "EMAIL" | tr '[:upper:]' '[:lower:]')
  identity_val=$(contact_vcard_field_raw "$file" "X-OWL-IDENTITY" | tr '[:upper:]' '[:lower:]')
  [ "$email_val" = "$target" ] || [ "$identity_val" = "$target" ]
}

resolve_contact_vcard_file() {
  identity=${1-}
  contact_key=${2-}
  dir=$(ensure_contacts_vcard_dir)
  for file in "$dir"/*.vcf; do
    [ -f "$file" ] || continue
    if contact_file_matches_identity "$file" "$identity"; then
      printf '%s\n' "$file"
      return 0
    fi
  done
  base="$identity"
  if [ -z "$base" ]; then
    base="$contact_key"
  fi
  base=$(sanitize_contact_filename "$base")
  printf '%s/%s.vcf\n' "$dir" "$base"
}

derive_name_from_identity() {
  identity=${1-}
  case "$identity" in
    *@*)
      printf '%s\n' "${identity%@*}"
      ;;
    *)
      printf '%s\n' "$identity"
      ;;
  esac
}

require_cmd jq

case "$action" in
  health)
    jq -n \
      --arg root "$ROOT" \
      --arg repo_root "$REPO_ROOT" \
      --arg mode "$OWL_MODE" \
      --arg bin "$OWL_BIN_PATH" \
      --arg has_owl "$(if [ "$OWL_MODE" = "none" ]; then printf 'false'; else printf 'true'; fi)" \
      '{ok:true,root:$root,repo_root:$repo_root,owl_mode:$mode,owl_bin:$bin,owl_available:($has_owl=="true")}'
    ;;

  overview)
    quarantine_senders=$(count_senders_for_list quarantine)
    quarantine_messages=$(count_messages_for_sender_list quarantine)
    accepted_messages=$(count_messages_for_sender_list accepted)
    spam_messages=$(count_messages_for_sender_list spam)
    banned_messages=$(count_messages_for_sender_list banned)
    spam_senders=$(count_senders_for_list spam)
    banned_senders=$(count_senders_for_list banned)
    archive_messages=$(count_messages_for_sender_list archive)
    trash_messages=$(count_messages_for_sender_list trash)
    drafts_count=$(find "$ROOT/drafts" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    outbox_count=$(count_flat_sidecars outbox)
    sent_count=$(count_flat_sidecars sent)

    jq -n \
      --arg root "$ROOT" \
      --argjson quarantine_senders "$quarantine_senders" \
      --argjson quarantine_messages "$quarantine_messages" \
      --argjson accepted_messages "$accepted_messages" \
      --argjson spam_messages "$spam_messages" \
      --argjson banned_messages "$banned_messages" \
      --argjson spam_senders "$spam_senders" \
      --argjson banned_senders "$banned_senders" \
      --argjson archive_messages "$archive_messages" \
      --argjson trash_messages "$trash_messages" \
      --argjson drafts_count "$drafts_count" \
      --argjson outbox_count "$outbox_count" \
      --argjson sent_count "$sent_count" \
      '{
        ok:true,
        root:$root,
        counts:{
          new_senders:$quarantine_senders,
          new_messages:$quarantine_messages,
          inbox_messages:$accepted_messages,
          spam_senders:($spam_senders + $banned_senders),
          spam_messages:($spam_messages + $banned_messages),
          archive_messages:$archive_messages,
          trash_messages:$trash_messages,
          drafts:$drafts_count,
          outbox:$outbox_count,
          sent:$sent_count
        }
      }'
    ;;

  settings-controls)
    test_recipient=$(load_test_recipient_value)
    smtp_host=$(settings_env_get smtp_host)
    email_domain=$(email_domain_from_smtp_host "$smtp_host")
    email_local_part=$(derive_email_local_part "$test_recipient")
    domain_configured_json=$(domain_configured_for_smtp_host "$smtp_host")
    ssl_status_json=$(ssl_status_json_for_smtp_host "$smtp_host")
    ssl_ready_json=$(printf '%s\n' "$ssl_status_json" | jq -r '.ready')
    ssl_path=$(printf '%s\n' "$ssl_status_json" | jq -r '.cert_path')
    ssl_expires_at=$(printf '%s\n' "$ssl_status_json" | jq -r '.expires_at')
    ssl_days_remaining=$(printf '%s\n' "$ssl_status_json" | jq -r '.days_remaining')
    ssl_expiring_soon=$(printf '%s\n' "$ssl_status_json" | jq -r '.expiring_soon')
    daemon_json=$(daemon_status_json)
    remote_json=$(load_remote_state_json)
    remote_auth_json=$(remote_auth_state_json "$remote_json")
    if folders_ready; then
      folders_ready_json=true
    else
      folders_ready_json=false
    fi
    jq -n \
      --arg test_recipient "$test_recipient" \
      --arg email_local_part "$email_local_part" \
      --arg smtp_host "$smtp_host" \
      --arg email_domain "$email_domain" \
      --arg ssl_path "$ssl_path" \
      --arg ssl_expires_at "$ssl_expires_at" \
      --argjson daemon "$daemon_json" \
      --argjson remote "$remote_json" \
      --argjson remote_auth "$remote_auth_json" \
      --argjson domain_configured "$domain_configured_json" \
      --argjson ssl_ready "$ssl_ready_json" \
      --argjson ssl_days_remaining "${ssl_days_remaining:-null}" \
      --argjson ssl_expiring_soon "$ssl_expiring_soon" \
      --argjson folders_ready "$folders_ready_json" \
      '{ok:true,test_recipient:$test_recipient,email_local_part:$email_local_part,smtp_host:$smtp_host,email_domain:$email_domain,domain_configured:$domain_configured,ssl_ready:$ssl_ready,ssl_path:$ssl_path,ssl_expires_at:$ssl_expires_at,ssl_days_remaining:$ssl_days_remaining,ssl_expiring_soon:$ssl_expiring_soon,daemon:$daemon,folders_ready:$folders_ready,remote:$remote,remote_auth:$remote_auth}'
    ;;

  settings-llm-controls)
    llm_json=$(llm_settings_state_json)
    jq -n --argjson llm "$llm_json" '{ok:true,llm:$llm}'
    ;;

  settings-llm-set)
    enabled_value=${3-}
    auto_install_value=${4-}
    model_value=${5-}
    case "$enabled_value" in
      0|1|true|false|yes|no|on|off) ;;
      *)
        printf '%s\n' "owl-desktop-backend: settings-llm-set ENABLED must be 0|1" >&2
        exit 2
        ;;
    esac
    case "$auto_install_value" in
      0|1|true|false|yes|no|on|off) ;;
      *)
        printf '%s\n' "owl-desktop-backend: settings-llm-set AUTO_INSTALL must be 0|1" >&2
        exit 2
        ;;
    esac
    enabled_flag=$(json_bool "$enabled_value")
    if [ "$enabled_flag" = "true" ]; then
      settings_env_set spam_llm_enabled "1"
    else
      settings_env_set spam_llm_enabled "0"
    fi
    # Manual model installation only: keep auto-install disabled.
    settings_env_set spam_llm_auto_install "0"
    if [ -n "$model_value" ]; then
      if ! safe_model_name "$model_value"; then
        printf '%s\n' "owl-desktop-backend: invalid model name for settings-llm-set" >&2
        exit 2
      fi
      settings_env_set spam_llm_model "$model_value"
    fi
    llm_json=$(llm_settings_state_json)
    jq -n --argjson llm "$llm_json" '{ok:true,llm:$llm}'
    ;;

  settings-llm-install-ollama)
    run_ai_dev_script install-ollama
    llm_json=$(llm_settings_state_json)
    jq -n --argjson llm "$llm_json" '{ok:true,llm:$llm}'
    ;;

  settings-llm-set-daemon)
    daemon_target=${3-}
    case "$daemon_target" in
      on)
        run_ai_dev_script start-ollama-daemon
        ;;
      off)
        run_ai_dev_script stop-ollama-daemon
        ;;
      *)
        printf '%s\n' "owl-desktop-backend: settings-llm-set-daemon requires on|off" >&2
        exit 2
        ;;
    esac
    llm_json=$(llm_settings_state_json)
    jq -n --argjson llm "$llm_json" '{ok:true,llm:$llm}'
    ;;

  settings-llm-install-model)
    model_value=${3-}
    if ! safe_model_name "$model_value"; then
      printf '%s\n' "owl-desktop-backend: settings-llm-install-model requires MODEL" >&2
      exit 2
    fi
    run_ai_dev_script install-llm "$model_value"
    settings_env_set spam_llm_model "$model_value"
    llm_json=$(llm_settings_state_json)
    jq -n --argjson llm "$llm_json" '{ok:true,llm:$llm}'
    ;;

  settings-llm-uninstall-model)
    model_value=${3-}
    if ! safe_model_name "$model_value"; then
      printf '%s\n' "owl-desktop-backend: settings-llm-uninstall-model requires MODEL" >&2
      exit 2
    fi
    run_ai_dev_script uninstall-llm "$model_value"
    llm_json=$(llm_settings_state_json)
    jq -n --argjson llm "$llm_json" '{ok:true,llm:$llm}'
    ;;

  spam-classify)
    list=${3-quarantine}
    sender_filter=${4-}
    limit=${5-}
    allow_install=${6-0}
    if [ -z "$limit" ] || ! printf '%s' "$limit" | grep -Eq '^[0-9]+$'; then
      if [ -n "$sender_filter" ]; then
        limit=12
      else
        limit=24
      fi
    fi
    if [ "$limit" -lt 1 ]; then
      limit=1
    fi
    if [ "$limit" -gt 200 ]; then
      limit=200
    fi
    case "$allow_install" in
      1|true|yes|on) allow_install=1 ;;
      *) allow_install=0 ;;
    esac
    if ! is_sender_list "$list"; then
      printf '%s\n' "owl-desktop-backend: spam-classify supports sender lists only" >&2
      exit 2
    fi

    llm_json=$(llm_settings_state_json)
    llm_enabled=$(printf '%s\n' "$llm_json" | jq -r '.enabled')
    llm_selected=$(printf '%s\n' "$llm_json" | jq -r '.selected_model')
    llm_effective=$(printf '%s\n' "$llm_json" | jq -r '.effective_model')
    llm_selected_installed=$(printf '%s\n' "$llm_json" | jq -r '.selected_installed')
    score_model=''
    status='heuristic'
    status_message='Using heuristic spam scoring fallback.'

    if [ "$llm_enabled" = "true" ]; then
      score_model=$llm_effective
      if [ "$llm_selected_installed" = "true" ]; then
        status='llm'
        status_message="Scoring with $score_model."
      else
        status='model-missing'
        status_message="Model $llm_selected is not installed. Install it from the model picker."
      fi
    fi
    if [ "$status" != "llm" ]; then
      score_model=''
    fi

    tmp_targets=$(mktemp "${TMPDIR:-/tmp}/owl-desktop-spam-targets.XXXXXX")
    tmp_scored=$(mktemp "${TMPDIR:-/tmp}/owl-desktop-spam-scored.XXXXXX")
    list_dir="$ROOT/$list"
    if [ -d "$list_dir" ]; then
      if [ -n "$sender_filter" ]; then
        sender_dir="$list_dir/$sender_filter"
        if [ -d "$sender_dir" ]; then
          for sidecar in "$sender_dir"/.*.yml "$sender_dir"/*.yml; do
            [ -f "$sidecar" ] || continue
            ts=$(yaml_scalar "$sidecar" "received_at")
            printf '%s|%s|%s\n' "$ts" "$sender_filter" "$sidecar" >>"$tmp_targets"
          done
        fi
      else
        for sender_dir in "$list_dir"/*; do
          [ -d "$sender_dir" ] || continue
          sender_name=$(basename "$sender_dir")
          [ "$sender_name" = "attachments" ] && continue
          latest_sidecar=$(latest_sidecar_for_sender_dir "$sender_dir")
          [ -n "$latest_sidecar" ] || continue
          ts=$(yaml_scalar "$latest_sidecar" "received_at")
          printf '%s|%s|%s\n' "$ts" "$sender_name" "$latest_sidecar" >>"$tmp_targets"
        done
      fi
    fi

    sort -r "$tmp_targets" 2>/dev/null | head -n "$limit" | while IFS='|' read -r _ sender_name sidecar_path; do
      [ -n "$sender_name" ] || continue
      [ -n "$sidecar_path" ] || continue
      [ -f "$sidecar_path" ] || continue
      sidecar_spam_score_json "$list" "$sender_name" "$sidecar_path" "$score_model" >>"$tmp_scored"
    done

    jq -n \
      --arg list "$list" \
      --arg status "$status" \
      --arg message "$status_message" \
      --arg model "$score_model" \
      --argjson llm "$llm_json" \
      --slurpfile scored "$tmp_scored" \
      '{ok:true,list:$list,status:$status,message:$message,model:$model,llm:$llm,scored:$scored}'
    rm -f "$tmp_targets" "$tmp_scored"
    ;;

  settings-browse-root)
    start_path=$(normalize_path "${3-}")
    picked_path=$(pick_directory_path "$start_path" "Choose mail folder")
    if [ -z "$picked_path" ]; then
      jq -n '{ok:true,path:"",cancelled:true}'
      exit 0
    fi
    picked_path=$(normalize_path "$picked_path")
    if [ ! -d "$picked_path" ]; then
      printf '%s\n' "owl-desktop-backend: selected folder no longer exists" >&2
      exit 1
    fi
    jq -n --arg path "$picked_path" '{ok:true,path:$path,cancelled:false}'
    ;;

  settings-set-test-recipient)
    next_value=${3-}
    save_test_recipient_value "$next_value"
    test_recipient=$(load_test_recipient_value)
    jq -n --arg test_recipient "$test_recipient" '{ok:true,test_recipient:$test_recipient}'
    ;;

  settings-verify-domain)
    requested_domain=$(normalize_domain_input "${3-}")
    settings_mode=$(normalize_server_mode "${4-local}")
    remote_target_hint=${5-}
    if ! validate_domain_name "$requested_domain"; then
      printf '%s\n' "owl-desktop-backend: settings-verify-domain requires a valid domain (example.org)" >&2
      exit 2
    fi
    smtp_host=$(mail_host_from_domain_and_mode "$requested_domain" "$settings_mode" "$remote_target_hint")
    root_a=$(dns_values_for A "$requested_domain")
    root_aaaa=$(dns_values_for AAAA "$requested_domain")
    smtp_a=$(dns_values_for A "$smtp_host")
    smtp_aaaa=$(dns_values_for AAAA "$smtp_host")
    smtp_cname=$(dns_values_for CNAME "$smtp_host")
    mx_records=$(dns_values_for MX "$requested_domain")

    root_a_json=$(printf '%s\n%s\n' "$root_a" "$root_aaaa" | json_array_from_lines)
    smtp_a_json=$(printf '%s\n%s\n' "$smtp_a" "$smtp_aaaa" | json_array_from_lines)
    smtp_cname_json=$(printf '%s\n' "$smtp_cname" | json_array_from_lines)
    mx_json=$(printf '%s\n' "$mx_records" | json_array_from_lines)

    root_ok=$(printf '%s' "$root_a_json" | jq 'length > 0')
    smtp_has_ip=$(printf '%s' "$smtp_a_json" | jq 'length > 0')
    smtp_has_cname=$(printf '%s' "$smtp_cname_json" | jq 'length > 0')
    smtp_ok=false
    if [ "$smtp_has_ip" = "true" ] || [ "$smtp_has_cname" = "true" ]; then
      smtp_ok=true
    fi
    mx_present=$(printf '%s' "$mx_json" | jq 'length > 0')
    mx_ok=false
    if [ "$mx_present" = "true" ] && printf '%s\n' "$mx_records" | grep -Eiq "(^|[[:space:]])$smtp_host\\.?($|[[:space:]])"; then
      mx_ok=true
    fi

    live_json=false
    if [ "$root_ok" = "true" ] || [ "$smtp_ok" = "true" ] || [ "$mx_present" = "true" ]; then
      live_json=true
    fi

    mail_ready=false
    if [ "$smtp_ok" = "true" ] && [ "$mx_ok" = "true" ]; then
      mail_ready=true
    fi

    ssl_dns_ready=false
    if [ "$root_ok" = "true" ] && [ "$smtp_ok" = "true" ] && [ "$mx_ok" = "true" ]; then
      ssl_dns_ready=true
    fi

    if [ "$live_json" != "true" ]; then
      message="No live DNS records found for this domain."
    else
      message_detail=''
      if [ "$smtp_ok" != "true" ]; then
        message_detail="First add A/AAAA or CNAME for $smtp_host."
      fi
      if [ "$mx_ok" != "true" ]; then
        if [ -n "$message_detail" ]; then
          message_detail="$message_detail Then add MX for @ with target $smtp_host (priority 10; MX target is a hostname, not an IP)."
        else
          message_detail="Add MX for @ with target $smtp_host (priority 10; MX target is a hostname, not an IP)."
        fi
      fi
      if [ "$root_ok" != "true" ]; then
        if [ -n "$message_detail" ]; then
          message_detail="$message_detail Root A/AAAA for $requested_domain is optional but recommended."
        else
          message_detail="Root A/AAAA for $requested_domain is optional but recommended."
        fi
      fi
      if [ -n "$message_detail" ]; then
        message="Domain is live in DNS. $message_detail"
      else
        message="Domain DNS is ready (SMTP host and MX detected)."
      fi
    fi
    jq -n \
      --arg domain "$requested_domain" \
      --arg mode "$settings_mode" \
      --arg remote_target "$remote_target_hint" \
      --arg smtp_host "$smtp_host" \
      --arg message "$message" \
      --argjson live "$live_json" \
      --argjson root_a_records "$root_a_json" \
      --argjson smtp_a_records "$smtp_a_json" \
      --argjson smtp_cname_records "$smtp_cname_json" \
      --argjson mx_records "$mx_json" \
      --argjson root_a_ok "$root_ok" \
      --argjson smtp_a_ok "$smtp_ok" \
      --argjson smtp_cname_ok "$smtp_has_cname" \
      --argjson mx_ok "$mx_ok" \
      --argjson mail_routing_ready "$mail_ready" \
      --argjson ssl_dns_ready "$ssl_dns_ready" \
      '{
        ok:true,
        domain:$domain,
        mode:$mode,
        remote_target:$remote_target,
        smtp_host:$smtp_host,
        live:$live,
        message:$message,
        checks:{
          root_a_ok:$root_a_ok,
          smtp_a_ok:$smtp_a_ok,
          smtp_cname_ok:$smtp_cname_ok,
          mx_ok:$mx_ok
        },
        records:{
          root_a:$root_a_records,
          smtp_a:$smtp_a_records,
          smtp_cname:$smtp_cname_records,
          mx:$mx_records
        },
        ready:{
          mail_routing:$mail_routing_ready,
          ssl_dns:$ssl_dns_ready
        }
      }'
    ;;

  settings-set-domain)
    requested_domain=$(normalize_domain_input "${3-}")
    settings_mode=$(normalize_server_mode "${4-local}")
    remote_target_hint=${5-}
    if ! validate_domain_name "$requested_domain"; then
      printf '%s\n' "owl-desktop-backend: settings-set-domain requires a valid domain (example.org)" >&2
      exit 2
    fi
    smtp_host=$(mail_host_from_domain_and_mode "$requested_domain" "$settings_mode" "$remote_target_hint")
    settings_env_set smtp_host "$smtp_host"
    settings_env_set smtp_starttls true
    current_recipient=$(load_test_recipient_value)
    current_local=$(derive_email_local_part "$current_recipient")
    if [ -n "$current_local" ]; then
      save_test_recipient_value "${current_local}@${requested_domain}"
    fi
    ssl_status_json=$(ssl_status_json_for_smtp_host "$smtp_host")
    ssl_ready_json=$(printf '%s\n' "$ssl_status_json" | jq -r '.ready')
    ssl_expires_at=$(printf '%s\n' "$ssl_status_json" | jq -r '.expires_at')
    ssl_days_remaining=$(printf '%s\n' "$ssl_status_json" | jq -r '.days_remaining')
    ssl_expiring_soon=$(printf '%s\n' "$ssl_status_json" | jq -r '.expiring_soon')
    jq -n \
      --arg smtp_host "$smtp_host" \
      --arg email_domain "$requested_domain" \
      --argjson ssl_ready "$ssl_ready_json" \
      --arg ssl_expires_at "$ssl_expires_at" \
      --argjson ssl_days_remaining "${ssl_days_remaining:-null}" \
      --argjson ssl_expiring_soon "$ssl_expiring_soon" \
      '{ok:true,smtp_host:$smtp_host,email_domain:$email_domain,ssl_ready:$ssl_ready,ssl_expires_at:$ssl_expires_at,ssl_days_remaining:$ssl_days_remaining,ssl_expiring_soon:$ssl_expiring_soon}'
    ;;

  settings-ssl-prereq-status)
    status_json=$(ssl_prereq_status_json)
    jq -n --argjson status "$status_json" '{ok:true,prereqs:$status}'
    ;;

  settings-ssl-wizard-status)
    settings_mode=$(normalize_server_mode "${3-local}")
    remote_target_hint=${4-}
    configured_smtp_host=$(settings_env_get smtp_host)
    email_domain=$(email_domain_from_smtp_host "$configured_smtp_host")
    if [ -z "$configured_smtp_host" ] || [ "$configured_smtp_host" = "127.0.0.1" ] || [ "$configured_smtp_host" = "localhost" ] || [ "$email_domain" = "127.0.0.1" ] || [ "$email_domain" = "localhost" ]; then
      printf '%s\n' "owl-desktop-backend: configure domain first before SSL wizard" >&2
      exit 2
    fi
    smtp_host=$(mail_host_from_domain_and_mode "$email_domain" "$settings_mode" "$remote_target_hint")
    root_a=$(dns_values_for A "$email_domain")
    root_aaaa=$(dns_values_for AAAA "$email_domain")
    smtp_a=$(dns_values_for A "$smtp_host")
    smtp_aaaa=$(dns_values_for AAAA "$smtp_host")
    smtp_cname=$(dns_values_for CNAME "$smtp_host")
    mx_records=$(dns_values_for MX "$email_domain")
    public_ip=$(detect_public_ip)
    certbot_installed=false
    if command -v certbot >/dev/null 2>&1; then
      certbot_installed=true
    fi
    root_a_json=$(printf '%s\n%s\n' "$root_a" "$root_aaaa" | json_array_from_lines)
    smtp_a_json=$(printf '%s\n%s\n' "$smtp_a" "$smtp_aaaa" | json_array_from_lines)
    smtp_cname_json=$(printf '%s\n' "$smtp_cname" | json_array_from_lines)
    mx_json=$(printf '%s\n' "$mx_records" | json_array_from_lines)
    root_ok=$(printf '%s' "$root_a_json" | jq 'length > 0')
    smtp_has_ip=$(printf '%s' "$smtp_a_json" | jq 'length > 0')
    smtp_has_cname=$(printf '%s' "$smtp_cname_json" | jq 'length > 0')
    smtp_ok=false
    if [ "$smtp_has_ip" = "true" ] || [ "$smtp_has_cname" = "true" ]; then
      smtp_ok=true
    fi
    mx_ok=false
    if printf '%s\n' "$mx_records" | grep -Eiq "(^|[[:space:]])$smtp_host\\.?($|[[:space:]])"; then
      mx_ok=true
    fi
    expected_ip=$(expected_mail_target_ip "$settings_mode" "$remote_target_hint")
    jq -n \
      --arg domain "$email_domain" \
      --arg mode "$settings_mode" \
      --arg remote_target "$remote_target_hint" \
      --arg smtp_host "$smtp_host" \
      --arg public_ip "$public_ip" \
      --arg expected_ip "$expected_ip" \
      --argjson certbot_installed "$certbot_installed" \
      --argjson root_a_records "$root_a_json" \
      --argjson smtp_a_records "$smtp_a_json" \
      --argjson smtp_cname_records "$smtp_cname_json" \
      --argjson mx_records "$mx_json" \
      --argjson root_ok "$root_ok" \
      --argjson smtp_ok "$smtp_ok" \
      --argjson smtp_cname_ok "$smtp_has_cname" \
      --argjson mx_ok "$mx_ok" \
      '{
        ok:true,
        domain:$domain,
        mode:$mode,
        remote_target:$remote_target,
        smtp_host:$smtp_host,
        public_ip:$public_ip,
        checks:{
          certbot_installed:$certbot_installed,
          root_a_ok:$root_ok,
          smtp_a_ok:$smtp_ok,
          smtp_cname_ok:$smtp_cname_ok,
          mx_ok:$mx_ok
        },
        records:{
          root_a:$root_a_records,
          smtp_a:$smtp_a_records,
          smtp_cname:$smtp_cname_records,
          mx:$mx_records
        },
        suggested_records:[
          {type:"A",name:$domain,value:$expected_ip},
          {type:"A",name:$smtp_host,value:$expected_ip},
          {type:"MX",name:$domain,value:$smtp_host,priority:10}
        ]
      }'
    ;;

  settings-setup-ssl)
    setup_mode=$(printf '%s' "${3-auto}" | tr '[:upper:]' '[:lower:]' | tr -d '\r\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    case "$setup_mode" in
      ''|auto|local|remote)
        ;;
      *)
        printf '%s\n' "owl-desktop-backend: settings-setup-ssl MODE must be auto|local|remote" >&2
        exit 2
        ;;
    esac

    smtp_host=$(settings_env_get smtp_host)
    email_domain=$(email_domain_from_smtp_host "$smtp_host")
    if [ -z "$smtp_host" ] || [ "$smtp_host" = "127.0.0.1" ] || [ "$smtp_host" = "localhost" ] || [ "$email_domain" = "127.0.0.1" ] || [ "$email_domain" = "localhost" ]; then
      printf '%s\n' "owl-desktop-backend: configure domain first before SSL setup" >&2
      exit 2
    fi

    remote_state_json=$(load_remote_state_json)
    host_arg=$(normalize_remote_target_input "${4-}")
    key_arg=$(normalize_ssh_key_path_input "${5-}")
    ssh_key_password_arg=${6-}
    ssh_port_arg=$(normalize_remote_port_input "${7-}")

    if [ -n "$host_arg" ] && ! validate_remote_target "$host_arg"; then
      printf '%s\n' "owl-desktop-backend: provide a valid remote host like user@example.org or user@203.0.113.8" >&2
      exit 2
    fi
    if [ -n "$key_arg" ] && ! validate_ssh_key_path "$key_arg"; then
      printf '%s\n' "owl-desktop-backend: provide a readable SSH key file path with no spaces" >&2
      exit 2
    fi
    if ! validate_remote_port "$ssh_port_arg"; then
      printf '%s\n' "owl-desktop-backend: provide a valid SSH port between 1 and 65535" >&2
      exit 2
    fi

    if [ -n "$host_arg" ]; then
      remote_host=$host_arg
    else
      remote_host=$(printf '%s\n' "$remote_state_json" | jq -r '.host // ""')
    fi
    if [ -n "$key_arg" ]; then
      remote_key_path=$key_arg
    else
      remote_key_path=$(printf '%s\n' "$remote_state_json" | jq -r '.key_path // ""')
    fi
    if [ -n "$ssh_port_arg" ]; then
      remote_port=$ssh_port_arg
    else
      remote_port=$(printf '%s\n' "$remote_state_json" | jq -r '.port // ""')
    fi

    remote_configured=false
    if [ -n "$remote_host" ] && [ -n "$remote_key_path" ]; then
      remote_configured=true
    fi

    use_remote_ssl=false
    case "$setup_mode" in
      remote)
        use_remote_ssl=true
        ;;
      local)
        use_remote_ssl=false
        ;;
      ''|auto)
        if [ "$remote_configured" = "true" ]; then
          use_remote_ssl=true
        fi
        ;;
    esac

    if [ "$use_remote_ssl" = "true" ]; then
      if ! validate_remote_target "$remote_host"; then
        printf '%s\n' "owl-desktop-backend: set a valid remote host before remote SSL setup" >&2
        exit 2
      fi
      if ! validate_ssh_key_path "$remote_key_path"; then
        printf '%s\n' "owl-desktop-backend: set a readable SSH key path before remote SSL setup" >&2
        exit 2
      fi
      if ! validate_remote_port "$remote_port"; then
        printf '%s\n' "owl-desktop-backend: provide a valid SSH port between 1 and 65535" >&2
        exit 2
      fi
      if ! ssh_key_password=$(resolve_remote_ssh_key_password "$remote_state_json" "$remote_key_path" "$ssh_key_password_arg"); then
        exit 2
      fi

      if remote_output=$(remote_setup_ssl_over_ssh "$remote_host" "$remote_key_path" "$ssh_key_password" "$remote_port" "$smtp_host" "$email_domain" 2>&1); then
        :
      else
        printf '%s\n' "owl-desktop-backend: remote SSL setup failed on $remote_host" >&2
        printf '%s\n' "$remote_output" >&2
        exit 1
      fi

      remote_ssl_ready=$(printf '%s\n' "$remote_output" | awk -F= '/^owl_ssl_ready=/{print $2; exit}')
      remote_ssl_expires_at=$(printf '%s\n' "$remote_output" | awk -F= '/^owl_ssl_expires_at=/{sub(/^owl_ssl_expires_at=/, ""); print; exit}')
      remote_ssl_days_remaining=$(printf '%s\n' "$remote_output" | awk -F= '/^owl_ssl_days_remaining=/{sub(/^owl_ssl_days_remaining=/, ""); print; exit}')
      remote_ssl_expiring_soon=$(printf '%s\n' "$remote_output" | awk -F= '/^owl_ssl_expiring_soon=/{print $2; exit}')
      remote_ssl_already_configured=$(printf '%s\n' "$remote_output" | awk -F= '/^owl_ssl_already_configured=/{print $2; exit}')
      remote_ssl_smtp_host=$(printf '%s\n' "$remote_output" | awk -F= '/^owl_ssl_smtp_host=/{sub(/^owl_ssl_smtp_host=/, ""); print; exit}')
      remote_ssl_email_domain=$(printf '%s\n' "$remote_output" | awk -F= '/^owl_ssl_email_domain=/{sub(/^owl_ssl_email_domain=/, ""); print; exit}')
      remote_ssl_cert_path=$(printf '%s\n' "$remote_output" | awk -F= '/^owl_ssl_cert_path=/{sub(/^owl_ssl_cert_path=/, ""); print; exit}')

      case "$remote_ssl_ready" in
        true|false) ;;
        *) remote_ssl_ready=false ;;
      esac
      case "$remote_ssl_expiring_soon" in
        true|false) ;;
        *) remote_ssl_expiring_soon=false ;;
      esac
      case "$remote_ssl_already_configured" in
        true|false) ;;
        *) remote_ssl_already_configured=false ;;
      esac
      case "$remote_ssl_days_remaining" in
        ''|*[!0-9-]*)
          remote_ssl_days_remaining_json='null'
          ;;
        *)
          remote_ssl_days_remaining_json=$remote_ssl_days_remaining
          ;;
      esac

      remote_output_clean=$(printf '%s\n' "$remote_output" | awk '!/^owl_ssl_[a-z_]+=/' | sed '/^[[:space:]]*$/d')
      if [ -z "$remote_output_clean" ]; then
        if [ "$remote_ssl_already_configured" = "true" ]; then
          remote_output_clean="Remote SSL already provisioned; skipped re-provisioning."
        elif [ "$remote_ssl_ready" = "true" ]; then
          remote_output_clean="Remote SSL setup complete."
        else
          remote_output_clean="Remote SSL setup finished, but no certificate was detected."
        fi
      fi

      remote_result_smtp_host=$smtp_host
      if [ -n "$remote_ssl_smtp_host" ]; then
        remote_result_smtp_host=$remote_ssl_smtp_host
      fi
      remote_result_email_domain=$email_domain
      if [ -n "$remote_ssl_email_domain" ]; then
        remote_result_email_domain=$remote_ssl_email_domain
      fi

      jq -n \
        --arg mode "remote" \
        --arg remote_host "$remote_host" \
        --arg smtp_host "$remote_result_smtp_host" \
        --arg email_domain "$remote_result_email_domain" \
        --arg output "$remote_output_clean" \
        --arg ssl_path "$remote_ssl_cert_path" \
        --arg ssl_expires_at "$remote_ssl_expires_at" \
        --argjson ssl_ready "$(json_bool "$remote_ssl_ready")" \
        --argjson ssl_days_remaining "$remote_ssl_days_remaining_json" \
        --argjson ssl_expiring_soon "$(json_bool "$remote_ssl_expiring_soon")" \
        --argjson already_configured "$(json_bool "$remote_ssl_already_configured")" \
        '{ok:true,mode:$mode,remote_host:$remote_host,smtp_host:$smtp_host,email_domain:$email_domain,ssl_ready:$ssl_ready,output:$output,ssl_path:$ssl_path,ssl_expires_at:$ssl_expires_at,ssl_days_remaining:$ssl_days_remaining,ssl_expiring_soon:$ssl_expiring_soon,already_configured:$already_configured}'
      exit 0
    fi

    pre_status_json=$(ssl_status_json_for_smtp_host "$smtp_host")
    pre_ready=$(printf '%s\n' "$pre_status_json" | jq -r '.ready')
    pre_expiring_soon=$(printf '%s\n' "$pre_status_json" | jq -r '.expiring_soon')
    if [ "$pre_ready" = "true" ] && [ "$pre_expiring_soon" != "true" ]; then
      ensure_ssl_live_links_for_smtp_host "$smtp_host" || :
      ssl_status_json=$(ssl_status_json_for_smtp_host "$smtp_host")
      ssl_ready_json=$(printf '%s\n' "$ssl_status_json" | jq -r '.ready')
      ssl_expires_at=$(printf '%s\n' "$ssl_status_json" | jq -r '.expires_at')
      ssl_days_remaining=$(printf '%s\n' "$ssl_status_json" | jq -r '.days_remaining')
      ssl_expiring_soon=$(printf '%s\n' "$ssl_status_json" | jq -r '.expiring_soon')
      jq -n \
        --arg mode "local" \
        --arg smtp_host "$smtp_host" \
        --arg email_domain "$email_domain" \
        --argjson ssl_ready "$ssl_ready_json" \
        --arg output "SSL already provisioned; skipped re-provisioning." \
        --arg ssl_expires_at "$ssl_expires_at" \
        --argjson ssl_days_remaining "${ssl_days_remaining:-null}" \
        --argjson ssl_expiring_soon "$ssl_expiring_soon" \
        --argjson already_configured true \
        '{ok:true,mode:$mode,smtp_host:$smtp_host,email_domain:$email_domain,ssl_ready:$ssl_ready,output:$output,ssl_expires_at:$ssl_expires_at,ssl_days_remaining:$ssl_days_remaining,ssl_expiring_soon:$ssl_expiring_soon,already_configured:$already_configured}'
      exit 0
    fi
    install_output=$(install_ssl_prereqs_if_needed 2>&1) || {
      printf '%s\n' "owl-desktop-backend: SSL prerequisite installation failed." >&2
      printf '%s\n' "$install_output" >&2
      exit 1
    }
    if output=$(run_owl update 2>&1); then
      :
    else
      printf '%s\n' "owl-desktop-backend: SSL setup failed. Make sure DNS for ${email_domain} points to this host and retry." >&2
      printf '%s\n' "$output" >&2
      exit 1
    fi
    ensure_ssl_live_links_for_smtp_host "$smtp_host" || :
    ssl_status_json=$(ssl_status_json_for_smtp_host "$smtp_host")
    ssl_ready_json=$(printf '%s\n' "$ssl_status_json" | jq -r '.ready')
    ssl_expires_at=$(printf '%s\n' "$ssl_status_json" | jq -r '.expires_at')
    ssl_days_remaining=$(printf '%s\n' "$ssl_status_json" | jq -r '.days_remaining')
    ssl_expiring_soon=$(printf '%s\n' "$ssl_status_json" | jq -r '.expiring_soon')
    jq -n \
      --arg smtp_host "$smtp_host" \
      --arg email_domain "$email_domain" \
      --arg output "$(printf '%s\n%s' "$install_output" "$output")" \
      --argjson ssl_ready "$ssl_ready_json" \
      --arg ssl_expires_at "$ssl_expires_at" \
      --argjson ssl_days_remaining "${ssl_days_remaining:-null}" \
      --argjson ssl_expiring_soon "$ssl_expiring_soon" \
      --argjson already_configured false \
      '{ok:true,mode:"local",smtp_host:$smtp_host,email_domain:$email_domain,ssl_ready:$ssl_ready,output:$output,ssl_expires_at:$ssl_expires_at,ssl_days_remaining:$ssl_days_remaining,ssl_expiring_soon:$ssl_expiring_soon,already_configured:$already_configured}'
    ;;

  settings-set-daemon-running)
    desired=${3-}
    case "$desired" in
      on|off) ;;
      *)
        printf '%s\n' "owl-desktop-backend: settings-set-daemon-running requires on|off" >&2
        exit 2
        ;;
    esac
    smtp_host=$(settings_env_get smtp_host)
    domain_configured_json=$(domain_configured_for_smtp_host "$smtp_host")
    ssl_ready_json=$(ssl_ready_for_smtp_host "$smtp_host")
    daemon_require_available
    case "$desired" in
      on)
        if [ "$domain_configured_json" != "true" ]; then
          printf '%s\n' "owl-desktop-backend: set up domain first before turning on email server" >&2
          exit 2
        fi
        if [ "$ssl_ready_json" != "true" ]; then
          printf '%s\n' "owl-desktop-backend: SSL setup must be completed before turning on email server" >&2
          exit 2
        fi
        if ! daemon_is_installed; then
          printf '%s\n' "owl-desktop-backend: install service first before turning on email server" >&2
          exit 2
        fi
        if ! daemon_is_running; then
          "$DAEMON_SERVICE_SCRIPT" start
        fi
        ;;
      off)
        if daemon_is_installed && daemon_is_running; then
          "$DAEMON_SERVICE_SCRIPT" stop
        fi
        ;;
    esac
    daemon_json=$(daemon_status_json)
    jq -n --arg desired "$desired" --argjson daemon "$daemon_json" '{ok:true,desired:$desired,daemon:$daemon}'
    ;;

  settings-set-daemon-installed)
    desired=${3-}
    case "$desired" in
      on|off) ;;
      *)
        printf '%s\n' "owl-desktop-backend: settings-set-daemon-installed requires on|off" >&2
        exit 2
        ;;
    esac
    daemon_require_available
    case "$desired" in
      on)
        if ! daemon_is_installed; then
          "$DAEMON_SERVICE_SCRIPT" install
        fi
        ;;
      off)
        if daemon_is_installed; then
          "$DAEMON_SERVICE_SCRIPT" remove
        fi
        ;;
    esac
    daemon_json=$(daemon_status_json)
    jq -n --arg desired "$desired" --argjson daemon "$daemon_json" '{ok:true,desired:$desired,daemon:$daemon}'
    ;;

  settings-set-daemon-startup)
    desired=${3-}
    case "$desired" in
      on|off) ;;
      *)
        printf '%s\n' "owl-desktop-backend: settings-set-daemon-startup requires on|off" >&2
        exit 2
        ;;
    esac
    daemon_require_available
    if ! daemon_is_installed; then
      printf '%s\n' "owl-desktop-backend: install service first before changing startup behavior" >&2
      exit 2
    fi
    case "$desired" in
      on)
        "$DAEMON_SERVICE_SCRIPT" enable-startup
        ;;
      off)
        "$DAEMON_SERVICE_SCRIPT" disable-startup
        ;;
    esac
    daemon_json=$(daemon_status_json)
    jq -n --arg desired "$desired" --argjson daemon "$daemon_json" '{ok:true,desired:$desired,daemon:$daemon}'
    ;;

  settings-setup-folders)
    ensure_mail_dirs
    jq -n --arg root "$ROOT" '{ok:true,output:("mail folders ready at " + $root)}'
    ;;

  settings-remote-set-target)
    remote_state_json=$(load_remote_state_json)
    remote_host=$(normalize_remote_target_input "${3-}")
    remote_key_path=$(normalize_ssh_key_path_input "${4-}")
    remote_port=$(normalize_remote_port_input "${5-}")

    if [ -n "$remote_host" ] && ! validate_remote_target "$remote_host"; then
      printf '%s\n' "owl-desktop-backend: provide a valid remote host like user@example.org or user@203.0.113.8" >&2
      exit 2
    fi
    if [ -n "$remote_key_path" ] && ! validate_ssh_key_path "$remote_key_path"; then
      printf '%s\n' "owl-desktop-backend: provide a readable SSH key file path with no spaces" >&2
      exit 2
    fi
    if ! validate_remote_port "$remote_port"; then
      printf '%s\n' "owl-desktop-backend: provide a valid SSH port between 1 and 65535" >&2
      exit 2
    fi

    updated_remote_json=$(printf '%s\n' "$remote_state_json" | jq -c \
      --arg host "$remote_host" \
      --arg key_path "$remote_key_path" \
      --arg port "$remote_port" \
      '. as $orig
       | .host=$host
       | .key_path=$key_path
       | .port=$port
       | if (($orig.host // "") != $host or ($orig.key_path // "") != $key_path or ($orig.port // "") != $port) then
           .last_deploy_at=""
           | .last_deploy_status="idle"
           | .last_deploy_message=""
           | .last_verify_at=""
           | .last_verify_status="idle"
           | .last_verify_message=""
           | .last_test_at=""
           | .last_test_status="idle"
           | .last_test_message=""
           | .last_sync_at=""
           | .last_sync_status="idle"
           | .last_sync_message=""
         else
           .
         end')
    save_remote_state_json "$updated_remote_json"
    remote_auth_json=$(remote_auth_state_json "$updated_remote_json")

    jq -n --argjson remote "$updated_remote_json" --argjson remote_auth "$remote_auth_json" '{ok:true,remote:$remote,remote_auth:$remote_auth}'
    ;;

  settings-remote-set-auth)
    remote_state_json=$(load_remote_state_json)
    has_password=$(normalize_toggle_flag "${3-0}")
    save_choice=$(normalize_toggle_flag "${4-0}")
    ssh_key_password_input=${5-}
    host_arg=$(normalize_remote_target_input "${6-}")
    key_arg=$(normalize_ssh_key_path_input "${7-}")
    port_arg=$(normalize_remote_port_input "${8-}")
    backend=$(detect_remote_secret_backend)

    if [ -n "$host_arg" ] && ! validate_remote_target "$host_arg"; then
      printf '%s\n' "owl-desktop-backend: provide a valid remote host like user@example.org or user@203.0.113.8" >&2
      exit 2
    fi
    if [ -n "$key_arg" ] && ! validate_ssh_key_path "$key_arg"; then
      printf '%s\n' "owl-desktop-backend: provide a readable SSH key file path with no spaces" >&2
      exit 2
    fi
    if ! validate_remote_port "$port_arg"; then
      printf '%s\n' "owl-desktop-backend: provide a valid SSH port between 1 and 65535" >&2
      exit 2
    fi

    if [ "$has_password" != "1" ]; then
      save_choice=0
    fi

    remote_host=$(printf '%s\n' "$remote_state_json" | jq -r '.host // ""')
    remote_key_path=$(printf '%s\n' "$remote_state_json" | jq -r '.key_path // ""')
    remote_port=$(printf '%s\n' "$remote_state_json" | jq -r '.port // ""')
    if [ -n "$host_arg" ]; then
      remote_host=$host_arg
    fi
    if [ -n "$key_arg" ]; then
      remote_key_path=$key_arg
    fi
    if [ -n "$port_arg" ] || [ -z "$remote_port" ]; then
      remote_port=$port_arg
    fi

    if [ "$save_choice" = "1" ]; then
      if [ "$backend" = "none" ]; then
        printf '%s\n' "owl-desktop-backend: secure credential save is unavailable on this platform" >&2
        exit 2
      fi
      if [ -z "$remote_key_path" ]; then
        printf '%s\n' "owl-desktop-backend: set SSH key path before saving SSH key password" >&2
        exit 2
      fi
      if [ -n "$ssh_key_password_input" ]; then
        if ! remote_secret_store "$remote_key_path" "$ssh_key_password_input" "$backend"; then
          printf '%s\n' "owl-desktop-backend: failed to save SSH key password securely" >&2
          exit 1
        fi
      elif ! remote_secret_exists "$remote_key_path" "$backend"; then
        printf '%s\n' "owl-desktop-backend: enter SSH key password before enabling secure save" >&2
        exit 2
      fi
    else
      remote_secret_delete "$remote_key_path" "$backend"
    fi

    updated_remote_json=$(printf '%s\n' "$remote_state_json" | jq -c \
      --arg host "$remote_host" \
      --arg key_path "$remote_key_path" \
      --arg port "$remote_port" \
      --arg has_password "$has_password" \
      --arg save_choice "$save_choice" \
      '.host=$host
       | .key_path=$key_path
       | .port=$port
       | .ssh_key_has_password=$has_password
       | .ssh_key_save_choice=$save_choice')
    save_remote_state_json "$updated_remote_json"
    remote_auth_json=$(remote_auth_state_json "$updated_remote_json")

    jq -n \
      --argjson remote "$updated_remote_json" \
      --argjson remote_auth "$remote_auth_json" \
      '{ok:true,remote:$remote,remote_auth:$remote_auth}'
    ;;

  settings-remote-deploy)
    require_cmd ssh
    remote_state_json=$(load_remote_state_json)

    host_arg=$(normalize_remote_target_input "${3-}")
    key_arg=$(normalize_ssh_key_path_input "${4-}")
    ssh_key_password_arg=${5-}
    ssh_port_arg=$(normalize_remote_port_input "${6-}")

    if [ -n "$host_arg" ]; then
      remote_host=$host_arg
    else
      remote_host=$(printf '%s\n' "$remote_state_json" | jq -r '.host')
    fi
    if [ -n "$key_arg" ]; then
      remote_key_path=$key_arg
    else
      remote_key_path=$(printf '%s\n' "$remote_state_json" | jq -r '.key_path')
    fi
    if [ -n "$ssh_port_arg" ]; then
      remote_port=$ssh_port_arg
    else
      remote_port=$(printf '%s\n' "$remote_state_json" | jq -r '.port // ""')
    fi

    if ! validate_remote_target "$remote_host"; then
      printf '%s\n' "owl-desktop-backend: provide a valid remote host like user@example.org or user@203.0.113.8" >&2
      exit 2
    fi
    if ! validate_ssh_key_path "$remote_key_path"; then
      printf '%s\n' "owl-desktop-backend: provide a readable SSH key file path with no spaces" >&2
      exit 2
    fi
    if ! validate_remote_port "$remote_port"; then
      printf '%s\n' "owl-desktop-backend: provide a valid SSH port between 1 and 65535" >&2
      exit 2
    fi

    if ! ssh_key_password=$(resolve_remote_ssh_key_password "$remote_state_json" "$remote_key_path" "$ssh_key_password_arg"); then
      exit 2
    fi

    smtp_host=$(settings_env_get smtp_host)
    smtp_host_mail=$(email_domain_from_smtp_host "$smtp_host")
    domain_configured_json=$(domain_configured_for_smtp_host "$smtp_host")
    if [ -n "$smtp_host" ] && [ "$smtp_host" != "127.0.0.1" ] && [ "$smtp_host" != "localhost" ] && [ "$smtp_host_mail" != "127.0.0.1" ] && [ "$smtp_host_mail" != "localhost" ]; then
      remote_mail_host_hint="$smtp_host"
    else
      remote_host_only=$(remote_target_host_component "$remote_host")
      if looks_like_ip_address "$remote_host_only"; then
        remote_mail_host_hint=''
      else
        remote_mail_host_hint="$remote_host_only"
      fi
    fi
    domain_autoset_note=''
    if [ "$domain_configured_json" != "true" ] && [ -n "$remote_mail_host_hint" ]; then
      auto_email_domain=$(email_domain_from_smtp_host "$remote_mail_host_hint")
      if [ -n "$auto_email_domain" ] && ! looks_like_ip_address "$auto_email_domain"; then
        auto_smtp_host=$(smtp_host_from_domain "$auto_email_domain")
      else
        auto_smtp_host=$remote_mail_host_hint
      fi
      settings_env_set smtp_host "$auto_smtp_host"
      settings_env_set smtp_starttls true
      smtp_host="$auto_smtp_host"
      smtp_host_mail=$(email_domain_from_smtp_host "$smtp_host")
      domain_autoset_note="Domain auto-set to $smtp_host_mail (SMTP host: $smtp_host) based on remote target."
    fi

    if engine_install_output=$(install_bundled_engine_on_remote "$remote_host" "$remote_key_path" "$ssh_key_password" "$remote_port" 2>&1); then
      if remote_output=$(remote_deploy_over_ssh "$remote_host" "$remote_key_path" "$ssh_key_password" "$remote_port" "$smtp_host" "$remote_mail_host_hint" "${STELLAR_ADDRESS_ROUTES_B64-}" 2>&1); then
        deploy_output=$(printf '%s\n%s\n' "$engine_install_output" "$remote_output")
        deploy_status=ok
      else
        deploy_output=$(printf '%s\n%s\n' "$engine_install_output" "$remote_output")
        deploy_status=bad
      fi
    else
      deploy_output=$engine_install_output
      deploy_status=bad
    fi

    verify_status=''
    verify_message=''
    verify_json='{}'
    if [ "$deploy_status" = "ok" ]; then
      deploy_status=ok
      startup_mode=$(printf '%s\n' "$deploy_output" | awk -F= '/^startup_mode=/{print $2; exit}')
      deploy_note=$(printf '%s\n' "$deploy_output" | awk -F= '/^note=/{sub(/^note=/, ""); print; exit}')
      email_domain=$(email_domain_from_smtp_host "$smtp_host")
      domain_configured_json=$(domain_configured_for_smtp_host "$smtp_host")
      if verify_json=$(remote_verify_status_json "$remote_host" "$remote_key_path" "$ssh_key_password" "$remote_port" "$smtp_host" "$email_domain" "$domain_configured_json" 2>&1); then
        verify_status=$(printf '%s\n' "$verify_json" | jq -r '.status // "bad"' 2>/dev/null || printf 'bad')
        verify_message=$(printf '%s\n' "$verify_json" | jq -r '.message // ""' 2>/dev/null || compact_status_message "$verify_json")
      else
        verify_status=bad
        verify_message=$(compact_status_message "$verify_json")
      fi
      case "$startup_mode" in
        service)
          deploy_message='Remote deploy completed. Receiver startup is managed by service.'
          ;;
        cron)
          deploy_message='Remote deploy completed. Receiver startup uses cron keepalive.'
          ;;
        *)
          deploy_message='Remote deploy completed.'
          ;;
      esac
      if [ -n "$deploy_note" ]; then
        deploy_message="$deploy_message $deploy_note"
      fi
      if [ -n "$domain_autoset_note" ]; then
        deploy_message="$deploy_message $domain_autoset_note"
      fi
      if [ "$verify_status" = "ok" ]; then
        deploy_message="$deploy_message Verification: ready."
      elif [ -n "$verify_message" ]; then
        deploy_message="$deploy_message Verification: $verify_message"
      fi
      deploy_message=$(compact_status_message "$deploy_message")
    else
      deploy_status=bad
      deploy_message=$(compact_status_message "$deploy_output")
      if [ -z "$deploy_message" ]; then
        deploy_message='Remote deploy failed.'
      fi
    fi

    now_ts=$(current_utc_timestamp)
    updated_remote_json=$(printf '%s\n' "$remote_state_json" | jq -c \
      --arg host "$remote_host" \
      --arg key_path "$remote_key_path" \
      --arg port "$remote_port" \
      --arg now_ts "$now_ts" \
      --arg deploy_status "$deploy_status" \
      --arg deploy_message "$deploy_message" \
      --arg verify_status "$verify_status" \
      --arg verify_message "$verify_message" \
      '.host=$host
       | .key_path=$key_path
       | .port=$port
       | .last_deploy_at=$now_ts
       | .last_deploy_status=$deploy_status
       | .last_deploy_message=$deploy_message
       | if ($verify_status | length) > 0 then
           .last_verify_at=$now_ts
           | .last_verify_status=$verify_status
           | .last_verify_message=$verify_message
         else
           .
         end')
    save_remote_state_json "$updated_remote_json"

    if [ "$deploy_status" != "ok" ]; then
      printf '%s\n' "owl-desktop-backend: $deploy_message" >&2
      exit 1
    fi

    jq -n \
      --arg message "$deploy_message" \
      --arg output "$deploy_output" \
      --argjson verify "$verify_json" \
      --argjson remote "$updated_remote_json" \
      '{ok:true,message:$message,output:$output,verify:$verify,remote:$remote}'
    ;;

  address-publish)
    require_cmd ssh
    remote_state_json=$(load_remote_state_json)
    remote_host=$(normalize_remote_target_input "${3-}")
    remote_key_path=$(normalize_ssh_key_path_input "${4-}")
    ssh_key_password_arg=${5-}
    remote_port=$(normalize_remote_port_input "${6-}")
    [ -n "$remote_host" ] || remote_host=$(printf '%s\n' "$remote_state_json" | jq -r '.host // ""')
    [ -n "$remote_key_path" ] || remote_key_path=$(printf '%s\n' "$remote_state_json" | jq -r '.key_path // ""')
    [ -n "$remote_port" ] || remote_port=$(printf '%s\n' "$remote_state_json" | jq -r '.port // ""')

    validate_remote_target "$remote_host" || {
      printf '%s\n' "owl-desktop-backend: set a valid remote host before publishing addresses" >&2
      exit 2
    }
    validate_ssh_key_path "$remote_key_path" || {
      printf '%s\n' "owl-desktop-backend: set a readable SSH key before publishing addresses" >&2
      exit 2
    }
    validate_remote_port "$remote_port" || {
      printf '%s\n' "owl-desktop-backend: provide a valid SSH port between 1 and 65535" >&2
      exit 2
    }
    if ! ssh_key_password=$(resolve_remote_ssh_key_password "$remote_state_json" "$remote_key_path" "$ssh_key_password_arg"); then
      exit 2
    fi
    if ! output=$(publish_address_routes_over_ssh \
      "$remote_host" \
      "$remote_key_path" \
      "$ssh_key_password" \
      "$remote_port" \
      "${STELLAR_ADDRESS_ROUTES_B64-}" 2>&1); then
      printf '%s\n' "owl-desktop-backend: address publishing failed: $output" >&2
      exit 1
    fi
    jq -n \
      --arg message "Receiving addresses applied to the remote mail server." \
      --arg output "$output" \
      --argjson remote "$remote_state_json" \
      '{ok:true,message:$message,output:$output,remote:$remote}'
    ;;

  settings-remote-verify)
    require_cmd ssh
    remote_state_json=$(load_remote_state_json)

    host_arg=$(normalize_remote_target_input "${3-}")
    key_arg=$(normalize_ssh_key_path_input "${4-}")
    ssh_key_password_arg=${5-}
    ssh_port_arg=$(normalize_remote_port_input "${6-}")

    if [ -n "$host_arg" ]; then
      remote_host=$host_arg
    else
      remote_host=$(printf '%s\n' "$remote_state_json" | jq -r '.host')
    fi
    if [ -n "$key_arg" ]; then
      remote_key_path=$key_arg
    else
      remote_key_path=$(printf '%s\n' "$remote_state_json" | jq -r '.key_path')
    fi
    if [ -n "$ssh_port_arg" ]; then
      remote_port=$ssh_port_arg
    else
      remote_port=$(printf '%s\n' "$remote_state_json" | jq -r '.port // ""')
    fi

    if ! validate_remote_target "$remote_host"; then
      printf '%s\n' "owl-desktop-backend: set a valid remote host before verifying" >&2
      exit 2
    fi
    if ! validate_ssh_key_path "$remote_key_path"; then
      printf '%s\n' "owl-desktop-backend: set a readable SSH key file path with no spaces before verifying" >&2
      exit 2
    fi
    if ! validate_remote_port "$remote_port"; then
      printf '%s\n' "owl-desktop-backend: provide a valid SSH port between 1 and 65535" >&2
      exit 2
    fi

    if ! ssh_key_password=$(resolve_remote_ssh_key_password "$remote_state_json" "$remote_key_path" "$ssh_key_password_arg"); then
      exit 2
    fi

    smtp_host=$(settings_env_get smtp_host)
    email_domain=$(email_domain_from_smtp_host "$smtp_host")
    domain_configured_json=$(domain_configured_for_smtp_host "$smtp_host")

    verify_status=bad
    verify_message='Remote verification failed.'
    verify_json='{}'
    if verify_json=$(remote_verify_status_json "$remote_host" "$remote_key_path" "$ssh_key_password" "$remote_port" "$smtp_host" "$email_domain" "$domain_configured_json" 2>&1); then
      verify_status=$(printf '%s\n' "$verify_json" | jq -r '.status // "bad"' 2>/dev/null || printf 'bad')
      verify_message=$(printf '%s\n' "$verify_json" | jq -r '.message // "Remote verification failed."' 2>/dev/null || compact_status_message "$verify_json")
    else
      verify_message=$(compact_status_message "$verify_json")
      if [ -z "$verify_message" ]; then
        verify_message='Remote verification failed.'
      fi
      verify_json=$(jq -cn --arg status bad --arg message "$verify_message" '{status:$status,message:$message,ready:false}')
    fi

    now_ts=$(current_utc_timestamp)
    updated_remote_json=$(printf '%s\n' "$remote_state_json" | jq -c \
      --arg host "$remote_host" \
      --arg key_path "$remote_key_path" \
      --arg port "$remote_port" \
      --arg now_ts "$now_ts" \
      --arg verify_status "$verify_status" \
      --arg verify_message "$verify_message" \
      '.host=$host
       | .key_path=$key_path
       | .port=$port
       | .last_verify_at=$now_ts
       | .last_verify_status=$verify_status
       | .last_verify_message=$verify_message')
    save_remote_state_json "$updated_remote_json"

    jq -n \
      --arg message "$verify_message" \
      --argjson verify "$verify_json" \
      --argjson remote "$updated_remote_json" \
      '{ok:true,message:$message,verify:$verify,remote:$remote}'
    ;;

  settings-remote-send-test)
    require_cmd ssh
    require_cmd rsync
    remote_state_json=$(load_remote_state_json)

    host_arg=$(normalize_remote_target_input "${3-}")
    key_arg=$(normalize_ssh_key_path_input "${4-}")
    ssh_key_password_arg=${5-}
    ssh_port_arg=$(normalize_remote_port_input "${6-}")

    if [ -n "$host_arg" ]; then
      remote_host=$host_arg
    else
      remote_host=$(printf '%s\n' "$remote_state_json" | jq -r '.host')
    fi
    if [ -n "$key_arg" ]; then
      remote_key_path=$key_arg
    else
      remote_key_path=$(printf '%s\n' "$remote_state_json" | jq -r '.key_path')
    fi
    if [ -n "$ssh_port_arg" ]; then
      remote_port=$ssh_port_arg
    else
      remote_port=$(printf '%s\n' "$remote_state_json" | jq -r '.port // ""')
    fi

    if ! validate_remote_target "$remote_host"; then
      printf '%s\n' "owl-desktop-backend: set a valid remote host before sending test mail" >&2
      exit 2
    fi
    if ! validate_ssh_key_path "$remote_key_path"; then
      printf '%s\n' "owl-desktop-backend: set a readable SSH key file path with no spaces before sending test mail" >&2
      exit 2
    fi
    if ! validate_remote_port "$remote_port"; then
      printf '%s\n' "owl-desktop-backend: provide a valid SSH port between 1 and 65535" >&2
      exit 2
    fi

    if ! ssh_key_password=$(resolve_remote_ssh_key_password "$remote_state_json" "$remote_key_path" "$ssh_key_password_arg"); then
      exit 2
    fi

    smtp_host=$(settings_env_get smtp_host)
    email_domain=$(email_domain_from_smtp_host "$smtp_host")
    domain_configured_json=$(domain_configured_for_smtp_host "$smtp_host")
    test_recipient=$(load_test_recipient_value)
    if ! validate_test_recipient_email "$test_recipient"; then
      printf '%s\n' "owl-desktop-backend: set a valid email address in Settings > My Email Address before sending remote test email" >&2
      exit 2
    fi

    verify_status=bad
    verify_message='Remote verification failed.'
    verify_json='{}'
    if verify_json=$(remote_verify_status_json "$remote_host" "$remote_key_path" "$ssh_key_password" "$remote_port" "$smtp_host" "$email_domain" "$domain_configured_json" quick 2>&1); then
      verify_status=$(printf '%s\n' "$verify_json" | jq -r '.status // "bad"' 2>/dev/null || printf 'bad')
      verify_message=$(printf '%s\n' "$verify_json" | jq -r '.message // "Remote verification failed."' 2>/dev/null || compact_status_message "$verify_json")
    else
      verify_message=$(compact_status_message "$verify_json")
      if [ -z "$verify_message" ]; then
        verify_message='Remote verification failed.'
      fi
      verify_json=$(jq -cn --arg status bad --arg message "$verify_message" '{status:$status,message:$message,ready:false}')
    fi

    remote_host_only=$(remote_target_host_component "$remote_host")
    smtp_target_host=$smtp_host
    if [ -z "$smtp_target_host" ] || [ "$smtp_target_host" = "127.0.0.1" ] || [ "$smtp_target_host" = "localhost" ]; then
      smtp_target_host=$remote_host_only
    fi

    recipient_domain=$(email_domain_from_recipient "$test_recipient")
    sender_domain=$recipient_domain
    if [ -z "$sender_domain" ]; then
      sender_domain=$email_domain
    fi
    if [ -z "$sender_domain" ] || looks_like_ip_address "$sender_domain"; then
      sender_domain='local.invalid'
    fi
    sender_addr="owl-test@$sender_domain"
    test_subject="Owl Remote Receive Test $(current_utc_timestamp)"

    test_status=bad
    test_message='Remote test email failed.'
    test_output=''
    sync_status=idle
    sync_message=''
    sync_output=''
    copied_count_num=0
    send_status=failed
    send_detail=''
    fallback_detail=''
    delivery_seen_remote=false
    delivery_seen_local=false
    if send_output=$(smtp_send_test_message "$smtp_target_host" "$test_recipient" "$test_subject" "$sender_addr" "$SMTP_SEND_TIMEOUT_SECS" 2>&1); then
      send_status=local
      send_detail=$(compact_status_message "$send_output")
    else
      send_detail=$(compact_status_message "$send_output")
      if fallback_output=$(remote_smtp_send_test_message "$remote_host" "$remote_key_path" "$ssh_key_password" "$remote_port" "$test_recipient" "$test_subject" "$sender_addr" "$SMTP_SEND_TIMEOUT_SECS" 2>&1); then
        send_status=remote_fallback
        fallback_detail=$(compact_status_message "$fallback_output")
      else
        fallback_detail=$(compact_status_message "$fallback_output")
      fi
    fi

    if [ "$send_status" = "local" ] || [ "$send_status" = "remote_fallback" ]; then
      if [ "$send_status" = "remote_fallback" ]; then
        if [ -n "$fallback_detail" ]; then
          test_output="$fallback_detail"
        else
          test_output='remote fallback send succeeded'
        fi
      else
        test_output="$send_detail"
      fi
      if copied_count=$(remote_sync_over_ssh "$remote_host" "$remote_key_path" "$ssh_key_password" "$remote_port" 2>&1); then
        copied_count_num=$(printf '%s' "$copied_count" | tr -d '[:space:]')
        if [ -z "$copied_count_num" ] || [ "$copied_count_num" -eq 0 ] 2>/dev/null; then
          copied_count_num=0
          sync_message='Remote sync complete. Test email may still be processing; check again in a few seconds.'
        else
          sync_message="Remote sync complete. Copied ${copied_count_num} new files."
        fi
        sync_status=ok
        sync_output="$sync_message"
        delivery_seen_local=$(local_test_subject_seen "$test_subject" 2>/dev/null || printf 'false')
        if [ "$delivery_seen_local" != "true" ]; then
          delivery_seen_remote=$(remote_test_subject_seen "$remote_host" "$remote_key_path" "$ssh_key_password" "$remote_port" "$test_subject" 2>/dev/null || printf 'false')
        else
          delivery_seen_remote=true
        fi

        retry_idx=1
        while [ "$delivery_seen_local" != "true" ] && [ "$retry_idx" -le "$SEND_TEST_SYNC_RETRY_ATTEMPTS" ]; do
          sleep "$SEND_TEST_SYNC_RETRY_DELAY_SECS"
          if retry_copied=$(remote_sync_over_ssh "$remote_host" "$remote_key_path" "$ssh_key_password" "$remote_port" 2>/dev/null); then
            retry_copied_num=$(printf '%s' "$retry_copied" | tr -d '[:space:]')
            if [ -n "$retry_copied_num" ] && [ "$retry_copied_num" -gt 0 ] 2>/dev/null; then
              copied_count_num=$((copied_count_num + retry_copied_num))
            fi
          fi
          delivery_seen_local=$(local_test_subject_seen "$test_subject" 2>/dev/null || printf 'false')
          if [ "$delivery_seen_remote" != "true" ]; then
            delivery_seen_remote=$(remote_test_subject_seen "$remote_host" "$remote_key_path" "$ssh_key_password" "$remote_port" "$test_subject" 2>/dev/null || printf 'false')
          fi
          retry_idx=$((retry_idx + 1))
        done

        if [ "$delivery_seen_local" = "true" ]; then
          test_status=ok
          if [ "$copied_count_num" -gt 0 ] 2>/dev/null; then
            sync_message="Remote sync complete. Copied ${copied_count_num} new files and confirmed local delivery."
          else
            sync_message='Remote sync complete. Test email confirmed in local Owl folders.'
          fi
          sync_output="$sync_message"
          if [ "$send_status" = "remote_fallback" ]; then
            test_message="Sent test email to $test_recipient using remote fallback (local SMTP probe was blocked). $sync_message"
          else
            test_message="Sent test email to $test_recipient via $smtp_target_host. $sync_message"
          fi
        elif [ "$delivery_seen_remote" = "true" ]; then
          test_status=bad
          sync_message='Remote sync ran, but test subject is still missing in local Owl folders.'
          sync_output="$sync_message"
          if [ "$send_status" = "remote_fallback" ]; then
            test_message='SMTP accepted and remote Owl received the test email, but local sync did not retrieve it yet. Run Check Remote Mail again after a moment.'
          else
            test_message='SMTP accepted the test email, but local sync did not retrieve it yet. Run Check Remote Mail again after a moment.'
          fi
        else
          test_status=bad
          test_message='Test email reached SMTP but did not arrive in remote Owl folders. Check postfix routing and recipient mapping.'
          sync_message='Remote sync complete, but test subject was not found in remote/local Owl folders.'
          sync_output="$sync_message"
        fi
      else
        sync_status=bad
        sync_output=$(compact_status_message "$copied_count")
        if [ -z "$sync_output" ]; then
          sync_output='Remote sync failed after sending test email.'
        fi
        sync_message="$sync_output"
        test_status=bad
        if [ "$send_status" = "remote_fallback" ]; then
          test_message="Sent test email to $test_recipient using remote fallback, but sync failed: $sync_message"
        else
          test_message="Sent test email to $test_recipient via $smtp_target_host, but sync failed: $sync_message"
        fi
      fi
    else
      test_output="$send_detail"
      if [ -n "$fallback_detail" ]; then
        test_message="Failed to send test email to $test_recipient via $smtp_target_host: $send_detail; remote fallback also failed: $fallback_detail"
      elif [ -n "$test_output" ]; then
        test_message="Failed to send test email to $test_recipient via $smtp_target_host: $test_output"
      fi
    fi

    test_message=$(compact_status_message "$test_message")
    now_ts=$(current_utc_timestamp)
    updated_remote_json=$(printf '%s\n' "$remote_state_json" | jq -c \
      --arg host "$remote_host" \
      --arg key_path "$remote_key_path" \
      --arg port "$remote_port" \
      --arg now_ts "$now_ts" \
      --arg verify_status "$verify_status" \
      --arg verify_message "$verify_message" \
      --arg test_status "$test_status" \
      --arg test_message "$test_message" \
      --arg sync_status "$sync_status" \
      --arg sync_message "$sync_message" \
      '.host=$host
       | .key_path=$key_path
       | .port=$port
       | .last_verify_at=$now_ts
       | .last_verify_status=$verify_status
       | .last_verify_message=$verify_message
       | .last_test_at=$now_ts
       | .last_test_status=$test_status
       | .last_test_message=$test_message
       | if $sync_status != "idle" then
           .last_sync_at=$now_ts
           | .last_sync_status=$sync_status
           | .last_sync_message=$sync_message
         else
           .
         end')
    save_remote_state_json "$updated_remote_json"

    jq -n \
      --arg message "$test_message" \
      --arg recipient "$test_recipient" \
      --arg sender "$sender_addr" \
      --arg smtp_host "$smtp_target_host" \
      --argjson copied_files "${copied_count_num:-0}" \
      --argjson verify "$verify_json" \
      --argjson remote "$updated_remote_json" \
      --arg test_status "$test_status" \
      --arg test_output "$test_output" \
      --arg sync_status "$sync_status" \
      --arg sync_message "$sync_message" \
      --arg sync_output "$sync_output" \
      '{ok:true,message:$message,recipient:$recipient,sender:$sender,smtp_host:$smtp_host,copied_files:$copied_files,verify:$verify,test:{status:$test_status,output:$test_output},sync:{status:$sync_status,message:$sync_message,output:$sync_output},remote:$remote}'
    ;;

  settings-remote-sync)
    require_cmd ssh
    require_cmd rsync
    remote_state_json=$(load_remote_state_json)

    host_arg=$(normalize_remote_target_input "${3-}")
    key_arg=$(normalize_ssh_key_path_input "${4-}")
    ssh_key_password_arg=${5-}
    ssh_port_arg=$(normalize_remote_port_input "${6-}")

    if [ -n "$host_arg" ]; then
      remote_host=$host_arg
    else
      remote_host=$(printf '%s\n' "$remote_state_json" | jq -r '.host')
    fi
    if [ -n "$key_arg" ]; then
      remote_key_path=$key_arg
    else
      remote_key_path=$(printf '%s\n' "$remote_state_json" | jq -r '.key_path')
    fi
    if [ -n "$ssh_port_arg" ]; then
      remote_port=$ssh_port_arg
    else
      remote_port=$(printf '%s\n' "$remote_state_json" | jq -r '.port // ""')
    fi

    if ! validate_remote_target "$remote_host"; then
      printf '%s\n' "owl-desktop-backend: set a valid remote host before syncing" >&2
      exit 2
    fi
    if ! validate_ssh_key_path "$remote_key_path"; then
      printf '%s\n' "owl-desktop-backend: set a readable SSH key file path with no spaces before syncing" >&2
      exit 2
    fi
    if ! validate_remote_port "$remote_port"; then
      printf '%s\n' "owl-desktop-backend: provide a valid SSH port between 1 and 65535" >&2
      exit 2
    fi

    if ! ssh_key_password=$(resolve_remote_ssh_key_password "$remote_state_json" "$remote_key_path" "$ssh_key_password_arg"); then
      exit 2
    fi

    if copied_count=$(remote_sync_over_ssh "$remote_host" "$remote_key_path" "$ssh_key_password" "$remote_port" 2>&1); then
      copied_count_num=$(printf '%s' "$copied_count" | tr -d '[:space:]')
      if [ -z "$copied_count_num" ] || [ "$copied_count_num" -eq 0 ] 2>/dev/null; then
        sync_message='Remote sync complete. No new files found.'
      else
        sync_message="Remote sync complete. Copied ${copied_count_num} new files."
      fi
      sync_status=ok
      sync_output="$sync_message"
    else
      sync_status=bad
      sync_output=$(compact_status_message "$copied_count")
      if [ -z "$sync_output" ]; then
        sync_output='Remote sync failed.'
      fi
      sync_message="$sync_output"
    fi

    now_ts=$(current_utc_timestamp)
    updated_remote_json=$(printf '%s\n' "$remote_state_json" | jq -c \
      --arg host "$remote_host" \
      --arg key_path "$remote_key_path" \
      --arg port "$remote_port" \
      --arg now_ts "$now_ts" \
      --arg sync_status "$sync_status" \
      --arg sync_message "$sync_message" \
      '.host=$host
       | .key_path=$key_path
       | .port=$port
       | .last_sync_at=$now_ts
       | .last_sync_status=$sync_status
       | .last_sync_message=$sync_message')
    save_remote_state_json "$updated_remote_json"

    if [ "$sync_status" != "ok" ]; then
      printf '%s\n' "owl-desktop-backend: $sync_message" >&2
      exit 1
    fi

    jq -n \
      --arg message "$sync_message" \
      --arg output "$sync_output" \
      --argjson copied_files "${copied_count_num:-0}" \
      --argjson remote "$updated_remote_json" \
      '{ok:true,message:$message,output:$output,copied_files:$copied_files,remote:$remote}'
    ;;

  event-feed)
    limit=${3-80}
    case "$limit" in
      ''|*[!0-9]*) limit=80 ;;
    esac
    if [ "$limit" -lt 1 ]; then
      limit=1
    elif [ "$limit" -gt 250 ]; then
      limit=250
    fi

    log_file="$ROOT/logs/owl.log"
    if [ ! -f "$log_file" ]; then
      jq -n --arg log_path "$log_file" '{ok:true,log_path:$log_path,events:[]}'
    else
      events_json=$(
        tail -n "$limit" "$log_file" 2>/dev/null \
          | jq -c -R -s '
              split("\n")
              | map(select(length > 0) | fromjson?)
              | map(select(type == "object"))
              | map(select((.message // "") | startswith("daemon.")))
              | map({
                  timestamp: (.timestamp // ""),
                  level: (.level // ""),
                  message: (.message // ""),
                  detail: (.detail // ""),
                  stage: (
                    if ((.message // "") | startswith("daemon.quarantine")) then "inbound"
                    elif (.message // "") == "daemon.watch.error" then "watch-error"
                    elif ((.message // "") | startswith("daemon.retention")) then "retention"
                    elif ((.message // "") | startswith("daemon.outbox")) then "outbox"
                    else "daemon"
                    end
                  )
                })
              | reverse
            '
      )

      jq -n \
        --arg log_path "$log_file" \
        --argjson events "$events_json" \
        '{ok:true,log_path:$log_path,events:$events}'
    fi
    ;;

  contact-get)
    identity=$(printf '%s' "${3-}" | tr -d '\r\n')
    fallback_label=$(printf '%s' "${4-}" | tr -d '\r\n')
    contact_key=$(printf '%s' "${5-}" | tr -d '\r\n')
    card_path=$(resolve_contact_vcard_file "$identity" "$contact_key")

    exists=false
    name=''
    email=''
    phone=''
    address=''
    url=''
    note=''
    if [ -f "$card_path" ]; then
      exists=true
      name=$(contact_vcard_field "$card_path" "FN")
      email=$(contact_vcard_field "$card_path" "EMAIL")
      phone=$(contact_vcard_field "$card_path" "TEL")
      address=$(contact_vcard_field "$card_path" "ADR")
      case "$address" in
        *';'*)
          address=$(printf '%s' "$address" | awk -F';' '{print ($3 != "" ? $3 : $1)}')
          ;;
      esac
      url=$(contact_vcard_field "$card_path" "URL")
      note=$(contact_vcard_field "$card_path" "NOTE")
      stored_identity=$(contact_vcard_field "$card_path" "X-OWL-IDENTITY")
      if [ -n "$stored_identity" ]; then
        identity="$stored_identity"
      fi
    fi
    if [ -z "$name" ] && [ -n "$fallback_label" ] && [ "$fallback_label" != "Unknown contact" ]; then
      name="$fallback_label"
    fi
    if [ -z "$name" ] && [ -n "$identity" ]; then
      name=$(derive_name_from_identity "$identity")
    fi
    if [ -z "$email" ] && [ -n "$identity" ]; then
      case "$identity" in
        *@*) email="$identity" ;;
      esac
    fi

    jq -n \
      --argjson exists "$exists" \
      --arg path "$card_path" \
      --arg identity "$identity" \
      --arg name "$name" \
      --arg email "$email" \
      --arg phone "$phone" \
      --arg address "$address" \
      --arg url "$url" \
      --arg note "$note" \
      '{ok:true,contact:{exists:$exists,path:$path,identity:$identity,name:$name,email:$email,phone:$phone,address:$address,url:$url,note:$note}}'
    ;;

  contact-save)
    identity=$(printf '%s' "${3-}" | tr -d '\r\n')
    contact_key=$(printf '%s' "${4-}" | tr -d '\r\n')
    name=$(printf '%s' "${5-}" | tr -d '\r')
    email=$(printf '%s' "${6-}" | tr -d '\r')
    phone=$(printf '%s' "${7-}" | tr -d '\r')
    address=$(printf '%s' "${8-}" | tr -d '\r')
    url=$(printf '%s' "${9-}" | tr -d '\r')
    note=$(printf '%s' "${10:-}" | tr -d '\r')
    if [ -z "$identity" ] && [ -z "$contact_key" ]; then
      printf '%s\n' "owl-desktop-backend: contact-save requires IDENTITY or CONTACT_KEY" >&2
      exit 2
    fi
    if [ -z "$email" ] && [ -n "$identity" ]; then
      case "$identity" in
        *@*) email="$identity" ;;
      esac
    fi
    if [ -z "$name" ]; then
      if [ -n "$email" ]; then
        name=$(derive_name_from_identity "$email")
      else
        name=$(derive_name_from_identity "$identity")
      fi
    fi

    card_path=$(resolve_contact_vcard_file "$identity" "$contact_key")
    tmp_card=$(mktemp "${TMPDIR:-/tmp}/owl-contact-card.XXXXXX")
    {
      printf 'BEGIN:VCARD\n'
      printf 'VERSION:4.0\n'
      if [ -n "$name" ]; then
        printf 'FN:%s\n' "$(vcard_escape_value "$name")"
      fi
      if [ -n "$email" ]; then
        printf 'EMAIL;TYPE=INTERNET:%s\n' "$(vcard_escape_value "$email")"
      fi
      if [ -n "$phone" ]; then
        printf 'TEL;TYPE=CELL:%s\n' "$(vcard_escape_value "$phone")"
      fi
      if [ -n "$address" ]; then
        printf 'ADR;TYPE=HOME:;;%s;;;;\n' "$(vcard_escape_value "$address")"
      fi
      if [ -n "$url" ]; then
        printf 'URL:%s\n' "$(vcard_escape_value "$url")"
      fi
      if [ -n "$note" ]; then
        printf 'NOTE:%s\n' "$(vcard_escape_value "$note")"
      fi
      if [ -n "$identity" ]; then
        printf 'X-OWL-IDENTITY:%s\n' "$(vcard_escape_value "$identity")"
      fi
      if [ -n "$contact_key" ]; then
        printf 'X-OWL-KEY:%s\n' "$(vcard_escape_value "$contact_key")"
      fi
      printf 'END:VCARD\n'
    } >"$tmp_card"
    mkdir -p "$(dirname "$card_path")"
    mv "$tmp_card" "$card_path"

    jq -n \
      --arg path "$card_path" \
      --arg identity "$identity" \
      --arg name "$name" \
      --arg email "$email" \
      --arg phone "$phone" \
      --arg address "$address" \
      --arg url "$url" \
      --arg note "$note" \
      '{ok:true,contact:{path:$path,identity:$identity,name:$name,email:$email,phone:$phone,address:$address,url:$url,note:$note}}'
    ;;

  list-senders)
    list=${3-}
    if [ -z "$list" ]; then
      printf '%s\n' "owl-desktop-backend: list-senders requires LIST" >&2
      exit 2
    fi
    tmp=$(mktemp "${TMPDIR:-/tmp}/owl-desktop-senders.XXXXXX")
    case "$list" in
      spam-review)
        collect_sender_json_for_list spam >> "$tmp"
        collect_sender_json_for_list banned >> "$tmp"
        ;;
      *)
        if ! is_sender_list "$list"; then
          printf '%s\n' "owl-desktop-backend: unsupported sender list: $list" >&2
          rm -f "$tmp"
          exit 2
        fi
        collect_sender_json_for_list "$list" >> "$tmp"
        ;;
    esac
    jq -n --arg list "$list" --slurpfile items "$tmp" '{ok:true,list:$list,senders:($items|sort_by(.latest,.sender)|reverse)}'
    rm -f "$tmp"
    ;;

  list-archive-bundle)
    tmp_archive=$(mktemp "${TMPDIR:-/tmp}/owl-desktop-archive.XXXXXX")
    tmp_sent=$(mktemp "${TMPDIR:-/tmp}/owl-desktop-sent.XXXXXX")
    tmp_trash=$(mktemp "${TMPDIR:-/tmp}/owl-desktop-trash.XXXXXX")
    collect_messages_flat_list archive >> "$tmp_archive"
    collect_messages_flat_list sent >> "$tmp_sent"
    collect_messages_flat_list trash >> "$tmp_trash"
    jq -n \
      --slurpfile archive_items "$tmp_archive" \
      --slurpfile sent_items "$tmp_sent" \
      --slurpfile trash_items "$tmp_trash" \
      '{ok:true,archive_messages:($archive_items|sort_by(.received_at)|reverse),sent_messages:($sent_items|sort_by(.received_at)|reverse),trash_messages:($trash_items|sort_by(.received_at)|reverse)}'
    rm -f "$tmp_archive" "$tmp_sent" "$tmp_trash"
    ;;

  list-inbox-bundle-fast)
    tmp_accepted=$(mktemp "${TMPDIR:-/tmp}/owl-desktop-inbox-accepted.XXXXXX")
    tmp_quarantine=$(mktemp "${TMPDIR:-/tmp}/owl-desktop-inbox-quarantine.XXXXXX")
    collect_messages_sender_list accepted "" fast >> "$tmp_accepted"
    collect_messages_sender_list quarantine "" fast >> "$tmp_quarantine"
    jq -n \
      --slurpfile accepted_items "$tmp_accepted" \
      --slurpfile quarantine_items "$tmp_quarantine" \
      '{ok:true,messages:(($accepted_items + $quarantine_items)|sort_by(.received_at)|reverse),accepted_messages:$accepted_items,quarantine_messages:$quarantine_items}'
    rm -f "$tmp_accepted" "$tmp_quarantine"
    ;;

  list-messages|list-messages-fast)
    message_mode=full
    if [ "$action" = "list-messages-fast" ]; then
      message_mode=fast
    fi
    list=${3-}
    sender_filter=${4-}
    if [ -z "$list" ]; then
      printf '%s\n' "owl-desktop-backend: $action requires LIST" >&2
      exit 2
    fi

    tmp=$(mktemp "${TMPDIR:-/tmp}/owl-desktop-messages.XXXXXX")
    case "$list" in
      spam-review)
        collect_messages_sender_list spam "$sender_filter" "$message_mode" >> "$tmp"
        collect_messages_sender_list banned "$sender_filter" "$message_mode" >> "$tmp"
        ;;
      *)
        if is_sender_list "$list"; then
          collect_messages_sender_list "$list" "$sender_filter" "$message_mode" >> "$tmp"
        elif is_flat_list "$list"; then
          collect_messages_flat_list "$list" "$message_mode" >> "$tmp"
        else
          printf '%s\n' "owl-desktop-backend: unsupported message list: $list" >&2
          rm -f "$tmp"
          exit 2
        fi
        ;;
    esac

    jq -n --arg list "$list" --slurpfile items "$tmp" '{ok:true,list:$list,messages:($items|sort_by(.received_at)|reverse)}'
    rm -f "$tmp"
    ;;

  get-message)
    list=${3-}
    sender=${4-}
    ulid=${5-}
    if [ -z "$list" ] || [ -z "$sender" ] || [ -z "$ulid" ]; then
      printf '%s\n' "owl-desktop-backend: get-message requires LIST SENDER ULID" >&2
      exit 2
    fi

    sidecar=$(find_sidecar_for_message "$list" "$sender" "$ulid" || true)
    if [ -z "$sidecar" ]; then
      printf '%s\n' "owl-desktop-backend: message not found ($list/$sender/$ulid)" >&2
      exit 1
    fi

    eml_path=$(sidecar_eml_path "$sidecar")
    html_path=$(sidecar_render_path "$sidecar" "html" || true)
    plain_path=$(sidecar_render_path "$sidecar" "plain" || true)

    plain_body=''
    if [ -n "$plain_path" ] && [ -f "$plain_path" ]; then
      plain_body=$(head -c 200000 "$plain_path" 2>/dev/null || true)
    elif [ -f "$eml_path" ]; then
      plain_body=$(extract_eml_body "$eml_path" | head -c 200000 2>/dev/null || true)
    fi

    html_body=''
    if [ -n "$html_path" ] && [ -f "$html_path" ]; then
      html_body=$(head -c 350000 "$html_path" 2>/dev/null || true)
    fi

    summary=$(emit_message_json "$list" "$sender" "$sidecar")
    jq -n \
      --argjson summary "$summary" \
      --arg plain_body "$plain_body" \
      --arg html_body "$html_body" \
      --arg sidecar_path "$sidecar" \
      '{ok:true,message:($summary + {plain_body:$plain_body,html_body:$html_body,sidecar_path:$sidecar_path})}'
    ;;

  set-flag)
    list=${3-}
    sender=${4-}
    ulid=${5-}
    field=${6-}
    value=${7-}
    if [ -z "$list" ] || [ -z "$sender" ] || [ -z "$ulid" ] || [ -z "$field" ] || [ -z "$value" ]; then
      printf '%s\n' "owl-desktop-backend: set-flag requires LIST SENDER ULID FIELD VALUE" >&2
      exit 2
    fi
    case "$field" in
      read|starred|pinned) ;;
      *)
        printf '%s\n' "owl-desktop-backend: unsupported field for set-flag: $field" >&2
        exit 2
        ;;
    esac

    sidecar=$(find_sidecar_for_message "$list" "$sender" "$ulid" || true)
    if [ -z "$sidecar" ]; then
      printf '%s\n' "owl-desktop-backend: message not found ($list/$sender/$ulid)" >&2
      exit 1
    fi

    bool_value=$(json_bool "$value")
    set_yaml_scalar "$sidecar" "$field" "$bool_value"
    touch_sidecar_activity "$sidecar"

    jq -n --arg list "$list" --arg sender "$sender" --arg ulid "$ulid" --arg field "$field" --argjson value "$bool_value" '{ok:true,list:$list,sender:$sender,ulid:$ulid,field:$field,value:$value}'
    ;;

  move-message)
    from=${3-}
    to=${4-}
    sender=${5-}
    ulid=${6-}
    if [ -z "$from" ] || [ -z "$to" ] || [ -z "$sender" ] || [ -z "$ulid" ]; then
      printf '%s\n' "owl-desktop-backend: move-message requires FROM TO SENDER ULID" >&2
      exit 2
    fi
    if [ "$from" = "$to" ]; then
      printf '%s\n' "owl-desktop-backend: source and destination lists are identical" >&2
      exit 2
    fi
    if ! is_sender_list "$from" || ! is_sender_list "$to"; then
      printf '%s\n' "owl-desktop-backend: move-message supports sender lists only" >&2
      exit 2
    fi

    sidecar=$(find_sidecar_for_message "$from" "$sender" "$ulid" || true)
    if [ -z "$sidecar" ]; then
      printf '%s\n' "owl-desktop-backend: message not found ($from/$sender/$ulid)" >&2
      exit 1
    fi

    source_dir=$(dirname "$sidecar")
    dest_dir="$ROOT/$to/$sender"
    mkdir -p "$dest_dir"

    base=$(basename "$sidecar")
    sidecar_dest=$(unique_destination_path "$dest_dir/$base")

    eml_src=$(sidecar_eml_path "$sidecar")
    eml_dest=$(sidecar_eml_path "$sidecar_dest")
    html_src=$(sidecar_render_path "$sidecar" "html" || true)
    html_dest=''
    html_rel=''
    if [ -n "$html_src" ]; then
      html_rel=$(yaml_scalar "$sidecar" "html")
      case "$html_rel" in
        /*)
          html_dest="$html_rel"
          ;;
        *)
          html_dest="$dest_dir/$html_rel"
          ;;
      esac
      html_dest=$(unique_destination_path "$html_dest")
    fi

    mv "$sidecar" "$sidecar_dest"
    [ -f "$eml_src" ] && mv "$eml_src" "$eml_dest"
    if [ -n "$html_src" ] && [ -f "$html_src" ] && [ -n "$html_dest" ]; then
      mv "$html_src" "$html_dest"
      case "$html_rel" in
        /*)
          set_yaml_scalar "$sidecar_dest" "html" "$html_dest"
          ;;
        *)
          html_rel_new=${html_dest#"$dest_dir"/}
          if [ "$html_rel_new" = "$html_dest" ]; then
            html_rel_new=$(basename "$html_dest")
          fi
          set_yaml_scalar "$sidecar_dest" "html" "$html_rel_new"
          ;;
      esac
    fi
    update_sidecar_status "$sidecar_dest" "$to"
    touch_sidecar_activity "$sidecar_dest"

    [ -d "$source_dir" ] && rmdir "$source_dir" 2>/dev/null || true

    jq -n --arg from "$from" --arg to "$to" --arg sender "$sender" --arg ulid "$ulid" '{ok:true,from:$from,to:$to,sender:$sender,ulid:$ulid}'
    ;;

  move-sender)
    from=${3-}
    to=${4-}
    sender=${5-}
    if [ -z "$from" ] || [ -z "$to" ] || [ -z "$sender" ]; then
      printf '%s\n' "owl-desktop-backend: move-sender requires FROM TO SENDER" >&2
      exit 2
    fi
    if [ "$from" = "$to" ]; then
      printf '%s\n' "owl-desktop-backend: source and destination lists are identical" >&2
      exit 2
    fi

    if ! is_sender_list "$from" || ! is_sender_list "$to"; then
      printf '%s\n' "owl-desktop-backend: unsupported sender move ($from -> $to)" >&2
      exit 2
    fi

    source_dir="$ROOT/$from/$sender"
    dest_dir="$ROOT/$to/$sender"
    [ -d "$source_dir" ] || {
      printf '%s\n' "owl-desktop-backend: sender folder not found: $source_dir" >&2
      exit 1
    }
    mkdir -p "$dest_dir"

    moved_count=0
    for sidecar in "$source_dir"/.*.yml "$source_dir"/*.yml; do
      [ -f "$sidecar" ] || continue
      base=$(basename "$sidecar")
      sidecar_dest=$(unique_destination_path "$dest_dir/$base")

      eml_src=$(sidecar_eml_path "$sidecar")
      eml_dest=$(sidecar_eml_path "$sidecar_dest")
      html_src=$(sidecar_render_path "$sidecar" "html" || true)
      html_dest=''
      html_rel=''
      if [ -n "$html_src" ]; then
        html_rel=$(yaml_scalar "$sidecar" "html")
        case "$html_rel" in
          /*)
            html_dest="$html_rel"
            ;;
          *)
            html_dest="$dest_dir/$html_rel"
            ;;
        esac
        html_dest=$(unique_destination_path "$html_dest")
      fi

      mv "$sidecar" "$sidecar_dest"
      [ -f "$eml_src" ] && mv "$eml_src" "$eml_dest"
      if [ -n "$html_src" ] && [ -f "$html_src" ] && [ -n "$html_dest" ]; then
        mv "$html_src" "$html_dest"
        case "$html_rel" in
          /*)
            set_yaml_scalar "$sidecar_dest" "html" "$html_dest"
            ;;
          *)
            html_rel_new=${html_dest#"$dest_dir"/}
            if [ "$html_rel_new" = "$html_dest" ]; then
              html_rel_new=$(basename "$html_dest")
            fi
            set_yaml_scalar "$sidecar_dest" "html" "$html_rel_new"
            ;;
        esac
      fi
      update_sidecar_status "$sidecar_dest" "$to"
      touch_sidecar_activity "$sidecar_dest"
      moved_count=$((moved_count + 1))
    done

    [ -d "$source_dir" ] && rmdir "$source_dir" 2>/dev/null || true
    jq -n --arg from "$from" --arg to "$to" --arg sender "$sender" --argjson moved "$moved_count" '{ok:true,from:$from,to:$to,sender:$sender,moved:$moved}'
    ;;

  delete-message)
    list=${3-}
    sender=${4-}
    ulid=${5-}
    if [ -z "$list" ] || [ -z "$sender" ] || [ -z "$ulid" ]; then
      printf '%s\n' "owl-desktop-backend: delete-message requires LIST SENDER ULID" >&2
      exit 2
    fi
    sidecar=$(find_sidecar_for_message "$list" "$sender" "$ulid" || true)
    if [ -z "$sidecar" ]; then
      printf '%s\n' "owl-desktop-backend: message not found ($list/$sender/$ulid)" >&2
      exit 1
    fi
    sender_dir=$(dirname "$sidecar")
    remove_message_files "$sidecar"
    [ -d "$sender_dir" ] && rmdir "$sender_dir" 2>/dev/null || true
    jq -n --arg list "$list" --arg sender "$sender" --arg ulid "$ulid" '{ok:true,list:$list,sender:$sender,ulid:$ulid}'
    ;;

  draft-list)
    drafts_dir="$ROOT/drafts"
    tmp=$(mktemp "${TMPDIR:-/tmp}/owl-desktop-drafts.XXXXXX")
    for file in "$drafts_dir"/*.md; do
      [ -f "$file" ] || continue
      ulid=$(basename "$file" .md)
      subject=$(strip_yaml_quotes "$(draft_field "$file" "subject")")
      from=$(strip_yaml_quotes "$(draft_field "$file" "from")")
      preview=$(draft_first_body_line "$file")
      mtime=$(file_mtime_epoch "$file")
      jq -cn \
        --arg ulid "$ulid" \
        --arg path "$file" \
        --arg subject "$subject" \
        --arg from "$from" \
        --arg preview "$preview" \
        --argjson mtime "$mtime" \
        '{ulid:$ulid,path:$path,subject:$subject,from:$from,preview:$preview,mtime:$mtime}' >> "$tmp"
    done
    jq -n --slurpfile drafts "$tmp" '{ok:true,drafts:($drafts|sort_by(.mtime)|reverse)}'
    rm -f "$tmp"
    ;;

  draft-get)
    ulid=${3-}
    if [ -z "$ulid" ]; then
      printf '%s\n' "owl-desktop-backend: draft-get requires ULID" >&2
      exit 2
    fi
    path="$ROOT/drafts/$ulid.md"
    [ -f "$path" ] || {
      printf '%s\n' "owl-desktop-backend: draft not found: $path" >&2
      exit 1
    }
    raw=$(cat "$path")
    subject=$(strip_yaml_quotes "$(draft_field "$path" "subject")")
    from=$(strip_yaml_quotes "$(draft_field "$path" "from")")
    to=$(strip_yaml_quotes "$(draft_field "$path" "to")")
    cc=$(strip_yaml_quotes "$(draft_field "$path" "cc")")
    bcc=$(strip_yaml_quotes "$(draft_field "$path" "bcc")")
    reply_to=$(strip_yaml_quotes "$(draft_field "$path" "reply_to")")
    jq -n \
      --arg ulid "$ulid" \
      --arg path "$path" \
      --arg raw "$raw" \
      --arg subject "$subject" \
      --arg from "$from" \
      --arg to "$to" \
      --arg cc "$cc" \
      --arg bcc "$bcc" \
      --arg reply_to "$reply_to" \
      '{ok:true,draft:{ulid:$ulid,path:$path,raw:$raw,subject:$subject,from:$from,to:$to,cc:$cc,bcc:$bcc,reply_to:$reply_to}}'
    ;;

  draft-save)
    ulid=${3-}
    from=${4-}
    to_csv=${5-}
    cc_csv=${6-}
    bcc_csv=${7-}
    subject=${8-}
    reply_to=${9-}
    body_b64=${10-}

    case "$ulid" in
      ''|new|NEW|_)
        ulid=$(generate_ulid)
        ;;
    esac

    drafts_dir="$ROOT/drafts"
    mkdir -p "$drafts_dir"
    path="$drafts_dir/$ulid.md"

    body_tmp=$(mktemp "${TMPDIR:-/tmp}/owl-draft-body.XXXXXX")
    if printf '%s' "$body_b64" | base64 --decode > "$body_tmp" 2>/dev/null; then
      :
    elif printf '%s' "$body_b64" | base64 -D > "$body_tmp" 2>/dev/null; then
      :
    else
      rm -f "$body_tmp"
      printf '%s\n' "owl-desktop-backend: invalid base64 body payload" >&2
      exit 2
    fi
    body=$(cat "$body_tmp")
    rm -f "$body_tmp"

    {
      printf '%s\n' '---'
      printf 'subject: %s\n' "$(yaml_single_quote "$subject")"
      printf 'from: %s\n' "$(yaml_single_quote "$from")"
      printf '%s\n' 'to:'
      printf '%s' "$to_csv" | tr ',;' '\n' | while IFS= read -r addr; do
        trimmed=$(printf '%s' "$addr" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [ -n "$trimmed" ] || continue
        printf '  - %s\n' "$(yaml_single_quote "$trimmed")"
      done

      cc_block=$(mktemp "${TMPDIR:-/tmp}/owl-draft-cc.XXXXXX")
      printf '%s' "$cc_csv" | tr ',;' '\n' | while IFS= read -r addr; do
        trimmed=$(printf '%s' "$addr" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [ -n "$trimmed" ] || continue
        printf '  - %s\n' "$(yaml_single_quote "$trimmed")"
      done > "$cc_block"
      if [ -s "$cc_block" ]; then
        printf '%s\n' 'cc:'
        cat "$cc_block"
      fi
      rm -f "$cc_block"

      bcc_block=$(mktemp "${TMPDIR:-/tmp}/owl-draft-bcc.XXXXXX")
      printf '%s' "$bcc_csv" | tr ',;' '\n' | while IFS= read -r addr; do
        trimmed=$(printf '%s' "$addr" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [ -n "$trimmed" ] || continue
        printf '  - %s\n' "$(yaml_single_quote "$trimmed")"
      done > "$bcc_block"
      if [ -s "$bcc_block" ]; then
        printf '%s\n' 'bcc:'
        cat "$bcc_block"
      fi
      rm -f "$bcc_block"

      if [ -n "$reply_to" ]; then
        printf 'reply_to: %s\n' "$(yaml_single_quote "$reply_to")"
      fi
      printf '%s\n' '---'
      printf '%s\n' "$body"
    } > "$path"

    jq -n --arg ulid "$ulid" --arg path "$path" '{ok:true,ulid:$ulid,path:$path}'
    ;;

  draft-delete)
    ulid=${3-}
    if [ -z "$ulid" ]; then
      printf '%s\n' "owl-desktop-backend: draft-delete requires ULID" >&2
      exit 2
    fi
    path="$ROOT/drafts/$ulid.md"
    [ -f "$path" ] || {
      printf '%s\n' "owl-desktop-backend: draft not found: $path" >&2
      exit 1
    }
    rm -f "$path"
    jq -n --arg ulid "$ulid" '{ok:true,ulid:$ulid}'
    ;;

  draft-send)
    ulid=${3-}
    if [ -z "$ulid" ]; then
      printf '%s\n' "owl-desktop-backend: draft-send requires ULID" >&2
      exit 2
    fi
    out=$(run_owl send "$ulid")
    jq -n --arg ulid "$ulid" --arg output "$out" '{ok:true,ulid:$ulid,output:$output}'
    ;;

  *)
    printf '%s\n' "owl-desktop-backend: unknown action: $action" >&2
    exit 2
    ;;
esac
