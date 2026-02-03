#!/bin/sh
# POSIX-compliant script to remove owl daemon from system services
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

detect_os() {
  case "$(uname -s)" in
    Linux) echo "linux" ;;
    Darwin) echo "darwin" ;;
    *) fail "unsupported OS: $(uname -s)" ;;
  esac
}

remove_systemd() {
  if [ "$(id -u)" -eq 0 ]; then
    # System-wide removal
    if [ -f /etc/systemd/system/owld.service ]; then
      systemctl stop owld.service 2>/dev/null || true
      systemctl disable owld.service 2>/dev/null || true
      rm -f /etc/systemd/system/owld.service
      systemctl daemon-reload
      log "Removed owld.service from /etc/systemd/system/"
    else
      log "System service not found: /etc/systemd/system/owld.service"
    fi
  else
    # User-level removal
    user_unit_dir="$HOME/.config/systemd/user"
    if [ -f "$user_unit_dir/owld.service" ]; then
      systemctl --user stop owld.service 2>/dev/null || true
      systemctl --user disable owld.service 2>/dev/null || true
      rm -f "$user_unit_dir/owld.service"
      systemctl --user daemon-reload
      log "Removed owld.service from $user_unit_dir/"
    else
      log "User service not found: $user_unit_dir/owld.service"
    fi
  fi
}

remove_launchd() {
  user_agent_dir="$HOME/Library/LaunchAgents"
  plist_path="$user_agent_dir/com.owl.daemon.plist"
  
  if [ -f "$plist_path" ]; then
    # Try bootout first (modern macOS), fall back to unload
    # The service target is gui/<uid>/com.owl.daemon
    uid=$(id -u)
    launchctl bootout "gui/$uid/com.owl.daemon" 2>/dev/null || \
      launchctl unload "$plist_path" 2>/dev/null || true
    rm -f "$plist_path"
    log "Removed com.owl.daemon.plist from $user_agent_dir/"
  else
    log "LaunchAgent not found: $plist_path"
  fi
}

main() {
  os=$(detect_os)
  
  log "Removing owl daemon service..."
  log "OS: $os"
  
  case "$os" in
    linux)
      if ! command_exists systemctl; then
        fail "systemctl not found. Cannot remove systemd service."
      fi
      remove_systemd
      ;;
    darwin)
      if ! command_exists launchctl; then
        fail "launchctl not found. Cannot remove launchd service."
      fi
      remove_launchd
      ;;
  esac
  
  log "Owl daemon removed successfully!"
}

main "$@"
