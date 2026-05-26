import SwiftUI

struct ContentView: View {
    private let items = [
        "Inbox",
        "Timeline",
        "People",
        "Groups",
        "Settings",
        "Remote Setup",
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
                    TextField("Message", text: $message, axis: .vertical)
                    Button("Send") { message = "" }
                }
                remoteSetupSection
            }
            .navigationTitle("Inbox")
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
                    TextField("https://stellar.example.org/backend", text: $remoteBridgeURL)
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
                    TextField("user@203.0.113.8", text: $remoteHost)
                        .stellarRemoteTargetContentType()
                        .autocorrectionDisabled(true)
                    TextField("~/.ssh/id_ed25519", text: $remoteKeyPath)
                        .autocorrectionDisabled(true)
                    TextField("SSH port", text: $remotePort)
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
                    Toggle("SSH key has password", isOn: $remoteKeyHasPassword)
                    if remoteKeyHasPassword {
                        SecureField("SSH key password", text: $remotePassword)
                        Toggle("Save on this device", isOn: $remoteSavePassword)
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
