#!/bin/sh
set -eu

OWL_REPO_DEFAULT="owl-mail/owl"
OWL_REPO="${OWL_REPO:-$OWL_REPO_DEFAULT}"
OWL_VERSION="${OWL_VERSION:-latest}"
OWL_INSTALL_DIR="${OWL_INSTALL_DIR:-}"
OWL_BIN_NAME="owl"
OWL_DAEMON_NAME="owl-daemon"

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

ensure_download_tool() {
  if command_exists curl; then
    echo curl
    return
  fi
  if command_exists wget; then
    echo wget
    return
  fi
  fail "curl or wget is required"
}

download_to() {
  url="$1"
  dest="$2"
  tool=$(ensure_download_tool)
  if [ "$tool" = "curl" ]; then
    curl -fsSL "$url" -o "$dest"
  else
    wget -q "$url" -O "$dest"
  fi
}

resolve_install_dir() {
  if [ -n "$OWL_INSTALL_DIR" ]; then
    printf '%s' "$OWL_INSTALL_DIR"
    return
  fi
  if [ "$(id -u)" -eq 0 ]; then
    printf '%s' "/usr/local/bin"
  else
    printf '%s' "$HOME/.local/bin"
  fi
}

ensure_install_dir() {
  dir="$1"
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
  fi
  case ":$PATH:" in
    *":$dir:"*)
      ;;
    *)
      log "notice: $dir is not on PATH. Add it to your shell profile."
      ;;
  esac
}

resolve_target() {
  os=$(uname -s)
  arch=$(uname -m)
  case "$os" in
    Linux) os_id=linux ;;
    Darwin) os_id=darwin ;;
    *) fail "unsupported OS: $os" ;;
  esac
  case "$arch" in
    x86_64|amd64) arch_id=x86_64 ;;
    aarch64|arm64) arch_id=aarch64 ;;
    armv7l|armv7) arch_id=armv7 ;;
    *) fail "unsupported architecture: $arch" ;;
  esac
  if [ "$os_id" = "linux" ]; then
    case "$arch_id" in
      x86_64) echo "x86_64-unknown-linux-musl" ;;
      aarch64) echo "aarch64-unknown-linux-musl" ;;
      armv7) echo "armv7-unknown-linux-gnueabihf" ;;
    esac
  else
    if [ "$arch_id" = "x86_64" ]; then
      echo "x86_64-apple-darwin"
    else
      echo "aarch64-apple-darwin"
    fi
  fi
}

fetch_release_url() {
  target="$1"
  repo="$2"
  version="$3"
  api_url="https://api.github.com/repos/$repo/releases"
  if [ "$version" = "latest" ]; then
    api_url="$api_url/latest"
  else
    api_url="$api_url/tags/$version"
  fi
  tmp_json=$(mktemp)
  download_to "$api_url" "$tmp_json"
  url=$(grep -E '"browser_download_url"' "$tmp_json" | sed -n "s/.*\"browser_download_url\": \"\(.*$OWL_BIN_NAME-$target\)\".*/\1/p" | head -n 1)
  daemon_url=$(grep -E '"browser_download_url"' "$tmp_json" | sed -n "s/.*\"browser_download_url\": \"\(.*$OWL_DAEMON_NAME-$target\)\".*/\1/p" | head -n 1)
  rm -f "$tmp_json"
  if [ -z "$url" ] || [ -z "$daemon_url" ]; then
    return 1
  fi
  printf '%s\n%s\n' "$url" "$daemon_url"
}

install_from_release() {
  target="$1"
  repo="$2"
  version="$3"
  urls=$(fetch_release_url "$target" "$repo" "$version") || return 1
  bin_url=$(printf '%s' "$urls" | sed -n '1p')
  daemon_url=$(printf '%s' "$urls" | sed -n '2p')
  tmp_dir=$(mktemp -d)
  download_to "$bin_url" "$tmp_dir/$OWL_BIN_NAME"
  download_to "$daemon_url" "$tmp_dir/$OWL_DAEMON_NAME"
  chmod +x "$tmp_dir/$OWL_BIN_NAME" "$tmp_dir/$OWL_DAEMON_NAME"
  install_dir=$(resolve_install_dir)
  ensure_install_dir "$install_dir"
  install -m 0755 "$tmp_dir/$OWL_BIN_NAME" "$install_dir/$OWL_BIN_NAME"
  install -m 0755 "$tmp_dir/$OWL_DAEMON_NAME" "$install_dir/$OWL_DAEMON_NAME"
  rm -rf "$tmp_dir"
  log "installed $OWL_BIN_NAME and $OWL_DAEMON_NAME to $install_dir"
}

install_from_source() {
  repo="$1"
  if ! command_exists git; then
    fail "git is required to build from source"
  fi
  if ! command_exists cargo; then
    fail "cargo is required to build from source"
  fi
  tmp_dir=$(mktemp -d)
  git clone "https://github.com/$repo" "$tmp_dir/owl-src" >/dev/null 2>&1
  (cd "$tmp_dir/owl-src" && cargo build --release --locked --bins)
  install_dir=$(resolve_install_dir)
  ensure_install_dir "$install_dir"
  install -m 0755 "$tmp_dir/owl-src/target/release/$OWL_BIN_NAME" "$install_dir/$OWL_BIN_NAME"
  install -m 0755 "$tmp_dir/owl-src/target/release/$OWL_DAEMON_NAME" "$install_dir/$OWL_DAEMON_NAME"
  rm -rf "$tmp_dir"
  log "built and installed from source to $install_dir"
}

prompt_yes_no() {
  prompt="$1"
  default="$2"
  while :; do
    if [ "$default" = "y" ]; then
      printf '%s [Y/n]: ' "$prompt"
    else
      printf '%s [y/N]: ' "$prompt"
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

print_welcome() {
  log ""
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "              Owl - File-First Email System"
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log ""
  log "Owl is a self-hosted email system that stores your mail as files,"
  log "making it easy to sync, backup, and manage with standard tools."
  log ""
  log "This installer will set you up to:"
  log "  • Receive and organize incoming mail"
  log "  • Send outgoing messages with DKIM signing"
  log "  • Route mail to custom lists (accepted, spam, banned)"
  log "  • Run an optional background daemon for automatic processing"
  log ""
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log ""
}

setup_daemon_service() {
  script_dir="$(dirname "$0")"
  if [ ! -f "$script_dir/add-daemon.sh" ]; then
    log "Daemon setup script not found. Skipping daemon setup."
    return
  fi
  
  if prompt_yes_no "Would you like to set up Owl daemon to start at system startup?" "n"; then
    log "Setting up daemon service..."
    if sh "$script_dir/add-daemon.sh"; then
      log "Daemon service installed successfully!"
    else
      log "Failed to install daemon service. You can try manually later with:"
      log "  sh $script_dir/add-daemon.sh"
    fi
  else
    log "Daemon setup skipped. You can run it later with:"
    log "  sh $script_dir/add-daemon.sh"
    log ""
    log "Or start the daemon manually when needed:"
    log "  owl-daemon"
  fi
}

print_tips() {
  log ""
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "              Installation Complete!"
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log ""
  log "Useful commands to get started:"
  log ""
  log "  owl triage              # View messages in quarantine"
  log "  owl list-senders        # Show all senders across lists"
  log "  owl move-sender <addr> <list>  # Move sender to a list"
  log "  owl send <draft-id>     # Queue a draft for sending"
  log "  owl logs                # View system logs"
  log "  owl-daemon              # Start background processor manually"
  log ""
  log "Configuration files:"
  log ""
  log "  ~/mail/.env             # Main configuration"
  log "  ~/mail/accepted/.rules  # Routing rules for accepted mail"
  log "  ~/mail/spam/.rules      # Routing rules for spam"
  log ""
  log "Tips:"
  log ""
  log "  • Run 'owl configure' to set up SMTP and customize settings"
  log "  • Messages arrive in ~/mail/quarantine/ until routed"
  log "  • Use .rules files to automatically route mail to lists"
  log "  • The daemon processes mail automatically in the background"
  log "  • Without the daemon, run 'owl triage' and 'owl send' manually"
  log ""
  log "Documentation: https://github.com/owl-mail/owl"
  log ""
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log ""
}

main() {
  print_welcome
  
  log "Repository: $OWL_REPO"
  target=$(resolve_target)
  log "Detected target: $target"
  log ""

  if ! install_from_release "$target" "$OWL_REPO" "$OWL_VERSION"; then
    log "release assets not found; falling back to source build"
    install_from_source "$OWL_REPO"
  fi

  log ""
  if prompt_yes_no "Would you like to configure Owl now?" "y"; then
    if command -v owl >/dev/null 2>&1; then
      owl configure
    else
      log "Configuration wizard requires the owl binary on PATH."
      log "Run: owl configure"
    fi
  else
    log "Configuration skipped. You can run: owl configure"
  fi

  log ""
  setup_daemon_service

  print_tips
}

main "$@"
