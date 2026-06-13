#!/bin/sh

set -eu

test_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
repo_dir=$(CDPATH= cd -- "$test_dir/../.." && pwd -P)
. "$repo_dir/scripts/stellar-paths.sh"
mobile_dir="$repo_dir/stellar-mobile"
mobile_generated_root=$(stellar_mobile_generated_root)
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/stellar-mobile-test.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
expected_version=$(tr -d ' \t\r\n' <"$mobile_dir/VERSION")

[ -f "$mobile_dir/wizardry.workspace.conf" ] || {
  printf '%s\n' "Stellar Mobile workspace profile missing" >&2
  exit 1
}

grep -F "project_type=native-mobile" "$mobile_dir/wizardry.workspace.conf" >/dev/null
grep -F "targets=android,ios" "$mobile_dir/wizardry.workspace.conf" >/dev/null
grep -F "mobile_ir_path=app-blueprint/mobile.ir.yaml" "$mobile_dir/wizardry.workspace.conf" >/dev/null

sh "$mobile_dir/scripts/validate-native-mobile-ir.sh" \
  "$mobile_dir/app-blueprint/mobile.ir.yaml" \
  "$mobile_dir/schemas/native-mobile-ir-v1.json" >/dev/null

render_out=$(cd "$mobile_dir" && sh scripts/render-native-mobile.sh)
printf '%s\n' "$render_out" | grep -F "status=ok" >/dev/null

[ -f "$mobile_generated_root/android/settings.gradle" ]
[ -f "$mobile_generated_root/android/app/src/main/AndroidManifest.xml" ]
[ -f "$mobile_generated_root/android/app/src/main/java/app/wizardry/generated/stellar/MainActivity.java" ]
[ -f "$mobile_generated_root/ios/project.yml" ]
[ -f "$mobile_generated_root/ios/Host/ContentView.swift" ]

grep -F "app.wizardry.stellar" "$mobile_generated_root/android/app/build.gradle" >/dev/null
grep -F "versionName '$expected_version'" "$mobile_generated_root/android/app/build.gradle" >/dev/null
grep -F "MARKETING_VERSION: \"$expected_version\"" "$mobile_generated_root/ios/project.yml" >/dev/null
version_code=$(awk '/versionCode/ {print $2; exit}' "$mobile_generated_root/android/app/build.gradle")
[ "$version_code" -gt 0 ] && [ "$version_code" -le 2100000000 ]
grep -F 'android:label="Stellar"' "$mobile_generated_root/android/app/src/main/AndroidManifest.xml" >/dev/null
grep -F "Inbox" "$mobile_generated_root/android/app/src/main/java/app/wizardry/generated/stellar/MainActivity.java" >/dev/null
grep -F "Remote Setup" "$mobile_generated_root/android/app/src/main/java/app/wizardry/generated/stellar/MainActivity.java" >/dev/null
grep -F "Remote Mail Server" "$mobile_generated_root/android/app/src/main/java/app/wizardry/generated/stellar/MainActivity.java" >/dev/null
grep -F "Save Backend Bridge" "$mobile_generated_root/android/app/src/main/java/app/wizardry/generated/stellar/MainActivity.java" >/dev/null
grep -F "Save Remote Target" "$mobile_generated_root/android/app/src/main/java/app/wizardry/generated/stellar/MainActivity.java" >/dev/null
grep -F "Deploy Remote Server" "$mobile_generated_root/android/app/src/main/java/app/wizardry/generated/stellar/MainActivity.java" >/dev/null
grep -F "Set Up Remote TLS" "$mobile_generated_root/android/app/src/main/java/app/wizardry/generated/stellar/MainActivity.java" >/dev/null
grep -F "TLS DNS checklist" "$mobile_generated_root/android/app/src/main/java/app/wizardry/generated/stellar/MainActivity.java" >/dev/null
grep -F "Target/Value set to the mail host hostname, not an IP" "$mobile_generated_root/android/app/src/main/java/app/wizardry/generated/stellar/MainActivity.java" >/dev/null
grep -F "HttpURLConnection" "$mobile_generated_root/android/app/src/main/java/app/wizardry/generated/stellar/MainActivity.java" >/dev/null
grep -F "settings-remote-deploy" "$mobile_generated_root/android/app/src/main/java/app/wizardry/generated/stellar/MainActivity.java" >/dev/null
grep -F "settings-remote-set-target" "$mobile_generated_root/android/app/src/main/java/app/wizardry/generated/stellar/MainActivity.java" >/dev/null
grep -F "validPort(String port)" "$mobile_generated_root/android/app/src/main/java/app/wizardry/generated/stellar/MainActivity.java" >/dev/null
grep -F "name: stellar-mobile" "$mobile_generated_root/ios/project.yml" >/dev/null
grep -F "PRODUCT_BUNDLE_IDENTIFIER: app.wizardry.stellar" "$mobile_generated_root/ios/project.yml" >/dev/null
grep -F "GENERATE_INFOPLIST_FILE: YES" "$mobile_generated_root/ios/project.yml" >/dev/null
grep -F "Timeline" "$mobile_generated_root/ios/Host/ContentView.swift" >/dev/null
grep -F "RemoteSetupStepView" "$mobile_generated_root/ios/Host/ContentView.swift" >/dev/null
grep -F 'Section("Remote Mail Server")' "$mobile_generated_root/ios/Host/ContentView.swift" >/dev/null
grep -F 'Button("Save Backend Bridge")' "$mobile_generated_root/ios/Host/ContentView.swift" >/dev/null
grep -F 'Button("Deploy Remote Server")' "$mobile_generated_root/ios/Host/ContentView.swift" >/dev/null
grep -F 'title: "Remote TLS"' "$mobile_generated_root/ios/Host/ContentView.swift" >/dev/null
grep -F 'MX targets must be hostnames, not IP addresses.' "$mobile_generated_root/ios/Host/ContentView.swift" >/dev/null
grep -F 'title: "Test And Sync"' "$mobile_generated_root/ios/Host/ContentView.swift" >/dev/null
grep -F 'Button("Set Up Remote TLS")' "$mobile_generated_root/ios/Host/ContentView.swift" >/dev/null
grep -F "URLSession.shared.data" "$mobile_generated_root/ios/Host/ContentView.swift" >/dev/null
grep -F 'action: "settings-remote-deploy"' "$mobile_generated_root/ios/Host/ContentView.swift" >/dev/null
grep -F 'action: "settings-remote-set-target"' "$mobile_generated_root/ios/Host/ContentView.swift" >/dev/null
grep -F "remotePortValid" "$mobile_generated_root/ios/Host/ContentView.swift" >/dev/null
grep -F '"save_remote_bridge"' "$mobile_dir/app-blueprint/mobile.ir.yaml" >/dev/null
grep -F '"deploy_remote_server"' "$mobile_dir/app-blueprint/mobile.ir.yaml" >/dev/null
grep -F '"setup_remote_tls"' "$mobile_dir/app-blueprint/mobile.ir.yaml" >/dev/null

[ -x "$repo_dir/scripts/stellar-mobile-backend-bridge.sh" ]
grep -F "settings-remote-deploy" "$repo_dir/scripts/stellar-mobile-backend-bridge.sh" >/dev/null
invalid_bridge_out=$(printf '%s\n' '{"action":"not-allowed","args":[]}' | "$repo_dir/scripts/stellar-mobile-backend-bridge.sh")
printf '%s\n' "$invalid_bridge_out" | jq -e '.ok == false' >/dev/null
printf '%s\n' "$invalid_bridge_out" | grep -F 'unsupported mobile backend action' >/dev/null
fake_backend="$tmpdir/backend"
cat >"$fake_backend" <<'SH'
#!/bin/sh
set -eu
jq -n --arg action "$1" --arg root "$2" --arg a1 "${3-}" --arg a2 "${4-}" '{ok:true,action:$action,root:$root,args:[$a1,$a2]}'
SH
chmod +x "$fake_backend"
bridge_out=$(printf '%s\n' '{"action":"settings-remote-deploy","root":"/tmp/stellar mail","args":["user@example.org","key path"]}' | STELLAR_NATIVE_BACKEND="$fake_backend" "$repo_dir/scripts/stellar-mobile-backend-bridge.sh")
printf '%s\n' "$bridge_out" | jq -e '.ok == true and .action == "settings-remote-deploy" and .root == "/tmp/stellar mail" and .args[0] == "user@example.org" and .args[1] == "key path"' >/dev/null

if grep -R "desktop Stellar runs the SSH deploy bridge\\|Use desktop Stellar" "$mobile_generated_root" >/dev/null 2>&1; then
  printf '%s\n' "Stellar Mobile remote setup must not delegate deploy capability back to desktop Stellar" >&2
  exit 1
fi

if grep -R "com.google.android.gms\|play-services" "$mobile_generated_root/android" >/dev/null 2>&1; then
  printf '%s\n' "Stellar Mobile generated Android project must not depend on Play Services" >&2
  exit 1
fi

printf '%s\n' "native mobile tests passed"
