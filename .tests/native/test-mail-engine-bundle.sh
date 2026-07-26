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
grep -Fq 'name: stellar-mail-server-x86_64-linux' "$repo_dir/.github/workflows/native-release.yml"
grep -Fq 'libexec/stellar-mail/remote/x86_64-linux' "$repo_dir/.github/workflows/native-release.yml"
grep -Fq -- '--target x86_64-unknown-linux-musl' "$repo_dir/.github/workflows/native-release.yml"

grep -Fq 'virtual_alias_domains=$domain_host' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
grep -Fq 'virtual_alias_maps=hash:/etc/postfix/stellar_virtual_aliases' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
grep -Fq 'cert_dir="$remote_root/config/letsencrypt/live/$mail_hostname"' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
grep -Fq "postconf -e 'mailbox_transport='" "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
test "$(grep -Fc 'postconf -e "smtpd_tls_cert_file=' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh")" -ge 2
grep -Fq 'stellar-certbot-renew.timer' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
grep -Fq 'submission inet n - n - - smtpd' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
grep -Fq 'smtpd_relay_restrictions=permit_sasl_authenticated,reject' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
grep -Fq 'smtp_address_preference=ipv4' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
grep -Fq 'opendkim-genkey' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
grep -Fq 'smtp_submit_test_message' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
grep -Fq 'delivery_status=bounced' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
grep -Fq 'server IP reverse DNS (PTR) does not point to the SMTP host' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
test ! -e "$repo_dir/mail-engine/src/util/dkim.rs"
grep -Fq 'chown -R root:root "$cert_config_dir"' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
grep -Fq '/^stellar-inbox@localhost\$/ owlinbound:' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
! grep -Fq '/^.+@${regex_domain}\$/ owlinbound:' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
! grep -Fq 'andersaamodt/owl' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
grep -Fq "SSH_KEYCHAIN_OPTIONS='-o AddKeysToAgent=yes -o UseKeychain=yes'" "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
grep -Fq 'tar --no-xattrs -czf' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
grep -Fq 'CARGO_BUILD_JOBS=1 CARGO_TARGET_DIR="$target_dir" cargo build' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"
grep -Fq -- '--profile server' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh"

for marker in REMOTE_BINARY_INSTALL REMOTE_SOURCE_BUILD REMOTE_DEPLOY REMOTE_ADDRESS_PUBLISH REMOTE_SSL_SETUP; do
  extracted="$tmpdir/$marker.sh"
  awk -v marker="$marker" '
    index($0, "<<" marker) || index($0, "<<'\''" marker "'\''") { capture = 1; next }
    $0 == marker { capture = 0 }
    capture { print }
  ' "$repo_dir/mail-engine/scripts/owl-desktop-backend.sh" >"$extracted"
  test -s "$extracted"
  sh -n "$extracted"
done

test ! -e "$repo_dir/mail-engine/target"
printf '%s\n' "bundled mail engine tests passed"
