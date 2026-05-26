package app.wizardry.stellar;

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
        title.setText("Inbox");
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
