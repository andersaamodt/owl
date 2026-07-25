#!/bin/sh

set -eu

test_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
repo_dir=$(CDPATH= cd -- "$test_dir/../.." && pwd -P)
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/stellar-mail-bundle-test.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

test -f "$repo_dir/mail-engine/Cargo.toml"
test -f "$repo_dir/mail-engine/Cargo.lock"
test -f "$repo_dir/mail-engine/src/bin/owl-daemon.rs"
test -x "$repo_dir/scripts/stellar-mail-backend.sh"
test -x "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"

HOME="$tmpdir/home" \
XDG_STATE_HOME="$tmpdir/state" \
XDG_CONFIG_HOME="$tmpdir/config" \
  sh "$repo_dir/scripts/stellar-backend.sh" doctor "$tmpdir/mail" |
  jq -e '
    .ok == true and
    .mail_backend.available == true and
    .mail_backend.source == "bundled"
  ' >/dev/null

grep -Fq 'cp scripts/stellar-mail-backend.sh' "$repo_dir/.github/workflows/native-release.yml"
grep -Fq 'cp -R mail-engine' "$repo_dir/.github/workflows/native-release.yml"
grep -Fq 'cargo build --manifest-path mail-engine/Cargo.toml --release --locked --bins' "$repo_dir/.github/workflows/native-release.yml"
grep -Fq 'cargo test --manifest-path mail-engine/Cargo.toml --locked' "$repo_dir/.github/workflows/native-release.yml"

grep -Fq 'virtual_alias_domains=$domain_host' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
grep -Fq 'virtual_alias_maps=hash:/etc/postfix/stellar_virtual_aliases' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
grep -Fq "postconf -e 'mailbox_transport='" "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
grep -Fq '/^stellar-inbox@localhost\$/ owlinbound:' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
! grep -Fq '/^.+@${regex_domain}\$/ owlinbound:' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
! grep -Fq 'andersaamodt/owl' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"

awk '
  /<<'\''REMOTE_DEPLOY'\''/ { capture = 1; next }
  /^REMOTE_DEPLOY$/ { capture = 0 }
  capture { print }
' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh" >"$tmpdir/remote-deploy.sh"
test -s "$tmpdir/remote-deploy.sh"
sh -n "$tmpdir/remote-deploy.sh"

test ! -e "$repo_dir/mail-engine/target"
printf '%s\n' "bundled mail engine tests passed"
