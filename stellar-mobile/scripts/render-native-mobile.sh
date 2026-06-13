#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
project_dir=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
ir_path="$project_dir/app-blueprint/mobile.ir.yaml"
schema_path="$project_dir/schemas/native-mobile-ir-v1.json"
version_file="$project_dir/VERSION"
workspace_conf="$project_dir/wizardry.workspace.conf"
legacy_generated_root="$project_dir/generated/mobile"

"$script_dir/validate-native-mobile-ir.sh" "$ir_path" "$schema_path" >/dev/null

app_name=$(jq -r '.app.name' "$ir_path")
app_id=$(jq -r '.app.id' "$ir_path")
project_id=$(awk -F= '$1 == "project_id" { print $2; exit }' "$workspace_conf")
[ -n "$project_id" ] || project_id=$(basename "$project_dir")
package_part=$(printf '%s' "$app_id" | tr '-' '_')
android_package=$(jq -r '.app.android.applicationId // ""' "$ir_path")
[ -n "$android_package" ] || android_package="app.wizardry.generated.$package_part"
android_compile_sdk=$(jq -r '.app.android.compileSdk // 35' "$ir_path")
android_min_sdk=$(jq -r '.app.android.minSdk // 23' "$ir_path")
android_target_sdk=$(jq -r '.app.android.targetSdk // 35' "$ir_path")
ios_bundle=$(jq -r '.app.ios.bundleId // ""' "$ir_path")
[ -n "$ios_bundle" ] || ios_bundle="app.wizardry.generated.$package_part"
ios_deployment_target=$(jq -r '.app.ios.deploymentTarget // "16.0"' "$ir_path")
state_root="${XDG_STATE_HOME:-$HOME/.local/state}/$project_id"
legacy_state_generated_root="${XDG_STATE_HOME:-$HOME/.local/state}/$app_id/generated/mobile"
generated_root="$state_root/generated/mobile"
android_dir="$generated_root/android"
ios_dir="$generated_root/ios"
if [ -f "$version_file" ]; then
  app_version=$(tr -d ' \t\r\n' <"$version_file")
else
  app_version=0.1.0
fi
version_code=$(printf '%s\n' "$app_version" | awk -F. '
  NF >= 3 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ {
    print ($1 * 1000000) + ($2 * 1000) + $3
    found = 1
  }
  END { exit found ? 0 : 1 }
' 2>/dev/null || true)
if [ -z "$version_code" ]; then
  version_code=$(printf '%s' "$app_version" | cksum | awk '{ print ($1 % 2000000000) + 1 }')
fi
[ -n "$version_code" ] || version_code=1

mkdir -p "$state_root/generated"
if [ -d "$legacy_generated_root" ]; then
  if [ ! -e "$generated_root" ]; then
    mv "$legacy_generated_root" "$generated_root"
  else
    rm -rf "$legacy_generated_root"
  fi
fi
if [ "$legacy_state_generated_root" != "$generated_root" ] && [ -d "$legacy_state_generated_root" ]; then
  if [ ! -e "$generated_root" ]; then
    mv "$legacy_state_generated_root" "$generated_root"
  else
    rm -rf "$legacy_state_generated_root"
  fi
fi

mkdir -p "$android_dir/app/src/main/java/app/wizardry/generated/$package_part" "$ios_dir/Host"

screen_titles=$(jq -r '.app.screens[].title' "$ir_path")
primary_title=$(printf '%s\n' "$screen_titles" | sed -n '1p')
[ -n "$primary_title" ] || primary_title="$app_name"
android_items=$(jq -r '.app.screens[] | "        items.add(\"" + (.title | gsub("\\\\";"\\\\\\") | gsub("\"";"\\\"")) + "\");"' "$ir_path")
ios_items=$(jq -r '.app.screens[] | "        \"" + (.title | gsub("\\\\";"\\\\\\\\") | gsub("\"";"\\\"")) + "\","' "$ir_path")

cat >"$android_dir/settings.gradle" <<GRADLE
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
rootProject.name = "$app_id-mobile"
include ':app'
GRADLE

cat >"$android_dir/build.gradle" <<'GRADLE'
plugins {
    id 'com.android.application' version '8.5.2' apply false
}
GRADLE

cat >"$android_dir/app/build.gradle" <<GRADLE
plugins { id 'com.android.application' }

android {
    namespace '$android_package'
    compileSdk $android_compile_sdk

    defaultConfig {
        applicationId '$android_package'
        minSdk $android_min_sdk
        targetSdk $android_target_sdk
        versionCode $version_code
        versionName '$app_version'
    }

    def signingStorePath = System.getenv('ANDROID_SIGNING_KEYSTORE')
    def signingStoreBase64 = System.getenv('ANDROID_SIGNING_KEYSTORE_BASE64')
    if (signingStoreBase64 != null && signingStoreBase64.trim()) {
        def decodedStore = layout.buildDirectory.file('ci-release.keystore').get().asFile
        decodedStore.parentFile.mkdirs()
        decodedStore.bytes = signingStoreBase64.decodeBase64()
        signingStorePath = decodedStore.absolutePath
    }
    def signingStorePassword = System.getenv('ANDROID_SIGNING_STORE_PASSWORD')
    def signingKeyAlias = System.getenv('ANDROID_SIGNING_KEY_ALIAS')
    def signingKeyPassword = System.getenv('ANDROID_SIGNING_KEY_PASSWORD')
    def hasReleaseSigning = signingStorePath != null && signingStorePath.trim() &&
        signingStorePassword != null && signingStorePassword.trim() &&
        signingKeyAlias != null && signingKeyAlias.trim() &&
        signingKeyPassword != null && signingKeyPassword.trim()

    signingConfigs {
        release {
            if (hasReleaseSigning) {
                storeFile file(signingStorePath)
                storePassword signingStorePassword
                keyAlias signingKeyAlias
                keyPassword signingKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig signingConfigs.release
            }
        }
    }
}
GRADLE

cat >"$android_dir/app/src/main/AndroidManifest.xml" <<XML
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application android:theme="@style/AppTheme" android:label="$app_name" android:allowBackup="false" android:supportsRtl="true">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
XML

mkdir -p "$android_dir/app/src/main/res/values"
cat >"$android_dir/app/src/main/res/values/styles.xml" <<'XML'
<resources>
    <style name="AppTheme" parent="android:style/Theme.Material.Light.NoActionBar">
        <item name="android:fontFamily">sans</item>
        <item name="android:windowLightStatusBar">true</item>
        <item name="android:navigationBarColor">#F7F7F2</item>
        <item name="android:colorAccent">#2F6F6A</item>
    </style>
</resources>
XML

cat >"$android_dir/app/src/main/java/app/wizardry/generated/$package_part/MainActivity.java" <<JAVA
package $android_package;

import android.app.Activity;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.graphics.Color;
import android.text.InputType;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import java.io.BufferedReader;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import org.json.JSONArray;
import org.json.JSONObject;

public final class MainActivity extends Activity {
    private SharedPreferences prefs;
    private TextView remoteStatus;
    private EditText remoteBridgeUrl;
    private EditText remoteHost;
    private EditText remoteKey;
    private EditText remotePort;
    private EditText remotePassword;
    private CheckBox remoteHasPassword;
    private CheckBox remoteSavePassword;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        prefs = getSharedPreferences("stellar-mobile", MODE_PRIVATE);

        ScrollView scroll = new ScrollView(this);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(28, 28, 28, 28);
        root.setBackgroundColor(Color.rgb(247, 247, 242));
        scroll.addView(root);

        TextView title = new TextView(this);
        title.setText("$primary_title");
        title.setTextSize(24);
        title.setTextColor(Color.rgb(24, 33, 35));
        root.addView(title, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        TextView screenTitle = sectionTitle("Screens");
        root.addView(screenTitle);
        addScreenRow(root, "Inbox");
        addScreenRow(root, "Timeline");
        addScreenRow(root, "People");
        addScreenRow(root, "Groups");
        addScreenRow(root, "Settings");
        addScreenRow(root, "Remote Setup");

        EditText composer = new EditText(this);
        composer.setHint("Message");
        composer.setSingleLine(false);
        root.addView(composer, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        Button send = new Button(this);
        send.setText("Send");
        root.addView(send, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        addRemoteSetup(root);
        setContentView(scroll);
    }

    private TextView sectionTitle(String label) {
        TextView view = new TextView(this);
        view.setText(label);
        view.setTextSize(18);
        view.setTextColor(Color.rgb(35, 54, 54));
        view.setPadding(0, 28, 0, 8);
        return view;
    }

    private TextView bodyText(String label) {
        TextView view = new TextView(this);
        view.setText(label);
        view.setTextSize(14);
        view.setTextColor(Color.rgb(78, 86, 83));
        view.setPadding(0, 4, 0, 8);
        return view;
    }

    private void addScreenRow(LinearLayout root, String label) {
        TextView row = bodyText(label);
        row.setTextSize(16);
        root.addView(row, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
    }

    private EditText field(String hint, String key) {
        EditText edit = new EditText(this);
        edit.setHint(hint);
        edit.setSingleLine(true);
        edit.setText(prefs.getString(key, ""));
        edit.setPadding(0, 4, 0, 4);
        return edit;
    }

    private void addRemoteSetup(LinearLayout root) {
        root.addView(sectionTitle("Remote Mail Server"));
        root.addView(bodyText("Step through the same Stellar remote setup flow from mobile: connect to an Stellar backend bridge, save SSH details, save authentication, deploy, verify, set up TLS with DNS records checked first, send a test email, then check remote mail."));

        remoteBridgeUrl = field("https://stellar.example.org/backend", "remote.bridgeUrl");
        remoteHost = field("user@203.0.113.8", "remote.host");
        remoteKey = field("~/.ssh/id_ed25519", "remote.key");
        remotePort = field("SSH port", "remote.port");
        root.addView(remoteBridgeUrl, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        root.addView(remoteHost, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        root.addView(remoteKey, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        root.addView(remotePort, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        Button saveBridge = new Button(this);
        saveBridge.setText("Save Backend Bridge");
        saveBridge.setOnClickListener(v -> saveRemoteBridge());
        root.addView(saveBridge, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        Button saveTarget = new Button(this);
        saveTarget.setText("Save Remote Target");
        saveTarget.setOnClickListener(v -> saveRemoteTarget());
        root.addView(saveTarget, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        remoteHasPassword = new CheckBox(this);
        remoteHasPassword.setText("SSH key has password");
        remoteHasPassword.setChecked(prefs.getBoolean("remote.hasPassword", false));
        root.addView(remoteHasPassword);

        remotePassword = field("SSH key password", "remote.password");
        remotePassword.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        root.addView(remotePassword, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        remoteSavePassword = new CheckBox(this);
        remoteSavePassword.setText("Save password on this device");
        remoteSavePassword.setChecked(prefs.getBoolean("remote.savePassword", false));
        root.addView(remoteSavePassword);

        Button saveAuth = new Button(this);
        saveAuth.setText("Save Authentication");
        saveAuth.setOnClickListener(v -> saveRemoteAuth());
        root.addView(saveAuth, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        addWorkflowButton(root, "Deploy Remote Server", "settings-remote-deploy", "Deploy uses the saved SSH target to install Stellar, configure the receiver, and enable startup.");
        addWorkflowButton(root, "Verify Remote Setup", "settings-remote-verify", "Verification checks Stellar binaries, daemon health, SMTP reachability, DNS, and mail folders on the saved target.");
        root.addView(bodyText("TLS DNS checklist: add the mail host record first (A/AAAA for a stable IP, or CNAME/A for DDNS), then add MX with Host/Name @, Priority 10, and Target/Value set to the mail host hostname, not an IP. Certbot and supporting tools are installed during setup when needed."));
        addWorkflowButton(root, "Set Up Remote TLS", "settings-setup-ssl", "Remote TLS setup uses Stellar's SSL wizard flow after DNS points at the active remote mail server.");
        addWorkflowButton(root, "Send Test Email", "settings-remote-send-test", "The test email step confirms the public route reaches the remote Stellar receiver.");
        addWorkflowButton(root, "Check Remote Mail", "settings-remote-sync", "Remote sync pulls server mail folders back into local Stellar without deleting remote mail.");

        remoteStatus = bodyText(remoteSummary());
        root.addView(remoteStatus, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
    }

    private void addWorkflowButton(LinearLayout root, String title, String action, String detail) {
        Button button = new Button(this);
        button.setText(title);
        button.setOnClickListener(v -> runRemoteWorkflowAction(title, action, detail));
        root.addView(button, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        root.addView(bodyText(detail));
    }

    private void saveRemoteBridge() {
        String bridge = remoteBridgeUrl.getText().toString().trim();
        if (!validBackendBridgeUrl(bridge)) {
            setRemoteStatus("Enter an http or https Stellar backend bridge URL.");
            return;
        }
        prefs.edit().putString("remote.bridgeUrl", bridge).apply();
        setRemoteStatus("Backend bridge saved. " + remoteSummary());
    }

    private void saveRemoteTarget() {
        String port = normalizedPort();
        if (!validPort(port)) {
            setRemoteStatus("SSH port must be 1-65535.");
            return;
        }
        prefs.edit()
            .putString("remote.host", remoteHost.getText().toString().trim())
            .putString("remote.key", remoteKey.getText().toString().trim())
            .putString("remote.port", port)
            .apply();
        setRemoteStatus("Remote target saved. " + remoteSummary());
        runBackendAction("settings-remote-set-target", remoteTargetArgs(), "Remote target saved");
    }

    private void saveRemoteAuth() {
        prefs.edit()
            .putBoolean("remote.hasPassword", remoteHasPassword.isChecked())
            .putBoolean("remote.savePassword", remoteSavePassword.isChecked())
            .putString("remote.password", remoteHasPassword.isChecked() ? remotePassword.getText().toString() : "")
            .apply();
        setRemoteStatus("Remote authentication saved. " + remoteSummary());
        runBackendAction("settings-remote-set-auth", remoteAuthArgs(), "Remote authentication saved");
    }

    private void runRemoteWorkflowAction(String title, String action, String detail) {
        if (!remoteReadyForActions()) {
            setRemoteStatus("Save the backend bridge, SSH target, SSH key, and authentication before running " + title + ".");
            return;
        }
        setRemoteStatus(title + ": starting...");
        String bridge = remoteBridgeUrl.getText().toString().trim();
        String[] targetArgs = remoteTargetArgs();
        String[] authArgs = remoteAuthArgs();
        String[] actionArgs = workflowArgs(action);
        new Thread(() -> {
            try {
                postBackendAction(bridge, "settings-remote-set-target", targetArgs, "Remote target saved");
                postBackendAction(bridge, "settings-remote-set-auth", authArgs, "Remote authentication saved");
                String message = postBackendAction(bridge, action, actionArgs, title + ": " + detail);
                runOnUiThread(() -> setRemoteStatus(message));
            } catch (Exception ex) {
                runOnUiThread(() -> setRemoteStatus(action + " failed: " + ex.getMessage()));
            }
        }).start();
    }

    private String[] remoteTargetArgs() {
        return new String[] {
            remoteHost.getText().toString().trim(),
            remoteKey.getText().toString().trim(),
            normalizedPort()
        };
    }

    private String[] remoteAuthArgs() {
        return new String[] {
            remoteHasPassword.isChecked() ? "1" : "0",
            remoteSavePassword.isChecked() ? "1" : "0",
            remoteHasPassword.isChecked() ? remotePassword.getText().toString() : "",
            remoteHost.getText().toString().trim(),
            remoteKey.getText().toString().trim(),
            normalizedPort()
        };
    }

    private String[] workflowArgs(String action) {
        String host = remoteHost.getText().toString().trim();
        String key = remoteKey.getText().toString().trim();
        String password = remoteHasPassword.isChecked() ? remotePassword.getText().toString() : "";
        String port = normalizedPort();
        if ("settings-setup-ssl".equals(action)) {
            return new String[] {"remote", host, key, password, port};
        }
        return new String[] {host, key, password, port};
    }

    private boolean remoteReadyForActions() {
        return validBackendBridgeUrl(remoteBridgeUrl.getText().toString().trim()) &&
            remoteHost.getText().toString().trim().length() > 0 &&
            remoteKey.getText().toString().trim().length() > 0 &&
            validPort(normalizedPort()) &&
            (!remoteHasPassword.isChecked() || remotePassword.getText().toString().length() > 0 || remoteSavePassword.isChecked());
    }

    private boolean validBackendBridgeUrl(String bridge) {
        return bridge.startsWith("https://") || bridge.startsWith("http://");
    }

    private void runBackendAction(String action, String[] args, String fallbackStatus) {
        String bridge = remoteBridgeUrl.getText().toString().trim();
        if (!validBackendBridgeUrl(bridge)) {
            setRemoteStatus("Enter an http or https Stellar backend bridge URL.");
            return;
        }
        new Thread(() -> {
            try {
                String message = postBackendAction(bridge, action, args, fallbackStatus);
                runOnUiThread(() -> setRemoteStatus(message));
            } catch (Exception ex) {
                runOnUiThread(() -> setRemoteStatus(action + " failed: " + ex.getMessage()));
            }
        }).start();
    }

    private String postBackendAction(String bridge, String action, String[] args, String fallbackStatus) throws Exception {
        HttpURLConnection connection = null;
        try {
            JSONObject payload = new JSONObject();
            payload.put("action", action);
            payload.put("root", "");
            JSONArray jsonArgs = new JSONArray();
            for (String arg : args) {
                jsonArgs.put(arg == null ? "" : arg);
            }
            payload.put("args", jsonArgs);

            URL url = new URL(bridge);
            connection = (HttpURLConnection) url.openConnection();
            connection.setRequestMethod("POST");
            connection.setConnectTimeout(10000);
            connection.setReadTimeout(action.equals("settings-remote-deploy") ? 1800000 : 120000);
            connection.setDoOutput(true);
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
            byte[] body = payload.toString().getBytes("UTF-8");
            try (OutputStream output = connection.getOutputStream()) {
                output.write(body);
            }
            int status = connection.getResponseCode();
            InputStream responseStream = status >= 200 && status < 300 ? connection.getInputStream() : connection.getErrorStream();
            if (responseStream == null) {
                throw new IllegalStateException("HTTP " + status);
            }
            BufferedReader reader = new BufferedReader(new InputStreamReader(responseStream, "UTF-8"));
            StringBuilder response = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                response.append(line);
            }
            if (status < 200 || status >= 300) {
                throw new IllegalStateException(response.length() == 0 ? "HTTP " + status : response.toString());
            }
            return backendMessage(response.toString(), fallbackStatus);
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    private String backendMessage(String response, String fallbackStatus) {
        try {
            JSONObject json = new JSONObject(response);
            String message = json.optString("message", "");
            if (message.length() > 0) {
                return message;
            }
            String status = json.optString("status", "");
            if (status.length() > 0) {
                return fallbackStatus + " (" + status + ")";
            }
        } catch (Exception ignored) {
        }
        return fallbackStatus;
    }

    private String normalizedPort() {
        String port = remotePort.getText().toString().trim();
        if (port.startsWith(":")) {
            port = port.substring(1);
        }
        return port;
    }

    private boolean validPort(String port) {
        if (port.length() == 0) {
            return true;
        }
        try {
            int parsed = Integer.parseInt(port);
            return parsed >= 1 && parsed <= 65535;
        } catch (NumberFormatException ex) {
            return false;
        }
    }

    private String remoteSummary() {
        String host = prefs.getString("remote.host", "");
        String key = prefs.getString("remote.key", "");
        String port = prefs.getString("remote.port", "");
        String bridge = prefs.getString("remote.bridgeUrl", "");
        if (bridge.length() == 0) {
            return "Set the Stellar backend bridge, host, and SSH key, then deploy.";
        }
        if (host.length() == 0 || key.length() == 0) {
            return "Set host and SSH key, then deploy from mobile.";
        }
        return "Bridge: " + bridge + " - Target: " + host + (port.length() == 0 ? "" : " - SSH port: " + port);
    }

    private void setRemoteStatus(String text) {
        if (remoteStatus != null) {
            remoteStatus.setText(text);
        }
    }
}
JAVA

cat >"$ios_dir/project.yml" <<YAML
name: $app_id-mobile
options:
  bundleIdPrefix: app.wizardry.generated
targets:
  $app_id:
    type: application
    platform: iOS
    deploymentTarget: "$ios_deployment_target"
    sources:
      - Host
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: $ios_bundle
      GENERATE_INFOPLIST_FILE: YES
      INFOPLIST_KEY_CFBundleDisplayName: "$app_name"
      CURRENT_PROJECT_VERSION: "$version_code"
      MARKETING_VERSION: "$app_version"
YAML

cat >"$ios_dir/Host/App.swift" <<SWIFT
import SwiftUI

@main
struct GeneratedNativeMobileApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
SWIFT

cat >"$ios_dir/Host/ContentView.swift" <<SWIFT
import SwiftUI

struct ContentView: View {
    private let items = [
$ios_items
    ]
    @State private var message = ""
    @State private var remoteStatus = "Set the Stellar backend bridge, host, and SSH key, then deploy."
    @State private var remoteBusyAction: String?
    @AppStorage("remote.bridgeURL") private var remoteBridgeURL = ""
    @AppStorage("remote.host") private var remoteHost = ""
    @AppStorage("remote.keyPath") private var remoteKeyPath = ""
    @AppStorage("remote.port") private var remotePort = ""
    @AppStorage("remote.keyHasPassword") private var remoteKeyHasPassword = false
    @AppStorage("remote.savePassword") private var remoteSavePassword = false
    @AppStorage("remote.password") private var remotePassword = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Screens") {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                    }
                }
                Section("Compose") {
                    TextField("Message", text: \$message, axis: .vertical)
                    Button("Send") { message = "" }
                }
                remoteSetupSection
            }
            .navigationTitle("$primary_title")
        }
    }

    private var remoteSetupSection: some View {
        Section("Remote Mail Server") {
            VStack(alignment: .leading, spacing: 10) {
                RemoteSetupStepView(
                    number: 1,
                    title: "Backend Bridge",
                    detail: remoteBackendReady ? "The mobile app can invoke Stellar backend actions." : "Enter the Stellar backend bridge URL used by mobile.",
                    complete: remoteBackendReady
                ) {
                    TextField("https://stellar.example.org/backend", text: \$remoteBridgeURL)
                        .stellarRemoteTargetContentType()
                        .autocorrectionDisabled(true)
                    Button("Save Backend Bridge") {
                        saveRemoteBridge()
                    }
                    .disabled(!remoteBackendURLValid)
                    if !remoteBackendURLValid && !remoteBridgeURL.isEmpty {
                        Text("Bridge URL must start with http:// or https://.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                RemoteSetupStepView(
                    number: 2,
                    title: "SSH Target",
                    detail: remoteTargetReady ? "Remote login and key are ready to save." : "Enter the server login and SSH key.",
                    complete: remoteTargetReady && remotePortValid
                ) {
                    TextField("user@203.0.113.8", text: \$remoteHost)
                        .stellarRemoteTargetContentType()
                        .autocorrectionDisabled(true)
                    TextField("~/.ssh/id_ed25519", text: \$remoteKeyPath)
                        .autocorrectionDisabled(true)
                    TextField("SSH port", text: \$remotePort)
                        .stellarNumberPadKeyboard()
                    if !remotePortValid {
                        Text("SSH port must be 1-65535.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Button("Save Remote Target") {
                        Task { await saveRemoteTarget() }
                    }
                    .disabled(!remotePortValid)
                }

                RemoteSetupStepView(
                    number: 3,
                    title: "SSH Authentication",
                    detail: remoteAuthReady ? "SSH authentication is available for remote actions." : "Enter the SSH key password or use a passwordless key.",
                    complete: remoteAuthReady
                ) {
                    Toggle("SSH key has password", isOn: \$remoteKeyHasPassword)
                    if remoteKeyHasPassword {
                        SecureField("SSH key password", text: \$remotePassword)
                        Toggle("Save on this device", isOn: \$remoteSavePassword)
                    }
                    Button("Save Authentication") {
                        Task { await saveRemoteAuth() }
                    }
                    .disabled(!remoteTargetReady || !remoteAuthReady)
                }

                RemoteSetupStepView(
                    number: 4,
                    title: "Deploy And Verify",
                    detail: "Deploy Stellar to the saved server, then verify receiver health.",
                    complete: false
                ) {
                    Button("Deploy Remote Server") {
                        Task { await runRemoteWorkflowAction(title: "Deploy Remote Server", action: "settings-remote-deploy", fallbackStatus: "Remote deploy finished") }
                    }
                    .disabled(!remoteReadyForActions)
                    Button("Verify Remote Setup") {
                        Task { await runRemoteWorkflowAction(title: "Verify Remote Setup", action: "settings-remote-verify", fallbackStatus: "Remote verification finished") }
                    }
                    .disabled(!remoteReadyForActions)
                }

                RemoteSetupStepView(
                    number: 5,
                    title: "Remote TLS",
                    detail: "Add A/AAAA or CNAME for the mail host, add MX @ priority 10 to the mail host hostname, then run TLS setup. Certbot installs during setup when needed.",
                    complete: false
                ) {
                    Button("Set Up Remote TLS") {
                        Task { await runRemoteWorkflowAction(title: "Set Up Remote TLS", action: "settings-setup-ssl", fallbackStatus: "TLS setup finished") }
                    }
                    .disabled(!remoteReadyForActions)
                    Text("For dynamic IP, keep DDNS updating the mail host. MX targets must be hostnames, not IP addresses.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                RemoteSetupStepView(
                    number: 6,
                    title: "Test And Sync",
                    detail: "Send a test email, then check remote mail.",
                    complete: false
                ) {
                    Button("Send Test Email") {
                        Task { await runRemoteWorkflowAction(title: "Send Test Email", action: "settings-remote-send-test", fallbackStatus: "Remote test email finished") }
                    }
                    .disabled(!remoteReadyForActions)
                    Button("Check Remote Mail") {
                        Task { await runRemoteWorkflowAction(title: "Check Remote Mail", action: "settings-remote-sync", fallbackStatus: "Remote sync finished") }
                    }
                    .disabled(!remoteReadyForActions)
                }

                Text(remoteStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 4)
        }
    }

    private var normalizedRemotePort: String {
        var trimmed = remotePort.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix(":") {
            trimmed.removeFirst()
        }
        return trimmed
    }

    private var remotePortValid: Bool {
        let port = normalizedRemotePort
        guard !port.isEmpty else { return true }
        guard let parsed = Int(port) else { return false }
        return (1...65_535).contains(parsed)
    }

    private var remoteTargetReady: Bool {
        !remoteHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !remoteKeyPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var remoteBackendURLValid: Bool {
        remoteBridgeURL.hasPrefix("https://") || remoteBridgeURL.hasPrefix("http://")
    }

    private var remoteBackendReady: Bool {
        remoteBackendURLValid
    }

    private var remoteAuthReady: Bool {
        !remoteKeyHasPassword || !remotePassword.isEmpty || remoteSavePassword
    }

    private var remoteReadyForActions: Bool {
        remoteBackendReady && remoteTargetReady && remotePortValid && remoteAuthReady && remoteBusyAction == nil
    }

    private var remoteSummary: String {
        let host = remoteHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = normalizedRemotePort
        guard !host.isEmpty else { return "the saved remote target" }
        return port.isEmpty ? host : "\(host) on SSH port \(port)"
    }

    private func saveRemoteBridge() {
        remoteBridgeURL = remoteBridgeURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard remoteBackendURLValid else {
            remoteStatus = "Bridge URL must start with http:// or https://."
            return
        }
        remoteStatus = "Backend bridge saved."
    }

    private func saveRemoteTarget() async {
        remotePort = normalizedRemotePort
        remoteStatus = "Remote target saved. Target: \(remoteSummary)."
        _ = await runBackendAction(action: "settings-remote-set-target", args: remoteTargetArgs(), fallbackStatus: "Remote target saved")
    }

    private func saveRemoteAuth() async {
        if !remoteKeyHasPassword {
            remotePassword = ""
            remoteSavePassword = false
        }
        remoteStatus = "Remote authentication saved."
        _ = await runBackendAction(action: "settings-remote-set-auth", args: remoteAuthArgs(), fallbackStatus: "Remote authentication saved")
    }

    private func remoteTargetArgs() -> [String] {
        [
            remoteHost.trimmingCharacters(in: .whitespacesAndNewlines),
            remoteKeyPath.trimmingCharacters(in: .whitespacesAndNewlines),
            normalizedRemotePort
        ]
    }

    private func remoteAuthArgs() -> [String] {
        [
            remoteKeyHasPassword ? "1" : "0",
            remoteSavePassword ? "1" : "0",
            remoteKeyHasPassword ? remotePassword : "",
            remoteHost.trimmingCharacters(in: .whitespacesAndNewlines),
            remoteKeyPath.trimmingCharacters(in: .whitespacesAndNewlines),
            normalizedRemotePort
        ]
    }

    private func remoteWorkflowArgs(for action: String) -> [String] {
        let args = [
            remoteHost.trimmingCharacters(in: .whitespacesAndNewlines),
            remoteKeyPath.trimmingCharacters(in: .whitespacesAndNewlines),
            remoteKeyHasPassword ? remotePassword : "",
            normalizedRemotePort
        ]
        if action == "settings-setup-ssl" {
            return ["remote"] + args
        }
        return args
    }

    @MainActor
    private func runRemoteWorkflowAction(title: String, action: String, fallbackStatus: String) async {
        guard remoteReadyForActions else {
            remoteStatus = "Save the backend bridge, SSH target, SSH key, and authentication before running \(title)."
            return
        }
        remoteBusyAction = action
        remoteStatus = "\(title): starting..."
        guard await runBackendAction(action: "settings-remote-set-target", args: remoteTargetArgs(), fallbackStatus: "Remote target saved") else {
            remoteBusyAction = nil
            return
        }
        guard await runBackendAction(action: "settings-remote-set-auth", args: remoteAuthArgs(), fallbackStatus: "Remote authentication saved") else {
            remoteBusyAction = nil
            return
        }
        _ = await runBackendAction(action: action, args: remoteWorkflowArgs(for: action), fallbackStatus: fallbackStatus)
        remoteBusyAction = nil
    }

    private func runBackendAction(action: String, args: [String], fallbackStatus: String) async -> Bool {
        guard remoteBackendURLValid, let url = URL(string: remoteBridgeURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            await MainActor.run { remoteStatus = "Enter an http or https Stellar backend bridge URL." }
            return false
        }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = action == "settings-remote-deploy" ? 1_800 : 120
            let payload = MobileBackendRequest(action: action, root: "", args: args)
            request.httpBody = try JSONEncoder().encode(payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code) else {
                let text = String(data: data, encoding: .utf8) ?? "HTTP \(code)"
                await MainActor.run { remoteStatus = "\(action) failed: \(text)" }
                return false
            }
            let message = backendMessage(from: data, fallbackStatus: fallbackStatus)
            await MainActor.run { remoteStatus = message }
            return true
        } catch {
            await MainActor.run { remoteStatus = "\(action) failed: \(error.localizedDescription)" }
            return false
        }
    }

    private func backendMessage(from data: Data, fallbackStatus: String) -> String {
        if let result = try? JSONDecoder().decode(MobileBackendResult.self, from: data) {
            if let message = result.message, !message.isEmpty {
                return message
            }
            if let status = result.status, !status.isEmpty {
                return "\(fallbackStatus) (\(status))"
            }
        }
        return fallbackStatus
    }
}

private struct MobileBackendRequest: Encodable {
    let action: String
    let root: String
    let args: [String]
}

private struct MobileBackendResult: Decodable {
    let ok: Bool?
    let status: String?
    let message: String?
}

private struct RemoteSetupStepView<Content: View>: View {
    let number: Int
    let title: String
    let detail: String
    let complete: Bool
    let content: Content

    init(number: Int, title: String, detail: String, complete: Bool, @ViewBuilder content: () -> Content) {
        self.number = number
        self.title = title
        self.detail = detail
        self.complete = complete
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(complete ? .green : .accentColor)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill((complete ? Color.green : Color.accentColor).opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content
                .padding(.leading, 30)
        }
        .padding(.vertical, 6)
    }
}

private extension View {
    @ViewBuilder
    func stellarRemoteTargetContentType() -> some View {
#if os(iOS)
        self.textContentType(.URL)
#else
        if #available(macOS 14.0, *) {
            self.textContentType(.URL)
        } else {
            self
        }
#endif
    }

    @ViewBuilder
    func stellarNumberPadKeyboard() -> some View {
#if os(iOS)
        self.keyboardType(.numberPad)
#else
        self
#endif
    }
}
SWIFT

cat >"$generated_root/README.md" <<README
# $app_name Mobile Build

Generated from \`app-blueprint/mobile.ir.yaml\`.

- Android output is a plain Gradle Android project with no Play Services dependency.
- Android direct distribution is the primary release route; Play upload is optional.
- iOS output is a SwiftUI project generated through XcodeGen.
- Remote Setup is generated as native Android and SwiftUI controls with an Stellar backend bridge client so mobile users can save the SSH target/auth details and run the same deploy, verify, TLS, test, and sync workflow.
README

printf 'status=ok\n'
printf 'ir=%s\n' "$ir_path"
printf 'android=%s\n' "$android_dir"
printf 'ios=%s\n' "$ios_dir"
