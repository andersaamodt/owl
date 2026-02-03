#!/bin/sh
# POSIX-compliant script to install owl daemon as a system service
set -eu

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

get_install_dir() {
  if command_exists owl-daemon; then
    dirname "$(command -v owl-daemon)"
  elif [ -n "${OWL_INSTALL_DIR:-}" ]; then
    printf '%s' "$OWL_INSTALL_DIR"
  elif [ "$(id -u)" -eq 0 ]; then
    printf '%s' "/usr/local/bin"
  else
    printf '%s' "$HOME/.local/bin"
  fi
}

get_mail_root() {
  if [ -n "${OWL_MAIL_ROOT:-}" ]; then
    printf '%s' "$OWL_MAIL_ROOT"
  else
    printf '%s' "$HOME/mail"
  fi
}

detect_os() {
  case "$(uname -s)" in
    Linux) echo "linux" ;;
    Darwin) echo "darwin" ;;
    *) fail "unsupported OS: $(uname -s)" ;;
  esac
}

install_systemd() {
  install_dir="$1"
  mail_root="$2"
  user="${3:-$(whoami)}"
  
  service_file="/tmp/owld.service.$$"
  
  if [ "$(id -u)" -eq 0 ]; then
    # System-wide installation
    sed -e "s|%INSTALL_DIR%|$install_dir|g" \
        -e "s|%MAIL_ROOT%|$mail_root|g" \
        -e "s|%USER%|$user|g" \
        "$(dirname "$0")/owld.service" > "$service_file"
    install -m 0644 "$service_file" /etc/systemd/system/owld.service
    systemctl daemon-reload
    systemctl enable owld.service
    log "Installed owld.service to /etc/systemd/system/"
    log "Start with: systemctl start owld"
  else
    # User-level installation - use default.target instead of multi-user.target
    sed -e "s|%INSTALL_DIR%|$install_dir|g" \
        -e "s|%MAIL_ROOT%|$mail_root|g" \
        -e "s|%USER%|$user|g" \
        -e "s|WantedBy=multi-user.target|WantedBy=default.target|g" \
        "$(dirname "$0")/owld.service" > "$service_file"
    user_unit_dir="$HOME/.config/systemd/user"
    mkdir -p "$user_unit_dir"
    install -m 0644 "$service_file" "$user_unit_dir/owld.service"
    systemctl --user daemon-reload
    systemctl --user enable owld.service
    log "Installed owld.service to $user_unit_dir/"
    log "Start with: systemctl --user start owld"
  fi
  
  rm -f "$service_file"
}

install_launchd() {
  install_dir="$1"
  mail_root="$2"
  
  plist_file="/tmp/com.owl.daemon.plist.$$"
  sed -e "s|%INSTALL_DIR%|$install_dir|g" \
      -e "s|%MAIL_ROOT%|$mail_root|g" \
      "$(dirname "$0")/com.owl.daemon.plist" > "$plist_file"
  
  user_agent_dir="$HOME/Library/LaunchAgents"
  mkdir -p "$user_agent_dir"
  install -m 0644 "$plist_file" "$user_agent_dir/com.owl.daemon.plist"
  launchctl load "$user_agent_dir/com.owl.daemon.plist"
  
  log "Installed com.owl.daemon.plist to $user_agent_dir/"
  log "Start with: launchctl start com.owl.daemon"
  
  rm -f "$plist_file"
}

main() {
  if ! command_exists owl-daemon; then
    fail "owl-daemon not found. Please install owl first."
  fi
  
  install_dir=$(get_install_dir)
  mail_root=$(get_mail_root)
  os=$(detect_os)
  
  log "Installing owl daemon service..."
  log "Install dir: $install_dir"
  log "Mail root: $mail_root"
  log "OS: $os"
  
  case "$os" in
    linux)
      if ! command_exists systemctl; then
        fail "systemctl not found. systemd is required on Linux."
      fi
      install_systemd "$install_dir" "$mail_root"
      ;;
    darwin)
      if ! command_exists launchctl; then
        fail "launchctl not found. launchd is required on macOS."
      fi
      install_launchd "$install_dir" "$mail_root"
      ;;
  esac
  
  log "Owl daemon installed successfully!"
}

main "$@"
