#!/bin/sh
set -eu

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

prompt() {
  label="$1"
  default="$2"
  if [ -n "$default" ]; then
    printf '%s [%s]: ' "$label" "$default"
  else
    printf '%s: ' "$label"
  fi
  read value
  if [ -z "$value" ]; then
    value="$default"
  fi
  printf '%s' "$value"
}

prompt_yes_no() {
  label="$1"
  default="$2"
  while :; do
    if [ "$default" = "y" ]; then
      printf '%s [Y/n]: ' "$label"
    else
      printf '%s [y/N]: ' "$label"
    fi
    read ans
    if [ -z "$ans" ]; then
      ans="$default"
    fi
    case "$ans" in
      y|Y) return 0 ;;
      n|N) return 1 ;;
    esac
    log "Please answer y or n."
  done
}

ensure_dir() {
  path="$1"
  if [ ! -d "$path" ]; then
    mkdir -p "$path"
  fi
}

write_env_setting() {
  file="$1"
  key="$2"
  value="$3"
  tmp=$(mktemp)
  if [ -f "$file" ]; then
    awk -v key="$key" -v value="$value" 'BEGIN{found=0}
      $0 ~ "^"key"=" {print key"="value; found=1; next}
      {print}
      END{if (!found) print key"="value}
    ' "$file" > "$tmp"
  else
    printf '%s=%s\n' "$key" "$value" > "$tmp"
  fi
  mv "$tmp" "$file"
}

set_rules_entry() {
  rules_path="$1"
  entry="$2"
  ensure_dir "$(dirname "$rules_path")"
  if [ ! -f "$rules_path" ]; then
    printf '%s\n' "$entry" > "$rules_path"
    return
  fi
  if ! grep -F "$entry" "$rules_path" >/dev/null 2>&1; then
    printf '%s\n' "$entry" >> "$rules_path"
  fi
}

set_settings_file() {
  settings_path="$1"
  from_value="$2"
  reply_to="$3"
  signature="$4"
  body_format="$5"
  delete_after="$6"
  list_status="$7"
  ensure_dir "$(dirname "$settings_path")"
  cat > "$settings_path" <<SETTINGS
list_status=$list_status
delete_after=$delete_after
from=$from_value
reply_to=$reply_to
signature=$signature
body_format=$body_format
collapse_signatures=true
SETTINGS
}

setup_env() {
  env_path="$1"
  log "Configuring env file at $env_path"
  keep_plus=$(prompt "Keep plus-tags in addresses? (true/false)" "false")
  render_mode=$(prompt "Render mode (strict/moderate)" "strict")
  logging=$(prompt "Logging level (off/minimal/verbose_sanitized/verbose_full)" "minimal")
  max_quarantine=$(prompt "Max size for quarantine (e.g. 25M)" "25M")
  max_approved=$(prompt "Max size for approved mail (e.g. 50M)" "50M")
  dkim_selector=$(prompt "DKIM selector" "mail")
  dmarc_policy=$(prompt "DMARC policy" "none")
  retry_backoff=$(prompt "Retry backoff schedule" "1m,5m,15m,1h")

  write_env_setting "$env_path" "keep_plus_tags" "$keep_plus"
  write_env_setting "$env_path" "render_mode" "$render_mode"
  write_env_setting "$env_path" "logging" "$logging"
  write_env_setting "$env_path" "max_size_quarantine" "$max_quarantine"
  write_env_setting "$env_path" "max_size_approved_default" "$max_approved"
  write_env_setting "$env_path" "dkim_selector" "$dkim_selector"
  write_env_setting "$env_path" "dmarc_policy" "$dmarc_policy"
  write_env_setting "$env_path" "retry_backoff" "$retry_backoff"
}

run_install() {
  env_path="$1"
  if ! command -v owl >/dev/null 2>&1; then
    fail "owl binary not found on PATH"
  fi
  owl install --env "$env_path"
}

menu() {
  env_path="$1"
  root_dir="$2"
  while :; do
    log ""
    log "Owl configuration wizard"
    log "1) Initialize mail root (owl install)"
    log "2) Configure env settings"
    log "3) Add accepted routing rule"
    log "4) Add spam routing rule"
    log "5) Add banned routing rule"
    log "6) Configure list settings"
    log "7) Show current env + rules summary"
    log "8) Quit"
    printf 'Choose an option [1-8]: '
    read choice
    case "$choice" in
      1)
        run_install "$env_path"
        ;;
      2)
        setup_env "$env_path"
        ;;
      3)
        entry=$(prompt "Accepted rule (address/domain/regex)" "")
        if [ -n "$entry" ]; then
          set_rules_entry "$root_dir/accepted/.rules" "$entry"
        fi
        ;;
      4)
        entry=$(prompt "Spam rule (address/domain/regex)" "")
        if [ -n "$entry" ]; then
          set_rules_entry "$root_dir/spam/.rules" "$entry"
        fi
        ;;
      5)
        entry=$(prompt "Banned rule (address/domain/regex)" "")
        if [ -n "$entry" ]; then
          set_rules_entry "$root_dir/banned/.rules" "$entry"
        fi
        ;;
      6)
        list=$(prompt "List to configure (accepted/spam/banned)" "accepted")
        case "$list" in
          accepted|spam|banned) ;;
          *)
            log "Unknown list: $list"
            continue
            ;;
        esac
        from_value=$(prompt "From header" "Owl <owl@example.org>")
        reply_to=$(prompt "Reply-To header" "")
        signature=$(prompt "Signature path (optional)" "")
        body_format=$(prompt "Body format (both/plain/html)" "both")
        delete_after=$(prompt "Delete after (never/30d/6m/2y)" "never")
        list_status=$(prompt "List status (accepted/rejected/banned)" "accepted")
        set_settings_file "$root_dir/$list/.settings" "$from_value" "$reply_to" "$signature" "$body_format" "$delete_after" "$list_status"
        ;;
      7)
        log "Env file: $env_path"
        if [ -f "$env_path" ]; then
          sed 's/^/  /' "$env_path"
        else
          log "  (missing)"
        fi
        for list in accepted spam banned; do
          rules="$root_dir/$list/.rules"
          log "Rules for $list: $rules"
          if [ -f "$rules" ]; then
            sed 's/^/  /' "$rules"
          else
            log "  (missing)"
          fi
        done
        ;;
      8)
        log "Exiting configuration wizard."
        return
        ;;
      *)
        log "Invalid selection."
        ;;
    esac
  done
}

main() {
  log "Welcome to Owl configuration"
  mail_root=$(prompt "Mail root directory" "/home/pi/mail")
  ensure_dir "$mail_root"
  env_path=$(prompt "Env file path" "$mail_root/.env")

  if [ ! -f "$env_path" ]; then
    if prompt_yes_no "Create env file now?" "y"; then
      setup_env "$env_path"
    fi
  fi

  menu "$env_path" "$mail_root"
}

main "$@"
