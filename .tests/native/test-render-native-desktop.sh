#!/bin/sh

set -eu

test_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
repo_dir=$(CDPATH= cd -- "$test_dir/../.." && pwd -P)
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/owl-render-test.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

failures=0

run_case() {
  name=$1
  shift
  if "$@"; then
    printf 'ok - %s\n' "$name"
  else
    printf 'not ok - %s\n' "$name" >&2
    failures=$((failures + 1))
  fi
}

render_is_deterministic() {
  cd "$repo_dir"
  sh scripts/render-native-desktop.sh >"$tmpdir/render.out"
  git diff --exit-code -- generated/macos/Package.swift generated/macos/Sources/App/App.swift generated/linux/meson.build generated/linux/src/main.c
}

generated_sources_have_no_template_tokens() {
  cd "$repo_dir"
  ! grep -E '__[A-Z0-9_]+__' generated/macos/Sources/App/App.swift generated/linux/src/main.c
}

swift_actions_cover_ir() {
  cd "$repo_dir"
  jq -r '.app.actions[].id' app-blueprint/app.ir.yaml | sort >"$tmpdir/ir-actions"
  sed -n 's/^[[:space:]]*case "\([^"]*\)":.*/\1/p' generated/macos/Sources/App/App.swift | sort -u >"$tmpdir/swift-actions"
  missing=$(comm -23 "$tmpdir/ir-actions" "$tmpdir/swift-actions")
  [ -z "$missing" ] || {
    printf 'missing Swift actions:\n%s\n' "$missing" >&2
    return 1
  }
}

linux_actions_cover_ir() {
  cd "$repo_dir"
  jq -r '.app.actions[].id | gsub("_"; "-")' app-blueprint/app.ir.yaml | sort >"$tmpdir/ir-actions-linux"
  sed -n 's/.*add_app_action(app, context, "\([^"]*\)").*/\1/p' generated/linux/src/main.c | sort -u >"$tmpdir/linux-actions"
  sed -n 's/.*g_strcmp0(action_name, "\([^"]*\)").*/\1/p' generated/linux/src/main.c | sort -u >"$tmpdir/linux-handlers"
  missing_registered=$(comm -23 "$tmpdir/ir-actions-linux" "$tmpdir/linux-actions")
  missing_handlers=$(comm -23 "$tmpdir/ir-actions-linux" "$tmpdir/linux-handlers")
  [ -z "$missing_registered" ] || {
    printf 'missing Linux registrations:\n%s\n' "$missing_registered" >&2
    return 1
  }
  [ -z "$missing_handlers" ] || {
    printf 'missing Linux handlers:\n%s\n' "$missing_handlers" >&2
    return 1
  }
}

swift_uses_native_desktop_idiom() {
  cd "$repo_dir"
  grep -Fq '@Published var snapshot: Snapshot = Snapshot(root: defaultMailRoot())' generated/macos/Sources/App/App.swift
  grep -Fq '@Published var hasLoadedInitialSnapshot: Bool = false' generated/macos/Sources/App/App.swift
  grep -Fq '@Published var startupMessage: String = "Loading mailbox..."' generated/macos/Sources/App/App.swift
  grep -Fq '@Published var startupErrorMessage: String?' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct StartupSplashView: View' generated/macos/Sources/App/App.swift
  grep -Fq 'if session.hasLoadedInitialSnapshot {' generated/macos/Sources/App/App.swift
  grep -Fq 'Image(nsImage: NSApp.applicationIconImage)' generated/macos/Sources/App/App.swift
  grep -Fq 'func retryInitialLoad()' generated/macos/Sources/App/App.swift
  grep -Fq 'private func loadInitialSnapshot() async' generated/macos/Sources/App/App.swift
  grep -Fq 'startupMessage = "Checking incoming messages..."' generated/macos/Sources/App/App.swift
  grep -Fq 'let transportResponse = try await OwlBackend.tickSimpleX(root: root)' generated/macos/Sources/App/App.swift
  grep -Fq 'startupMessage = "Loading new messages..."' generated/macos/Sources/App/App.swift
  grep -Fq 'loaded = try await OwlBackend.snapshot(root: root)' generated/macos/Sources/App/App.swift
  grep -Fq 'self.statusText = transportWarning ?? "Loaded \\(loaded.threads.count) conversations from \\(loaded.root)"' generated/macos/Sources/App/App.swift
  grep -Fq 'self.hasLoadedInitialSnapshot = true' generated/macos/Sources/App/App.swift
  grep -Fq 'Task { await loadInitialSnapshot() }' generated/macos/Sources/App/App.swift
  ! grep -Fq 'snapshot = SeedData.snapshot' generated/macos/Sources/App/App.swift
  ! grep -Fq 'Using seed state' generated/macos/Sources/App/App.swift
  grep -q 'PrimaryTabBar' generated/macos/Sources/App/App.swift
  grep -q 'NSTitlebarAccessoryViewController' generated/macos/Sources/App/App.swift
  grep -q 'window.titleVisibility = .hidden' generated/macos/Sources/App/App.swift
  grep -q 'installTitlebarTabs(in: window)' generated/macos/Sources/App/App.swift
  grep -q 'private final class NonDraggableHostingView<Content: View>: NSHostingView<Content>' generated/macos/Sources/App/App.swift
  grep -q 'override var mouseDownCanMoveWindow: Bool { false }' generated/macos/Sources/App/App.swift
  grep -q 'controller.view = NonDraggableHostingView(rootView: AnyView(tabsView))' generated/macos/Sources/App/App.swift
  grep -q 'NewSendersView' generated/macos/Sources/App/App.swift
  grep -q 'MailView' generated/macos/Sources/App/App.swift
  grep -q 'TabButton(title: "New Senders", systemImage: "tray.and.arrow.down"' generated/macos/Sources/App/App.swift
  grep -q 'TabButton(title: "Inbox", systemImage: "tray.full"' generated/macos/Sources/App/App.swift
  grep -q 'TabButton(title: "Mail", systemImage: "envelope"' generated/macos/Sources/App/App.swift
  grep -q 'let systemImage: String' generated/macos/Sources/App/App.swift
  grep -q 'ArchiveTabButton(selected: session.selectedRoute == "archive")' generated/macos/Sources/App/App.swift
  grep -q 'controller.view.frame = NSRect(x: 0, y: 0, width: 500, height: 34)' generated/macos/Sources/App/App.swift
  grep -q '.frame(width: 500, height: 34, alignment: .leading)' generated/macos/Sources/App/App.swift
  grep -q '.frame(width: 82)' generated/macos/Sources/App/App.swift
  grep -q '.opacity(selected ? 1 : 0)' generated/macos/Sources/App/App.swift
  grep -q '.fixedSize(horizontal: true, vertical: false)' generated/macos/Sources/App/App.swift
  grep -q '.frame(height: 26)' generated/macos/Sources/App/App.swift
  grep -q '.frame(minWidth: 18, minHeight: 16)' generated/macos/Sources/App/App.swift
  grep -q 'func openArchive()' generated/macos/Sources/App/App.swift
  grep -q 'case "focus_archive":' generated/macos/Sources/App/App.swift
  grep -q 'NSApplicationDelegate' generated/macos/Sources/App/App.swift
  grep -q 'NSWindow(' generated/macos/Sources/App/App.swift
  grep -q 'NSHostingView(rootView:' generated/macos/Sources/App/App.swift
  grep -q 'app.run()' generated/macos/Sources/App/App.swift
  grep -q 'NSOpenPanel' generated/macos/Sources/App/App.swift
  grep -q 'setActivationPolicy(.regular)' generated/macos/Sources/App/App.swift
  grep -q 'Process()' generated/macos/Sources/App/App.swift
  grep -q 'process.arguments = \\[script.path, action, root\\] + args' generated/macos/Sources/App/App.swift
  grep -q 'NSApp.windowsMenu = windowMenu' generated/macos/Sources/App/App.swift
  grep -q 'let editMenu = NSMenu(title: "Edit")' generated/macos/Sources/App/App.swift
  grep -q 'let messageMenu = NSMenu(title: "Message")' generated/macos/Sources/App/App.swift
  grep -q 'private let generatedAppMenuTitle = "Owl"' generated/macos/Sources/App/App.swift
  grep -q 'appMenuItem.title = generatedAppMenuTitle' generated/macos/Sources/App/App.swift
  grep -q '.executable(name: "owl", targets: \["App"\])' generated/macos/Package.swift
  grep -q 'actionItem("Preferences...", action: "open_settings", key: ",", modifiers: \\[.command\\])' generated/macos/Sources/App/App.swift
  ! grep -q 'actionItem("Settings...", action: "open_settings"' generated/macos/Sources/App/App.swift
  grep -q 'settingsWindow.title = "Preferences"' generated/macos/Sources/App/App.swift
  grep -q 'g_menu_append(app_menu, "Preferences", "app.open-settings")' generated/linux/src/main.c
  ! grep -q 'g_menu_append(app_menu, "Settings", "app.open-settings")' generated/linux/src/main.c
  grep -q 'TabView {' generated/macos/Sources/App/App.swift
  grep -q 'Label("General", systemImage: "gearshape")' generated/macos/Sources/App/App.swift
  grep -q 'Label("Appearance", systemImage: "paintpalette")' generated/macos/Sources/App/App.swift
  grep -q 'Label("Email", systemImage: "envelope")' generated/macos/Sources/App/App.swift
  grep -q 'Label("Delivery", systemImage: "network")' generated/macos/Sources/App/App.swift
  grep -q 'Label("SimpleX", systemImage: "lock.fill")' generated/macos/Sources/App/App.swift
  grep -q 'Button { session.chooseMailRoot() } label:' generated/macos/Sources/App/App.swift
  grep -q 'Label("Setup Folders", systemImage: "folder.badge.gearshape")' generated/macos/Sources/App/App.swift
  ! grep -q 'actionItem("Choose Mail Root...", action: "choose_mail_root")' generated/macos/Sources/App/App.swift
  ! grep -q 'actionItem("Setup Mail Folders", action: "setup_folders")' generated/macos/Sources/App/App.swift
  grep -q 'set-ui-pref' generated/macos/Sources/App/App.swift
  ! awk '
    /private struct RootView/ { in_view = 1 }
    /private enum MessageDropAction/ { in_view = 0 }
    in_view && /PrimaryTabBar[(][)]/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' generated/macos/Sources/App/App.swift
  ! grep -q 'WKWebView' generated/macos/Sources/App/App.swift
  ! grep -q 'UserDefaults' generated/macos/Sources/App/App.swift
}

swift_unified_simplex_email_ui_exists() {
  cd "$repo_dir"
  grep -q '@Published var optimisticOutgoingMessages: \\[MessageItem\\] = \\[\\]' generated/macos/Sources/App/App.swift
  grep -q 'let optimistic = optimisticMessage(for: thread, transport: transport, subject: subject, body: body, attachment: attachment)' generated/macos/Sources/App/App.swift
  grep -q 'upsertOptimisticOutgoingMessage(optimistic)' generated/macos/Sources/App/App.swift
  grep -q 'composeBody = ""' generated/macos/Sources/App/App.swift
  grep -q 'self.updateOptimisticOutgoingMessage(id: optimistic.id, status: "sent")' generated/macos/Sources/App/App.swift
  grep -q 'self.updateOptimisticOutgoingMessage(id: optimistic.id, status: "error")' generated/macos/Sources/App/App.swift
  grep -q 'status: "sending"' generated/macos/Sources/App/App.swift
  grep -q 'var isSending: Bool { status == "sending" || status == "waiting-adapter" }' generated/macos/Sources/App/App.swift
  grep -q 'ProgressView()' generated/macos/Sources/App/App.swift
  grep -q 'Text("Sending...")' generated/macos/Sources/App/App.swift
  grep -q 'selectedTransport = thread.hasSimpleXPath ? .simplex : .email' generated/macos/Sources/App/App.swift
  grep -q 'var canSwitchComposerTransport: Bool' generated/macos/Sources/App/App.swift
  grep -q 'return thread.hasSimpleXPath && thread.hasEmailPath' generated/macos/Sources/App/App.swift
  grep -q 'func selectComposerTransport(_ transport: Transport)' generated/macos/Sources/App/App.swift
  grep -q 'guard thread.hasSimpleXPath else { return }' generated/macos/Sources/App/App.swift
  grep -q 'guard thread.hasEmailPath else { return }' generated/macos/Sources/App/App.swift
  grep -q 'selectComposerTransport(.simplex)' generated/macos/Sources/App/App.swift
  grep -q 'selectComposerTransport(.email)' generated/macos/Sources/App/App.swift
  grep -q 'let subject = transport == .email ? composeSubject : ""' generated/macos/Sources/App/App.swift
  grep -q 'private struct TransportMiniToggle: View' generated/macos/Sources/App/App.swift
  grep -q 'isEnabled: session.canSwitchComposerTransport' generated/macos/Sources/App/App.swift
  grep -q 'let isEnabled: Bool' generated/macos/Sources/App/App.swift
  grep -q '.disabled(!isEnabled)' generated/macos/Sources/App/App.swift
  grep -q 'Add both SimpleX and email contact information to switch transports' generated/macos/Sources/App/App.swift
  grep -q 'Image(systemName: isSecure ? "lock.fill" : "lock.open")' generated/macos/Sources/App/App.swift
  grep -q 'transport = isSecure ? .email : .simplex' generated/macos/Sources/App/App.swift
  grep -q '.frame(width: 26, height: 14)' generated/macos/Sources/App/App.swift
  grep -q '.accessibilityValue(isSecure ? "SimpleX" : "Email")' generated/macos/Sources/App/App.swift
  ! grep -q 'Picker("Transport"' generated/macos/Sources/App/App.swift
  grep -q 'if session.selectedTransport == .email {' generated/macos/Sources/App/App.swift
  grep -q 'TextField("Subject", text: $session.composeSubject)' generated/macos/Sources/App/App.swift
  grep -q '.animation(.easeOut(duration: 0.16), value: session.selectedTransport)' generated/macos/Sources/App/App.swift
  grep -q 'ZStack(alignment: .bottom)' generated/macos/Sources/App/App.swift
  grep -q 'TextEditor(text: $session.composeBody)' generated/macos/Sources/App/App.swift
  grep -q '.scrollIndicators(.automatic)' generated/macos/Sources/App/App.swift
  grep -q '.padding(.bottom, 30)' generated/macos/Sources/App/App.swift
  grep -q '.frame(minHeight: 58, idealHeight: 72, maxHeight: 118)' generated/macos/Sources/App/App.swift
  grep -q '.controlSize(.small)' generated/macos/Sources/App/App.swift
  grep -q 'Image(systemName: "paperplane.fill")' generated/macos/Sources/App/App.swift
  grep -q 'Attachments send by SimpleX' generated/macos/Sources/App/App.swift
  ! grep -q 'Label(session.selectedTransport == .email ? "Send Email" : "Send"' generated/macos/Sources/App/App.swift
  grep -q 'session.openInbox(focusing: message.id)' generated/macos/Sources/App/App.swift
  grep -q 'message.in_inbox ? 0.62 : 1.0' generated/macos/Sources/App/App.swift
  grep -q 'TransportPill(message: message)' generated/macos/Sources/App/App.swift
}

swift_compose_accepts_file_drops() {
  cd "$repo_dir"
  grep -Fq 'private struct PendingAttachment: Identifiable, Hashable' generated/macos/Sources/App/App.swift
  grep -Fq '@Published var pendingAttachment: PendingAttachment?' generated/macos/Sources/App/App.swift
  grep -Fq 'func attachDroppedFiles(_ providers: [NSItemProvider], selecting thread: ThreadItem? = nil) -> Bool' generated/macos/Sources/App/App.swift
  grep -Fq 'provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil)' generated/macos/Sources/App/App.swift
  grep -Fq 'func addPendingAttachment(_ url: URL)' generated/macos/Sources/App/App.swift
  grep -Fq 'func removePendingAttachment()' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct PendingAttachmentPill: View' generated/macos/Sources/App/App.swift
  grep -Fq 'PendingAttachmentPill(attachment: attachment)' generated/macos/Sources/App/App.swift
  grep -Fq '.onDrop(of: [UTType.fileURL], isTargeted: $isAttachmentTargeted) { providers in' generated/macos/Sources/App/App.swift
  grep -Fq 'session.attachDroppedFiles(providers, selecting: thread)' generated/macos/Sources/App/App.swift
  grep -Fq 'static func sendAttachment(root: String, threadID: String, transport: Transport, subject: String, body: String, attachmentPath: String) async throws -> Data' generated/macos/Sources/App/App.swift
  grep -Fq 'runJSON(action: "send-attachment", root: root, args: [threadID, transport.rawValue, subject, body64, attachmentPath])' generated/macos/Sources/App/App.swift
  grep -Fq 'OwlBackend.sendAttachment(root: root, threadID: thread.id, transport: transport, subject: subject, body: body, attachmentPath: attachment.path)' generated/macos/Sources/App/App.swift
  grep -Fq 'return thread.hasEmailPath && pendingAttachment == nil' generated/macos/Sources/App/App.swift
}

swift_new_and_inbox_use_card_stack_layout() {
  cd "$repo_dir"
  grep -q 'CardStackFrame' generated/macos/Sources/App/App.swift
  grep -q 'NewSenderStackCard' generated/macos/Sources/App/App.swift
  grep -q 'private struct NewSenderRealPile: View' generated/macos/Sources/App/App.swift
  grep -Fq 'ForEach(messages.indices, id: \.self)' generated/macos/Sources/App/App.swift
  grep -Fq '.offset(x: cardOffsetX(index), y: cardOffsetY(index))' generated/macos/Sources/App/App.swift
  grep -Fq 'isExpanded ? CGFloat(index) * 326 : -CGFloat(index) * 5.4' generated/macos/Sources/App/App.swift
  grep -Fq 'isExpanded ? 0 : [0.0, -8.0, 6.0, -5.0, 4.0][min(index, 4)]' generated/macos/Sources/App/App.swift
  grep -q 'NewSenderMessageStackCard' generated/macos/Sources/App/App.swift
  grep -q 'InboxStackCard' generated/macos/Sources/App/App.swift
  grep -Fq 'if stage != .senders {' generated/macos/Sources/App/App.swift
  ! grep -Fq 'HeaderView(title: "Inbox"' generated/macos/Sources/App/App.swift
  ! grep -Fq 'HeaderView(title: "Mail"' generated/macos/Sources/App/App.swift
  grep -Fq 'private var stackBadgeText: String?' generated/macos/Sources/App/App.swift
  grep -Fq 'guard depth > 3, let badge, !badge.isEmpty else { return nil }' generated/macos/Sources/App/App.swift
  grep -Fq 'badge: quarantineMessages.count > 3 ? String(quarantineMessages.count) : nil' generated/macos/Sources/App/App.swift
  grep -Fq 'var cardWidth: CGFloat' generated/macos/Sources/App/App.swift
  grep -Fq 'cardTextWeight > 720 ? 500 : 420' generated/macos/Sources/App/App.swift
  grep -Fq 'cardTextWeight > 720 ? 375 : (cardTextWeight > 260 ? 360 : 315)' generated/macos/Sources/App/App.swift
  grep -Fq 'var cardBodyLineLimit: Int' generated/macos/Sources/App/App.swift
  grep -Fq 'var inboxCardWidth: CGFloat' generated/macos/Sources/App/App.swift
  grep -Fq 'cardTextWeight > 720 ? 420 : (cardTextWeight > 260 ? 330 : 300)' generated/macos/Sources/App/App.swift
  grep -Fq 'cardTextWeight > 720 ? 350 : (cardTextWeight > 260 ? 275 : 250)' generated/macos/Sources/App/App.swift
  grep -Fq 'var inboxCardBodyLineLimit: Int' generated/macos/Sources/App/App.swift
  grep -Fq '.frame(width: width, alignment: .topLeading)' generated/macos/Sources/App/App.swift
  grep -Fq '.frame(minHeight: minHeight, alignment: .topLeading)' generated/macos/Sources/App/App.swift
  grep -Fq '.fixedSize(horizontal: true, vertical: false)' generated/macos/Sources/App/App.swift
  grep -Fq 'StaticCardStackBackplates(' generated/macos/Sources/App/App.swift
  grep -Fq 'width: message.inboxCardWidth,' generated/macos/Sources/App/App.swift
  grep -Fq 'minHeight: message.inboxCardMinHeight' generated/macos/Sources/App/App.swift
  grep -Fq '.frame(width: width, height: minHeight)' generated/macos/Sources/App/App.swift
  grep -Fq 'private func stackOffsetX(_ index: Int) -> CGFloat' generated/macos/Sources/App/App.swift
  grep -Fq 'CardStackFrame(' generated/macos/Sources/App/App.swift
  grep -Fq 'depth: 1,' generated/macos/Sources/App/App.swift
  grep -Fq 'Text("\\(stackDepth)")' generated/macos/Sources/App/App.swift
  grep -Fq 'LazyVStack(spacing: 32)' generated/macos/Sources/App/App.swift
  grep -Fq 'ForEach(inboxStackCards)' generated/macos/Sources/App/App.swift
  grep -Fq 'private var inboxStackCards: [MessageItem]' generated/macos/Sources/App/App.swift
  grep -Fq 'let grouped = Dictionary(grouping: session.snapshot.inbox, by: { inboxStackKey(for: $0) })' generated/macos/Sources/App/App.swift
  grep -Fq 'private func inboxStackMessages(for message: MessageItem) -> [MessageItem]' generated/macos/Sources/App/App.swift
  ! grep -Fq 'revealedMessage: inboxStackMessages(for: message).dropFirst().first' generated/macos/Sources/App/App.swift
  ! grep -Fq 'let revealedMessage: MessageItem?' generated/macos/Sources/App/App.swift
  ! grep -Fq 'InboxCardContent(message: revealedMessage, actionsVisible: false)' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct InboxCardContent: View' generated/macos/Sources/App/App.swift
  awk '
    /private struct InboxCardContent/ { in_view = 1 }
    /private struct TimelineViewportHeightPreferenceKey/ { in_view = 0 }
    in_view && /Spacer[(]minLength: 10[)]/ { top_spacer = 1 }
    in_view && /Text[(]friendlyTime[(]message[.]received_at[)][)]/ { time = 1 }
    in_view && /Spacer[(]minLength: 0[)]/ { bottom_spacer = 1 }
    in_view && /Button [{] session[.]archive[(]message[)] [}] label:/ { archive = 1 }
    in_view && /TransportMark[(]message: message[)]/ { bad_lock = 1 }
    in_view && /session[.]markRead[(]message/ { bad_mark = 1 }
    END { exit (top_spacer && time && bottom_spacer && archive && !bad_lock && !bad_mark) ? 0 : 1 }
  ' generated/macos/Sources/App/App.swift
  grep -Fq '.id(inboxStackID(for: message))' generated/macos/Sources/App/App.swift
  grep -Fq '.zIndex(inboxStackZIndex(for: message))' generated/macos/Sources/App/App.swift
  grep -Fq 'private func inboxStackZIndex(for message: MessageItem) -> Double' generated/macos/Sources/App/App.swift
  grep -Fq 'return 1000' generated/macos/Sources/App/App.swift
  ! grep -Fq 'SidebarMailboxRow(mailbox: trashMailbox)' generated/macos/Sources/App/App.swift
  ! grep -Fq 'private var trashMailbox: MailboxItem' generated/macos/Sources/App/App.swift
  grep -Fq 'session.selectedRoute == "archive"' generated/macos/Sources/App/App.swift
  grep -Fq '.frame(maxWidth: 420)' generated/macos/Sources/App/App.swift
  grep -Fq '.frame(maxWidth: .infinity, alignment: .center)' generated/macos/Sources/App/App.swift
  grep -Fq '.frame(maxWidth: 540, alignment: .center)' generated/macos/Sources/App/App.swift
  grep -Fq 'TransportPill(message: latest)' generated/macos/Sources/App/App.swift
  grep -Fq '.frame(maxWidth: .infinity, alignment: .trailing)' generated/macos/Sources/App/App.swift
  grep -Fq 'offset(x: stackOffsetX(index), y: -CGFloat(index + 1) * 5.4)' generated/macos/Sources/App/App.swift
  grep -Fq '.background(Capsule().fill(tint.opacity(0.86)))' generated/macos/Sources/App/App.swift
  grep -Fq 'private var latestMessage: MessageItem?' generated/macos/Sources/App/App.swift
  ! grep -Fq 'Label("\\(quarantineMessages.count) pending", systemImage: "tray")' generated/macos/Sources/App/App.swift
  ! awk '
    /private struct NewSendersView/ { in_view = 1 }
    /private struct MailView/ { in_view = 0 }
    in_view && /List[[:space:]]*[(]/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' generated/macos/Sources/App/App.swift
  ! awk '
    /private struct InboxView/ { in_view = 1 }
    /private struct MailboxView/ { in_view = 0 }
    in_view && /List[[:space:]]*[(]/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' generated/macos/Sources/App/App.swift
}

swift_mail_favorites_move_between_sections() {
  cd "$repo_dir"
  grep -Fq 'func applyContactBinding(threadID: String, name: String, email: String, simplex: String, favorite: Bool)' generated/macos/Sources/App/App.swift
  grep -Fq 'func renameContact(_ thread: ThreadItem, to proposedName: String)' generated/macos/Sources/App/App.swift
  grep -Fq 'runMessageAction(status: "Contact renamed", refreshAfter: false)' generated/macos/Sources/App/App.swift
  grep -Fq 'func toggleFavorite(for thread: ThreadItem)' generated/macos/Sources/App/App.swift
  grep -Fq 'withAnimation(.spring(response: 0.30, dampingFraction: 0.86))' generated/macos/Sources/App/App.swift
  grep -Fq 'runMessageAction(status: favorite ? "Added to Favorites" : "Removed from Favorites", refreshAfter: false)' generated/macos/Sources/App/App.swift
  grep -Fq 'snapshot.favorites.removeAll { $0.id == threadID }' generated/macos/Sources/App/App.swift
  grep -Fq 'snapshot.favorites.insert(updated, at: 0)' generated/macos/Sources/App/App.swift
  grep -Fq '@Namespace private var threadMoveNamespace' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct ThreadTimelineHeader: View' generated/macos/Sources/App/App.swift
  grep -Fq 'Image(systemName: thread.favorite ? "star.fill" : "star")' generated/macos/Sources/App/App.swift
  grep -Fq 'session.toggleFavorite(for: thread)' generated/macos/Sources/App/App.swift
  grep -Fq '@State private var contactFilter: MailContactFilter = .all' generated/macos/Sources/App/App.swift
  grep -Fq '@State private var contactSort: MailContactSort = .recent' generated/macos/Sources/App/App.swift
  grep -Fq '@State private var contactListWidth: CGFloat = 290' generated/macos/Sources/App/App.swift
  grep -Fq '@State private var inspectorWidth: CGFloat = 260' generated/macos/Sources/App/App.swift
  grep -Fq '@State private var contactInfoVisible = true' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct SidebarResizeDivider: View' generated/macos/Sources/App/App.swift
  grep -Fq 'SidebarResizeDivider(width: $contactListWidth, range: 220...420, edge: .trailing)' generated/macos/Sources/App/App.swift
  grep -Fq 'TimelineView(inspectorWidth: $inspectorWidth, contactInfoVisible: $contactInfoVisible)' generated/macos/Sources/App/App.swift
  grep -Fq '.animation(.easeInOut(duration: 0.22), value: contactInfoVisible)' generated/macos/Sources/App/App.swift
  grep -Fq 'SidebarResizeDivider(width: $inspectorWidth, range: 220...380, edge: .leading)' generated/macos/Sources/App/App.swift
  grep -Fq 'if contactInfoVisible {' generated/macos/Sources/App/App.swift
  grep -Fq '.transition(.move(edge: .trailing).combined(with: .opacity))' generated/macos/Sources/App/App.swift
  grep -Fq 'Image(systemName: "person.text.rectangle")' generated/macos/Sources/App/App.swift
  grep -Fq 'contactInfoVisible.toggle()' generated/macos/Sources/App/App.swift
  grep -Fq 'contactInfoVisible ? "Hide contact" : "Show contact"' generated/macos/Sources/App/App.swift
  ! grep -Fq 'Toggle("Favorite", isOn: $session.contactDraftFavorite)' generated/macos/Sources/App/App.swift
  grep -Fq '@State private var simpleXAddressVisible = false' generated/macos/Sources/App/App.swift
  grep -Fq 'Text("Contact")' generated/macos/Sources/App/App.swift
  grep -Fq 'Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8)' generated/macos/Sources/App/App.swift
  grep -Fq 'Text("Name")' generated/macos/Sources/App/App.swift
  grep -Fq 'Text("Email")' generated/macos/Sources/App/App.swift
  grep -Fq 'Text("SimpleX")' generated/macos/Sources/App/App.swift
  grep -Fq 'Image(systemName: simpleXAddressVisible ? "eye.slash" : "eye")' generated/macos/Sources/App/App.swift
  grep -Fq 'No SimpleX binding' generated/macos/Sources/App/App.swift
  grep -Fq 'Label("Save Contact", systemImage: "person.crop.circle.badge.checkmark")' generated/macos/Sources/App/App.swift
  grep -Fq 'SimpleX address bound' generated/macos/Sources/App/App.swift
  ! grep -Fq 'Text("Identity")' generated/macos/Sources/App/App.swift
  ! grep -Fq 'Label("Save Binding", systemImage: "person.crop.circle.badge.checkmark")' generated/macos/Sources/App/App.swift
  grep -Fq 'DragGesture(minimumDistance: 2)' generated/macos/Sources/App/App.swift
  grep -Fq '.highPriorityGesture(' generated/macos/Sources/App/App.swift
  grep -Fq 'transaction.disablesAnimations = true' generated/macos/Sources/App/App.swift
  grep -Fq 'NSCursor.resizeLeftRight.push()' generated/macos/Sources/App/App.swift
  grep -Fq 'private enum MailContactFilter: String, CaseIterable' generated/macos/Sources/App/App.swift
  grep -Fq 'private enum MailContactSort: String, CaseIterable' generated/macos/Sources/App/App.swift
  grep -Fq 'Label("Favorites", systemImage: "line.3.horizontal.decrease.circle")' generated/macos/Sources/App/App.swift
  grep -Fq 'FriendlyTime.sortTimestamp(lhs.latest_at)' generated/macos/Sources/App/App.swift
  grep -Fq 'if lhsTime != rhsTime { return lhsTime > rhsTime }' generated/macos/Sources/App/App.swift
  grep -Fq 'private func sortedThreads(_ threads: [ThreadItem]) -> [ThreadItem]' generated/macos/Sources/App/App.swift
  grep -Fq '.matchedGeometryEffect(id: thread.id, in: threadMoveNamespace, properties: .position)' generated/macos/Sources/App/App.swift
  grep -Fq 'private func mailThreadRow(_ thread: ThreadItem) -> some View' generated/macos/Sources/App/App.swift
  grep -Fq '@FocusState private var nameFieldFocused: Bool' generated/macos/Sources/App/App.swift
  grep -Fq '@State private var isRenaming = false' generated/macos/Sources/App/App.swift
  grep -Fq 'TextField("Name", text: $draftName)' generated/macos/Sources/App/App.swift
  grep -Fq '.onSubmit { commitRename() }' generated/macos/Sources/App/App.swift
  grep -Fq '.onTapGesture(count: 2)' generated/macos/Sources/App/App.swift
  grep -Fq 'session.renameContact(thread, to: draftName)' generated/macos/Sources/App/App.swift
  grep -Fq 'private var favoriteThreads: [ThreadItem]' generated/macos/Sources/App/App.swift
  grep -Fq 'uniqueThreads(session.snapshot.favorites + session.snapshot.individuals.filter { $0.favorite } + session.snapshot.groups.filter { $0.favorite })' generated/macos/Sources/App/App.swift
  grep -Fq 'session.snapshot.individuals.filter { !favoriteThreadIDs.contains($0.id) && !$0.favorite }' generated/macos/Sources/App/App.swift
  grep -Fq 'session.snapshot.groups.filter { !favoriteThreadIDs.contains($0.id) && !$0.favorite }' generated/macos/Sources/App/App.swift
  awk '
    /private struct ContactListView/ { in_view = 1 }
    /private struct MessageListRow/ { in_view = 0 }
    in_view && /ForEach[(]session[.]snapshot[.](favorites|individuals|groups)/ { found = 1 }
    END { exit found ? 1 : 0 }
  ' generated/macos/Sources/App/App.swift
}

swift_cards_have_horizontal_flick_actions() {
  cd "$repo_dir"
  grep -Fq 'func moveNewSender(_ thread: ThreadItem, to list: String)' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct SenderDropDock: View' generated/macos/Sources/App/App.swift
  grep -Fq 'SenderDropTarget(action: .accept)' generated/macos/Sources/App/App.swift
  grep -Fq 'SenderDropTarget(action: .reject)' generated/macos/Sources/App/App.swift
  grep -Fq 'SenderDropTarget(action: .spam)' generated/macos/Sources/App/App.swift
  ! awk '
    /private struct SenderDropTarget/ { in_view = 1 }
    /private struct MessageDropDock/ { in_view = 0 }
    in_view && /Text[(]action[.]label[)]/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' generated/macos/Sources/App/App.swift
  grep -Fq 'func handleSenderDrop(threadID: String, action: SenderDropAction)' generated/macos/Sources/App/App.swift
  grep -Fq 'private let senderDragPayloadPrefix = "owl-sender:"' generated/macos/Sources/App/App.swift
  grep -Fq 'return NSItemProvider(object: "\(senderDragPayloadPrefix)\(thread.id)" as NSString)' generated/macos/Sources/App/App.swift
  grep -Fq 'return NSItemProvider(object: "\(senderDragPayloadPrefix)\(threadID)" as NSString)' generated/macos/Sources/App/App.swift
  grep -Fq '@State private var expandedSenderID: String?' generated/macos/Sources/App/App.swift
  grep -Fq 'NewSenderMessageStackCard(' generated/macos/Sources/App/App.swift
  grep -Fq 'dragPayload: .senderPile(threadID: thread.id)' generated/macos/Sources/App/App.swift
  grep -Fq 'private func quarantineMessages(for thread: ThreadItem) -> [MessageItem]' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct NewSenderMessageDragModifier: ViewModifier' generated/macos/Sources/App/App.swift
  grep -Fq '.animation(.spring(response: 0.30, dampingFraction: 0.84), value: isExpanded)' generated/macos/Sources/App/App.swift
  ! grep -Fq 'private struct NewSenderExpandedMessageRow' generated/macos/Sources/App/App.swift
  grep -Fq 'private var newSenderFlickGesture: some Gesture' generated/macos/Sources/App/App.swift
  grep -Fq 'let isIntentionalFlick = abs(actual) > 145 || (abs(actual) > 84 && abs(projected) > 290 && actual * projected > 0)' generated/macos/Sources/App/App.swift
  grep -Fq 'let destination = actual >= 0 ? "accepted" : "spam"' generated/macos/Sources/App/App.swift
  grep -Fq 'session.moveNewSender(thread, to: destination)' generated/macos/Sources/App/App.swift
  grep -Fq 'private var cardDragGesture: some Gesture' generated/macos/Sources/App/App.swift
  grep -Fq 'let isIntentionalFlick = abs(actual) > 150 || (abs(actual) > 86 && abs(projected) > 300 && actual * projected > 0)' generated/macos/Sources/App/App.swift
  grep -Fq 'let shouldFlickArchive = message.in_inbox && isIntentionalFlick' generated/macos/Sources/App/App.swift
  grep -Fq 'session.archive(message)' generated/macos/Sources/App/App.swift
  grep -Fq '.simultaneousGesture(newSenderFlickGesture)' generated/macos/Sources/App/App.swift
  grep -Fq '.simultaneousGesture(cardDragGesture)' generated/macos/Sources/App/App.swift
}

swift_message_cards_are_drag_droppable() {
  cd "$repo_dir"
  grep -q 'PrioritiesTrashIcon' generated/macos/Sources/App/App.swift
  grep -q 'MessageDropTarget(action: .trash)' generated/macos/Sources/App/App.swift
  grep -q 'MessageDropTarget(action: .archive)' generated/macos/Sources/App/App.swift
  grep -q 'func trash(_ message: MessageItem)' generated/macos/Sources/App/App.swift
  grep -q 'NSWorkspace.shared.recycle(urls)' generated/macos/Sources/App/App.swift
  grep -q 'if response.delete_after_trash' generated/macos/Sources/App/App.swift
  ! grep -q 'Deleting SimpleX message' generated/macos/Sources/App/App.swift
  grep -q 'private func recycleInSystemTrash(_ urls: \\[URL\\]) async throws -> \\[URL: URL\\]' generated/macos/Sources/App/App.swift
  grep -q 'func undoLastTrashAction()' generated/macos/Sources/App/App.swift
  grep -q 'func openSystemTrash()' generated/macos/Sources/App/App.swift
  grep -q 'Label("Undo Last Trash", systemImage: "arrow.uturn.backward")' generated/macos/Sources/App/App.swift
  grep -q 'Label("Open System Trash", systemImage: "trash")' generated/macos/Sources/App/App.swift
  grep -q 'static func messageTrashFiles(root: String, messageID: String) async throws -> TrashFilesResponse' generated/macos/Sources/App/App.swift
  grep -q 'message-trash-files' generated/macos/Sources/App/App.swift scripts/owl-backend.sh
  grep -q 'delete_after_trash' generated/macos/Sources/App/App.swift scripts/owl-backend.sh
  grep -Fq '.zIndex(session.draggingMessageID == nil ? 10 : 0)' generated/macos/Sources/App/App.swift
  grep -Fq 'private var showsMessageDropDock: Bool' generated/macos/Sources/App/App.swift
  grep -Fq 'session.selectedRoute == "inbox-message"' generated/macos/Sources/App/App.swift
  ! grep -Fq 'session.selectedRoute == "mail" ||' generated/macos/Sources/App/App.swift
  grep -Fq '.contentShape(Circle())' generated/macos/Sources/App/App.swift
  grep -Fq 'case .trash: return .white' generated/macos/Sources/App/App.swift
  grep -Fq 'Color.red.opacity(0.78)' generated/macos/Sources/App/App.swift
  grep -Fq 'Color.purple.opacity(0.15)' generated/macos/Sources/App/App.swift
  grep -q 'func draggableMessageCard(_ message: MessageItem)' generated/macos/Sources/App/App.swift
  grep -q '@Published var draggingMessageID: String?' generated/macos/Sources/App/App.swift
  grep -q 'session.beginDraggingMessage(message)' generated/macos/Sources/App/App.swift
  grep -q 'return session.draggingMessageID == message.id ? 0 : 1' generated/macos/Sources/App/App.swift
  grep -Fq '.offset(dragOffset)' generated/macos/Sources/App/App.swift
  grep -Fq '.zIndex(isPointerDragging ? 20 : 0)' generated/macos/Sources/App/App.swift
  grep -q 'endDraggingMessage(id)' generated/macos/Sources/App/App.swift
  grep -q 'onDrop(of: \[UTType.plainText\]' generated/macos/Sources/App/App.swift
  grep -q 'session.handleMessageDrop(id: messageID, action: action)' generated/macos/Sources/App/App.swift
  ! awk '
    /private struct MailboxMessageRow/ { in_view = 1 }
    /private struct DraftsView/ { in_view = 0 }
    in_view && /draggableMessageCard/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' generated/macos/Sources/App/App.swift
}

swift_message_timestamps_are_friendly() {
  cd "$repo_dir"
  grep -q 'private enum FriendlyTime' generated/macos/Sources/App/App.swift
  grep -Fq 'return "\(compactDuration(delta)) ago"' generated/macos/Sources/App/App.swift
  grep -Fq 'private func fullTimestamp(_ rawValue: String) -> String' generated/macos/Sources/App/App.swift
  grep -Fq 'Text(friendlyTime(message.received_at))' generated/macos/Sources/App/App.swift
  grep -Fq '.help(fullTimestamp(message.received_at))' generated/macos/Sources/App/App.swift
  grep -Fq 'Text(thread.latest_at.isEmpty ? "No messages" : friendlyTime(thread.latest_at))' generated/macos/Sources/App/App.swift
  ! grep -Fq 'Text("\(message.contact_name) - \(friendlyTime(message.received_at))")' generated/macos/Sources/App/App.swift
  ! grep -Fq 'Text(message.received_at)' generated/macos/Sources/App/App.swift
  ! grep -Fq 'Text(thread.latest_at)' generated/macos/Sources/App/App.swift
}

swift_mail_timelines_restore_scroll_position() {
  cd "$repo_dir"
  grep -Fq '@Published var timelineScrollPositions: [String: String] = [:]' generated/macos/Sources/App/App.swift
  grep -Fq '@Published var timelineAtEndByThread: [String: Bool] = [:]' generated/macos/Sources/App/App.swift
  grep -Fq 'func rememberTimelineScrollPosition(threadID: String?, messageID: String)' generated/macos/Sources/App/App.swift
  grep -Fq 'func rememberTimelineAtEnd(threadID: String?, isAtEnd: Bool)' generated/macos/Sources/App/App.swift
  grep -Fq 'func timelineShouldFollowEnd(for thread: ThreadItem?) -> Bool' generated/macos/Sources/App/App.swift
  grep -Fq 'func timelineEndID(for thread: ThreadItem?) -> String?' generated/macos/Sources/App/App.swift
  grep -Fq 'func timelineScrollTarget(for thread: ThreadItem?) -> String?' generated/macos/Sources/App/App.swift
  grep -Fq 'return thread.messages.last?.id' generated/macos/Sources/App/App.swift
  grep -Fq 'session.rememberTimelineScrollPosition(threadID: session.selectedThreadID, messageID: message.id)' generated/macos/Sources/App/App.swift
  grep -Fq 'private let timelineBottomID = "timeline-bottom-anchor"' generated/macos/Sources/App/App.swift
  grep -Fq '.frame(height: 18)' generated/macos/Sources/App/App.swift
  grep -Fq '.id(timelineBottomID)' generated/macos/Sources/App/App.swift
  grep -Fq '.padding(.horizontal, 18)' generated/macos/Sources/App/App.swift
  grep -Fq '.padding(.top, 18)' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct TimelineViewportHeightPreferenceKey: PreferenceKey' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct TimelineBottomMaxYPreferenceKey: PreferenceKey' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct TimelineContentMinYPreferenceKey: PreferenceKey' generated/macos/Sources/App/App.swift
  ! grep -Fq 'NSViewRepresentable' generated/macos/Sources/App/App.swift
  ! grep -Fq 'TimelineScrollEndObserver' generated/macos/Sources/App/App.swift
  ! grep -Fq 'NSView.boundsDidChangeNotification' generated/macos/Sources/App/App.swift
  grep -Fq 'private let timelineCoordinateSpace = "timeline-scroll-space"' generated/macos/Sources/App/App.swift
  grep -Fq '.coordinateSpace(name: timelineCoordinateSpace)' generated/macos/Sources/App/App.swift
  grep -Fq 'geometry.frame(in: .named(timelineCoordinateSpace)).minY' generated/macos/Sources/App/App.swift
  grep -Fq 'geometry.frame(in: .named(timelineCoordinateSpace)).maxY' generated/macos/Sources/App/App.swift
  grep -Fq '.onPreferenceChange(TimelineViewportHeightPreferenceKey.self)' generated/macos/Sources/App/App.swift
  grep -Fq '.onPreferenceChange(TimelineBottomMaxYPreferenceKey.self)' generated/macos/Sources/App/App.swift
  grep -Fq '.onPreferenceChange(TimelineContentMinYPreferenceKey.self)' generated/macos/Sources/App/App.swift
  grep -Fq '.overlay(alignment: .bottom)' generated/macos/Sources/App/App.swift
  grep -Fq '.padding(.bottom, 14)' generated/macos/Sources/App/App.swift
  grep -Fq 'let distanceFromEnd = timelineBottomMaxY - timelineViewportHeight' generated/macos/Sources/App/App.swift
  grep -Fq 'let tolerance: CGFloat = timelineContentMinY > 0 ? 24 : 16' generated/macos/Sources/App/App.swift
  grep -Fq 'setTimelineEndVisible(distanceFromEnd <= tolerance)' generated/macos/Sources/App/App.swift
  grep -Fq 'setTimelineEndVisible(false)' generated/macos/Sources/App/App.swift
  grep -Fq 'Image(systemName: "arrow.down.circle.fill")' generated/macos/Sources/App/App.swift
  grep -Fq 'scrollToTimelineEnd(proxy)' generated/macos/Sources/App/App.swift
  grep -Fq '.onChange(of: session.timelineEndID(for: session.selectedThread)) { _ in' generated/macos/Sources/App/App.swift
  grep -Fq '.onChange(of: session.timelineMessages.map(\.id).joined(separator: "|")) { _ in' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct TimelineMessageFramePreferenceKey: PreferenceKey' generated/macos/Sources/App/App.swift
  grep -Fq 'visibleMessageFrames = frames' generated/macos/Sources/App/App.swift
  grep -Fq 'geometry.frame(in: .named(timelineCoordinateSpace))' generated/macos/Sources/App/App.swift
  grep -Fq 'func markVisibleTimelineMessagesSeen(threadID: String?, visibleFrames: [String: CGRect], viewportHeight: CGFloat)' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct SeenMessageEdges' generated/macos/Sources/App/App.swift
  grep -Fq 'private var witnessedTimelineMessageEdges: [String: [String: SeenMessageEdges]] = [:]' generated/macos/Sources/App/App.swift
  grep -Fq 'frame.minY >= -1 && frame.maxY <= viewportHeight + 1' generated/macos/Sources/App/App.swift
  grep -Fq 'frame.minY >= -1 && frame.minY <= viewportHeight + 1' generated/macos/Sources/App/App.swift
  grep -Fq 'frame.maxY >= -1 && frame.maxY <= viewportHeight + 1' generated/macos/Sources/App/App.swift
  grep -Fq 'edges.top && edges.bottom ? id : nil' generated/macos/Sources/App/App.swift
  grep -Fq 'selectedRoute == "mail"' generated/macos/Sources/App/App.swift
  grep -Fq 'markEarlierMessagesSeen' generated/macos/Sources/App/App.swift
  grep -Fq 'action: "mark-seen"' generated/macos/Sources/App/App.swift
  grep -Fq 'func applySeen(messageID: String)' generated/macos/Sources/App/App.swift
  grep -Fq 'session.noteApplicationFocused()' generated/macos/Sources/App/App.swift
  grep -Fq 'mark-seen ROOT MESSAGE_ID...' scripts/owl-backend.sh
  grep -Fq 'mark_seen_action()' scripts/owl-backend.sh
  grep -Fq 'mark_read_action "$id" true >/dev/null' scripts/owl-backend.sh
  grep -Fq 'archive_message_action "$id" >/dev/null' scripts/owl-backend.sh
  grep -Fq 'private func scrollToTimelineTarget(_ proxy: ScrollViewProxy, animated: Bool = true)' generated/macos/Sources/App/App.swift
  grep -Fq 'target == session.timelineEndID(for: session.selectedThread)' generated/macos/Sources/App/App.swift
  grep -Fq 'session.timelineShouldFollowEnd(for: session.selectedThread)' generated/macos/Sources/App/App.swift
  grep -Fq 'private func scrollToTimelineEnd(_ proxy: ScrollViewProxy, animated: Bool = true)' generated/macos/Sources/App/App.swift
  grep -Fq 'private func performScrollToTimelineEnd(_ proxy: ScrollViewProxy, animated: Bool)' generated/macos/Sources/App/App.swift
  grep -Fq 'proxy.scrollTo(timelineBottomID, anchor: .bottom)' generated/macos/Sources/App/App.swift
  grep -Fq 'try? await Task.sleep(nanoseconds: 120_000_000)' generated/macos/Sources/App/App.swift
  grep -Fq 'proxy.scrollTo(target, anchor: session.focusedMessageID == target ? .center : .bottom)' generated/macos/Sources/App/App.swift
  grep -Fq '.onChange(of: session.selectedThreadID) { _ in' generated/macos/Sources/App/App.swift
}

swift_inbox_cards_open_reader_before_mail() {
  cd "$repo_dir"
  grep -Fq 'selectedRoute = "inbox-message"' generated/macos/Sources/App/App.swift
  grep -Fq '@Namespace private var inboxCardNamespace' generated/macos/Sources/App/App.swift
  grep -Fq 'MessageReaderView(message: session.activeMessage, emptyTitle: "No Inbox Message Selected", animationNamespace: inboxCardNamespace)' generated/macos/Sources/App/App.swift
  grep -Fq 'InboxView(animationNamespace: inboxCardNamespace)' generated/macos/Sources/App/App.swift
  grep -Fq 'func matchedInboxCardGeometry(_ id: String, in namespace: Namespace.ID?) -> some View' generated/macos/Sources/App/App.swift
  grep -Fq 'matchedGeometryEffect(id: "inbox-card:\(id)", in: namespace, properties: .frame)' generated/macos/Sources/App/App.swift
  grep -Fq 'MessageReaderCard(message: message, animationNamespace: animationNamespace)' generated/macos/Sources/App/App.swift
  grep -Fq '.transition(.opacity)' generated/macos/Sources/App/App.swift
  grep -Fq '.onTapGesture { session.openInboxMessage(message) }' generated/macos/Sources/App/App.swift
  grep -Fq '.help("Show this message in Mail")' generated/macos/Sources/App/App.swift
  grep -Fq 'Image(systemName: "bubble.left.and.bubble.right")' generated/macos/Sources/App/App.swift
  ! grep -Fq 'Text("\(message.contact_name) - \(friendlyTime(message.received_at))")' generated/macos/Sources/App/App.swift
  ! awk '
    /private struct InboxStackCard/ { in_view = 1 }
    /private struct TimelineView/ { in_view = 0 }
    in_view && /openTimeline[(]for: message[)]/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' generated/macos/Sources/App/App.swift
}

swift_message_surfaces_use_colored_backgrounds() {
  cd "$repo_dir"
  grep -Fq 'private struct MessageSurfaceBackground: View' generated/macos/Sources/App/App.swift
  grep -Fq 'private var cardBackground: some View' generated/macos/Sources/App/App.swift
  grep -Fq 'tintOpacity: isSelected ? 0.082 : 0.050' generated/macos/Sources/App/App.swift
  grep -Fq 'RoundedRectangle(cornerRadius: 14, style: .continuous)' generated/macos/Sources/App/App.swift
  grep -Fq 'private var messageTint: Color' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct TelegramBubbleShape: Shape' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct MessageDetailsView: View' generated/macos/Sources/App/App.swift
  grep -Fq 'import AVKit' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct AttachmentPreview: View' generated/macos/Sources/App/App.swift
  grep -Fq 'Image(nsImage: image)' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct InlineVideoAttachmentView: View' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct InlineAudioAttachmentView: View' generated/macos/Sources/App/App.swift
  grep -Fq '.frame(width: 360, height: 58)' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct NativeVideoPlayerView: NSViewRepresentable' generated/macos/Sources/App/App.swift
  grep -Fq 'func makeNSView(context: Context) -> AVPlayerView' generated/macos/Sources/App/App.swift
  grep -Fq 'view.player = AVPlayer(url: url)' generated/macos/Sources/App/App.swift
  grep -Fq '.linkedFramework("AVKit")' generated/macos/Package.swift
  grep -Fq 'private struct ExternalAttachmentOpenIconButton: View' generated/macos/Sources/App/App.swift
  grep -Fq 'Image(systemName: "arrow.up.forward.square")' generated/macos/Sources/App/App.swift
  grep -Fq '.help("Open attachment externally")' generated/macos/Sources/App/App.swift
  grep -Fq 'NSWorkspace.shared.open(url)' generated/macos/Sources/App/App.swift
  grep -Fq 'Image(systemName: attachment.isAudio ? "waveform.circle.fill" : "doc")' generated/macos/Sources/App/App.swift
  grep -Fq 'Image(systemName: attachment.isImage ? "photo" : (attachment.isVideo ? "film" : (attachment.isAudio ? "waveform" : "doc")))' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct InboxSplitPill: View' generated/macos/Sources/App/App.swift
  grep -Fq 'InboxSplitPill(message: message)' generated/macos/Sources/App/App.swift
  grep -Fq 'Image(systemName: "tray.full")' generated/macos/Sources/App/App.swift
  grep -Fq 'Image(systemName: "xmark")' generated/macos/Sources/App/App.swift
  grep -Fq 'session.openInbox(focusing: message.id)' generated/macos/Sources/App/App.swift
  grep -Fq 'session.archive(message)' generated/macos/Sources/App/App.swift
  grep -Fq 'Image(systemName: "ellipsis.vertical")' generated/macos/Sources/App/App.swift
  grep -Fq 'Button { showingDetails = true } label:' generated/macos/Sources/App/App.swift
  grep -Fq 'Label("Details", systemImage: "info.circle")' generated/macos/Sources/App/App.swift
  grep -Fq '.fill(messageFill)' generated/macos/Sources/App/App.swift
  grep -Fq 'tintOpacity: 0.090' generated/macos/Sources/App/App.swift
  ! grep -Fq 'edgeOpacity:' generated/macos/Sources/App/App.swift
  ! grep -Fq 'edgeWidth:' generated/macos/Sources/App/App.swift
  ! awk '
    /private struct CardStackFrame/ { in_view = 1 }
    /private struct NewSendersView/ { in_view = 0 }
    in_view && /[.]stroke[(]/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' generated/macos/Sources/App/App.swift
  ! awk '
    /private struct MessageBubble/ { in_view = 1 }
    /private struct MessageContextMenu/ { in_view = 0 }
    in_view && /[.]stroke[(]/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' generated/macos/Sources/App/App.swift
  ! awk '
    /private struct MessageBubble/ { in_view = 1 }
    /private struct TelegramBubbleShape/ { in_view = 0 }
    in_view && /Text[(]"Inbox"[)]|TransportPill[(]message: message[)]|Label[(]message[.]read [?] "Mark Unread"/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' generated/macos/Sources/App/App.swift
  ! grep -Fq 'Remove From Inbox' generated/macos/Sources/App/App.swift
  grep -Fq 'actionItem("Archive", action: "archive_selected"' generated/macos/Sources/App/App.swift
  grep -Fq 'Image(systemName: "archivebox")' generated/macos/Sources/App/App.swift
  grep -Fq '.help("Archive")' generated/macos/Sources/App/App.swift
  grep -Fq 'Label(message.read ? "Mark Unread" : "Mark Read", systemImage: message.read ? "envelope.badge" : "envelope.open")' generated/macos/Sources/App/App.swift
}

swift_chat_bubble_colors_are_preferences() {
  cd "$repo_dir"
  grep -Fq 'private enum BubbleColors' generated/macos/Sources/App/App.swift
  grep -Fq 'private enum LLMCategoryColors' generated/macos/Sources/App/App.swift
  grep -Fq 'case "high-risk":' generated/macos/Sources/App/App.swift
  grep -Fq 'case "likely-spam":' generated/macos/Sources/App/App.swift
  grep -Fq 'case "uncertain":' generated/macos/Sources/App/App.swift
  grep -Fq 'case "likely-legit":' generated/macos/Sources/App/App.swift
  grep -Fq 'static let defaultSelfSimpleXHex = "#DDF4E3"' generated/macos/Sources/App/App.swift
  grep -Fq 'static let defaultSelfEmailHex = "#F7DADA"' generated/macos/Sources/App/App.swift
  grep -Fq 'static let defaultOtherSimpleXHex = "#EDF7F0"' generated/macos/Sources/App/App.swift
  grep -Fq 'static let defaultOtherEmailHex = "#F5ECEC"' generated/macos/Sources/App/App.swift
  grep -Fq '@Published var bubbleSelfSimpleXColor: Color = BubbleColors.defaultSelfSimpleX' generated/macos/Sources/App/App.swift
  grep -Fq 'func persistBubbleColors()' generated/macos/Sources/App/App.swift
  grep -Fq 'func resetBubbleColors()' generated/macos/Sources/App/App.swift
  grep -Fq 'func bubbleFill(for message: MessageItem) -> Color' generated/macos/Sources/App/App.swift
  grep -Fq 'var llmDetectedCategory: String?' generated/macos/Sources/App/App.swift
  grep -Fq 'if let category = message.llmDetectedCategory {' generated/macos/Sources/App/App.swift
  grep -Fq 'return LLMCategoryColors.bubbleFill(for: category)' generated/macos/Sources/App/App.swift
  grep -Fq 'return bubbleSelfSimpleXColor' generated/macos/Sources/App/App.swift
  grep -Fq 'return bubbleSelfEmailColor' generated/macos/Sources/App/App.swift
  grep -Fq 'return bubbleOtherSimpleXColor' generated/macos/Sources/App/App.swift
  grep -Fq 'return bubbleOtherEmailColor' generated/macos/Sources/App/App.swift
  grep -Fq 'Section("Chat Bubbles")' generated/macos/Sources/App/App.swift
  grep -Fq 'ColorPicker(title, selection: $color, supportsOpacity: false)' generated/macos/Sources/App/App.swift
  grep -Fq 'set: { session.bubbleSelfSimpleXColor = $0; session.persistBubbleColors() }' generated/macos/Sources/App/App.swift
  grep -Fq 'session.bubbleFill(for: message)' generated/macos/Sources/App/App.swift
  grep -Fq 'llm_spam_category: (($m.llm_spam_category // "") | tostring)' scripts/owl-backend.sh
  grep -Fq 'llm_spam_source: (($m.llm_spam_source // "") | tostring)' scripts/owl-backend.sh
  grep -Fq 'bubble_self_simplex)' scripts/owl-backend.sh
  grep -Fq 'bubble_self_simplex:$bubble_self_simplex' scripts/owl-backend.sh
  grep -Fq 'mark_read_when_seen)' scripts/owl-backend.sh
  grep -Fq 'mark_earlier_seen)' scripts/owl-backend.sh
  grep -Fq 'mark_read_when_seen:$mark_read_when_seen' scripts/owl-backend.sh
  grep -Fq 'mark_earlier_seen:$mark_earlier_seen' scripts/owl-backend.sh
  grep -Fq 'mail_root|selected_route|bubble_self_simplex|bubble_self_email|bubble_other_simplex|bubble_other_email|mark_read_when_seen|mark_earlier_seen|show_temporal_distance|detect_temporal_distance)' scripts/owl-backend.sh
  grep -Fq '@Published var markMessagesReadWhenSeen: Bool = true' generated/macos/Sources/App/App.swift
  grep -Fq '@Published var markEarlierMessagesSeen: Bool = true' generated/macos/Sources/App/App.swift
  grep -Fq 'Toggle("Mark messages read when seen"' generated/macos/Sources/App/App.swift
  grep -Fq 'Toggle("Mark all earlier messages seen"' generated/macos/Sources/App/App.swift
  grep -Fq '.disabled(!session.markMessagesReadWhenSeen)' generated/macos/Sources/App/App.swift
  grep -Fq 'func persistSeenPreferences()' generated/macos/Sources/App/App.swift
  grep -Fq 'show_temporal_distance)' scripts/owl-backend.sh
  grep -Fq 'detect_temporal_distance)' scripts/owl-backend.sh
  grep -Fq 'show_temporal_distance:$show_temporal_distance' scripts/owl-backend.sh
  grep -Fq 'detect_temporal_distance:$detect_temporal_distance' scripts/owl-backend.sh
  grep -Fq '@Published var showTemporalDistance: Bool = true' generated/macos/Sources/App/App.swift
  grep -Fq '@Published var detectTemporalDistanceAutomatically: Bool = true' generated/macos/Sources/App/App.swift
  grep -Fq 'Toggle("Show temporal distance"' generated/macos/Sources/App/App.swift
  grep -Fq 'Toggle("Detect temporal distance automatically"' generated/macos/Sources/App/App.swift
  grep -Fq 'func persistTemporalDistancePreferences()' generated/macos/Sources/App/App.swift
}

swift_temporal_distance_ui_exists() {
  cd "$repo_dir"
  grep -Fq 'set-temporal-distance ROOT THREAD_ID SECONDS|auto' scripts/owl-backend.sh
  grep -Fq 'set_temporal_distance_action()' scripts/owl-backend.sh
  grep -Fq 'temporal_distance_seconds:(if $temporal_distance_seconds == "" then null else ($temporal_distance_seconds | tonumber? // null) end)' scripts/owl-backend.sh
  grep -Fq 'temporal_distance_seconds: ($contact.temporal_distance_seconds // null)' scripts/owl-backend.sh
  grep -Fq 'temporal_distance_seconds: (.temporal_distance_seconds // null)' scripts/owl-backend.sh
  grep -Fq 'private enum TemporalDistance' generated/macos/Sources/App/App.swift
  grep -Fq 'func automaticTemporalDistance(for thread: ThreadItem) -> Int?' generated/macos/Sources/App/App.swift
  grep -Fq 'thread.temporal_distance_seconds ?? automaticTemporalDistance(for: thread)' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct TemporalDistanceBadge: View' generated/macos/Sources/App/App.swift
  grep -Fq 'SidebarThreadRow(thread: thread, showsTemporalDistance: true)' generated/macos/Sources/App/App.swift
  grep -Fq 'if showsTemporalDistance, session.showTemporalDistance' generated/macos/Sources/App/App.swift
  grep -Fq 'Image(systemName: thread.temporal_distance_seconds == nil ? "clock" : "clock.badge.checkmark")' generated/macos/Sources/App/App.swift
  grep -Fq 'Text(TemporalDistance.label(seconds))' generated/macos/Sources/App/App.swift
  grep -Fq 'func increaseTemporalDistance(for thread: ThreadItem)' generated/macos/Sources/App/App.swift
  grep -Fq 'func decreaseTemporalDistance(for thread: ThreadItem)' generated/macos/Sources/App/App.swift
  grep -Fq 'Button { session.setTemporalDistance(for: thread, seconds: nil) } label:' generated/macos/Sources/App/App.swift
}

swift_new_sender_actions_skip_full_refresh() {
  cd "$repo_dir"
  grep -Fq 'func applySenderMove(sender: String, to list: String)' generated/macos/Sources/App/App.swift
  grep -Fq 'runMessageAction(status: "Moved sender to \(list)", refreshAfter: false)' generated/macos/Sources/App/App.swift
  grep -Fq 'self.applySenderMove(sender: sender, to: list)' generated/macos/Sources/App/App.swift
  grep -Fq 'if refreshAfter {' generated/macos/Sources/App/App.swift
  ! awk '
    /func moveSelectedNewSender/ { in_view = 1 }
    /func applySenderMove/ { in_view = 0 }
    in_view && /self[.]refresh[(][)]|refresh[(][)]/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' generated/macos/Sources/App/App.swift
}

native_ui_has_no_manual_refresh_controls() {
  cd "$repo_dir"
  grep -Fq 'func applicationDidBecomeActive' generated/macos/Sources/App/App.swift
  grep -Fq 'session.refreshIfStale()' generated/macos/Sources/App/App.swift
  grep -Fq 'session.refreshIfStale(force: true)' generated/macos/Sources/App/App.swift
  grep -Fq 'func windowDidBecomeKey' generated/macos/Sources/App/App.swift
  grep -Fq 'func refreshIfStale(force: Bool = false)' generated/macos/Sources/App/App.swift
  ! grep -Fq 'refresh_snapshot' generated/macos/Sources/App/App.swift generated/linux/src/main.c app-blueprint/app.ir.yaml
  ! grep -Fq 'toolbar.refresh' generated/macos/Sources/App/App.swift generated/linux/src/main.c app-blueprint/app.ir.yaml
  ! grep -Fq 'menuitem.refresh' generated/macos/Sources/App/App.swift generated/linux/src/main.c app-blueprint/app.ir.yaml
  ! grep -Fq 'Label("Refresh"' generated/macos/Sources/App/App.swift
  ! grep -Fq 'view-refresh-symbolic' generated/linux/src/main.c
}

swift_uses_toasts_not_status_bar() {
  cd "$repo_dir"
  grep -Fq 'private struct ToastOverlay' generated/macos/Sources/App/App.swift
  grep -Fq '@Published var toastMessage: String' generated/macos/Sources/App/App.swift
  grep -Fq 'func showStatus(_ message: String, busy: Bool = false, isError: Bool = false)' generated/macos/Sources/App/App.swift
  grep -Fq '.background(.thinMaterial, in: Capsule())' generated/macos/Sources/App/App.swift
  grep -Fq '.transition(.move(edge: .top).combined(with: .opacity))' generated/macos/Sources/App/App.swift
  ! grep -Fq 'showToast(statusText, busy: isBusy)' generated/macos/Sources/App/App.swift
  ! grep -Fq 'statusText = "Syncing ' generated/macos/Sources/App/App.swift
  ! grep -Fq 'private struct StatusStrip' generated/macos/Sources/App/App.swift
  ! grep -Fq 'StatusStrip()' generated/macos/Sources/App/App.swift
  ! grep -Fq 'v\\(generatedAppVersion)' generated/macos/Sources/App/App.swift
  ! grep -Fq '"type": "StatusBar"' generated/macos/Sources/App/App.swift generated/linux/src/main.c app-blueprint/app.ir.yaml
}

swift_refresh_is_quiet_and_incremental() {
  cd "$repo_dir"
  grep -Fq '@Published var isRefreshingSnapshot: Bool = false' generated/macos/Sources/App/App.swift
  grep -Fq '@Published var isTickingTransport: Bool = false' generated/macos/Sources/App/App.swift
  grep -Fq 'func refresh()' generated/macos/Sources/App/App.swift
  grep -Fq 'func tickTransportIfStale(force: Bool = false, notify: Bool = false)' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct SimpleXTickResponse: Decodable, Sendable' generated/macos/Sources/App/App.swift
  grep -Fq 'var changedLocalState: Bool' generated/macos/Sources/App/App.swift
  grep -Fq 'let response = try await OwlBackend.tickSimpleX(root: root)' generated/macos/Sources/App/App.swift
  grep -Fq 'if response.changedLocalState {' generated/macos/Sources/App/App.swift
  grep -Fq 'static func tickSimpleX(root: String) async throws -> SimpleXTickResponse' generated/macos/Sources/App/App.swift
  ! grep -Fq 'showToast("Loaded ' generated/macos/Sources/App/App.swift
  ! grep -Fq 'refresh(silent:' generated/macos/Sources/App/App.swift
  ! grep -Fq 'refresh(tickTransport:' generated/macos/Sources/App/App.swift
  grep -Fq 'applyArchived(messageID: message.id)' generated/macos/Sources/App/App.swift
  grep -Fq 'applyDeleted(messageID: message.id)' generated/macos/Sources/App/App.swift
  grep -Fq 'applyMessageUpdate(id: message.id)' generated/macos/Sources/App/App.swift
  ! awk '
    /func refresh[(][)]/ { in_view = 1 }
    /func refreshIfStale/ { in_view = 0 }
    in_view && /OwlBackend[.]tickSimpleX/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' generated/macos/Sources/App/App.swift
  ! awk '
    /func tickTransportIfStale/ { in_view = 1 }
    /func refreshBootstrapStatus/ { in_view = 0 }
    in_view && /self[.]refresh[(][)]/ && !seen_condition { found = 1 }
    in_view && /if response[.]changedLocalState/ { seen_condition = 1 }
    END { exit found ? 0 : 1 }
  ' generated/macos/Sources/App/App.swift
}

swift_remote_server_setup_walkthrough_exists() {
  cd "$repo_dir"
  grep -Fq 'private struct RemoteAuthSettings: Decodable, Sendable' generated/macos/Sources/App/App.swift
  grep -Fq 'var remote_auth: RemoteAuthSettings' generated/macos/Sources/App/App.swift
  grep -Fq '@Published var remoteKeyHasPassword: Bool = false' generated/macos/Sources/App/App.swift
  grep -Fq '@Published var remoteKeyPasswordDraft: String = ""' generated/macos/Sources/App/App.swift
  grep -Fq 'var remotePasswordAvailable: Bool' generated/macos/Sources/App/App.swift
  grep -Fq 'func saveRemoteAuth()' generated/macos/Sources/App/App.swift
  grep -Fq 'func deployRemoteServer()' generated/macos/Sources/App/App.swift
  grep -Fq 'func sendRemoteTestEmail()' generated/macos/Sources/App/App.swift
  grep -Fq 'func setupTLSForCurrentServer()' generated/macos/Sources/App/App.swift
  grep -Fq 'OwlBackend.runJSON(action: "settings-remote-set-auth", root: root, args: self.remoteAuthArgs())' generated/macos/Sources/App/App.swift
  grep -Fq 'action: "settings-remote-deploy"' generated/macos/Sources/App/App.swift
  grep -Fq 'action: "settings-remote-send-test"' generated/macos/Sources/App/App.swift
  grep -Fq 'actionArgs: ["remote"] + remoteWorkflowArgs()' generated/macos/Sources/App/App.swift
  grep -Fq 'private func remoteWorkflowArgs() -> [String]' generated/macos/Sources/App/App.swift
  grep -Fq 'OwlBackend.runJSON(action: "settings-ssl-wizard-status", root: root, args: [mode, remoteHint])' generated/macos/Sources/App/App.swift
  grep -Fq 'runBackendAction("settings-setup-ssl", args: ["local"], status: "TLS setup finished")' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct TLSWizardStatus: Decodable, Sendable' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct TLSDNSRecord: Decodable, Identifiable, Sendable' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct TLSSetupWalkthroughView: View' generated/macos/Sources/App/App.swift
  grep -Fq '@Published var tlsWizardIPMode: String = "stable"' generated/macos/Sources/App/App.swift
  grep -Fq 'var tlsWizardDNSReady: Bool' generated/macos/Sources/App/App.swift
  grep -Fq 'func refreshTLSWizardStatus()' generated/macos/Sources/App/App.swift
  grep -Fq 'title: "Configure DNS Records"' generated/macos/Sources/App/App.swift
  grep -Fq 'Text("Dynamic IP (DDNS)").tag("dynamic")' generated/macos/Sources/App/App.swift
  grep -Fq 'Label(session.isRefreshingTLSWizard ? "Checking DNS" : "Refresh Checks", systemImage: "arrow.clockwise")' generated/macos/Sources/App/App.swift
  grep -Fq 'title: "Prepare TLS Tooling"' generated/macos/Sources/App/App.swift
  grep -Fq 'title: "Run TLS Setup"' generated/macos/Sources/App/App.swift
  grep -Fq 'MX target must be a hostname' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct RemoteServerWalkthroughView: View' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct RemoteSetupStep<Content: View>: View' generated/macos/Sources/App/App.swift
  grep -Fq 'private struct RemoteStatusPill: View' generated/macos/Sources/App/App.swift
  grep -Fq 'Section("Remote Mail Server")' generated/macos/Sources/App/App.swift
  grep -Fq 'RemoteSetupStep(' generated/macos/Sources/App/App.swift
  grep -Fq 'title: "SSH Target"' generated/macos/Sources/App/App.swift
  grep -Fq 'title: "SSH Authentication"' generated/macos/Sources/App/App.swift
  grep -Fq 'title: "Deploy And Verify"' generated/macos/Sources/App/App.swift
  grep -Fq 'title: "Test And Sync"' generated/macos/Sources/App/App.swift
  grep -Fq 'Toggle("SSH key has password"' generated/macos/Sources/App/App.swift
  grep -Fq 'SecureField("SSH key password", text: $session.remoteKeyPasswordDraft)' generated/macos/Sources/App/App.swift
  grep -Fq 'Save securely on this \(session.snapshot.settings.remote_auth.secrets_device_label)' generated/macos/Sources/App/App.swift
  grep -Fq 'Label("Deploy Remote Server", systemImage: "shippingbox.and.arrow.backward")' generated/macos/Sources/App/App.swift
  grep -Fq 'Label("Verify Remote Setup", systemImage: "network")' generated/macos/Sources/App/App.swift
  grep -Fq 'Label("Check Remote Mail", systemImage: "arrow.triangle.2.circlepath")' generated/macos/Sources/App/App.swift
  grep -Fq 'Label("Send Test Email", systemImage: "paperplane")' generated/macos/Sources/App/App.swift
  grep -Fq 'Text(session.remoteStatusSummary)' generated/macos/Sources/App/App.swift
  grep -Fq 'settings-remote-deploy)' scripts/owl-backend.sh
  grep -Fq 'OWL_MAIL_LIST_TIMEOUT_SECONDS:-15' scripts/owl-backend.sh
  grep -Fq 'OWL_REMOTE_DEPLOY_TIMEOUT_SECONDS:-1800' scripts/owl-backend.sh
  grep -Fq 'OWL_REMOTE_TLS_TIMEOUT_SECONDS:-900' scripts/owl-backend.sh
  grep -Fq '../owl-nonnative/scripts/owl-desktop-backend.sh' scripts/owl-backend.sh
  grep -Fq 'git/owl-nonnative/scripts/owl-desktop-backend.sh' scripts/owl-backend.sh
  ! grep -Fq 'Section("Remote") {' generated/macos/Sources/App/App.swift
}

linux_uses_native_gtk_and_argv_backend() {
  cd "$repo_dir"
  grep -q 'gtk_header_bar_new' generated/linux/src/main.c
  grep -q 'gtk_search_entry_new' generated/linux/src/main.c
  grep -q 'gtk_list_box_new' generated/linux/src/main.c
  grep -q 'gtk_text_view_new' generated/linux/src/main.c
  grep -q 'g_spawn_sync' generated/linux/src/main.c
  grep -q 'g_ptr_array_add(argv, (char *)"/bin/sh");' generated/linux/src/main.c
  grep -q 'g_ptr_array_add(argv, script_path);' generated/linux/src/main.c
  grep -q 'run_backend(context, "snapshot-lines", NULL, NULL)' generated/linux/src/main.c
  grep -q 'populate_snapshot_lines' generated/linux/src/main.c
  grep -q 'context->mailbox_list = gtk_list_box_new' generated/linux/src/main.c
  ! grep -q '/bin/sh -c' generated/linux/src/main.c
}

secure_chat_hook_has_offline_timeout() {
  cd "$repo_dir"
  grep -Fq 'ssh_transport()' scripts/owl-secure-chat-hook.sh
  grep -Fq 'timeout_seconds=${OWL_TRANSPORT_TIMEOUT:-4}' scripts/owl-secure-chat-hook.sh
  grep -Fq -- '-o BatchMode=yes' scripts/owl-secure-chat-hook.sh
  grep -Fq -- '-o ConnectTimeout="$timeout_seconds"' scripts/owl-secure-chat-hook.sh
  grep -Fq -- '-o ServerAliveCountMax=1' scripts/owl-secure-chat-hook.sh
  ! grep -Fq 'response=$(ssh "$ssh_host"' scripts/owl-secure-chat-hook.sh
}

run_case "render is deterministic" render_is_deterministic
run_case "generated sources have no template tokens" generated_sources_have_no_template_tokens
run_case "Swift actions cover IR" swift_actions_cover_ir
run_case "Linux actions cover IR" linux_actions_cover_ir
run_case "Swift uses native desktop idiom" swift_uses_native_desktop_idiom
run_case "Swift has unified SimpleX/email UI" swift_unified_simplex_email_ui_exists
run_case "Swift compose accepts file drops" swift_compose_accepts_file_drops
run_case "Swift New Senders and Inbox use card-stack layout" swift_new_and_inbox_use_card_stack_layout
run_case "Swift Mail favorites move between sections" swift_mail_favorites_move_between_sections
run_case "Swift cards have horizontal flick actions" swift_cards_have_horizontal_flick_actions
run_case "Swift message cards are drag droppable" swift_message_cards_are_drag_droppable
run_case "Swift message timestamps are friendly" swift_message_timestamps_are_friendly
run_case "Swift Mail timelines restore scroll position" swift_mail_timelines_restore_scroll_position
run_case "Swift Inbox cards open reader before Mail" swift_inbox_cards_open_reader_before_mail
run_case "Swift message surfaces use colored backgrounds" swift_message_surfaces_use_colored_backgrounds
run_case "Swift chat bubble colors are preferences" swift_chat_bubble_colors_are_preferences
run_case "Swift temporal distance UI exists" swift_temporal_distance_ui_exists
run_case "Swift new sender actions skip full refresh" swift_new_sender_actions_skip_full_refresh
run_case "Native UI has no manual refresh controls" native_ui_has_no_manual_refresh_controls
run_case "Swift uses toasts not status bar" swift_uses_toasts_not_status_bar
run_case "Swift refresh is quiet and incremental" swift_refresh_is_quiet_and_incremental
run_case "Swift remote server setup walkthrough exists" swift_remote_server_setup_walkthrough_exists
run_case "Linux uses GTK native backend bridge" linux_uses_native_gtk_and_argv_backend
run_case "Secure Chat hook has offline timeout" secure_chat_hook_has_offline_timeout

if [ "$failures" -ne 0 ]; then
  printf '%s\n' "$failures test(s) failed" >&2
  exit 1
fi

printf '%s\n' "23/23 native render tests passed"
