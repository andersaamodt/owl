// Generated from app-blueprint/app.ir.yaml. Regenerate with scripts/render-native-desktop.sh.
import AppKit
import AVKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

private let canonicalIR = #"""
{
  "version": "native-desktop-ir/v1",
  "format": "yaml-1.2-json-compatible",
  "app": {
    "id": "stellar",
    "name": "Stellar",
    "targets": [
      "macos",
      "linux"
    ],
    "actions": [
      {
        "id": "focus_new",
        "title": "New Senders"
      },
      {
        "id": "focus_inbox",
        "title": "Inbox"
      },
      {
        "id": "focus_mail",
        "title": "Mail"
      },
      {
        "id": "focus_archive",
        "title": "Archive"
      },
      {
        "id": "focus_favorites",
        "title": "Favorites"
      },
      {
        "id": "focus_people",
        "title": "People"
      },
      {
        "id": "focus_groups",
        "title": "Groups"
      },
      {
        "id": "send_message",
        "title": "Send Message"
      },
      {
        "id": "archive_message",
        "title": "Remove From Inbox"
      },
      {
        "id": "delete_message",
        "title": "Delete"
      },
      {
        "id": "toggle_star",
        "title": "Star"
      },
      {
        "id": "mark_read",
        "title": "Mark Read"
      },
      {
        "id": "open_settings",
        "title": "Settings"
      },
      {
        "id": "choose_mail_root",
        "title": "Choose Mail Root"
      },
      {
        "id": "install_simplex_cli",
        "title": "Install SimpleX CLI"
      },
      {
        "id": "provision_simplex_identity",
        "title": "Provision SimpleX Identity"
      },
      {
        "id": "configure_simplex_local_transport",
        "title": "Enable Local SimpleX Transport"
      },
      {
        "id": "tick_simplex",
        "title": "Check SimpleX"
      },
      {
        "id": "bind_contact",
        "title": "Bind Contact"
      },
      {
        "id": "compose_simplex",
        "title": "Use SimpleX"
      },
      {
        "id": "compose_email",
        "title": "Use Email"
      },
      {
        "id": "quit_app",
        "title": "Quit"
      }
    ],
    "state": {
      "mailRoot": "~/mail",
      "selectedRoute": "inbox",
      "selectedTransport": "simplex"
    },
    "window": {
      "id": "window.main",
      "name": "mainWindow",
      "type": "Window",
      "title": "Stellar",
      "width": 128,
      "minWidth": 96,
      "height": 82,
      "minHeight": 58,
      "menuBar": {
        "id": "menubar.main",
        "type": "MenuBar",
        "children": [
          {
            "id": "menu.app",
            "type": "Menu",
            "title": "Stellar",
            "children": [
              {
                "id": "menuitem.settings",
                "type": "MenuItem",
                "title": "Settings",
                "action": "open_settings",
                "shortcut": "cmd+,"
              },
              {
                "id": "menuitem.quit",
                "type": "MenuItem",
                "title": "Quit",
                "action": "quit_app",
                "shortcut": "cmd+q"
              }
            ]
          },
          {
            "id": "menu.view",
            "type": "Menu",
            "title": "View",
            "children": [
              {
                "id": "menuitem.inbox",
                "type": "MenuItem",
                "title": "Inbox",
                "action": "focus_inbox",
                "shortcut": "cmd+1"
              },
              {
                "id": "menuitem.favorites",
                "type": "MenuItem",
                "title": "Favorites",
                "action": "focus_favorites",
                "shortcut": "cmd+2"
              },
              {
                "id": "menuitem.people",
                "type": "MenuItem",
                "title": "People",
                "action": "focus_people",
                "shortcut": "cmd+3"
              },
              {
                "id": "menuitem.groups",
                "type": "MenuItem",
                "title": "Groups",
                "action": "focus_groups",
                "shortcut": "cmd+4"
              }
            ]
          },
          {
            "id": "menu.transport",
            "type": "Menu",
            "title": "Transport",
            "children": [
              {
                "id": "menuitem.simplex",
                "type": "MenuItem",
                "title": "Compose With SimpleX",
                "action": "compose_simplex"
              },
              {
                "id": "menuitem.email",
                "type": "MenuItem",
                "title": "Compose With Email",
                "action": "compose_email"
              },
              {
                "id": "menuitem.tickSimplex",
                "type": "MenuItem",
                "title": "Check SimpleX",
                "action": "tick_simplex"
              }
            ]
          }
        ]
      },
      "toolbar": {
        "id": "toolbar.main",
        "type": "Toolbar",
        "children": [
          {
            "id": "toolbar.inbox",
            "type": "Button",
            "title": "Inbox",
            "action": "focus_inbox"
          },
          {
            "id": "toolbar.spacer",
            "type": "Spacer"
          },
          {
            "id": "toolbar.simplex",
            "type": "Button",
            "title": "Check SimpleX",
            "action": "tick_simplex"
          },
          {
            "id": "toolbar.settings",
            "type": "Button",
            "title": "Settings",
            "action": "open_settings"
          }
        ]
      },
      "content": {
        "id": "content.main",
        "type": "Content",
        "child": {
          "id": "split.messenger",
          "type": "Split",
          "children": [
            {
              "id": "sidebar.contacts",
              "type": "Sidebar",
              "children": [
                {
                  "id": "list.inbox",
                  "type": "List",
                  "title": "Inbox",
                  "action": "focus_inbox"
                },
                {
                  "id": "list.favorites",
                  "type": "List",
                  "title": "Favorites",
                  "action": "focus_favorites"
                },
                {
                  "id": "list.people",
                  "type": "List",
                  "title": "People",
                  "action": "focus_people"
                },
                {
                  "id": "list.groups",
                  "type": "List",
                  "title": "Groups",
                  "action": "focus_groups"
                }
              ]
            },
            {
              "id": "detail.timeline",
              "type": "Detail",
              "children": [
                {
                  "id": "section.timeline",
                  "type": "Section",
                  "title": "Timeline"
                },
                {
                  "id": "form.compose",
                  "type": "Form",
                  "title": "Compose"
                },
                {
                  "id": "select.transport",
                  "type": "Select",
                  "title": "Transport",
                  "action": "compose_simplex"
                },
                {
                  "id": "button.send",
                  "type": "Button",
                  "title": "Send",
                  "action": "send_message"
                }
              ]
            }
          ]
        }
      }
    },
    "mock": {
      "contacts": [
        {
          "id": "alice-ledger",
          "kind": "person",
          "name": "Alice Ledger",
          "email": "alice@example.org",
          "simplex_address": "simplex://alice-ledger",
          "favorite": true
        },
        {
          "id": "river-stone",
          "kind": "group",
          "name": "River Stone",
          "email": "",
          "simplex_address": "simplex://river-stone",
          "favorite": true
        }
      ],
      "messages": [
        {
          "id": "seed-email-1",
          "thread_id": "alice-ledger",
          "transport": "email",
          "lock": "open",
          "subject": "Longer email-style note",
          "body": "This is a longer email-shaped message rendered in the same continuous contact timeline as short chat messages.",
          "received_at": "2026-04-20T10:00:00Z",
          "in_inbox": true,
          "from_self": false
        },
        {
          "id": "seed-simplex-1",
          "thread_id": "alice-ledger",
          "transport": "simplex",
          "lock": "closed",
          "subject": "",
          "body": "Short secure reply.",
          "received_at": "2026-04-20T10:03:00Z",
          "in_inbox": false,
          "from_self": true
        }
      ]
    }
  },
  "extensions": []
}
"""#

private let generatedAppName = "Stellar"
private let generatedAppMenuTitle = "Stellar"
private let generatedAppID = "stellar"
private let generatedAppVersion = "0.1.0"
private let messageDragPayloadPrefix = "stellar-message:"
private let senderDragPayloadPrefix = "stellar-sender:"

private final class NonDraggableHostingView<Content: View>: NSHostingView<Content> {
  override var mouseDownCanMoveWindow: Bool { false }
}

@main
private enum StellarGeneratedApp {
  @MainActor private static var appDelegate: StellarAppDelegate?

  @MainActor
  static func main() {
    let app = NSApplication.shared
    let delegate = StellarAppDelegate()
    appDelegate = delegate
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
  }
}

@MainActor
private final class StellarAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  private let session = StellarSession()
  private var window: NSWindow?
  private var settingsWindow: NSWindow?
  private var titlebarTabsController: NSHostingController<AnyView>?
  private var titlebarTabsAccessory: NSTitlebarAccessoryViewController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.mainMenu = makeMainMenu()
    showMainWindow()
    activateApplication()
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    session.noteApplicationFocused()
    session.refreshIfStale()
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    showMainWindow()
    session.refreshIfStale(force: true)
    return true
  }

  private func showMainWindow() {
    if let window {
      window.makeKeyAndOrderFront(nil)
      activateApplication()
      session.refreshIfStale()
      return
    }

    let rootView = RootView()
      .environmentObject(session)
      .frame(minWidth: 920, minHeight: 620)
    let hostingView = NSHostingView(rootView: rootView)
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Stellar"
    window.titleVisibility = .hidden
    window.contentView = hostingView
    window.isReleasedWhenClosed = false
    window.delegate = self
    installTitlebarTabs(in: window)
    window.center()
    window.makeKeyAndOrderFront(nil)
    self.window = window
  }

  func windowDidBecomeKey(_ notification: Notification) {
    session.noteApplicationFocused()
    session.refreshIfStale()
  }

  private func installTitlebarTabs(in window: NSWindow) {
    let tabsView = PrimaryTabBar()
      .environmentObject(session)
    let controller = NSHostingController(rootView: AnyView(tabsView))
    controller.view = NonDraggableHostingView(rootView: AnyView(tabsView))
    controller.view.frame = NSRect(x: 0, y: 0, width: 500, height: 34)
    let accessory = NSTitlebarAccessoryViewController()
    accessory.view = controller.view
    accessory.layoutAttribute = .left
    window.addTitlebarAccessoryViewController(accessory)
    titlebarTabsController = controller
    titlebarTabsAccessory = accessory
  }

  @objc func showSettingsWindow(_ sender: Any?) {
    if let settingsWindow {
      settingsWindow.makeKeyAndOrderFront(nil)
      activateApplication()
      return
    }

    let settingsView = SettingsView()
      .environmentObject(session)
      .frame(width: 700, height: 520)
      .padding(20)
    let hostingView = NSHostingView(rootView: settingsView)
    let settingsWindow = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    settingsWindow.title = "Preferences"
    settingsWindow.contentView = hostingView
    settingsWindow.isReleasedWhenClosed = false
    settingsWindow.delegate = self
    settingsWindow.center()
    settingsWindow.makeKeyAndOrderFront(nil)
    self.settingsWindow = settingsWindow
    activateApplication()
  }

  private func makeMainMenu() -> NSMenu {
    let mainMenu = NSMenu()

    let appMenuItem = NSMenuItem()
    appMenuItem.title = generatedAppMenuTitle
    let appMenu = NSMenu(title: generatedAppMenuTitle)
    appMenu.addItem(NSMenuItem(title: "About \(generatedAppMenuTitle)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
    appMenu.addItem(.separator())
    appMenu.addItem(actionItem("Preferences...", action: "open_settings", key: ",", modifiers: [.command]))
    appMenu.addItem(.separator())
    appMenu.addItem(actionItem("Quit \(generatedAppMenuTitle)", action: "quit_app", key: "q", modifiers: [.command]))
    appMenuItem.submenu = appMenu
    mainMenu.addItem(appMenuItem)

    let fileMenuItem = NSMenuItem()
    let fileMenu = NSMenu(title: "File")
    fileMenu.addItem(actionItem("Send Message", action: "send_message", key: "\r", modifiers: [.command]))
    fileMenuItem.submenu = fileMenu
    mainMenu.addItem(fileMenuItem)

    let editMenuItem = NSMenuItem()
    let editMenu = NSMenu(title: "Edit")
    editMenu.addItem(standardItem("Undo", selector: Selector(("undo:")), key: "z"))
    editMenu.addItem(standardItem("Redo", selector: Selector(("redo:")), key: "Z"))
    editMenu.addItem(.separator())
    editMenu.addItem(standardItem("Cut", selector: #selector(NSText.cut(_:)), key: "x"))
    editMenu.addItem(standardItem("Copy", selector: #selector(NSText.copy(_:)), key: "c"))
    editMenu.addItem(standardItem("Paste", selector: #selector(NSText.paste(_:)), key: "v"))
    editMenu.addItem(.separator())
    editMenu.addItem(standardItem("Select All", selector: #selector(NSText.selectAll(_:)), key: "a"))
    editMenuItem.submenu = editMenu
    mainMenu.addItem(editMenuItem)

    let viewMenuItem = NSMenuItem()
    let viewMenu = NSMenu(title: "View")
    viewMenu.addItem(actionItem("New Senders", action: "focus_new", key: "1", modifiers: [.command]))
    viewMenu.addItem(actionItem("Inbox", action: "focus_inbox", key: "2", modifiers: [.command]))
    viewMenu.addItem(actionItem("Mail", action: "focus_mail", key: "3", modifiers: [.command]))
    viewMenu.addItem(actionItem("Archive", action: "focus_archive", key: "4", modifiers: [.command]))
    viewMenuItem.submenu = viewMenu
    mainMenu.addItem(viewMenuItem)

    let messageMenuItem = NSMenuItem()
    let messageMenu = NSMenu(title: "Message")
    messageMenu.addItem(actionItem("Archive", action: "archive_selected", key: "e", modifiers: [.command]))
    messageMenu.addItem(actionItem("Delete", action: "delete_selected", key: "\u{8}", modifiers: []))
    messageMenu.addItem(actionItem("Star", action: "star_selected", key: "l", modifiers: [.command]))
    messageMenu.addItem(.separator())
    messageMenu.addItem(actionItem("Mark Read", action: "mark_selected_read", key: "u", modifiers: [.command, .shift]))
    messageMenu.addItem(actionItem("Mark Unread", action: "mark_selected_unread", key: "u", modifiers: [.command]))
    messageMenuItem.submenu = messageMenu
    mainMenu.addItem(messageMenuItem)

    let transportMenuItem = NSMenuItem()
    let transportMenu = NSMenu(title: "Transport")
    transportMenu.addItem(actionItem("Use SimpleX", action: "compose_simplex"))
    transportMenu.addItem(actionItem("Use Email", action: "compose_email"))
    transportMenu.addItem(.separator())
    transportMenu.addItem(actionItem("Install SimpleX CLI", action: "install_simplex_cli"))
    transportMenu.addItem(actionItem("Provision SimpleX Identity", action: "provision_simplex_identity"))
    transportMenu.addItem(actionItem("Enable Local SimpleX Transport", action: "configure_simplex_local_transport"))
    transportMenu.addItem(actionItem("Check SimpleX", action: "tick_simplex"))
    transportMenuItem.submenu = transportMenu
    mainMenu.addItem(transportMenuItem)

    let windowMenuItem = NSMenuItem()
    let windowMenu = NSMenu(title: "Window")
    windowMenu.addItem(standardItem("Minimize", selector: #selector(NSWindow.miniaturize(_:)), key: "m"))
    windowMenu.addItem(standardItem("Zoom", selector: #selector(NSWindow.performZoom(_:)), key: ""))
    windowMenu.addItem(.separator())
    windowMenu.addItem(NSMenuItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))
    windowMenuItem.submenu = windowMenu
    mainMenu.addItem(windowMenuItem)
    NSApp.windowsMenu = windowMenu

    let helpMenuItem = NSMenuItem()
    let helpMenu = NSMenu(title: "Help")
    helpMenu.addItem(actionItem("Show Events", action: "focus_events"))
    helpMenuItem.submenu = helpMenu
    mainMenu.addItem(helpMenuItem)
    NSApp.helpMenu = helpMenu

    return mainMenu
  }

  private func actionItem(_ title: String, action: String, key: String = "", modifiers: NSEvent.ModifierFlags = []) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: #selector(performMenuAction(_:)), keyEquivalent: key)
    item.target = self
    item.representedObject = action
    item.keyEquivalentModifierMask = modifiers
    return item
  }

  private func standardItem(_ title: String, selector: Selector, key: String, modifiers: NSEvent.ModifierFlags = [.command]) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
    item.keyEquivalentModifierMask = modifiers
    return item
  }

  @objc private func performMenuAction(_ sender: NSMenuItem) {
    if let action = sender.representedObject as? String {
      session.perform(action: action)
    }
  }

  func windowWillClose(_ notification: Notification) {
    guard let closedWindow = notification.object as? NSWindow else { return }
    if closedWindow == settingsWindow {
      settingsWindow = nil
    }
    if closedWindow == window {
      window = nil
    }
  }

  private func activateApplication() {
    NSRunningApplication.current.activate(options: [.activateAllWindows])
  }
}

private enum Transport: String, CaseIterable, Identifiable, Sendable {
  case simplex
  case email

  var id: String { rawValue }
  var label: String { self == .simplex ? "SimpleX" : "Email" }
  var symbol: String { self == .simplex ? "lock.fill" : "lock.open" }
}

private struct Snapshot: Decodable, Sendable {
  var ok: Bool
  var root: String
  var inbox: [MessageItem]
  var favorites: [ThreadItem]
  var individuals: [ThreadItem]
  var groups: [ThreadItem]
  var threads: [ThreadItem]
  var messages: [MessageItem]
  var mailboxes: [MailboxItem]
  var drafts: [DraftItem]
  var events: [EventItem]
  var overview: Overview
  var prefs: UIPrefs
  var settings: SettingsSnapshot
  var simplex: SimpleXSnapshot

  init(
    ok: Bool = true,
    root: String = "~/mail",
    inbox: [MessageItem] = [],
    favorites: [ThreadItem] = [],
    individuals: [ThreadItem] = [],
    groups: [ThreadItem] = [],
    threads: [ThreadItem] = [],
    messages: [MessageItem] = [],
    mailboxes: [MailboxItem] = [],
    drafts: [DraftItem] = [],
    events: [EventItem] = [],
    overview: Overview = Overview(),
    prefs: UIPrefs = UIPrefs(),
    settings: SettingsSnapshot = SettingsSnapshot(),
    simplex: SimpleXSnapshot = SimpleXSnapshot()
  ) {
    self.ok = ok
    self.root = root
    self.inbox = inbox
    self.favorites = favorites
    self.individuals = individuals
    self.groups = groups
    self.threads = threads
    self.messages = messages
    self.mailboxes = mailboxes
    self.drafts = drafts
    self.events = events
    self.overview = overview
    self.prefs = prefs
    self.settings = settings
    self.simplex = simplex
  }

  private enum CodingKeys: String, CodingKey {
    case ok, root, inbox, favorites, individuals, groups, threads, messages, mailboxes, drafts, events, overview, prefs, settings, simplex
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    ok = try values.decodeIfPresent(Bool.self, forKey: .ok) ?? true
    root = try values.decodeIfPresent(String.self, forKey: .root) ?? "~/mail"
    inbox = try values.decodeIfPresent([MessageItem].self, forKey: .inbox) ?? []
    favorites = try values.decodeIfPresent([ThreadItem].self, forKey: .favorites) ?? []
    individuals = try values.decodeIfPresent([ThreadItem].self, forKey: .individuals) ?? []
    groups = try values.decodeIfPresent([ThreadItem].self, forKey: .groups) ?? []
    threads = try values.decodeIfPresent([ThreadItem].self, forKey: .threads) ?? []
    messages = try values.decodeIfPresent([MessageItem].self, forKey: .messages) ?? []
    mailboxes = try values.decodeIfPresent([MailboxItem].self, forKey: .mailboxes) ?? []
    drafts = try values.decodeIfPresent([DraftItem].self, forKey: .drafts) ?? []
    events = try values.decodeIfPresent([EventItem].self, forKey: .events) ?? []
    overview = try values.decodeIfPresent(Overview.self, forKey: .overview) ?? Overview()
    prefs = try values.decodeIfPresent(UIPrefs.self, forKey: .prefs) ?? UIPrefs()
    settings = try values.decodeIfPresent(SettingsSnapshot.self, forKey: .settings) ?? SettingsSnapshot()
    simplex = try values.decodeIfPresent(SimpleXSnapshot.self, forKey: .simplex) ?? SimpleXSnapshot()
  }
}

private struct Overview: Decodable, Sendable {
  var counts: OverviewCounts

  init(counts: OverviewCounts = OverviewCounts()) {
    self.counts = counts
  }

  private enum CodingKeys: String, CodingKey { case counts }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    counts = try values.decodeIfPresent(OverviewCounts.self, forKey: .counts) ?? OverviewCounts()
  }
}

private struct OverviewCounts: Decodable, Sendable {
  var inbox_messages: Int = 0
  var new_messages: Int = 0
  var archive_messages: Int = 0
  var trash_messages: Int = 0
  var drafts: Int = 0
  var sent: Int = 0
}

private struct SettingsSnapshot: Decodable, Sendable {
  var ok: Bool
  var test_recipient: String
  var email_domain: String
  var domain_configured: Bool
  var ssl_ready: Bool
  var folders_ready: Bool
  var daemon: DaemonSettings
  var remote: RemoteSettings
  var remote_auth: RemoteAuthSettings

  init(
    ok: Bool = false,
    test_recipient: String = "",
    email_domain: String = "",
    domain_configured: Bool = false,
    ssl_ready: Bool = false,
    folders_ready: Bool = false,
    daemon: DaemonSettings = DaemonSettings(),
    remote: RemoteSettings = RemoteSettings(),
    remote_auth: RemoteAuthSettings = RemoteAuthSettings()
  ) {
    self.ok = ok
    self.test_recipient = test_recipient
    self.email_domain = email_domain
    self.domain_configured = domain_configured
    self.ssl_ready = ssl_ready
    self.folders_ready = folders_ready
    self.daemon = daemon
    self.remote = remote
    self.remote_auth = remote_auth
  }

  private enum CodingKeys: String, CodingKey {
    case ok, test_recipient, email_domain, domain, domain_configured, ssl_ready, folders_ready, daemon, remote, remote_auth
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    ok = try values.decodeIfPresent(Bool.self, forKey: .ok) ?? false
    test_recipient = try values.decodeIfPresent(String.self, forKey: .test_recipient) ?? ""
    email_domain = try values.decodeIfPresent(String.self, forKey: .email_domain)
      ?? values.decodeIfPresent(String.self, forKey: .domain)
      ?? ""
    domain_configured = try values.decodeIfPresent(Bool.self, forKey: .domain_configured) ?? false
    ssl_ready = try values.decodeIfPresent(Bool.self, forKey: .ssl_ready) ?? false
    folders_ready = try values.decodeIfPresent(Bool.self, forKey: .folders_ready) ?? false
    daemon = try values.decodeIfPresent(DaemonSettings.self, forKey: .daemon) ?? DaemonSettings()
    remote = try values.decodeIfPresent(RemoteSettings.self, forKey: .remote) ?? RemoteSettings()
    remote_auth = try values.decodeIfPresent(RemoteAuthSettings.self, forKey: .remote_auth) ?? RemoteAuthSettings()
  }
}

private struct DaemonSettings: Decodable, Sendable {
  var available: Bool = false
  var manager: String = ""
  var installed: Bool = false
  var running: Bool = false
  var startup_enabled: Bool = false
}

private struct RemoteSettings: Decodable, Sendable {
  var host: String = ""
  var key_path: String = ""
  var port: String = ""
  var ssh_key_has_password: String = "0"
  var ssh_key_save_choice: String = "0"
  var last_deploy_at: String = ""
  var last_deploy_status: String = ""
  var last_deploy_message: String = ""
  var last_verify_at: String = ""
  var last_verify_status: String = ""
  var last_verify_message: String = ""
  var last_test_at: String = ""
  var last_test_status: String = ""
  var last_test_message: String = ""
  var last_sync_at: String = ""
  var last_sync_status: String = ""
  var last_sync_message: String = ""

  var isConfigured: Bool {
    !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !key_path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private enum CodingKeys: String, CodingKey {
    case host, key_path, port, ssh_key_has_password, ssh_key_save_choice
    case last_deploy_at, last_deploy_status, last_deploy_message
    case last_verify_at, last_verify_status, last_verify_message
    case last_test_at, last_test_status, last_test_message
    case last_sync_at, last_sync_status, last_sync_message
  }

  init() {}

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    host = try values.decodeIfPresent(String.self, forKey: .host) ?? ""
    key_path = try values.decodeIfPresent(String.self, forKey: .key_path) ?? ""
    port = try values.decodeIfPresent(String.self, forKey: .port) ?? ""
    ssh_key_has_password = try values.decodeIfPresent(String.self, forKey: .ssh_key_has_password) ?? "0"
    ssh_key_save_choice = try values.decodeIfPresent(String.self, forKey: .ssh_key_save_choice) ?? "0"
    last_deploy_at = try values.decodeIfPresent(String.self, forKey: .last_deploy_at) ?? ""
    last_deploy_status = try values.decodeIfPresent(String.self, forKey: .last_deploy_status) ?? "idle"
    last_deploy_message = try values.decodeIfPresent(String.self, forKey: .last_deploy_message) ?? ""
    last_verify_at = try values.decodeIfPresent(String.self, forKey: .last_verify_at) ?? ""
    last_verify_status = try values.decodeIfPresent(String.self, forKey: .last_verify_status) ?? "idle"
    last_verify_message = try values.decodeIfPresent(String.self, forKey: .last_verify_message) ?? ""
    last_test_at = try values.decodeIfPresent(String.self, forKey: .last_test_at) ?? ""
    last_test_status = try values.decodeIfPresent(String.self, forKey: .last_test_status) ?? "idle"
    last_test_message = try values.decodeIfPresent(String.self, forKey: .last_test_message) ?? ""
    last_sync_at = try values.decodeIfPresent(String.self, forKey: .last_sync_at) ?? ""
    last_sync_status = try values.decodeIfPresent(String.self, forKey: .last_sync_status) ?? "idle"
    last_sync_message = try values.decodeIfPresent(String.self, forKey: .last_sync_message) ?? ""
  }
}

private struct RemoteAuthSettings: Decodable, Sendable {
  var ssh_key_has_password: String = "0"
  var ssh_key_save_choice: String = "0"
  var ssh_key_password_saved: Bool = false
  var secrets_supported: Bool = false
  var secrets_device_label: String = "computer"

  var keyHasPassword: Bool { ssh_key_has_password == "1" }
  var savePassword: Bool { ssh_key_save_choice == "1" }

  private enum CodingKeys: String, CodingKey {
    case ssh_key_has_password, ssh_key_save_choice, ssh_key_password_saved, secrets_supported, secrets_device_label
  }

  init() {}

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    ssh_key_has_password = try values.decodeIfPresent(String.self, forKey: .ssh_key_has_password) ?? "0"
    ssh_key_save_choice = try values.decodeIfPresent(String.self, forKey: .ssh_key_save_choice) ?? "0"
    ssh_key_password_saved = try values.decodeIfPresent(Bool.self, forKey: .ssh_key_password_saved) ?? false
    secrets_supported = try values.decodeIfPresent(Bool.self, forKey: .secrets_supported) ?? false
    secrets_device_label = try values.decodeIfPresent(String.self, forKey: .secrets_device_label) ?? "computer"
  }
}

private struct UIPrefs: Decodable, Sendable {
  var mail_root: String
  var selected_route: String
  var bubble_self_simplex: String
  var bubble_self_email: String
  var bubble_other_simplex: String
  var bubble_other_email: String
  var mark_read_when_seen: String
  var mark_earlier_seen: String
  var show_temporal_distance: String
  var detect_temporal_distance: String

  init(
    mail_root: String = "",
    selected_route: String = "inbox",
    bubble_self_simplex: String = BubbleColors.defaultSelfSimpleXHex,
    bubble_self_email: String = BubbleColors.defaultSelfEmailHex,
    bubble_other_simplex: String = BubbleColors.defaultOtherSimpleXHex,
    bubble_other_email: String = BubbleColors.defaultOtherEmailHex,
    mark_read_when_seen: String = "true",
    mark_earlier_seen: String = "true",
    show_temporal_distance: String = "true",
    detect_temporal_distance: String = "true"
  ) {
    self.mail_root = mail_root
    self.selected_route = selected_route
    self.bubble_self_simplex = bubble_self_simplex
    self.bubble_self_email = bubble_self_email
    self.bubble_other_simplex = bubble_other_simplex
    self.bubble_other_email = bubble_other_email
    self.mark_read_when_seen = mark_read_when_seen
    self.mark_earlier_seen = mark_earlier_seen
    self.show_temporal_distance = show_temporal_distance
    self.detect_temporal_distance = detect_temporal_distance
  }

  private enum CodingKeys: String, CodingKey {
    case mail_root
    case selected_route
    case bubble_self_simplex
    case bubble_self_email
    case bubble_other_simplex
    case bubble_other_email
    case mark_read_when_seen
    case mark_earlier_seen
    case show_temporal_distance
    case detect_temporal_distance
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    mail_root = try values.decodeIfPresent(String.self, forKey: .mail_root) ?? ""
    selected_route = try values.decodeIfPresent(String.self, forKey: .selected_route) ?? "new"
    bubble_self_simplex = try values.decodeIfPresent(String.self, forKey: .bubble_self_simplex) ?? BubbleColors.defaultSelfSimpleXHex
    bubble_self_email = try values.decodeIfPresent(String.self, forKey: .bubble_self_email) ?? BubbleColors.defaultSelfEmailHex
    bubble_other_simplex = try values.decodeIfPresent(String.self, forKey: .bubble_other_simplex) ?? BubbleColors.defaultOtherSimpleXHex
    bubble_other_email = try values.decodeIfPresent(String.self, forKey: .bubble_other_email) ?? BubbleColors.defaultOtherEmailHex
    mark_read_when_seen = try values.decodeIfPresent(String.self, forKey: .mark_read_when_seen) ?? "true"
    mark_earlier_seen = try values.decodeIfPresent(String.self, forKey: .mark_earlier_seen) ?? "true"
    show_temporal_distance = try values.decodeIfPresent(String.self, forKey: .show_temporal_distance) ?? "true"
    detect_temporal_distance = try values.decodeIfPresent(String.self, forKey: .detect_temporal_distance) ?? "true"
  }
}

private struct TrashFilesResponse: Decodable, Sendable {
  var ok: Bool = false
  var id: String = ""
  var paths: [String] = []
  var delete_after_trash: Bool = false
}

private struct SimpleXTickResponse: Decodable, Sendable {
  struct Outbox: Decodable, Sendable {
    var sent: Int = 0
    var waiting: Int = 0
    var failed: Int = 0
  }

  var ok: Bool = false
  var imported: Int = 0
  var outbox: Outbox = Outbox()
  var poll_error: String = ""

  var changedLocalState: Bool {
    imported > 0 || outbox.sent > 0 || outbox.failed > 0
  }
}

private struct BackendActionResult: Decodable, Sendable {
  var ok: Bool = false
  var message: String = ""
  var remote: RemoteSettings?
  var remote_auth: RemoteAuthSettings?
  var copied_files: Int = 0
}

private struct TLSWizardChecks: Decodable, Sendable {
  var certbot_installed: Bool = false
  var root_a_ok: Bool = false
  var smtp_a_ok: Bool = false
  var smtp_cname_ok: Bool = false
  var mx_ok: Bool = false
}

private struct TLSDNSRecord: Decodable, Identifiable, Sendable {
  var type: String = ""
  var name: String = ""
  var value: String = ""
  var priority: Int?

  var id: String {
    "\(type)|\(name)|\(value)|\(priority.map(String.init) ?? "")"
  }
}

private struct TLSWizardStatus: Decodable, Sendable {
  var ok: Bool = false
  var domain: String = ""
  var mode: String = "local"
  var remote_target: String = ""
  var smtp_host: String = ""
  var public_ip: String = ""
  var expected_ip: String = ""
  var checks: TLSWizardChecks = TLSWizardChecks()
  var suggested_records: [TLSDNSRecord] = []
}

private struct SystemTrashAction {
  var messageID: String
  var originalToTrash: [(original: URL, trashed: URL)]
}

private enum BubbleColors {
  static let defaultSelfSimpleXHex = "#DDF4E3"
  static let defaultSelfEmailHex = "#F7DADA"
  static let defaultOtherSimpleXHex = "#EDF7F0"
  static let defaultOtherEmailHex = "#F5ECEC"

  static let defaultSelfSimpleX = Color(hex: defaultSelfSimpleXHex, fallback: Color.green.opacity(0.17))
  static let defaultSelfEmail = Color(hex: defaultSelfEmailHex, fallback: Color.red.opacity(0.15))
  static let defaultOtherSimpleX = Color(hex: defaultOtherSimpleXHex, fallback: Color.green.opacity(0.08))
  static let defaultOtherEmail = Color(hex: defaultOtherEmailHex, fallback: Color.red.opacity(0.07))
}

private enum LLMCategoryColors {
  static func bubbleFill(for category: String) -> Color {
    switch normalized(category) {
    case "high-risk":
      return Color(hex: "#F5C4CC", fallback: Color.red.opacity(0.22))
    case "likely-spam":
      return Color(hex: "#F8D4BE", fallback: Color.orange.opacity(0.20))
    case "uncertain":
      return Color(hex: "#F3E5B7", fallback: Color.yellow.opacity(0.18))
    case "likely-legit":
      return Color(hex: "#DCEEE4", fallback: Color.green.opacity(0.15))
    default:
      return Color(hex: "#E6E0F2", fallback: Color.purple.opacity(0.14))
    }
  }

  private static func normalized(_ category: String) -> String {
    category
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      .replacingOccurrences(of: " ", with: "-")
      .replacingOccurrences(of: "_", with: "-")
  }
}

private extension Color {
  init(hex: String, fallback: Color) {
    let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#").union(.whitespacesAndNewlines))
    guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else {
      self = fallback
      return
    }
    let red = Double((value >> 16) & 0xFF) / 255.0
    let green = Double((value >> 8) & 0xFF) / 255.0
    let blue = Double(value & 0xFF) / 255.0
    self = Color(red: red, green: green, blue: blue)
  }

  var stellarHexString: String {
    guard let color = NSColor(self).usingColorSpace(.sRGB) else {
      return "#FFFFFF"
    }
    let red = Int((color.redComponent * 255.0).rounded()).clamped(to: 0...255)
    let green = Int((color.greenComponent * 255.0).rounded()).clamped(to: 0...255)
    let blue = Int((color.blueComponent * 255.0).rounded()).clamped(to: 0...255)
    return String(format: "#%02X%02X%02X", red, green, blue)
  }
}

private extension String {
  func stellarBool(defaultValue: Bool) -> Bool {
    switch trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "true", "1", "yes", "on":
      return true
    case "false", "0", "no", "off":
      return false
    default:
      return defaultValue
    }
  }
}

private extension Comparable {
  func clamped(to limits: ClosedRange<Self>) -> Self {
    min(max(self, limits.lowerBound), limits.upperBound)
  }
}

private struct MailboxItem: Identifiable, Decodable, Hashable, Sendable {
  var id: String
  var title: String
  var count: Int
  var unread: Int

  init(id: String, title: String, count: Int = 0, unread: Int = 0) {
    self.id = id
    self.title = title
    self.count = count
    self.unread = unread
  }
}

private struct DraftItem: Identifiable, Decodable, Hashable, Sendable {
  var id: String { ulid }
  var ulid: String
  var to: String
  var subject: String
  var updated_at: String

  init(ulid: String = "", to: String = "", subject: String = "", updated_at: String = "") {
    self.ulid = ulid
    self.to = to
    self.subject = subject
    self.updated_at = updated_at
  }

  private enum CodingKeys: String, CodingKey { case ulid, to, subject, updated_at }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    ulid = try values.decodeIfPresent(String.self, forKey: .ulid) ?? UUID().uuidString
    to = try values.decodeIfPresent(String.self, forKey: .to) ?? ""
    subject = try values.decodeIfPresent(String.self, forKey: .subject) ?? ""
    updated_at = try values.decodeIfPresent(String.self, forKey: .updated_at) ?? ""
  }
}

private struct EventItem: Identifiable, Decodable, Hashable, Sendable {
  var id: String
  var kind: String
  var message: String
  var created_at: String

  init(id: String = UUID().uuidString, kind: String = "", message: String = "", created_at: String = "") {
    self.id = id
    self.kind = kind
    self.message = message
    self.created_at = created_at
  }

  private enum CodingKeys: String, CodingKey { case id, kind, message, created_at, at, label }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
    let decodedKind = try values.decodeIfPresent(String.self, forKey: .kind)
    let decodedLabel = try values.decodeIfPresent(String.self, forKey: .label)
    kind = decodedKind ?? decodedLabel ?? ""
    message = try values.decodeIfPresent(String.self, forKey: .message) ?? ""
    let decodedCreatedAt = try values.decodeIfPresent(String.self, forKey: .created_at)
    let decodedAt = try values.decodeIfPresent(String.self, forKey: .at)
    created_at = decodedCreatedAt ?? decodedAt ?? ""
  }
}

private struct SimpleXSnapshot: Decodable, Sendable {
  var install_state: String
  var system_root: String
  var incoming_dir: String
  var outbox_dir: String

  init(install_state: String = "unknown", system_root: String = "", incoming_dir: String = "", outbox_dir: String = "") {
    self.install_state = install_state
    self.system_root = system_root
    self.incoming_dir = incoming_dir
    self.outbox_dir = outbox_dir
  }
}

private struct SimpleXBootstrap: Decodable, Sendable {
  var ok: Bool
  var supported: Bool
  var install_state: String
  var version: String
  var binary_path: String
  var profile_prefix: String
  var profile_ready: Bool
  var hook_path: String
  var hook_ready: Bool
  var last_error: String

  init(
    ok: Bool = true,
    supported: Bool = false,
    install_state: String = "unknown",
    version: String = "",
    binary_path: String = "",
    profile_prefix: String = "",
    profile_ready: Bool = false,
    hook_path: String = "",
    hook_ready: Bool = false,
    last_error: String = ""
  ) {
    self.ok = ok
    self.supported = supported
    self.install_state = install_state
    self.version = version
    self.binary_path = binary_path
    self.profile_prefix = profile_prefix
    self.profile_ready = profile_ready
    self.hook_path = hook_path
    self.hook_ready = hook_ready
    self.last_error = last_error
  }
}

private struct ThreadItem: Identifiable, Decodable, Hashable, Sendable {
  var id: String
  var kind: String
  var name: String
  var email: String
  var simplex_address: String
  var favorite: Bool
  var group: String
  var temporal_distance_seconds: Int?
  var unread_count: Int
  var latest_at: String
  var messages: [MessageItem]

  var hasSimpleXPath: Bool { !simplex_address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  var hasEmailPath: Bool { !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  var displayName: String { name.isEmpty ? id : name }

  init(
    id: String,
    kind: String = "person",
    name: String,
    email: String = "",
    simplex_address: String = "",
    favorite: Bool = false,
    group: String = "",
    temporal_distance_seconds: Int? = nil,
    unread_count: Int = 0,
    latest_at: String = "",
    messages: [MessageItem] = []
  ) {
    self.id = id
    self.kind = kind
    self.name = name
    self.email = email
    self.simplex_address = simplex_address
    self.favorite = favorite
    self.group = group
    self.temporal_distance_seconds = temporal_distance_seconds
    self.unread_count = unread_count
    self.latest_at = latest_at
    self.messages = messages
  }

  private enum CodingKeys: String, CodingKey {
    case id, kind, name, email, simplex_address, favorite, group, temporal_distance_seconds, unread_count, latest_at, messages
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decodeIfPresent(String.self, forKey: .id) ?? "unknown"
    kind = try values.decodeIfPresent(String.self, forKey: .kind) ?? "person"
    name = try values.decodeIfPresent(String.self, forKey: .name) ?? id
    email = try values.decodeIfPresent(String.self, forKey: .email) ?? ""
    simplex_address = try values.decodeIfPresent(String.self, forKey: .simplex_address) ?? ""
    favorite = try values.decodeIfPresent(Bool.self, forKey: .favorite) ?? false
    group = try values.decodeIfPresent(String.self, forKey: .group) ?? ""
    temporal_distance_seconds = try values.decodeIfPresent(Int.self, forKey: .temporal_distance_seconds)
    unread_count = try values.decodeIfPresent(Int.self, forKey: .unread_count) ?? 0
    latest_at = try values.decodeIfPresent(String.self, forKey: .latest_at) ?? ""
    messages = try values.decodeIfPresent([MessageItem].self, forKey: .messages) ?? []
  }
}

private struct AttachmentItem: Decodable, Hashable, Sendable {
  var name: String
  var mime: String
  var size: Int
  var data_url: String

  var isImage: Bool { mime.lowercased().hasPrefix("image/") }
  var isVideo: Bool { mime.lowercased().hasPrefix("video/") }
  var isAudio: Bool { mime.lowercased().hasPrefix("audio/") }

  init(name: String = "", mime: String = "", size: Int = 0, data_url: String = "") {
    self.name = name
    self.mime = mime
    self.size = size
    self.data_url = data_url
  }

  private enum CodingKeys: String, CodingKey { case name, mime, size, data_url }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    name = try values.decodeIfPresent(String.self, forKey: .name) ?? "Attachment"
    mime = try values.decodeIfPresent(String.self, forKey: .mime) ?? ""
    size = try values.decodeIfPresent(Int.self, forKey: .size) ?? 0
    data_url = try values.decodeIfPresent(String.self, forKey: .data_url) ?? ""
  }

  var data: Data? {
    guard let comma = data_url.firstIndex(of: ",") else { return nil }
    let encoded = String(data_url[data_url.index(after: comma)...])
    return Data(base64Encoded: encoded)
  }

  var nsImage: NSImage? {
    guard isImage, let data else { return nil }
    return NSImage(data: data)
  }

  var temporaryURL: URL? {
    guard (isVideo || isAudio), let data else { return nil }
    let safeName = name.isEmpty ? "attachment.bin" : name.replacingOccurrences(of: "/", with: "-")
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("stellar-secure-chat")
      .appendingPathComponent(safeName)
    do {
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      if !FileManager.default.fileExists(atPath: url.path) {
        try data.write(to: url, options: .atomic)
      }
      return url
    } catch {
      return nil
    }
  }
}

private struct MessageItem: Identifiable, Decodable, Hashable, Sendable {
  var id: String
  var backend_kind: String
  var transport: String
  var lock: String
  var thread_id: String
  var contact_name: String
  var contact_kind: String
  var email: String
  var simplex_address: String
  var list: String
  var sender: String
  var ulid: String
  var subject: String
  var body: String
  var preview: String
  var received_at: String
  var from_self: Bool
  var in_inbox: Bool
  var read: Bool
  var starred: Bool
  var attachments: Int
  var attachment: AttachmentItem?
  var status: String
  var llm_spam_category: String
  var llm_spam_source: String

  var isSimpleX: Bool { transport == "simplex" }
  var isEmail: Bool { transport == "email" }
  var isSending: Bool { status == "sending" || status == "waiting-adapter" }
  var isSendError: Bool { status == "error" }
  var isLongBlock: Bool { isEmail || body.count > 180 || subject.count > 0 }
  var displayBody: String { body.isEmpty ? preview : body }
  var cardTextWeight: Int {
    subject.count + displayBody.count + (attachment == nil ? 0 : 260)
  }
  var cardWidth: CGFloat {
    cardTextWeight > 720 ? 500 : 420
  }
  var cardMinHeight: CGFloat {
    cardTextWeight > 720 ? 375 : (cardTextWeight > 260 ? 360 : 315)
  }
  var cardBodyLineLimit: Int {
    cardTextWeight > 720 ? 12 : (cardTextWeight > 260 ? 8 : 5)
  }
  var inboxCardWidth: CGFloat {
    cardTextWeight > 720 ? 420 : (cardTextWeight > 260 ? 330 : 300)
  }
  var inboxCardMinHeight: CGFloat {
    cardTextWeight > 720 ? 350 : (cardTextWeight > 260 ? 275 : 250)
  }
  var inboxCardBodyLineLimit: Int {
    cardTextWeight > 720 ? 9 : (cardTextWeight > 260 ? 6 : 4)
  }
  var llmDetectedCategory: String? {
    let category = llm_spam_category.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !category.isEmpty, category != "unknown" else { return nil }
    let source = llm_spam_source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard source.isEmpty || source == "llm" else { return nil }
    return category
  }

  init(
    id: String,
    backend_kind: String,
    transport: String,
    lock: String,
    thread_id: String,
    contact_name: String,
    contact_kind: String = "person",
    email: String = "",
    simplex_address: String = "",
    list: String = "",
    sender: String = "",
    ulid: String = "",
    subject: String = "",
    body: String = "",
    preview: String = "",
    received_at: String = "",
    from_self: Bool = false,
    in_inbox: Bool = false,
    read: Bool = false,
    starred: Bool = false,
    attachments: Int = 0,
    attachment: AttachmentItem? = nil,
    status: String = "",
    llm_spam_category: String = "",
    llm_spam_source: String = ""
  ) {
    self.id = id
    self.backend_kind = backend_kind
    self.transport = transport
    self.lock = lock
    self.thread_id = thread_id
    self.contact_name = contact_name
    self.contact_kind = contact_kind
    self.email = email
    self.simplex_address = simplex_address
    self.list = list
    self.sender = sender
    self.ulid = ulid
    self.subject = subject
    self.body = body
    self.preview = preview
    self.received_at = received_at
    self.from_self = from_self
    self.in_inbox = in_inbox
    self.read = read
    self.starred = starred
    self.attachments = attachments
    self.attachment = attachment
    self.status = status
    self.llm_spam_category = llm_spam_category
    self.llm_spam_source = llm_spam_source
  }

  private enum CodingKeys: String, CodingKey {
    case id, backend_kind, transport, lock, thread_id, contact_name, contact_kind, email, simplex_address
    case list, sender, ulid, subject, body, preview, received_at, from_self, in_inbox, read, starred, attachments, attachment, status
    case llm_spam_category, llm_spam_source
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
    backend_kind = try values.decodeIfPresent(String.self, forKey: .backend_kind) ?? ""
    transport = try values.decodeIfPresent(String.self, forKey: .transport) ?? "email"
    lock = try values.decodeIfPresent(String.self, forKey: .lock) ?? (transport == "simplex" ? "closed" : "open")
    thread_id = try values.decodeIfPresent(String.self, forKey: .thread_id) ?? "unknown"
    contact_name = try values.decodeIfPresent(String.self, forKey: .contact_name) ?? thread_id
    contact_kind = try values.decodeIfPresent(String.self, forKey: .contact_kind) ?? "person"
    email = try values.decodeIfPresent(String.self, forKey: .email) ?? ""
    simplex_address = try values.decodeIfPresent(String.self, forKey: .simplex_address) ?? ""
    list = try values.decodeIfPresent(String.self, forKey: .list) ?? ""
    sender = try values.decodeIfPresent(String.self, forKey: .sender) ?? ""
    ulid = try values.decodeIfPresent(String.self, forKey: .ulid) ?? ""
    subject = try values.decodeIfPresent(String.self, forKey: .subject) ?? ""
    body = try values.decodeIfPresent(String.self, forKey: .body) ?? ""
    preview = try values.decodeIfPresent(String.self, forKey: .preview) ?? ""
    received_at = try values.decodeIfPresent(String.self, forKey: .received_at) ?? ""
    from_self = try values.decodeIfPresent(Bool.self, forKey: .from_self) ?? false
    in_inbox = try values.decodeIfPresent(Bool.self, forKey: .in_inbox) ?? false
    read = try values.decodeIfPresent(Bool.self, forKey: .read) ?? false
    starred = try values.decodeIfPresent(Bool.self, forKey: .starred) ?? false
    attachments = try values.decodeIfPresent(Int.self, forKey: .attachments) ?? 0
    attachment = try values.decodeIfPresent(AttachmentItem.self, forKey: .attachment)
    status = try values.decodeIfPresent(String.self, forKey: .status) ?? ""
    llm_spam_category = try values.decodeIfPresent(String.self, forKey: .llm_spam_category) ?? ""
    llm_spam_source = try values.decodeIfPresent(String.self, forKey: .llm_spam_source) ?? ""
  }
}

private func defaultMailRoot() -> String {
  FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("mail").path
}

private enum FriendlyTime {
  static func relative(_ rawValue: String, now: Date = Date()) -> String {
    guard let date = parse(rawValue) else {
      return rawValue
    }
    let delta = Int(now.timeIntervalSince(date))
    if delta < -60 {
      return "in \(compactDuration(abs(delta)))"
    }
    if delta < 60 {
      return "now"
    }
    return "\(compactDuration(delta)) ago"
  }

  private static func compactDuration(_ seconds: Int) -> String {
    if seconds < 60 {
      return "\(max(1, seconds))s"
    }
    let minutes = seconds / 60
    if minutes < 60 {
      return "\(minutes)m"
    }
    let hours = minutes / 60
    if hours < 24 {
      return "\(hours)h"
    }
    let days = hours / 24
    if days < 7 {
      return "\(days)d"
    }
    let weeks = days / 7
    if weeks < 5 {
      return "\(weeks)w"
    }
    let months = days / 30
    if months < 12 {
      return "\(max(1, months))mo"
    }
    let years = days / 365
    return "\(max(1, years))y"
  }

  private static func parse(_ rawValue: String) -> Date? {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = isoFormatter.date(from: trimmed) {
      return date
    }
    let isoFormatterWithoutFractionalSeconds = ISO8601DateFormatter()
    isoFormatterWithoutFractionalSeconds.formatOptions = [.withInternetDateTime]
    if let date = isoFormatterWithoutFractionalSeconds.date(from: trimmed) {
      return date
    }
    for format in ["yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.dateFormat = format
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
      if let date = formatter.date(from: trimmed) {
        return date
      }
    }
    return nil
  }

  static func sortTimestamp(_ rawValue: String) -> TimeInterval {
    parse(rawValue)?.timeIntervalSince1970 ?? 0
  }
}

private func friendlyTime(_ rawValue: String) -> String {
  FriendlyTime.relative(rawValue)
}

private func fullTimestamp(_ rawValue: String) -> String {
  rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No timestamp" : rawValue
}

private enum TemporalDistance {
  static let steps: [Int] = [
    60 * 60,
    4 * 60 * 60,
    8 * 60 * 60,
    12 * 60 * 60,
    24 * 60 * 60,
    2 * 24 * 60 * 60,
    3 * 24 * 60 * 60,
    4 * 24 * 60 * 60,
    7 * 24 * 60 * 60,
    14 * 24 * 60 * 60,
    30 * 24 * 60 * 60,
    90 * 24 * 60 * 60
  ]

  static func label(_ seconds: Int) -> String {
    let value = max(seconds, 60 * 60)
    if value < 24 * 60 * 60 {
      return "\(max(1, value / (60 * 60)))h"
    }
    let days = value / (24 * 60 * 60)
    if days < 7 {
      return "\(days)d"
    }
    if days < 30 {
      return "\(max(1, days / 7))w"
    }
    return "\(max(1, days / 30))mo"
  }

  static func roundedStep(for seconds: Int) -> Int {
    steps.min { abs($0 - seconds) < abs($1 - seconds) } ?? steps[4]
  }

  static func next(after seconds: Int?) -> Int {
    guard let seconds else { return steps[4] }
    let current = roundedStep(for: seconds)
    guard let index = steps.firstIndex(of: current), index < steps.count - 1 else {
      return steps.last ?? current
    }
    return steps[index + 1]
  }

  static func previous(before seconds: Int?) -> Int {
    guard let seconds else { return steps[4] }
    let current = roundedStep(for: seconds)
    guard let index = steps.firstIndex(of: current), index > 0 else {
      return steps.first ?? current
    }
    return steps[index - 1]
  }
}

private func formatBytes(_ size: Int) -> String {
  if size >= 1024 * 1024 {
    return String(format: "%.1f MB", Double(size) / Double(1024 * 1024)).replacingOccurrences(of: ".0 MB", with: " MB")
  }
  if size >= 1024 {
    return String(format: "%.1f KB", Double(size) / 1024).replacingOccurrences(of: ".0 KB", with: " KB")
  }
  return "\(max(0, size)) B"
}

private struct PendingAttachment: Identifiable, Hashable {
  var path: String
  var name: String
  var size: Int
  var typeDescription: String

  var id: String { path }
  var url: URL { URL(fileURLWithPath: path) }
  var displaySize: String { formatBytes(size) }

  init(url: URL) {
    path = url.path
    name = url.lastPathComponent.isEmpty ? "Attachment" : url.lastPathComponent
    let values = try? url.resourceValues(forKeys: [.fileSizeKey, .localizedTypeDescriptionKey])
    size = values?.fileSize ?? 0
    typeDescription = values?.localizedTypeDescription ?? "File"
  }
}

@MainActor
private final class StellarSession: ObservableObject {
  @Published var snapshot: Snapshot = Snapshot(root: defaultMailRoot())
  @Published var hasLoadedInitialSnapshot: Bool = false
  @Published var startupMessage: String = "Loading mailbox..."
  @Published var startupErrorMessage: String?
  @Published var selectedRoute: String = "new"
  @Published var focusedMessageID: String?
  @Published var selectedMessageID: String?
  @Published var draggingMessageID: String?
  @Published var timelineScrollPositions: [String: String] = [:]
  @Published var timelineAtEndByThread: [String: Bool] = [:]
  @Published var selectedNewSenderID: String?
  @Published var selectedMailThreadID: String?
  @Published var mailRoot: String = defaultMailRoot()
  @Published var selectedTransport: Transport = .simplex
  @Published var composeSubject: String = ""
  @Published var composeBody: String = ""
  @Published var pendingAttachment: PendingAttachment?
  @Published var optimisticOutgoingMessages: [MessageItem] = []
  @Published var statusText: String = "Ready"
  @Published var isBusy: Bool = false
  @Published var isRefreshingSnapshot: Bool = false
  @Published var isTickingTransport: Bool = false
  @Published var toastMessage: String = ""
  @Published var toastBusy: Bool = false
  @Published var toastVisible: Bool = false
  @Published var bootstrap: SimpleXBootstrap = SimpleXBootstrap()
  @Published var contactDraftName: String = ""
  @Published var contactDraftEmail: String = ""
  @Published var contactDraftSimpleX: String = ""
  @Published var contactDraftFavorite: Bool = false
  @Published var settingsDomainDraft: String = ""
  @Published var settingsTestRecipientDraft: String = ""
  @Published var remoteHostDraft: String = ""
  @Published var remoteKeyPathDraft: String = ""
  @Published var remotePortDraft: String = ""
  @Published var remoteKeyHasPassword: Bool = false
  @Published var remoteKeySavePassword: Bool = false
  @Published var remoteKeyPasswordDraft: String = ""
  @Published var remotePasswordVisible: Bool = false
  @Published var tlsWizardIPMode: String = "stable"
  @Published var tlsWizardStatus: TLSWizardStatus?
  @Published var tlsWizardError: String = ""
  @Published var isRefreshingTLSWizard: Bool = false
  @Published var bubbleSelfSimpleXColor: Color = BubbleColors.defaultSelfSimpleX
  @Published var bubbleSelfEmailColor: Color = BubbleColors.defaultSelfEmail
  @Published var bubbleOtherSimpleXColor: Color = BubbleColors.defaultOtherSimpleX
  @Published var bubbleOtherEmailColor: Color = BubbleColors.defaultOtherEmail
  @Published var markMessagesReadWhenSeen: Bool = true
  @Published var markEarlierMessagesSeen: Bool = true
  @Published var showTemporalDistance: Bool = true
  @Published var detectTemporalDistanceAutomatically: Bool = true
  @Published var applicationFocusGeneration: Int = 0
  private var lastSystemTrashAction: SystemTrashAction?
  private var seenMessageIDsInFlight: Set<String> = []
  private var witnessedTimelineMessageEdges: [String: [String: SeenMessageEdges]] = [:]
  private var lastRefreshAt: Date?
  private var lastTransportTickAt: Date?
  private var transportAutoSyncTimer: Timer?
  private let refreshStaleInterval: TimeInterval = 20
  private let transportTickInterval: TimeInterval = 5
  private let transportAutoSyncInterval: TimeInterval = 5
  private var toastGeneration = 0

  init() {
    snapshot = Snapshot(root: defaultMailRoot())
    mailRoot = defaultMailRoot()
    selectedRoute = "new"
    selectedTransport = .simplex
    Task { await loadPreferencesThenRefresh() }
  }

  var inboxUnreadCount: Int {
    snapshot.inbox.filter { !$0.read }.count
  }

  var selectedThreadID: String? {
    if let selectedMailThreadID {
      return selectedMailThreadID
    }
    guard selectedRoute.hasPrefix("thread:") else { return nil }
    return String(selectedRoute.dropFirst("thread:".count))
  }

  var selectedThread: ThreadItem? {
    guard let id = selectedThreadID else { return nil }
    return snapshot.threads.first(where: { $0.id == id })
  }

  func automaticTemporalDistance(for thread: ThreadItem) -> Int? {
    guard detectTemporalDistanceAutomatically else { return nil }
    let messages = thread.messages.sorted {
      FriendlyTime.sortTimestamp($0.received_at) < FriendlyTime.sortTimestamp($1.received_at)
    }
    var replyDelays: [Int] = []
    for (index, message) in messages.enumerated() where !message.from_self {
      let received = FriendlyTime.sortTimestamp(message.received_at)
      guard received > 0 else { continue }
      if let reply = messages[(index + 1)...].first(where: { $0.from_self && FriendlyTime.sortTimestamp($0.received_at) > received }) {
        let delay = Int(FriendlyTime.sortTimestamp(reply.received_at) - received)
        if delay > 0 {
          replyDelays.append(delay)
        }
      }
    }
    guard !replyDelays.isEmpty else { return nil }
    let sorted = replyDelays.sorted()
    return TemporalDistance.roundedStep(for: sorted[sorted.count / 2])
  }

  func effectiveTemporalDistance(for thread: ThreadItem) -> Int? {
    thread.temporal_distance_seconds ?? automaticTemporalDistance(for: thread)
  }

  func temporalDistanceHelp(for thread: ThreadItem) -> String {
    let automatic = automaticTemporalDistance(for: thread)
    if let explicit = thread.temporal_distance_seconds, let automatic {
      return "Temporal distance \(TemporalDistance.label(explicit)); automatic \(TemporalDistance.label(automatic))"
    }
    if let explicit = thread.temporal_distance_seconds {
      return "Temporal distance \(TemporalDistance.label(explicit))"
    }
    if let automatic {
      return "Automatic temporal distance \(TemporalDistance.label(automatic))"
    }
    return "Temporal distance not set"
  }

  var newSenderThreads: [ThreadItem] {
    snapshot.threads
      .filter { thread in thread.messages.contains(where: { $0.list == "quarantine" }) }
      .sorted { $0.latest_at > $1.latest_at }
  }

  var selectedNewSender: ThreadItem? {
    if let selectedNewSenderID {
      return newSenderThreads.first(where: { $0.id == selectedNewSenderID })
    }
    return newSenderThreads.first
  }

  var newSenderMessages: [MessageItem] {
    (selectedNewSender?.messages ?? [])
      .filter { $0.list == "quarantine" }
      .sorted { $0.received_at > $1.received_at }
  }

  var selectedMailboxID: String? {
    if selectedRoute == "archive" {
      return "archive"
    }
    guard selectedRoute.hasPrefix("mailbox:") else { return nil }
    return String(selectedRoute.dropFirst("mailbox:".count))
  }

  var selectedMailbox: MailboxItem? {
    guard let id = selectedMailboxID else { return nil }
    return snapshot.mailboxes.first(where: { $0.id == id })
  }

  var mailboxMessages: [MessageItem] {
    guard let id = selectedMailboxID else { return [] }
    return snapshot.messages
      .filter { $0.list == id || $0.status == id }
      .sorted { $0.received_at > $1.received_at }
  }

  var timelineMessages: [MessageItem] {
    guard let thread = selectedThread else { return [] }
    let optimistic = optimisticOutgoingMessages
      .filter { $0.thread_id == thread.id && !messageMatchesSnapshot($0) }
    return (thread.messages + optimistic)
      .sorted { FriendlyTime.sortTimestamp($0.received_at) < FriendlyTime.sortTimestamp($1.received_at) }
  }

  var activeMessage: MessageItem? {
    if let selectedMessageID {
      return message(withID: selectedMessageID)
    }
    if let focusedMessageID {
      return message(withID: focusedMessageID)
    }
    return nil
  }

  var canSend: Bool {
    let bodyReady = !composeBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let attachmentReady = pendingAttachment != nil
    guard (bodyReady || attachmentReady), let thread = selectedThread else { return false }
    switch selectedTransport {
    case .simplex:
      return thread.hasSimpleXPath
    case .email:
      return thread.hasEmailPath && pendingAttachment == nil
    }
  }

  var canSwitchComposerTransport: Bool {
    guard let thread = selectedThread else { return false }
    return thread.hasSimpleXPath && thread.hasEmailPath
  }

  var canUndoLastTrashAction: Bool {
    lastSystemTrashAction != nil
  }

  var remoteDraftConfigured: Bool {
    !remoteHostDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !remoteKeyPathDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var remotePortDraftValid: Bool {
    let trimmed = normalizedRemotePortDraft()
    guard !trimmed.isEmpty else { return true }
    guard let port = Int(trimmed) else { return false }
    return (1...65_535).contains(port)
  }

  var remotePasswordAvailable: Bool {
    if !remoteKeyHasPassword {
      return true
    }
    if !remoteKeyPasswordDraft.isEmpty {
      return true
    }
    return remoteKeySavePassword && snapshot.settings.remote_auth.ssh_key_password_saved
  }

  var remoteReadyForDeploy: Bool {
    remoteDraftConfigured && remotePortDraftValid && remotePasswordAvailable
  }

  var tlsWizardUsesDynamicIP: Bool {
    tlsWizardIPMode == "dynamic"
  }

  var tlsWizardDNSReady: Bool {
    guard let status = tlsWizardStatus else { return false }
    return status.checks.smtp_a_ok && status.checks.mx_ok && (tlsWizardUsesDynamicIP || status.checks.root_a_ok)
  }

  var tlsWizardServerMode: String {
    remoteDraftConfigured ? "remote" : "local"
  }

  var remoteStatusSummary: String {
    let remote = snapshot.settings.remote
    let auth = snapshot.settings.remote_auth
    var bits: [String] = []
    if remote.isConfigured {
      bits.append("Target: \(remote.host)")
      if !remote.port.isEmpty {
        bits.append("SSH port: \(remote.port)")
      }
    } else {
      bits.append("Set host and SSH key, then deploy.")
    }
    if auth.keyHasPassword {
      if auth.savePassword && auth.ssh_key_password_saved {
        bits.append("SSH key password saved securely on this \(auth.secrets_device_label).")
      } else if auth.savePassword {
        bits.append("Enter SSH key password to finish secure save.")
      } else {
        bits.append("Enter SSH key password for deploy, verify, test, and sync.")
      }
    }
    appendRemoteStatus("Deploy", status: remote.last_deploy_status, message: remote.last_deploy_message, at: remote.last_deploy_at, to: &bits)
    appendRemoteStatus("Verify", status: remote.last_verify_status, message: remote.last_verify_message, at: remote.last_verify_at, to: &bits)
    appendRemoteStatus("Test", status: remote.last_test_status, message: remote.last_test_message, at: remote.last_test_at, to: &bits)
    appendRemoteStatus("Sync", status: remote.last_sync_status, message: remote.last_sync_message, at: remote.last_sync_at, to: &bits)
    return bits.joined(separator: " • ")
  }

  private func appendRemoteStatus(_ label: String, status: String, message: String, at: String, to bits: inout [String]) {
    guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    let prefix = status == "ok" ? label : "\(label) issue"
    let suffix = at.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : " (\(friendlyTime(at)))"
    bits.append("\(prefix): \(message)\(suffix)")
  }

  func normalizedRemotePortDraft() -> String {
    var trimmed = remotePortDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix(":") {
      trimmed.removeFirst()
    }
    return trimmed
  }

  func loadPreferencesThenRefresh() async {
    startupMessage = "Loading preferences..."
    do {
      let prefs = try await StellarBackend.uiPrefs(root: mailRoot)
      if !prefs.mail_root.isEmpty {
        mailRoot = prefs.mail_root
      }
      selectedRoute = prefs.selected_route.isEmpty ? "new" : prefs.selected_route
      apply(uiPrefs: prefs)
    } catch {
      statusText = "Preferences unavailable: \(error.localizedDescription)"
    }
    await loadInitialSnapshot()
    if hasLoadedInitialSnapshot {
      startTransportAutoSync()
      tickTransportIfStale()
    }
  }

  func retryInitialLoad() {
    startupErrorMessage = nil
    Task { await loadPreferencesThenRefresh() }
  }

  private func loadInitialSnapshot() async {
    if isRefreshingSnapshot { return }
    lastRefreshAt = Date()
    let root = mailRoot
    isRefreshingSnapshot = true
    do {
      let next = try await StellarBackend.snapshot(root: root)
      self.apply(snapshot: next)
      self.statusText = "Loaded \(next.threads.count) conversations from \(next.root)"
      self.hasLoadedInitialSnapshot = true
      self.startupErrorMessage = nil
      self.isRefreshingSnapshot = false
      self.refreshBootstrapStatus()
    } catch {
      self.isRefreshingSnapshot = false
      self.startupErrorMessage = "Mailbox unavailable: \(error.localizedDescription)"
      self.statusText = self.startupErrorMessage ?? "Mailbox unavailable"
    }
  }

  func refresh() {
    if !hasLoadedInitialSnapshot {
      Task { await loadInitialSnapshot() }
      return
    }
    if isRefreshingSnapshot { return }
    lastRefreshAt = Date()
    let root = mailRoot
    isRefreshingSnapshot = true
    Task {
      do {
        let next = try await StellarBackend.snapshot(root: root)
        self.apply(snapshot: next)
        self.statusText = "Loaded \(next.threads.count) conversations from \(next.root)"
        self.isRefreshingSnapshot = false
      } catch {
        self.isRefreshingSnapshot = false
        self.showStatus("Mailbox refresh failed: \(error.localizedDescription)", isError: true)
      }
    }
    refreshBootstrapStatus()
  }

  func refreshIfStale(force: Bool = false) {
    if isRefreshingSnapshot && !force {
      return
    }
    if !force, let lastRefreshAt, Date().timeIntervalSince(lastRefreshAt) < refreshStaleInterval {
      tickTransportIfStale()
      return
    }
    refresh()
    if force {
      tickTransportIfStale(force: true)
    }
  }

  func noteApplicationFocused() {
    applicationFocusGeneration += 1
  }

  private func startTransportAutoSync() {
    guard transportAutoSyncTimer == nil else { return }
    let timer = Timer(timeInterval: transportAutoSyncInterval, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.tickTransportIfStale()
      }
    }
    timer.tolerance = 1
    RunLoop.main.add(timer, forMode: .common)
    transportAutoSyncTimer = timer
  }

  func tickTransportIfStale(force: Bool = false, notify: Bool = false) {
    if isTickingTransport {
      return
    }
    if !force, let lastTransportTickAt, Date().timeIntervalSince(lastTransportTickAt) < transportTickInterval {
      return
    }
    lastTransportTickAt = Date()
    let root = mailRoot
    isTickingTransport = true
    Task {
      do {
        let response = try await StellarBackend.tickSimpleX(root: root)
        self.isTickingTransport = false
        if notify {
          self.showStatus("SimpleX incoming queue checked")
        }
        if response.changedLocalState {
          self.refresh()
        }
      } catch {
        self.isTickingTransport = false
        if notify {
          self.showStatus("SimpleX transport check failed: \(error.localizedDescription)", isError: true)
        } else {
          self.statusText = "SimpleX transport check failed: \(error.localizedDescription)"
        }
      }
    }
  }

  func refreshBootstrapStatus() {
    let root = mailRoot
    Task {
      do {
        let next = try await StellarBackend.bootstrapStatus(root: root)
        self.bootstrap = next
      } catch {
        self.bootstrap = SimpleXBootstrap(install_state: "unknown", last_error: error.localizedDescription)
      }
    }
  }

  func showToast(_ message: String, busy: Bool = false, autoDismiss: Bool = true) {
    guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    toastGeneration += 1
    let generation = toastGeneration
    toastMessage = message
    toastBusy = busy
    withAnimation(.easeOut(duration: 0.16)) {
      toastVisible = true
    }
    if autoDismiss && !busy {
      Task {
        try? await Task.sleep(nanoseconds: 3_200_000_000)
        if self.toastGeneration == generation {
          withAnimation(.easeIn(duration: 0.16)) {
            self.toastVisible = false
          }
        }
      }
    }
  }

  func showStatus(_ message: String, busy: Bool = false, isError: Bool = false) {
    statusText = message
    showToast(message, busy: busy && !isError, autoDismiss: !busy || isError)
  }

  func apply(snapshot next: Snapshot) {
    snapshot = next
    mailRoot = next.root
    if selectedRoute.hasPrefix("thread:") {
      selectedMailThreadID = String(selectedRoute.dropFirst("thread:".count))
      selectedRoute = "mail"
    }
    let stableRoutes = ["new", "inbox", "inbox-message", "mail", "archive", "drafts", "events", "settings"]
    if !stableRoutes.contains(selectedRoute) && !selectedRoute.hasPrefix("mailbox:") {
      selectedRoute = "new"
    }
    if selectedMailThreadID == nil {
      selectedMailThreadID = snapshot.threads.first?.id
    }
    if selectedNewSenderID == nil {
      selectedNewSenderID = newSenderThreads.first?.id
    }
    if let thread = selectedThread {
      syncTransportDefault(for: thread)
      loadContactDraft(from: thread)
    }
    settingsDomainDraft = next.settings.email_domain
    settingsTestRecipientDraft = next.settings.test_recipient
    remoteHostDraft = next.settings.remote.host
    remoteKeyPathDraft = next.settings.remote.key_path
    remotePortDraft = next.settings.remote.port
    remoteKeyHasPassword = next.settings.remote_auth.keyHasPassword
    remoteKeySavePassword = next.settings.remote_auth.savePassword
  }

  func openNewSenders() {
    selectedRoute = "new"
    if selectedNewSenderID == nil {
      selectedNewSenderID = newSenderThreads.first?.id
    }
    selectedMessageID = newSenderMessages.first?.id
    focusedMessageID = selectedMessageID
    persistSelectedRoute()
  }

  func selectThread(_ thread: ThreadItem) {
    selectedRoute = "mail"
    selectedMailThreadID = thread.id
    focusedMessageID = nil
    selectedMessageID = nil
    syncTransportDefault(for: thread)
    loadContactDraft(from: thread)
    persistSelectedRoute()
  }

  func openMail() {
    selectedRoute = "mail"
    if selectedMailThreadID == nil {
      selectedMailThreadID = snapshot.threads.first?.id
    }
    if let thread = selectedThread {
      syncTransportDefault(for: thread)
      loadContactDraft(from: thread)
    }
    persistSelectedRoute()
  }

  func openArchive() {
    selectedRoute = "archive"
    focusedMessageID = nil
    selectedMessageID = nil
    persistSelectedRoute()
  }

  func openTimeline(for message: MessageItem) {
    selectedRoute = "mail"
    selectedMailThreadID = message.thread_id
    focusedMessageID = message.id
    selectedMessageID = message.id
    if let thread = selectedThread {
      syncTransportDefault(for: thread)
      loadContactDraft(from: thread)
    }
    persistSelectedRoute()
  }

  func openInbox(focusing messageID: String?) {
    selectedRoute = "inbox"
    focusedMessageID = messageID
    selectedMessageID = messageID
    persistSelectedRoute()
  }

  func openInboxMessage(_ message: MessageItem) {
    selectedRoute = "inbox-message"
    focusedMessageID = message.id
    selectedMessageID = message.id
    persistSelectedRoute()
  }

  func selectNewSender(_ thread: ThreadItem) {
    selectedRoute = "new"
    selectedNewSenderID = thread.id
    let firstMessage = thread.messages.filter { $0.list == "quarantine" }.sorted { $0.received_at > $1.received_at }.first
    selectedMessageID = firstMessage?.id
    focusedMessageID = firstMessage?.id
    persistSelectedRoute()
  }

  func moveSelectedNewSender(to list: String) {
    guard let message = newSenderMessages.first else { return }
    let root = mailRoot
    let sender = message.sender
    runMessageAction(status: "Moved sender to \(list)", refreshAfter: false) {
      try await StellarBackend.runJSON(action: "move-sender", root: root, args: ["quarantine", list, message.sender])
    } afterSuccess: {
      self.applySenderMove(sender: sender, to: list)
    }
  }

  func moveNewSender(_ thread: ThreadItem, to list: String) {
    guard let message = thread.messages.first(where: { $0.list == "quarantine" }) else { return }
    selectedNewSenderID = thread.id
    selectedMessageID = message.id
    focusedMessageID = message.id
    let root = mailRoot
    let sender = message.sender
    runMessageAction(status: "Moved sender to \(list)", refreshAfter: false) {
      try await StellarBackend.runJSON(action: "move-sender", root: root, args: ["quarantine", list, sender])
    } afterSuccess: {
      self.applySenderMove(sender: sender, to: list)
    }
  }

  func handleSenderDrop(threadID: String, action: SenderDropAction) {
    guard let thread = newSenderThreads.first(where: { $0.id == threadID }) else {
      showStatus("Dropped sender is no longer available.", isError: true)
      return
    }
    moveNewSender(thread, to: action.destinationList)
  }

  func applySenderMove(sender: String, to list: String) {
    func movedMessage(_ message: MessageItem) -> MessageItem {
      guard message.sender == sender, message.list == "quarantine" else {
        return message
      }
      var moved = message
      moved.list = list
      moved.status = list
      return moved
    }

    func movedThread(_ thread: ThreadItem) -> ThreadItem {
      var moved = thread
      moved.messages = thread.messages.map(movedMessage)
      moved.unread_count = moved.messages.filter { !$0.read && $0.list != "archive" && $0.list != "trash" }.count
      return moved
    }

    let movedCount = snapshot.messages.filter { $0.sender == sender && $0.list == "quarantine" }.count
    snapshot.messages = snapshot.messages.map(movedMessage)
    snapshot.inbox = snapshot.inbox.map(movedMessage)
    snapshot.threads = snapshot.threads.map(movedThread)
    snapshot.favorites = snapshot.favorites.map(movedThread)
    snapshot.individuals = snapshot.individuals.map(movedThread)
    snapshot.groups = snapshot.groups.map(movedThread)
    snapshot.mailboxes = snapshot.mailboxes.map { mailbox in
      var updated = mailbox
      if updated.id == "quarantine" {
        updated.count = max(0, updated.count - movedCount)
      } else if updated.id == list {
        updated.count += movedCount
      }
      return updated
    }
    if selectedNewSenderID != nil, selectedNewSender?.messages.contains(where: { $0.list == "quarantine" }) != true {
      selectedNewSenderID = newSenderThreads.first?.id
    }
    let firstMessage = newSenderMessages.first
    selectedMessageID = firstMessage?.id
    focusedMessageID = firstMessage?.id
  }

  func applyArchived(messageID: String) {
    applyMessageUpdate(id: messageID) { message in
      message.in_inbox = false
      message.list = "archive"
      message.status = "archive"
    }
  }

  func applySeen(messageID: String) {
    applyMessageUpdate(id: messageID) { message in
      message.read = true
      message.in_inbox = false
      message.list = "archive"
      message.status = "archive"
    }
  }

  func applyDeleted(messageID: String) {
    snapshot.messages.removeAll { $0.id == messageID }
    snapshot.inbox.removeAll { $0.id == messageID }
    snapshot.threads = snapshot.threads.map { thread in
      var updated = thread
      updated.messages.removeAll { $0.id == messageID }
      return updated
    }
    snapshot.favorites = snapshot.favorites.map { thread in
      var updated = thread
      updated.messages.removeAll { $0.id == messageID }
      return updated
    }
    snapshot.individuals = snapshot.individuals.map { thread in
      var updated = thread
      updated.messages.removeAll { $0.id == messageID }
      return updated
    }
    snapshot.groups = snapshot.groups.map { thread in
      var updated = thread
      updated.messages.removeAll { $0.id == messageID }
      return updated
    }
    normalizeMessageCollections()
    if selectedMessageID == messageID {
      selectedMessageID = nil
    }
    if focusedMessageID == messageID {
      focusedMessageID = nil
    }
  }

  func applyMessageUpdate(id messageID: String, mutate: (inout MessageItem) -> Void) {
    var found = false
    func updatedMessage(_ message: MessageItem) -> MessageItem {
      guard message.id == messageID else { return message }
      var updated = message
      mutate(&updated)
      found = true
      return updated
    }
    snapshot.messages = snapshot.messages.map(updatedMessage)
    snapshot.inbox = snapshot.inbox.map(updatedMessage)
    snapshot.threads = snapshot.threads.map { thread in
      var updated = thread
      updated.messages = thread.messages.map(updatedMessage)
      return updated
    }
    snapshot.favorites = snapshot.favorites.map { thread in
      var updated = thread
      updated.messages = thread.messages.map(updatedMessage)
      return updated
    }
    snapshot.individuals = snapshot.individuals.map { thread in
      var updated = thread
      updated.messages = thread.messages.map(updatedMessage)
      return updated
    }
    snapshot.groups = snapshot.groups.map { thread in
      var updated = thread
      updated.messages = thread.messages.map(updatedMessage)
      return updated
    }
    if found {
      normalizeMessageCollections()
    }
  }

  func normalizeMessageCollections() {
    func refreshedThread(_ thread: ThreadItem) -> ThreadItem {
      var refreshed = thread
      refreshed.messages = snapshot.messages
        .filter { $0.thread_id == thread.id }
        .sorted { $0.received_at < $1.received_at }
      refreshed.latest_at = refreshed.messages.map(\.received_at).max() ?? thread.latest_at
      refreshed.unread_count = refreshed.messages.filter { $0.in_inbox && !$0.read }.count
      return refreshed
    }

    snapshot.inbox = snapshot.messages
      .filter { $0.in_inbox }
      .sorted { $0.received_at > $1.received_at }
    snapshot.threads = snapshot.threads
      .map(refreshedThread)
      .sorted { $0.latest_at > $1.latest_at }
    snapshot.favorites = snapshot.threads
      .filter { $0.favorite }
      .sorted { $0.name < $1.name }
    snapshot.individuals = snapshot.threads
      .filter { $0.kind != "group" }
      .sorted { $0.latest_at > $1.latest_at }
    snapshot.groups = snapshot.threads
      .filter { $0.kind == "group" }
      .sorted { $0.latest_at > $1.latest_at }
  }

  private func messageMatchesSnapshot(_ message: MessageItem) -> Bool {
    snapshot.messages.contains { candidate in
      candidate.id == message.id || (
        candidate.thread_id == message.thread_id &&
        candidate.from_self == message.from_self &&
        candidate.transport == message.transport &&
        candidate.subject == message.subject &&
        candidate.body == message.body
      )
    }
  }

  private func upsertOptimisticOutgoingMessage(_ message: MessageItem) {
    optimisticOutgoingMessages.removeAll { $0.id == message.id }
    optimisticOutgoingMessages.append(message)
  }

  private func updateOptimisticOutgoingMessage(id: String, status: String) {
    guard let index = optimisticOutgoingMessages.firstIndex(where: { $0.id == id }) else { return }
    optimisticOutgoingMessages[index].status = status
  }

  private func optimisticMessage(for thread: ThreadItem, transport: Transport, subject: String, body: String, attachment: PendingAttachment? = nil) -> MessageItem {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let displayBody: String
    if body.isEmpty, let attachment {
      displayBody = "Attachment: \(attachment.name)"
    } else {
      displayBody = body
    }
    return MessageItem(
      id: "optimistic:\(UUID().uuidString)",
      backend_kind: transport.rawValue,
      transport: transport.rawValue,
      lock: transport == .simplex ? "closed" : "open",
      thread_id: thread.id,
      contact_name: thread.displayName,
      contact_kind: thread.kind,
      email: thread.email,
      simplex_address: thread.simplex_address,
      subject: subject,
      body: displayBody,
      preview: displayBody,
      received_at: timestamp,
      from_self: true,
      read: true,
      attachments: attachment == nil ? 0 : 1,
      attachment: attachment.map { AttachmentItem(name: $0.name, mime: $0.typeDescription, size: $0.size, data_url: "") },
      status: "sending"
    )
  }

  func openMailbox(_ mailbox: MailboxItem) {
    selectedRoute = "mailbox:\(mailbox.id)"
    focusedMessageID = nil
    selectedMessageID = nil
    persistSelectedRoute()
  }

  func openDrafts() {
    selectedRoute = "drafts"
    focusedMessageID = nil
    selectedMessageID = nil
    persistSelectedRoute()
  }

  func openEvents() {
    selectedRoute = "events"
    focusedMessageID = nil
    selectedMessageID = nil
    persistSelectedRoute()
  }

  func openSettingsRoute() {
    selectedRoute = "settings"
    focusedMessageID = nil
    selectedMessageID = nil
    persistSelectedRoute()
  }

  func selectMessage(_ message: MessageItem) {
    selectedMessageID = message.id
  }

  func rememberTimelineScrollPosition(threadID: String?, messageID: String) {
    guard let threadID, !threadID.isEmpty else { return }
    timelineScrollPositions[threadID] = messageID
  }

  func rememberTimelineAtEnd(threadID: String?, isAtEnd: Bool) {
    guard let threadID, !threadID.isEmpty else { return }
    timelineAtEndByThread[threadID] = isAtEnd
  }

  func timelineShouldFollowEnd(for thread: ThreadItem?) -> Bool {
    guard let thread else { return true }
    return timelineAtEndByThread[thread.id] ?? true
  }

  func timelineEndID(for thread: ThreadItem?) -> String? {
    thread?.messages.last?.id
  }

  func timelineScrollTarget(for thread: ThreadItem?) -> String? {
    guard let thread else { return nil }
    if let focusedMessageID, thread.messages.contains(where: { $0.id == focusedMessageID }) {
      return focusedMessageID
    }
    if let remembered = timelineScrollPositions[thread.id],
       thread.messages.contains(where: { $0.id == remembered }) {
      return remembered
    }
    return thread.messages.last?.id
  }

  func markVisibleTimelineMessagesSeen(threadID: String?, visibleFrames: [String: CGRect], viewportHeight: CGFloat) {
    guard markMessagesReadWhenSeen,
          selectedRoute == "mail",
          let threadID,
          selectedThreadID == threadID,
          viewportHeight > 0 else {
      return
    }
    let messages = timelineMessages
    let validMessageIDs = Set(messages.map(\.id))
    var edgeMap = witnessedTimelineMessageEdges[threadID] ?? [:]
    for (id, frame) in visibleFrames where validMessageIDs.contains(id) {
      let fullyVisible = frame.minY >= -1 && frame.maxY <= viewportHeight + 1
      var edges = edgeMap[id] ?? SeenMessageEdges()
      if fullyVisible || (frame.minY >= -1 && frame.minY <= viewportHeight + 1) {
        edges.top = true
      }
      if fullyVisible || (frame.maxY >= -1 && frame.maxY <= viewportHeight + 1) {
        edges.bottom = true
      }
      edgeMap[id] = edges
    }
    edgeMap = edgeMap.filter { validMessageIDs.contains($0.key) }
    witnessedTimelineMessageEdges[threadID] = edgeMap

    let witnessedIDs = Set(edgeMap.compactMap { id, edges in
      edges.top && edges.bottom ? id : nil
    })
    guard !witnessedIDs.isEmpty else { return }

    var candidates: [MessageItem]
    if markEarlierMessagesSeen,
       let lastWitnessedIndex = messages.lastIndex(where: { witnessedIDs.contains($0.id) }) {
      candidates = Array(messages.prefix(through: lastWitnessedIndex))
    } else {
      candidates = messages.filter { witnessedIDs.contains($0.id) }
    }

    let ids = candidates
      .filter { !$0.from_self && ($0.in_inbox || !$0.read) && !seenMessageIDsInFlight.contains($0.id) }
      .map(\.id)
    markMessagesSeen(ids)
  }

  private func markMessagesSeen(_ ids: [String]) {
    let uniqueIDs = Array(Set(ids)).sorted()
    guard !uniqueIDs.isEmpty else { return }
    seenMessageIDsInFlight.formUnion(uniqueIDs)
    let root = mailRoot
    Task {
      do {
        _ = try await StellarBackend.runJSON(action: "mark-seen", root: root, args: uniqueIDs)
        for id in uniqueIDs {
          self.applySeen(messageID: id)
        }
      } catch {
        self.statusText = "Seen update failed: \(error.localizedDescription)"
      }
      self.seenMessageIDsInFlight.subtract(uniqueIDs)
    }
  }

  func persistSelectedRoute() {
    let route = selectedRoute
    let root = mailRoot
    Task {
      try? await StellarBackend.setUIPref(root: root, key: "selected_route", value: route)
    }
  }

  func apply(uiPrefs prefs: UIPrefs) {
    bubbleSelfSimpleXColor = Color(hex: prefs.bubble_self_simplex, fallback: BubbleColors.defaultSelfSimpleX)
    bubbleSelfEmailColor = Color(hex: prefs.bubble_self_email, fallback: BubbleColors.defaultSelfEmail)
    bubbleOtherSimpleXColor = Color(hex: prefs.bubble_other_simplex, fallback: BubbleColors.defaultOtherSimpleX)
    bubbleOtherEmailColor = Color(hex: prefs.bubble_other_email, fallback: BubbleColors.defaultOtherEmail)
    markMessagesReadWhenSeen = prefs.mark_read_when_seen.stellarBool(defaultValue: true)
    markEarlierMessagesSeen = prefs.mark_earlier_seen.stellarBool(defaultValue: true)
    showTemporalDistance = prefs.show_temporal_distance.stellarBool(defaultValue: true)
    detectTemporalDistanceAutomatically = prefs.detect_temporal_distance.stellarBool(defaultValue: true)
  }

  func persistSeenPreferences() {
    let root = mailRoot
    let markWhenSeen = markMessagesReadWhenSeen
    let markEarlier = markEarlierMessagesSeen
    Task {
      try? await StellarBackend.setUIPref(root: root, key: "mark_read_when_seen", value: markWhenSeen ? "true" : "false")
      try? await StellarBackend.setUIPref(root: root, key: "mark_earlier_seen", value: markEarlier ? "true" : "false")
    }
  }

  func persistTemporalDistancePreferences() {
    let root = mailRoot
    let show = showTemporalDistance
    let detect = detectTemporalDistanceAutomatically
    Task {
      try? await StellarBackend.setUIPref(root: root, key: "show_temporal_distance", value: show ? "true" : "false")
      try? await StellarBackend.setUIPref(root: root, key: "detect_temporal_distance", value: detect ? "true" : "false")
    }
  }

  func persistBubbleColors() {
    let root = mailRoot
    let values = [
      ("bubble_self_simplex", bubbleSelfSimpleXColor.stellarHexString),
      ("bubble_self_email", bubbleSelfEmailColor.stellarHexString),
      ("bubble_other_simplex", bubbleOtherSimpleXColor.stellarHexString),
      ("bubble_other_email", bubbleOtherEmailColor.stellarHexString)
    ]
    Task {
      for (key, value) in values {
        try? await StellarBackend.setUIPref(root: root, key: key, value: value)
      }
    }
  }

  func resetBubbleColors() {
    bubbleSelfSimpleXColor = BubbleColors.defaultSelfSimpleX
    bubbleSelfEmailColor = BubbleColors.defaultSelfEmail
    bubbleOtherSimpleXColor = BubbleColors.defaultOtherSimpleX
    bubbleOtherEmailColor = BubbleColors.defaultOtherEmail
    persistBubbleColors()
  }

  func bubbleFill(for message: MessageItem) -> Color {
    if let category = message.llmDetectedCategory {
      return LLMCategoryColors.bubbleFill(for: category)
    }
    switch (message.from_self, message.isSimpleX) {
      case (true, true):
        return bubbleSelfSimpleXColor
      case (true, false):
        return bubbleSelfEmailColor
      case (false, true):
        return bubbleOtherSimpleXColor
      case (false, false):
        return bubbleOtherEmailColor
    }
  }

  func syncTransportDefault(for thread: ThreadItem) {
    selectedTransport = thread.hasSimpleXPath ? .simplex : .email
  }

  func selectComposerTransport(_ transport: Transport) {
    guard let thread = selectedThread else { return }
    switch transport {
    case .simplex:
      guard thread.hasSimpleXPath else { return }
    case .email:
      guard thread.hasEmailPath else { return }
    }
    selectedTransport = transport
  }

  func attachDroppedFiles(_ providers: [NSItemProvider], selecting thread: ThreadItem? = nil) -> Bool {
    guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
      return false
    }
    if let thread {
      selectThread(thread)
    }
    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
      let resolvedURL: URL?
      if let url = item as? URL {
        resolvedURL = url
      } else if let nsurl = item as? NSURL {
        resolvedURL = nsurl as URL
      } else if let data = item as? Data {
        resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
      } else {
        resolvedURL = nil
      }
      Task { @MainActor in
        if let error {
          self.showStatus("Attachment drop failed: \(error.localizedDescription)", isError: true)
          return
        }
        guard let resolvedURL else {
          self.showStatus("Dropped item was not a file URL.", isError: true)
          return
        }
        self.addPendingAttachment(resolvedURL)
      }
    }
    return true
  }

  func addPendingAttachment(_ url: URL) {
    let fileURL = url.isFileURL ? url : URL(fileURLWithPath: url.path)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
      showStatus("Attachment must be a file.", isError: true)
      return
    }
    pendingAttachment = PendingAttachment(url: fileURL)
    showStatus("Attached \(fileURL.lastPathComponent)")
  }

  func removePendingAttachment() {
    pendingAttachment = nil
  }

  func loadContactDraft(from thread: ThreadItem) {
    contactDraftName = thread.displayName
    contactDraftEmail = thread.email
    contactDraftSimpleX = thread.simplex_address
    contactDraftFavorite = thread.favorite
  }

  func sendComposedMessage() {
    guard let thread = selectedThread else { return }
    let transport = selectedTransport
    let attachment = pendingAttachment
    let subject = transport == .email ? composeSubject : ""
    let body = composeBody.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !body.isEmpty || attachment != nil else { return }
    if attachment != nil && transport == .email {
      showStatus("Email attachments are not available; SimpleX is the attachment path.", isError: true)
      return
    }
    let root = mailRoot
    let optimistic = optimisticMessage(for: thread, transport: transport, subject: subject, body: body, attachment: attachment)
    upsertOptimisticOutgoingMessage(optimistic)
    composeSubject = ""
    composeBody = ""
    pendingAttachment = nil
    rememberTimelineAtEnd(threadID: thread.id, isAtEnd: true)
    isBusy = true
    showStatus(attachment == nil ? (transport == .email ? "Sending by explicit email path..." : "Queueing SimpleX message...") : "Queueing SimpleX attachment...", busy: true)
    Task {
      do {
        if let attachment {
          _ = try await StellarBackend.sendAttachment(root: root, threadID: thread.id, transport: transport, subject: subject, body: body, attachmentPath: attachment.path)
        } else {
          _ = try await StellarBackend.send(root: root, threadID: thread.id, transport: transport, subject: subject, body: body)
        }
        if transport == .simplex {
          _ = try await StellarBackend.tickSimpleX(root: root)
        }
        self.updateOptimisticOutgoingMessage(id: optimistic.id, status: "sent")
        self.isBusy = false
        self.showStatus(transport == .email ? "Email sent through Stellar outbox." : "SimpleX message sent.")
        self.refresh()
      } catch {
        self.updateOptimisticOutgoingMessage(id: optimistic.id, status: "error")
        if self.pendingAttachment == nil {
          self.pendingAttachment = attachment
        }
        self.isBusy = false
        self.showStatus(error.localizedDescription, isError: true)
      }
    }
  }

  func archive(_ message: MessageItem) {
    let root = mailRoot
    runMessageAction(status: "Removed from Inbox", refreshAfter: false) {
      try await StellarBackend.runJSON(action: "archive-message", root: root, args: [message.id])
    } afterSuccess: {
      self.applyArchived(messageID: message.id)
      self.refresh()
    }
  }

  func delete(_ message: MessageItem) {
    trash(message)
  }

  func trash(_ message: MessageItem) {
    let root = mailRoot
    isBusy = true
    showStatus("Moving message to system Trash", busy: true)
    Task {
      do {
        let response = try await StellarBackend.messageTrashFiles(root: root, messageID: message.id)
        let urls = response.paths.map { URL(fileURLWithPath: $0) }
        guard !urls.isEmpty else {
          throw NSError(domain: "StellarTrash", code: 1, userInfo: [NSLocalizedDescriptionKey: "Message files were not found for system Trash."])
        }
        let recycled = try await recycleInSystemTrash(urls)
        if response.delete_after_trash {
          _ = try await StellarBackend.runJSON(action: "delete-message", root: root, args: [message.id])
        }
        self.lastSystemTrashAction = SystemTrashAction(
          messageID: message.id,
          originalToTrash: recycled.map { (original: $0.key, trashed: $0.value) }
        )
        self.applyDeleted(messageID: message.id)
        self.isBusy = false
        self.showStatus("Moved message to system Trash")
        self.refresh()
      } catch {
        self.isBusy = false
        self.showStatus(error.localizedDescription, isError: true)
      }
    }
  }

  func undoLastTrashAction() {
    guard let action = lastSystemTrashAction else {
      showStatus("No system Trash action to undo", isError: true)
      return
    }
    isBusy = true
    showStatus("Restoring message from system Trash", busy: true)
    Task {
      do {
        let fileManager = FileManager.default
        for mapping in action.originalToTrash.reversed() {
          try fileManager.createDirectory(at: mapping.original.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
          if fileManager.fileExists(atPath: mapping.original.path) {
            throw NSError(domain: "StellarTrash", code: 2, userInfo: [NSLocalizedDescriptionKey: "\(mapping.original.lastPathComponent) already exists at its original location."])
          }
          try fileManager.moveItem(at: mapping.trashed, to: mapping.original)
        }
        self.lastSystemTrashAction = nil
        self.isBusy = false
        self.showStatus("Restored message from system Trash")
        self.refresh()
      } catch {
        self.isBusy = false
        self.showStatus("Could not undo Trash action: \(error.localizedDescription)", isError: true)
      }
    }
  }

  func openSystemTrash() {
    NSWorkspace.shared.open(URL(fileURLWithPath: "\(NSHomeDirectory())/.Trash", isDirectory: true))
  }

  private func recycleInSystemTrash(_ urls: [URL]) async throws -> [URL: URL] {
    try await withCheckedThrowingContinuation { continuation in
      NSWorkspace.shared.recycle(urls) { trashedURLs, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: trashedURLs)
        }
      }
    }
  }

  func toggleStar(_ message: MessageItem) {
    let root = mailRoot
    runMessageAction(status: message.starred ? "Unstarred" : "Starred", refreshAfter: false) {
      try await StellarBackend.runJSON(action: "toggle-star", root: root, args: [message.id, message.starred ? "false" : "true"])
    } afterSuccess: {
      self.applyMessageUpdate(id: message.id) { updated in
        updated.starred.toggle()
      }
      self.refresh()
    }
  }

  func markRead(_ message: MessageItem, read: Bool) {
    let root = mailRoot
    runMessageAction(status: read ? "Marked read" : "Marked unread", refreshAfter: false) {
      try await StellarBackend.runJSON(action: "mark-read", root: root, args: [message.id, read ? "true" : "false"])
    } afterSuccess: {
      self.applyMessageUpdate(id: message.id) { updated in
        updated.read = read
      }
      self.refresh()
    }
  }

  func archiveSelectedMessage() {
    if let message = activeMessage { archive(message) }
  }

  func deleteSelectedMessage() {
    if let message = activeMessage { delete(message) }
  }

  func toggleSelectedStar() {
    if let message = activeMessage { toggleStar(message) }
  }

  func markSelectedRead() {
    if let message = activeMessage { markRead(message, read: true) }
  }

  func markSelectedUnread() {
    if let message = activeMessage { markRead(message, read: false) }
  }

  func message(withID id: String) -> MessageItem? {
    if let message = snapshot.messages.first(where: { $0.id == id }) {
      return message
    }
    if let message = snapshot.inbox.first(where: { $0.id == id }) {
      return message
    }
    for thread in snapshot.threads {
      if let message = thread.messages.first(where: { $0.id == id }) {
        return message
      }
    }
    return nil
  }

  func handleMessageDrop(id: String, action: MessageDropAction) {
    endDraggingMessage(id)
    guard let message = message(withID: id) else {
      showStatus("Dropped message is no longer available.", isError: true)
      return
    }
    selectedMessageID = message.id
    switch action {
    case .archive:
      archive(message)
    case .trash:
      trash(message)
    }
  }

  func beginDraggingMessage(_ message: MessageItem) {
    draggingMessageID = message.id
    let expectedID = message.id
    Task {
      try? await Task.sleep(nanoseconds: 30_000_000_000)
      if self.draggingMessageID == expectedID {
        self.draggingMessageID = nil
      }
    }
  }

  func endDraggingMessage(_ id: String? = nil) {
    guard id == nil || draggingMessageID == id else { return }
    draggingMessageID = nil
  }

  func runMessageAction(
    status: String,
    refreshAfter: Bool = true,
    action: @escaping () async throws -> Data,
    afterSuccess: @escaping () -> Void = {}
  ) {
    isBusy = true
    Task {
      do {
        _ = try await action()
        afterSuccess()
        self.isBusy = false
        self.showStatus(status)
        if refreshAfter {
          self.refresh()
        }
      } catch {
        self.isBusy = false
        self.showStatus(error.localizedDescription, isError: true)
      }
    }
  }

  func runBackendAction(_ action: String, args: [String] = [], status: String) {
    let root = mailRoot
    runMessageAction(status: status) {
      try await StellarBackend.runJSON(action: action, root: root, args: args)
    }
  }

  func saveContactBinding() {
    guard let thread = selectedThread else { return }
    let root = mailRoot
    let kind = thread.kind == "group" ? "group" : "person"
    let name = contactDraftName
    let email = contactDraftEmail
    let simplex = contactDraftSimpleX
    let favorite = contactDraftFavorite
    let args = [
      thread.id,
      name,
      kind,
      email,
      simplex,
      favorite ? "yes" : "no"
    ]
    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
      applyContactBinding(threadID: thread.id, name: name, email: email, simplex: simplex, favorite: favorite)
    }
    runMessageAction(status: "Contact binding saved", refreshAfter: false) {
      try await StellarBackend.runJSON(action: "bind-contact", root: root, args: args)
    }
  }

  func renameContact(_ thread: ThreadItem, to proposedName: String) {
    let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, name != thread.displayName else { return }
    let root = mailRoot
    let kind = thread.kind == "group" ? "group" : "person"
    let args = [
      thread.id,
      name,
      kind,
      thread.email,
      thread.simplex_address,
      thread.favorite ? "yes" : "no"
    ]
    if selectedThreadID == thread.id {
      contactDraftName = name
    }
    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
      applyContactBinding(
        threadID: thread.id,
        name: name,
        email: thread.email,
        simplex: thread.simplex_address,
        favorite: thread.favorite
      )
    }
    runMessageAction(status: "Contact renamed", refreshAfter: false) {
      try await StellarBackend.runJSON(action: "bind-contact", root: root, args: args)
    }
  }

  func toggleFavorite(for thread: ThreadItem) {
    let root = mailRoot
    let kind = thread.kind == "group" ? "group" : "person"
    let favorite = !thread.favorite
    let args = [
      thread.id,
      thread.name,
      kind,
      thread.email,
      thread.simplex_address,
      favorite ? "yes" : "no"
    ]
    if selectedThreadID == thread.id {
      contactDraftFavorite = favorite
    }
    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
      applyContactBinding(
        threadID: thread.id,
        name: thread.name,
        email: thread.email,
        simplex: thread.simplex_address,
        favorite: favorite
      )
    }
    runMessageAction(status: favorite ? "Added to Favorites" : "Removed from Favorites", refreshAfter: false) {
      try await StellarBackend.runJSON(action: "bind-contact", root: root, args: args)
    }
  }

  func applyContactBinding(threadID: String, name: String, email: String, simplex: String, favorite: Bool) {
    func updatedThread(_ thread: ThreadItem) -> ThreadItem {
      guard thread.id == threadID else { return thread }
      var updated = thread
      updated.name = name
      updated.email = email
      updated.simplex_address = simplex
      updated.favorite = favorite
      updated.messages = thread.messages.map { message in
        var updatedMessage = message
        updatedMessage.contact_name = name
        return updatedMessage
      }
      return updated
    }

    snapshot.threads = snapshot.threads.map(updatedThread)
    snapshot.individuals = snapshot.individuals.map(updatedThread)
    snapshot.groups = snapshot.groups.map(updatedThread)
    snapshot.favorites = snapshot.favorites.map(updatedThread)

    guard let updated = snapshot.threads.first(where: { $0.id == threadID }) ??
      snapshot.individuals.first(where: { $0.id == threadID }) ??
      snapshot.groups.first(where: { $0.id == threadID }) ??
      snapshot.favorites.first(where: { $0.id == threadID }) else {
      return
    }

    snapshot.favorites.removeAll { $0.id == threadID }
    if favorite {
      snapshot.favorites.insert(updated, at: 0)
    }
  }

  func setTemporalDistance(for thread: ThreadItem, seconds: Int?) {
    let normalized = seconds.map { TemporalDistance.roundedStep(for: $0) }
    applyTemporalDistance(threadID: thread.id, seconds: normalized)
    let root = mailRoot
    runMessageAction(status: normalized == nil ? "Temporal distance automatic" : "Temporal distance \(TemporalDistance.label(normalized ?? 0))", refreshAfter: false) {
      try await StellarBackend.runJSON(action: "set-temporal-distance", root: root, args: [thread.id, normalized.map(String.init) ?? "auto"])
    }
  }

  func increaseTemporalDistance(for thread: ThreadItem) {
    setTemporalDistance(for: thread, seconds: TemporalDistance.next(after: thread.temporal_distance_seconds ?? effectiveTemporalDistance(for: thread)))
  }

  func decreaseTemporalDistance(for thread: ThreadItem) {
    setTemporalDistance(for: thread, seconds: TemporalDistance.previous(before: thread.temporal_distance_seconds ?? effectiveTemporalDistance(for: thread)))
  }

  func applyTemporalDistance(threadID: String, seconds: Int?) {
    func updatedThread(_ thread: ThreadItem) -> ThreadItem {
      guard thread.id == threadID else { return thread }
      var updated = thread
      updated.temporal_distance_seconds = seconds
      return updated
    }

    snapshot.threads = snapshot.threads.map(updatedThread)
    snapshot.individuals = snapshot.individuals.map(updatedThread)
    snapshot.groups = snapshot.groups.map(updatedThread)
    snapshot.favorites = snapshot.favorites.map(updatedThread)
  }

  func saveEmailDomain() {
    runBackendAction("settings-set-domain", args: [settingsDomainDraft], status: "Email domain saved")
  }

  func verifyEmailDomain() {
    runBackendAction("settings-verify-domain", args: [settingsDomainDraft], status: "Email domain verified")
  }

  func saveTestRecipient() {
    runBackendAction("settings-set-test-recipient", args: [settingsTestRecipientDraft], status: "Test recipient saved")
  }

  func setDaemonRunning(_ running: Bool) {
    runBackendAction("settings-set-daemon-running", args: [running ? "on" : "off"], status: running ? "Daemon started" : "Daemon stopped")
  }

  func setDaemonStartup(_ enabled: Bool) {
    runBackendAction("settings-set-daemon-startup", args: [enabled ? "on" : "off"], status: enabled ? "Startup enabled" : "Startup disabled")
  }

  private func applyRemoteActionResult(_ data: Data) {
    guard let result = try? JSONDecoder().decode(BackendActionResult.self, from: data) else { return }
    if let remote = result.remote {
      snapshot.settings.remote = remote
      remoteHostDraft = remote.host
      remoteKeyPathDraft = remote.key_path
      remotePortDraft = remote.port
    }
    if let auth = result.remote_auth {
      snapshot.settings.remote_auth = auth
      remoteKeyHasPassword = auth.keyHasPassword
      remoteKeySavePassword = auth.savePassword
      if !auth.keyHasPassword || auth.savePassword {
        remoteKeyPasswordDraft = ""
      }
    }
  }

  private func remoteTargetArgs() -> [String] {
    [remoteHostDraft.trimmingCharacters(in: .whitespacesAndNewlines),
     remoteKeyPathDraft.trimmingCharacters(in: .whitespacesAndNewlines),
     normalizedRemotePortDraft()]
  }

  private func remoteAuthArgs() -> [String] {
    [
      remoteKeyHasPassword ? "1" : "0",
      remoteKeySavePassword ? "1" : "0",
      remoteKeyHasPassword ? remoteKeyPasswordDraft : "",
      remoteHostDraft.trimmingCharacters(in: .whitespacesAndNewlines),
      remoteKeyPathDraft.trimmingCharacters(in: .whitespacesAndNewlines),
      normalizedRemotePortDraft()
    ]
  }

  func saveRemoteTarget() {
    let root = mailRoot
    runMessageAction(status: "Remote target saved", refreshAfter: false) {
      let data = try await StellarBackend.runJSON(action: "settings-remote-set-target", root: root, args: self.remoteTargetArgs())
      await MainActor.run { self.applyRemoteActionResult(data) }
      return data
    }
  }

  func saveRemoteAuth() {
    let root = mailRoot
    runMessageAction(status: "Remote SSH authentication saved", refreshAfter: false) {
      let data = try await StellarBackend.runJSON(action: "settings-remote-set-auth", root: root, args: self.remoteAuthArgs())
      await MainActor.run { self.applyRemoteActionResult(data) }
      return data
    }
  }

  func deployRemoteServer() {
    runRemoteWorkflowAction(
      title: "Deploying remote server",
      action: "settings-remote-deploy",
      fallbackStatus: "Remote deploy finished"
    )
  }

  func verifyRemote() {
    runRemoteWorkflowAction(
      title: "Verifying remote setup",
      action: "settings-remote-verify",
      fallbackStatus: "Remote verification finished"
    )
  }

  func syncRemote() {
    runRemoteWorkflowAction(
      title: "Checking remote mail",
      action: "settings-remote-sync",
      fallbackStatus: "Remote sync finished",
      refreshAfter: true
    )
  }

  func sendRemoteTestEmail() {
    runRemoteWorkflowAction(
      title: "Sending remote test email",
      action: "settings-remote-send-test",
      fallbackStatus: "Remote test email finished",
      refreshAfter: true
    )
  }

  func setupTLSForCurrentServer() {
    let mode = tlsWizardServerMode
    if mode != "remote" {
      runBackendAction("settings-setup-ssl", args: ["local"], status: "TLS setup finished")
      return
    }
    runRemoteWorkflowAction(
      title: "Setting up TLS",
      action: "settings-setup-ssl",
      actionArgs: ["remote"] + remoteWorkflowArgs(),
      fallbackStatus: "TLS setup finished"
    )
  }

  func refreshTLSWizardStatus() {
    guard snapshot.settings.domain_configured else {
      tlsWizardStatus = nil
      tlsWizardError = "Set the receiving domain first."
      return
    }
    let root = mailRoot
    let mode = tlsWizardServerMode
    let remoteHint = mode == "remote" ? remoteHostDraft.trimmingCharacters(in: .whitespacesAndNewlines) : ""
    isRefreshingTLSWizard = true
    tlsWizardError = ""
    Task {
      do {
        let data = try await StellarBackend.runJSON(action: "settings-ssl-wizard-status", root: root, args: [mode, remoteHint])
        let status = try JSONDecoder().decode(TLSWizardStatus.self, from: data)
        self.tlsWizardStatus = status
        self.isRefreshingTLSWizard = false
      } catch {
        self.tlsWizardError = error.localizedDescription
        self.isRefreshingTLSWizard = false
      }
    }
  }

  private func remoteWorkflowArgs() -> [String] {
    [
      remoteHostDraft.trimmingCharacters(in: .whitespacesAndNewlines),
      remoteKeyPathDraft.trimmingCharacters(in: .whitespacesAndNewlines),
      remoteKeyHasPassword ? remoteKeyPasswordDraft : "",
      normalizedRemotePortDraft()
    ]
  }

  private func runRemoteWorkflowAction(
    title: String,
    action: String,
    actionArgs: [String]? = nil,
    fallbackStatus: String,
    refreshAfter: Bool = true
  ) {
    let root = mailRoot
    isBusy = true
    showStatus(title, busy: true)
    Task {
      do {
        let targetData = try await StellarBackend.runJSON(action: "settings-remote-set-target", root: root, args: self.remoteTargetArgs())
        self.applyRemoteActionResult(targetData)
        let authData = try await StellarBackend.runJSON(action: "settings-remote-set-auth", root: root, args: self.remoteAuthArgs())
        self.applyRemoteActionResult(authData)
        let args = actionArgs ?? remoteWorkflowArgs()
        let data = try await StellarBackend.runJSON(action: action, root: root, args: args)
        self.applyRemoteActionResult(data)
        let result = try? JSONDecoder().decode(BackendActionResult.self, from: data)
        self.isBusy = false
        self.showStatus(result?.message.isEmpty == false ? result?.message ?? fallbackStatus : fallbackStatus)
        if refreshAfter {
          self.refresh()
        }
      } catch {
        self.isBusy = false
        self.showStatus(error.localizedDescription, isError: true)
        self.refresh()
      }
    }
  }

  func classifySpam() {
    runBackendAction("spam-classify", args: ["quarantine", "", "25", "0"], status: "Spam classification finished")
  }

  func chooseMailRoot() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Use Mail Root"
    if panel.runModal() == .OK, let url = panel.url {
      mailRoot = url.path
      Task {
        try? await StellarBackend.setUIPref(root: url.path, key: "mail_root", value: url.path)
      }
      refresh()
      tickTransportIfStale(force: true)
    }
  }

  func installSimpleX() {
    let root = mailRoot
    runMessageAction(status: "SimpleX CLI install checked") {
      try await StellarBackend.runJSON(action: "install-simplex-cli", root: root, args: [])
    }
  }

  func provisionSimpleX() {
    let root = mailRoot
    runMessageAction(status: "SimpleX profile provisioned") {
      try await StellarBackend.runJSON(action: "provision-simplex-identity", root: root, args: ["default", "Stellar", "Stellar"])
    }
  }

  func configureSimpleXLocalTransport() {
    let root = mailRoot
    runMessageAction(status: "Local SimpleX transport enabled") {
      try await StellarBackend.runJSON(action: "configure-simplex-local-transport", root: root, args: ["default"])
    }
  }

  func tickSimpleX() {
    tickTransportIfStale(force: true, notify: true)
    showStatus("SimpleX incoming queue check started")
  }

  func perform(action: String) {
    switch action {
      case "focus_new":
        runSymbolicAction("focus_new")
      case "focus_inbox":
        runSymbolicAction("focus_inbox")
      case "focus_mail":
        runSymbolicAction("focus_mail")
      case "focus_archive":
        runSymbolicAction("focus_archive")
      case "focus_favorites":
        runSymbolicAction("focus_favorites")
      case "focus_people":
        runSymbolicAction("focus_people")
      case "focus_groups":
        runSymbolicAction("focus_groups")
      case "send_message":
        runSymbolicAction("send_message")
      case "archive_message":
        runSymbolicAction("archive_message")
      case "delete_message":
        runSymbolicAction("delete_message")
      case "toggle_star":
        runSymbolicAction("toggle_star")
      case "mark_read":
        runSymbolicAction("mark_read")
      case "open_settings":
        runSymbolicAction("open_settings")
      case "choose_mail_root":
        runSymbolicAction("choose_mail_root")
      case "install_simplex_cli":
        runSymbolicAction("install_simplex_cli")
      case "provision_simplex_identity":
        runSymbolicAction("provision_simplex_identity")
      case "configure_simplex_local_transport":
        runSymbolicAction("configure_simplex_local_transport")
      case "tick_simplex":
        runSymbolicAction("tick_simplex")
      case "bind_contact":
        runSymbolicAction("bind_contact")
      case "compose_simplex":
        runSymbolicAction("compose_simplex")
      case "compose_email":
        runSymbolicAction("compose_email")
      case "quit_app":
        runSymbolicAction("quit_app")
      default:
        showStatus("Unsupported action: \(action)", isError: true)
    }
  }

  private func runSymbolicAction(_ action: String) {
    switch action {
      case "focus_new":
        openNewSenders()
      case "focus_inbox":
        openInbox(focusing: nil)
      case "focus_mail":
        openMail()
      case "focus_archive":
        openArchive()
      case "focus_drafts":
        openDrafts()
      case "focus_events":
        openEvents()
      case "focus_settings":
        openSettingsRoute()
      case "focus_favorites":
        if let first = snapshot.favorites.first { selectThread(first) }
      case "focus_people":
        if let first = snapshot.individuals.first { selectThread(first) }
      case "focus_groups":
        if let first = snapshot.groups.first { selectThread(first) }
      case let mailboxAction where mailboxAction.hasPrefix("focus_mailbox_"):
        let suffix = String(mailboxAction.dropFirst("focus_mailbox_".count)).replacingOccurrences(of: "_", with: "-")
        if let mailbox = snapshot.mailboxes.first(where: { $0.id == suffix }) {
          openMailbox(mailbox)
        } else {
          selectedRoute = "mailbox:\(suffix)"
          persistSelectedRoute()
        }
      case "open_settings":
        (NSApp.delegate as? StellarAppDelegate)?.showSettingsWindow(nil)
      case "choose_mail_root":
        chooseMailRoot()
      case "setup_folders":
        runBackendAction("settings-setup-folders", status: "Mail folders checked")
      case "compose_simplex":
        selectComposerTransport(.simplex)
      case "compose_email":
        selectComposerTransport(.email)
      case "send_message":
        sendComposedMessage()
      case "archive_selected":
        archiveSelectedMessage()
      case "delete_selected":
        deleteSelectedMessage()
      case "star_selected":
        toggleSelectedStar()
      case "mark_selected_read":
        markSelectedRead()
      case "mark_selected_unread":
        markSelectedUnread()
      case "install_simplex_cli":
        installSimpleX()
      case "provision_simplex_identity":
        provisionSimpleX()
      case "configure_simplex_local_transport":
        configureSimpleXLocalTransport()
      case "tick_simplex":
        tickSimpleX()
      case "bind_contact":
        saveContactBinding()
      case "quit_app":
        NSApplication.shared.terminate(nil)
      default:
        showStatus(action.replacingOccurrences(of: "_", with: " ").capitalized)
    }
  }
}

private enum StellarBackend {
  static func uiPrefs(root: String) async throws -> UIPrefs {
    let data = try await runJSON(action: "get-ui-prefs", root: root, args: [])
    return try JSONDecoder().decode(UIPrefs.self, from: data)
  }

  static func setUIPref(root: String, key: String, value: String) async throws {
    _ = try await runJSON(action: "set-ui-pref", root: root, args: [key, value])
  }

  static func snapshot(root: String) async throws -> Snapshot {
    let data = try await runJSON(action: "snapshot", root: root, args: [])
    return try JSONDecoder().decode(Snapshot.self, from: data)
  }

  static func tickSimpleX(root: String) async throws -> SimpleXTickResponse {
    let data = try await runJSON(action: "tick-simplex", root: root, args: [])
    return try JSONDecoder().decode(SimpleXTickResponse.self, from: data)
  }

  static func bootstrapStatus(root: String) async throws -> SimpleXBootstrap {
    let data = try await runJSON(action: "bootstrap-status", root: root, args: ["default"])
    return try JSONDecoder().decode(SimpleXBootstrap.self, from: data)
  }

  static func send(root: String, threadID: String, transport: Transport, subject: String, body: String) async throws -> Data {
    let body64 = Data(body.utf8).base64EncodedString()
    return try await runJSON(action: "send-message", root: root, args: [threadID, transport.rawValue, subject, body64])
  }

  static func sendAttachment(root: String, threadID: String, transport: Transport, subject: String, body: String, attachmentPath: String) async throws -> Data {
    let body64 = Data(body.utf8).base64EncodedString()
    return try await runJSON(action: "send-attachment", root: root, args: [threadID, transport.rawValue, subject, body64, attachmentPath])
  }

  static func messageTrashFiles(root: String, messageID: String) async throws -> TrashFilesResponse {
    let data = try await runJSON(action: "message-trash-files", root: root, args: [messageID])
    return try JSONDecoder().decode(TrashFilesResponse.self, from: data)
  }

  static func runJSON(action: String, root: String, args: [String]) async throws -> Data {
    try await Task.detached(priority: .userInitiated) {
      try run(action: action, root: root, args: args)
    }.value
  }

  private static func run(action: String, root: String, args: [String]) throws -> Data {
    guard let script = resolveBackendScript() else {
      throw NSError(domain: "StellarBackend", code: 1, userInfo: [NSLocalizedDescriptionKey: "Stellar backend script could not be resolved."])
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = [script.path, action, root] + args

    let fm = FileManager.default
    let temp = fm.temporaryDirectory
    let stdoutURL = temp.appendingPathComponent("stellar-stdout-\(UUID().uuidString).json")
    let stderrURL = temp.appendingPathComponent("stellar-stderr-\(UUID().uuidString).log")
    fm.createFile(atPath: stdoutURL.path, contents: nil)
    fm.createFile(atPath: stderrURL.path, contents: nil)
    let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
    let stderrHandle = try FileHandle(forWritingTo: stderrURL)
    defer {
      stdoutHandle.closeFile()
      stderrHandle.closeFile()
      try? fm.removeItem(at: stdoutURL)
      try? fm.removeItem(at: stderrURL)
    }
    process.standardOutput = stdoutHandle
    process.standardError = stderrHandle
    try process.run()
    process.waitUntilExit()

    let out = (try? Data(contentsOf: stdoutURL)) ?? Data()
    let err = (try? Data(contentsOf: stderrURL)) ?? Data()
    guard process.terminationStatus == 0 else {
      let message = String(data: err, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        ?? String(data: out, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        ?? "Backend command failed."
      throw NSError(domain: "StellarBackend", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message])
    }
    return out
  }

  private static func resolveBackendScript() -> URL? {
    let fm = FileManager.default
    var candidates: [URL] = []
    if let override = ProcessInfo.processInfo.environment["STELLAR_BACKEND"], !override.isEmpty {
      candidates.append(URL(fileURLWithPath: override))
    }
    if let resourceURL = Bundle.main.resourceURL {
      candidates.append(resourceURL.appendingPathComponent("scripts/stellar-backend.sh"))
      candidates.append(resourceURL.appendingPathComponent("stellar/scripts/stellar-backend.sh"))
    }
    let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
    candidates.append(cwd.appendingPathComponent("../../scripts/stellar-backend.sh").standardizedFileURL)
    candidates.append(cwd.appendingPathComponent("scripts/stellar-backend.sh").standardizedFileURL)
    candidates.append(fm.homeDirectoryForCurrentUser.appendingPathComponent("git/stellar/scripts/stellar-backend.sh"))
    return candidates.first(where: { fm.isExecutableFile(atPath: $0.path) || fm.fileExists(atPath: $0.path) })
  }
}

private struct RootView: View {
  @EnvironmentObject private var session: StellarSession

  var body: some View {
    Group {
      if session.hasLoadedInitialSnapshot {
        VStack(spacing: 0) {
          MainContentView()
        }
        .overlay(alignment: .top) {
          ToastOverlay()
            .padding(.top, 12)
        }
        .overlay(alignment: .bottom) {
          if session.selectedRoute == "new" {
            SenderDropDock()
              .padding(.bottom, 24)
          } else if showsMessageDropDock {
            MessageDropDock()
              .padding(.bottom, 24)
              .zIndex(session.draggingMessageID == nil ? 10 : 0)
          }
        }
      } else {
        StartupSplashView()
      }
    }
  }

  private var showsMessageDropDock: Bool {
    session.selectedRoute == "inbox" ||
      session.selectedRoute == "inbox-message"
  }
}

private struct StartupSplashView: View {
  var body: some View {
    VStack {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .scaledToFit()
        .frame(width: 96, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 5)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
  }
}

private struct ToastOverlay: View {
  @EnvironmentObject private var session: StellarSession

  var body: some View {
    if session.toastVisible {
      HStack(spacing: 8) {
        if session.toastBusy {
          ProgressView()
            .scaleEffect(0.62)
        }
        Text(session.toastMessage)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.primary)
          .lineLimit(2)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(.thinMaterial, in: Capsule())
      .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
      .frame(maxWidth: 340, alignment: .center)
      .transition(.move(edge: .top).combined(with: .opacity))
    }
  }
}

private enum MessageDropAction {
  case trash
  case archive

  var label: String {
    switch self {
    case .trash: return "Trash"
    case .archive: return "Archive"
    }
  }

  var systemImage: String {
    switch self {
    case .trash: return "trash"
    case .archive: return "archivebox"
    }
  }
}

private enum SenderDropAction {
  case accept
  case reject
  case spam

  var label: String {
    switch self {
    case .accept: return "Accept"
    case .reject: return "Reject"
    case .spam: return "Spam"
    }
  }

  var destinationList: String {
    switch self {
    case .accept: return "accepted"
    case .reject: return "spam"
    case .spam: return "banned"
    }
  }

  var systemImage: String {
    switch self {
    case .accept: return "checkmark"
    case .reject: return "xmark"
    case .spam: return "exclamationmark"
    }
  }

  var tint: Color {
    switch self {
    case .accept: return .green
    case .reject: return .orange
    case .spam: return .red
    }
  }
}

private struct SenderDropDock: View {
  var body: some View {
    HStack(alignment: .bottom, spacing: 16) {
      SenderDropTarget(action: .reject)
      Spacer()
      SenderDropTarget(action: .accept)
      Spacer()
      SenderDropTarget(action: .spam)
    }
    .padding(.horizontal, 22)
    .frame(maxWidth: .infinity)
    .allowsHitTesting(true)
  }
}

private struct SenderDropTarget: View {
  @EnvironmentObject private var session: StellarSession
  let action: SenderDropAction
  @State private var isTargeted = false

  var body: some View {
    ZStack {
      Circle()
        .fill(action.tint.opacity(isTargeted ? 0.24 : 0.15))
      Image(systemName: action.systemImage)
        .font(.title3.weight(.bold))
        .foregroundStyle(action.tint)
    }
    .frame(width: 54, height: 54)
    .contentShape(Circle())
    .shadow(color: action.tint.opacity(isTargeted ? 0.24 : 0.10), radius: isTargeted ? 9 : 4, x: 0, y: 3)
    .scaleEffect(isTargeted ? 1.08 : 1.0)
    .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isTargeted)
    .onDrop(of: [UTType.plainText], isTargeted: $isTargeted, perform: handleDrop(providers:))
    .help("Drop a new sender pile to \(action.label.lowercased()) it")
    .accessibilityLabel(action.label)
  }

  private func handleDrop(providers: [NSItemProvider]) -> Bool {
    guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
      return false
    }
    provider.loadObject(ofClass: NSString.self) { object, _ in
      guard let rawValue = object as? String, rawValue.hasPrefix(senderDragPayloadPrefix) else { return }
      let threadID = String(rawValue.dropFirst(senderDragPayloadPrefix.count))
      Task { @MainActor in
        session.handleSenderDrop(threadID: threadID, action: action)
      }
    }
    return true
  }
}

private struct MessageDropDock: View {
  @EnvironmentObject private var session: StellarSession

  var body: some View {
    HStack(alignment: .bottom) {
      MessageDropTarget(action: .trash)
        .contextMenu {
          Button {
            session.undoLastTrashAction()
          } label: {
            Label("Undo Last Trash", systemImage: "arrow.uturn.backward")
          }
          .disabled(!session.canUndoLastTrashAction)
          Button {
            session.openSystemTrash()
          } label: {
            Label("Open System Trash", systemImage: "trash")
          }
        }
      Spacer()
      MessageDropTarget(action: .archive)
    }
    .padding(.horizontal, 22)
    .frame(maxWidth: .infinity)
    .allowsHitTesting(true)
  }
}

private struct MessageDropTarget: View {
  @EnvironmentObject private var session: StellarSession
  let action: MessageDropAction
  @State private var isTargeted = false

  var body: some View {
    ZStack {
      Circle()
        .fill(backgroundColor)
      icon
        .font(.title3.weight(.semibold))
        .foregroundStyle(iconColor)
    }
    .frame(width: 54, height: 54)
    .contentShape(Circle())
    .shadow(color: iconColor.opacity(isTargeted ? 0.28 : 0.16), radius: isTargeted ? 9 : 5, x: 0, y: 3)
    .scaleEffect(isTargeted ? 1.10 : 1.0)
    .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isTargeted)
    .onDrop(of: [UTType.plainText], isTargeted: $isTargeted, perform: handleDrop(providers:))
    .help("Drop a message card to \(action.label.lowercased()) it")
    .accessibilityLabel(action.label)
  }

  @ViewBuilder
  private var icon: some View {
    switch action {
    case .trash:
      PrioritiesTrashIcon()
        .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .frame(width: 28, height: 28)
    case .archive:
      Image(systemName: action.systemImage)
    }
  }

  private var iconColor: Color {
    switch action {
    case .trash: return .white
    case .archive: return .purple
    }
  }

  private var backgroundColor: Color {
    switch action {
    case .trash:
      return isTargeted ? Color.red.opacity(0.92) : Color.red.opacity(0.78)
    case .archive:
      return isTargeted ? Color.purple.opacity(0.24) : Color.purple.opacity(0.15)
    }
  }

  private func handleDrop(providers: [NSItemProvider]) -> Bool {
    guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
      return false
    }
    provider.loadObject(ofClass: NSString.self) { object, _ in
      guard let rawValue = object as? String else { return }
      let messageID: String
      if rawValue.hasPrefix(messageDragPayloadPrefix) {
        messageID = String(rawValue.dropFirst(messageDragPayloadPrefix.count))
      } else {
        messageID = rawValue
      }
      Task { @MainActor in
        session.handleMessageDrop(id: messageID, action: action)
      }
    }
    return true
  }
}

private struct PrioritiesTrashIcon: Shape {
  func path(in rect: CGRect) -> Path {
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: rect.minX + (x / 24.0) * rect.width, y: rect.minY + (y / 24.0) * rect.height)
    }

    var path = Path()
    path.move(to: point(4, 7))
    path.addLine(to: point(20, 7))
    path.move(to: point(10, 11))
    path.addLine(to: point(10, 17))
    path.move(to: point(14, 11))
    path.addLine(to: point(14, 17))
    path.move(to: point(5, 7))
    path.addLine(to: point(6, 19))
    path.addQuadCurve(to: point(8, 21), control: point(6, 21))
    path.addLine(to: point(16, 21))
    path.addQuadCurve(to: point(18, 19), control: point(18, 21))
    path.addLine(to: point(19, 7))
    path.move(to: point(9, 7))
    path.addLine(to: point(9, 4))
    path.addQuadCurve(to: point(10, 3), control: point(9, 3))
    path.addLine(to: point(14, 3))
    path.addQuadCurve(to: point(15, 4), control: point(15, 3))
    path.addLine(to: point(15, 7))
    return path
  }
}

private struct DraggableMessageCardModifier: ViewModifier {
  @EnvironmentObject private var session: StellarSession
  @State private var dragOffset: CGSize = .zero
  @State private var isPointerDragging = false
  let message: MessageItem

  func body(content: Content) -> some View {
    content
      .offset(dragOffset)
      .rotationEffect(.degrees(Double(dragOffset.width / 34.0)))
      .opacity(cardOpacity)
      .zIndex(isPointerDragging ? 20 : 0)
      .simultaneousGesture(cardDragGesture)
      .animation(.spring(response: 0.24, dampingFraction: 0.82), value: dragOffset)
      .onDrag {
        session.beginDraggingMessage(message)
        return NSItemProvider(object: "\(messageDragPayloadPrefix)\(message.id)" as NSString)
      }
  }

  private var cardOpacity: Double {
    if isPointerDragging {
      return max(0.64, 1.0 - Double(abs(dragOffset.width) / 620.0))
    }
    return session.draggingMessageID == message.id ? 0 : 1
  }

  private var cardDragGesture: some Gesture {
    DragGesture(minimumDistance: 4)
      .onChanged { value in
        if !isPointerDragging {
          isPointerDragging = true
          session.beginDraggingMessage(message)
        }
        dragOffset = value.translation
      }
      .onEnded { value in
        let actual = value.translation.width
        let projected = value.predictedEndTranslation.width
        let isIntentionalFlick = abs(actual) > 150 || (abs(actual) > 86 && abs(projected) > 300 && actual * projected > 0)
        let shouldFlickArchive = message.in_inbox && isIntentionalFlick
        if shouldFlickArchive {
          dragOffset = CGSize(width: actual >= 0 ? 980 : -980, height: value.translation.height)
          session.archive(message)
          Task {
            try? await Task.sleep(nanoseconds: 260_000_000)
            dragOffset = .zero
            isPointerDragging = false
            session.endDraggingMessage(message.id)
          }
        } else {
          dragOffset = .zero
          isPointerDragging = false
          session.endDraggingMessage(message.id)
        }
      }
  }
}

private extension View {
  func draggableMessageCard(_ message: MessageItem) -> some View {
    modifier(DraggableMessageCardModifier(message: message))
  }

  @ViewBuilder
  func matchedInboxCardGeometry(_ id: String, in namespace: Namespace.ID?) -> some View {
    if let namespace {
      matchedGeometryEffect(id: "inbox-card:\(id)", in: namespace, properties: .frame)
    } else {
      self
    }
  }
}

private struct PrimaryTabBar: View {
  @EnvironmentObject private var session: StellarSession

  var body: some View {
    Group {
      if session.hasLoadedInitialSnapshot {
        HStack(spacing: 8) {
          TabButton(title: "New Senders", systemImage: "tray.and.arrow.down", count: session.newSenderThreads.count, selected: session.selectedRoute == "new") {
            session.openNewSenders()
          }
          TabButton(title: "Inbox", systemImage: "tray.full", count: session.snapshot.inbox.count, selected: session.selectedRoute == "inbox" || session.selectedRoute == "inbox-message") {
            session.openInbox(focusing: nil)
          }
          TabButton(title: "Mail", systemImage: "envelope", selected: session.selectedRoute == "mail") {
            session.openMail()
          }
          ArchiveTabButton(selected: session.selectedRoute == "archive") {
            session.openArchive()
          }
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
      } else {
        Color.clear
      }
    }
    .frame(width: 500, height: 34, alignment: .leading)
  }
}

private struct ArchiveTabButton: View {
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 7) {
        Image(systemName: "archivebox")
          .font(.callout.weight(selected ? .semibold : .regular))
        Text("Archive")
          .font(.callout.weight(.semibold))
          .opacity(selected ? 1 : 0)
      }
      .frame(width: 82)
      .padding(.horizontal, 9)
      .padding(.vertical, 6)
      .background(Capsule().fill(selected ? Color.accentColor.opacity(0.16) : Color.clear))
    }
    .buttonStyle(.plain)
    .help("Archive")
  }
}

private struct TabButton: View {
  let title: String
  let systemImage: String
  var count: Int? = nil
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 7) {
        Image(systemName: systemImage)
          .font(.callout.weight(selected ? .semibold : .regular))
        Text(title)
          .font(.callout.weight(selected ? .semibold : .regular))
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: false)
        if let count {
          CountBadge(count: count)
        }
      }
      .frame(height: 26)
      .padding(.horizontal, 12)
      .background(Capsule().fill(selected ? Color.accentColor.opacity(0.16) : Color.clear))
    }
    .buttonStyle(.plain)
    .fixedSize()
  }
}

private struct SidebarView: View {
  @EnvironmentObject private var session: StellarSession
  @Namespace private var threadMoveNamespace

  var body: some View {
    List(selection: $session.selectedRoute) {
      Section {
        SidebarInboxRow()
          .tag("inbox")
      }
      Section("Mailboxes") {
        ForEach(session.snapshot.mailboxes) { mailbox in
          SidebarMailboxRow(mailbox: mailbox)
            .tag("mailbox:\(mailbox.id)")
            .onTapGesture { session.openMailbox(mailbox) }
        }
        SidebarUtilityRow(title: "Drafts", systemImage: "square.and.pencil", count: session.snapshot.drafts.count)
          .tag("drafts")
          .onTapGesture { session.openDrafts() }
        SidebarUtilityRow(title: "Events", systemImage: "waveform.path.ecg", count: session.snapshot.events.count)
          .tag("events")
          .onTapGesture { session.openEvents() }
      }
      if !favoriteThreads.isEmpty {
        Section("Favorites") {
          ForEach(favoriteThreads) { thread in
            sidebarThreadRow(thread)
          }
        }
      }
      Section("Individuals") {
        ForEach(individualThreads) { thread in
          sidebarThreadRow(thread)
        }
      }
      Section {
        Divider()
      }
      Section("Groups") {
        ForEach(groupThreads) { thread in
          sidebarThreadRow(thread)
        }
      }
      Section {
        SidebarUtilityRow(title: "Settings", systemImage: "gearshape", count: 0)
          .tag("settings")
          .onTapGesture { session.openSettingsRoute() }
      }
    }
    .listStyle(.sidebar)
    .animation(.spring(response: 0.30, dampingFraction: 0.86), value: favoriteThreadIDs)
    .animation(.spring(response: 0.30, dampingFraction: 0.86), value: individualThreadIDs)
    .animation(.spring(response: 0.30, dampingFraction: 0.86), value: groupThreadIDs)
  }

  private var favoriteThreads: [ThreadItem] {
    uniqueThreads(session.snapshot.favorites + session.snapshot.individuals.filter { $0.favorite } + session.snapshot.groups.filter { $0.favorite })
  }

  private var individualThreads: [ThreadItem] {
    session.snapshot.individuals.filter { !favoriteThreadIDs.contains($0.id) && !$0.favorite }
  }

  private var groupThreads: [ThreadItem] {
    session.snapshot.groups.filter { !favoriteThreadIDs.contains($0.id) && !$0.favorite }
  }

  private var favoriteThreadIDs: [String] {
    favoriteThreads.map(\.id)
  }

  private var individualThreadIDs: [String] {
    individualThreads.map(\.id)
  }

  private var groupThreadIDs: [String] {
    groupThreads.map(\.id)
  }

  private func uniqueThreads(_ threads: [ThreadItem]) -> [ThreadItem] {
    var seen = Set<String>()
    return threads.filter { thread in
      if seen.contains(thread.id) {
        return false
      }
      seen.insert(thread.id)
      return true
    }
  }

  private func sidebarThreadRow(_ thread: ThreadItem) -> some View {
    SidebarThreadRow(thread: thread)
      .matchedGeometryEffect(id: thread.id, in: threadMoveNamespace, properties: .position)
      .tag("thread:\(thread.id)")
      .onTapGesture { session.selectThread(thread) }
  }
}

private struct SidebarInboxRow: View {
  @EnvironmentObject private var session: StellarSession

  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: "tray.full")
      Text("Inbox")
      Spacer()
      CountBadge(count: session.inboxUnreadCount)
    }
    .contentShape(Rectangle())
    .onTapGesture { session.openInbox(focusing: nil) }
  }
}

private struct SidebarThreadRow: View {
  @EnvironmentObject private var session: StellarSession
  @FocusState private var nameFieldFocused: Bool
  @State private var isRenaming = false
  @State private var isAttachmentTargeted = false
  @State private var draftName = ""
  let thread: ThreadItem
  var showsTemporalDistance = false

  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: thread.kind == "group" ? "person.3.fill" : "person.fill")
        .foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 2) {
        if isRenaming {
          TextField("Name", text: $draftName)
            .textFieldStyle(.plain)
            .focused($nameFieldFocused)
            .onSubmit { commitRename() }
            .onChange(of: nameFieldFocused) { focused in
              if !focused {
                commitRename()
              }
            }
        } else {
          Text(thread.displayName)
            .lineLimit(1)
            .onTapGesture(count: 2) {
              beginRename()
            }
        }
        HStack(spacing: 5) {
          if thread.hasSimpleXPath {
            Image(systemName: "lock.fill")
          }
          if thread.hasEmailPath {
            Image(systemName: "lock.open")
          }
          Text(thread.latest_at.isEmpty ? "No messages" : friendlyTime(thread.latest_at))
            .lineLimit(1)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
      }
      Spacer()
      if showsTemporalDistance, session.showTemporalDistance {
        TemporalDistanceBadge(thread: thread)
      }
      CountBadge(count: thread.unread_count)
    }
    .padding(.vertical, 2)
    .background {
      if isAttachmentTargeted {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .fill(Color.accentColor.opacity(0.12))
      }
    }
    .onDrop(of: [UTType.fileURL], isTargeted: $isAttachmentTargeted) { providers in
      session.attachDroppedFiles(providers, selecting: thread)
    }
    .onChange(of: thread.displayName) { nextName in
      if !isRenaming {
        draftName = nextName
      }
    }
  }

  private func beginRename() {
    draftName = thread.displayName
    isRenaming = true
    Task { @MainActor in
      try? await Task.sleep(nanoseconds: 50_000_000)
      nameFieldFocused = true
    }
  }

  private func commitRename() {
    guard isRenaming else { return }
    isRenaming = false
    nameFieldFocused = false
    session.renameContact(thread, to: draftName)
  }
}

private struct SidebarMailboxRow: View {
  let mailbox: MailboxItem

  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: mailboxIcon)
        .foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 2) {
        Text(mailbox.title)
          .lineLimit(1)
        Text("\(mailbox.count) message\(mailbox.count == 1 ? "" : "s")")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Spacer()
      CountBadge(count: mailbox.unread)
    }
  }

  private var mailboxIcon: String {
    switch mailbox.id {
    case "accepted": return "tray"
    case "quarantine": return "tray.and.arrow.down"
    case "spam": return "exclamationmark.octagon"
    case "banned": return "hand.raised"
    case "archive": return "archivebox"
    case "sent": return "paperplane"
    case "outbox": return "tray.and.arrow.up"
    case "trash": return "trash"
    default: return "folder"
    }
  }
}

private struct SidebarUtilityRow: View {
  let title: String
  let systemImage: String
  let count: Int

  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: systemImage)
        .foregroundStyle(.secondary)
      Text(title)
      Spacer()
      CountBadge(count: count)
    }
  }
}

private struct CountBadge: View {
  let count: Int

  var body: some View {
    if count > 0 {
      Text("\(count)")
        .font(.caption2.weight(.semibold))
        .frame(minWidth: 18, minHeight: 16)
        .background(Capsule().fill(Color.accentColor.opacity(0.16)))
        .foregroundStyle(Color.accentColor)
        .fixedSize(horizontal: true, vertical: false)
    }
  }
}

private struct TemporalDistanceBadge: View {
  @EnvironmentObject private var session: StellarSession
  let thread: ThreadItem

  var body: some View {
    if let seconds = session.effectiveTemporalDistance(for: thread) {
      Button {
        session.increaseTemporalDistance(for: thread)
      } label: {
        HStack(spacing: 3) {
          Image(systemName: thread.temporal_distance_seconds == nil ? "clock" : "clock.badge.checkmark")
          Text(TemporalDistance.label(seconds))
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(thread.temporal_distance_seconds == nil ? Color.secondary : Color.accentColor)
        .fixedSize(horizontal: true, vertical: false)
      }
      .buttonStyle(.plain)
      .contextMenu {
        Button { session.decreaseTemporalDistance(for: thread) } label: {
          Label("Decrease", systemImage: "minus")
        }
        Button { session.increaseTemporalDistance(for: thread) } label: {
          Label("Increase", systemImage: "plus")
        }
        Button { session.setTemporalDistance(for: thread, seconds: nil) } label: {
          Label("Automatic", systemImage: "wand.and.stars")
        }
      }
      .help(session.temporalDistanceHelp(for: thread))
      .accessibilityLabel("Temporal distance \(TemporalDistance.label(seconds))")
    }
  }
}

private struct MainContentView: View {
  @EnvironmentObject private var session: StellarSession
  @Namespace private var inboxCardNamespace

  var body: some View {
    Group {
      if session.selectedRoute == "new" {
        NewSendersView()
      } else if session.selectedRoute == "inbox" {
        InboxView(animationNamespace: inboxCardNamespace)
      } else if session.selectedRoute == "inbox-message" {
        MessageReaderView(message: session.activeMessage, emptyTitle: "No Inbox Message Selected", animationNamespace: inboxCardNamespace)
      } else if session.selectedRoute == "archive" {
        MailboxView()
      } else if session.selectedRoute == "mail" || session.selectedRoute.hasPrefix("mailbox:") {
        MailView()
      } else {
        NewSendersView()
      }
    }
    .transition(.opacity)
    .animation(.easeInOut(duration: 0.24), value: session.selectedRoute)
    .animation(.easeInOut(duration: 0.24), value: session.focusedMessageID)
  }
}

private enum NewSendersFlowStage {
  case senders
  case messages
  case reader
}

private struct MessageSurfaceBackground: View {
  let tint: Color
  let tintOpacity: Double
  let controlOpacity: Double

  init(
    tint: Color,
    tintOpacity: Double,
    controlOpacity: Double = 0.94
  ) {
    self.tint = tint
    self.tintOpacity = tintOpacity
    self.controlOpacity = controlOpacity
  }

  var body: some View {
    RoundedRectangle(cornerRadius: 14, style: .continuous)
      .fill(Color(nsColor: .controlBackgroundColor).opacity(controlOpacity))
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(tint.opacity(tintOpacity))
      }
  }
}

private struct CardStackFrame<Content: View>: View {
  let depth: Int
  let badge: String?
  let tint: Color
  let isSelected: Bool
  let width: CGFloat
  let minHeight: CGFloat
  let content: Content

  init(
    depth: Int = 1,
    badge: String? = nil,
    tint: Color = .accentColor,
    isSelected: Bool = false,
    width: CGFloat = 420,
    minHeight: CGFloat = 315,
    @ViewBuilder content: () -> Content
  ) {
    self.depth = depth
    self.badge = badge
    self.tint = tint
    self.isSelected = isSelected
    self.width = width
    self.minHeight = minHeight
    self.content = content()
  }

  private var backCount: Int {
    min(max(depth - 1, 0), 4)
  }

  private var stackBadgeText: String? {
    guard depth > 3, let badge, !badge.isEmpty else { return nil }
    return badge
  }

  private var cardBackground: some View {
    MessageSurfaceBackground(
      tint: tint,
      tintOpacity: isSelected ? 0.082 : 0.050,
      controlOpacity: isSelected ? 0.98 : 0.95
    )
  }

  private func stackedFill(_ index: Int) -> LinearGradient {
    LinearGradient(
      colors: [
        tint.opacity(0.055 - Double(index) * 0.006),
        Color(nsColor: .controlBackgroundColor).opacity(0.98)
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  var body: some View {
    content
      .frame(maxWidth: .infinity, minHeight: max(0, minHeight - 28), alignment: .topLeading)
      .padding(14)
      .frame(width: width, alignment: .topLeading)
      .frame(minHeight: minHeight, alignment: .topLeading)
      .fixedSize(horizontal: true, vertical: false)
      .background(
        cardBackground
      )
      .background {
        ZStack {
          ForEach(0..<backCount, id: \.self) { index in
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(stackedFill(index))
              .shadow(color: Color.black.opacity(0.13), radius: 5, x: 0, y: 2)
              .offset(x: stackOffsetX(index), y: -CGFloat(index + 1) * 5.4)
              .rotationEffect(.degrees(stackRotation(index)))
          }
        }
      }
      .overlay(alignment: .topTrailing) {
        if let badge = stackBadgeText {
          Text(badge)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.86)))
            .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
            .offset(x: 8, y: -8)
        }
      }
      .shadow(color: tint.opacity(isSelected ? 0.10 : 0.05), radius: isSelected ? 10 : 7, x: 0, y: 4)
      .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
  }

  private func stackRotation(_ index: Int) -> Double {
    [-4.2, 3.6, -3.0, 2.4][index % 4]
  }

  private func stackOffsetX(_ index: Int) -> CGFloat {
    [-8.0, 6.0, -5.0, 4.0][index % 4]
  }
}

private struct StaticCardStackBackplates: View {
  let depth: Int
  let tint: Color
  let width: CGFloat
  let minHeight: CGFloat

  private var backCount: Int {
    min(max(depth - 1, 0), 4)
  }

  var body: some View {
    ZStack {
      ForEach(0..<backCount, id: \.self) { index in
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(stackedFill(index))
          .frame(width: width, height: minHeight)
          .shadow(color: Color.black.opacity(0.13), radius: 5, x: 0, y: 2)
          .offset(x: stackOffsetX(index), y: -CGFloat(index + 1) * 5.4)
          .rotationEffect(.degrees(stackRotation(index)))
      }
    }
    .allowsHitTesting(false)
  }

  private func stackedFill(_ index: Int) -> LinearGradient {
    LinearGradient(
      colors: [
        tint.opacity(0.055 - Double(index) * 0.006),
        Color(nsColor: .controlBackgroundColor).opacity(0.98)
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private func stackRotation(_ index: Int) -> Double {
    [-4.2, 3.6, -3.0, 2.4][index % 4]
  }

  private func stackOffsetX(_ index: Int) -> CGFloat {
    0
  }
}

private struct NewSendersView: View {
  @EnvironmentObject private var session: StellarSession
  @State private var stage: NewSendersFlowStage = .senders

  var selectedMessage: MessageItem? {
    if let id = session.selectedMessageID, let match = session.newSenderMessages.first(where: { $0.id == id }) {
      return match
    }
    return session.newSenderMessages.first
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if stage != .senders {
        newSendersHeader
        Divider()
      }
      Group {
        switch stage {
        case .senders:
          NewSenderStackSurface(stage: $stage)
        case .messages:
          NewSenderMessageStackSurface(stage: $stage)
        case .reader:
          NewSenderReaderSurface(message: selectedMessage)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private var newSendersHeader: some View {
    HStack(alignment: .center, spacing: 12) {
      if stage != .senders {
        Button {
          stage = stage == .reader ? .messages : .senders
        } label: {
          Label("Back", systemImage: "chevron.left")
        }
        .fixedSize()
      }
      Spacer()
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
  }

  private var headerTitle: String {
    switch stage {
    case .senders:
      return "New Senders"
    case .messages:
      return session.selectedNewSender?.displayName ?? "Messages"
    case .reader:
      return selectedMessage?.subject.isEmpty == false ? selectedMessage?.subject ?? "Message" : "Message"
    }
  }

  private var headerSubtitle: String {
    switch stage {
    case .senders:
      return "\(session.newSenderThreads.count) sender\(session.newSenderThreads.count == 1 ? "" : "s")"
    case .messages:
      return "\(session.newSenderMessages.count) quarantined message\(session.newSenderMessages.count == 1 ? "" : "s")"
    case .reader:
      return selectedMessage.map { "\($0.contact_name) - \(friendlyTime($0.received_at))" } ?? "No message selected"
    }
  }
}

private struct NewSenderStackSurface: View {
  @EnvironmentObject private var session: StellarSession
  @Binding var stage: NewSendersFlowStage
  @State private var expandedSenderID: String?

  var body: some View {
    ScrollView {
      if session.newSenderThreads.isEmpty {
        EmptyStateView(title: "No New Senders", subtitle: "New sender cards will appear here.")
          .frame(maxWidth: .infinity, minHeight: 360)
      } else {
        LazyVStack(spacing: 30) {
          ForEach(session.newSenderThreads) { thread in
            NewSenderRealPile(
              thread: thread,
              messages: quarantineMessages(for: thread),
              isSelected: session.selectedNewSenderID == thread.id,
              isExpanded: expandedSenderID == thread.id
            ) { message in
              session.selectNewSender(thread)
              if expandedSenderID == thread.id {
                session.selectMessage(message)
                stage = .reader
              } else {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                  expandedSenderID = thread.id
                }
              }
            } collapseBeforeDrag: {
              if expandedSenderID == thread.id {
                withAnimation(.spring(response: 0.20, dampingFraction: 0.88)) {
                  expandedSenderID = nil
                }
              }
            }
            .frame(maxWidth: 540, alignment: .center)
            .frame(height: pileHeight(for: thread))
          }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
      }
    }
  }

  private func quarantineMessages(for thread: ThreadItem) -> [MessageItem] {
    thread.messages
      .filter { $0.list == "quarantine" }
      .sorted { $0.received_at > $1.received_at }
  }

  private func pileHeight(for thread: ThreadItem) -> CGFloat {
    let count = quarantineMessages(for: thread).count
    guard expandedSenderID == thread.id else { return 330 }
    return max(330, CGFloat(count) * 326)
  }
}

private struct NewSenderRealPile: View {
  let thread: ThreadItem
  let messages: [MessageItem]
  let isSelected: Bool
  let isExpanded: Bool
  let action: (MessageItem) -> Void
  let collapseBeforeDrag: () -> Void

  var body: some View {
    ZStack(alignment: .top) {
      ForEach(messages.indices, id: \.self) { index in
        let message = messages[index]
        NewSenderMessageStackCard(
          message: message,
          isSelected: isSelected && index == 0,
          dragPayload: .senderPile(threadID: thread.id),
          action: {
            action(message)
          },
          collapseBeforeDrag: collapseBeforeDrag
        )
        .id(message.id)
        .offset(x: cardOffsetX(index), y: cardOffsetY(index))
        .rotationEffect(.degrees(cardRotation(index)))
        .zIndex(Double(messages.count - index))
        .allowsHitTesting(isExpanded || index == 0)
      }
      if !isExpanded, messages.count > 3 {
        Text("\(messages.count)")
          .font(.caption.weight(.bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(Capsule().fill(Color.orange.opacity(0.86)))
          .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
          .offset(x: 8, y: -8)
          .frame(maxWidth: .infinity, alignment: .topTrailing)
      }
    }
    .animation(.spring(response: 0.30, dampingFraction: 0.84), value: isExpanded)
  }

  private func cardOffsetX(_ index: Int) -> CGFloat {
    isExpanded ? 0 : [0.0, -8.0, 6.0, -5.0, 4.0][min(index, 4)]
  }

  private func cardOffsetY(_ index: Int) -> CGFloat {
    isExpanded ? CGFloat(index) * 326 : -CGFloat(index) * 5.4
  }

  private func cardRotation(_ index: Int) -> Double {
    isExpanded ? 0 : [0.0, -4.2, 3.6, -3.0, 2.4][min(index, 4)]
  }
}

private struct NewSenderStackCard: View {
  @EnvironmentObject private var session: StellarSession
  @State private var flickOffset: CGFloat = 0
  let thread: ThreadItem
  let isSelected: Bool
  let isExpanded: Bool
  let action: () -> Void
  let collapseBeforeDrag: () -> Void

  private var quarantineMessages: [MessageItem] {
    thread.messages.filter { $0.list == "quarantine" }
  }

  private var latestMessage: MessageItem? {
    quarantineMessages.sorted(by: { $0.received_at > $1.received_at }).first
  }

  var body: some View {
    CardStackFrame(
      depth: max(1, quarantineMessages.count),
      badge: quarantineMessages.count > 3 ? String(quarantineMessages.count) : nil,
      tint: .orange,
      isSelected: isSelected,
      width: latestMessage?.cardWidth ?? 420,
      minHeight: latestMessage?.cardMinHeight ?? 315
    ) {
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
          Image(systemName: thread.kind == "group" ? "person.3.fill" : "person.crop.circle.badge.questionmark")
            .foregroundStyle(.orange)
          Text(thread.displayName)
            .font(.headline)
          Text(friendlyTime(thread.latest_at))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        if let latest = latestMessage {
          Text(latest.subject.isEmpty ? "(no subject)" : latest.subject)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
          Text(latest.displayBody.isEmpty ? latest.preview : latest.displayBody)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(latest.cardBodyLineLimit)
        }
        Spacer(minLength: 8)
        if let latest = latestMessage {
          TransportPill(message: latest)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
      }
    }
    .contentShape(Rectangle())
    .onTapGesture(perform: action)
    .offset(x: flickOffset)
    .rotationEffect(.degrees(Double(flickOffset / 28)))
    .opacity(flickOffset == 0 ? 1 : max(0.58, 1.0 - Double(abs(flickOffset) / 520.0)))
    .simultaneousGesture(newSenderFlickGesture)
    .animation(.spring(response: 0.24, dampingFraction: 0.82), value: flickOffset)
    .animation(.spring(response: 0.28, dampingFraction: 0.84), value: isExpanded)
    .onDrag {
      collapseBeforeDrag()
      return NSItemProvider(object: "\(senderDragPayloadPrefix)\(thread.id)" as NSString)
    }
  }

  private var newSenderFlickGesture: some Gesture {
    DragGesture(minimumDistance: 18)
      .onChanged { value in
        guard abs(value.translation.width) > abs(value.translation.height) else { return }
        collapseBeforeDrag()
        flickOffset = value.translation.width
      }
      .onEnded { value in
        let actual = value.translation.width
        let projected = value.predictedEndTranslation.width
        let isIntentionalFlick = abs(actual) > 145 || (abs(actual) > 84 && abs(projected) > 290 && actual * projected > 0)
        guard isIntentionalFlick else {
          flickOffset = 0
          return
        }
        let destination = actual >= 0 ? "accepted" : "spam"
        flickOffset = actual >= 0 ? 900 : -900
        session.moveNewSender(thread, to: destination)
        Task {
          try? await Task.sleep(nanoseconds: 260_000_000)
          flickOffset = 0
        }
      }
  }
}

private struct NewSenderMessageStackSurface: View {
  @EnvironmentObject private var session: StellarSession
  @Binding var stage: NewSendersFlowStage

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        if session.newSenderMessages.isEmpty {
          EmptyStateView(title: "No Messages", subtitle: "This sender has no pending messages.")
            .frame(maxWidth: .infinity, minHeight: 360)
        } else {
          LazyVStack(spacing: 30) {
            ForEach(session.newSenderMessages) { message in
              NewSenderMessageStackCard(message: message, isSelected: session.selectedMessageID == message.id) {
                session.selectMessage(message)
                stage = .reader
              }
              .id(message.id)
              .frame(maxWidth: 540, alignment: .center)
            }
          }
          .frame(maxWidth: .infinity)
          .padding(24)
        }
      }
      .onAppear {
        if let target = session.selectedMessageID {
          proxy.scrollTo(target, anchor: .center)
        }
      }
    }
  }
}

private struct NewSenderMessageStackCard: View {
  enum DragPayload {
    case message
    case senderPile(threadID: String)
  }

  let message: MessageItem
  let isSelected: Bool
  var dragPayload: DragPayload = .message
  let action: () -> Void
  var collapseBeforeDrag: () -> Void = {}

  var body: some View {
    Button(action: action) {
      CardStackFrame(
        depth: 1,
        tint: message.isSimpleX ? .green : .red,
        isSelected: isSelected,
        width: message.cardWidth,
        minHeight: message.cardMinHeight
      ) {
        VStack(alignment: .leading, spacing: 10) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(message.subject.isEmpty ? "(no subject)" : message.subject)
              .font(.headline)
              .lineLimit(1)
            Spacer(minLength: 10)
            Text(friendlyTime(message.received_at))
              .font(.caption)
              .foregroundStyle(.secondary)
              .help(fullTimestamp(message.received_at))
          }
          Text(message.contact_name)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(message.displayBody.isEmpty ? "No preview" : message.displayBody)
            .font(.body)
            .lineLimit(message.cardBodyLineLimit)
          Spacer(minLength: 8)
          HStack {
            TransportPill(message: message)
            if message.attachments > 0 {
              Label("\(message.attachments)", systemImage: "paperclip")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
          }
        }
      }
    }
    .buttonStyle(.plain)
    .modifier(NewSenderMessageDragModifier(message: message, dragPayload: dragPayload, collapseBeforeDrag: collapseBeforeDrag))
    .contextMenu { MessageContextMenu(message: message) }
  }
}

private struct NewSenderMessageDragModifier: ViewModifier {
  let message: MessageItem
  let dragPayload: NewSenderMessageStackCard.DragPayload
  let collapseBeforeDrag: () -> Void

  func body(content: Content) -> some View {
    switch dragPayload {
    case .message:
      content
        .draggableMessageCard(message)
    case .senderPile(let threadID):
      content
        .simultaneousGesture(
          DragGesture(minimumDistance: 4)
            .onChanged { _ in collapseBeforeDrag() }
        )
        .onDrag {
          collapseBeforeDrag()
          return NSItemProvider(object: "\(senderDragPayloadPrefix)\(threadID)" as NSString)
        }
        .help("Drag to sort this sender pile")
    }
  }
}

private struct NewSenderReaderSurface: View {
  let message: MessageItem?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if let message {
          MessageReaderCard(message: message)
            .frame(maxWidth: 760)
        } else {
          EmptyStateView(title: "No Message Selected", subtitle: "Choose a message card.")
            .frame(maxWidth: .infinity, minHeight: 360)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(24)
    }
  }
}

private struct MailView: View {
  @EnvironmentObject private var session: StellarSession
  @State private var contactListWidth: CGFloat = 290
  @State private var inspectorWidth: CGFloat = 260
  @State private var contactInfoVisible = true

  var body: some View {
    HStack(spacing: 0) {
      ContactListView()
        .frame(width: contactListWidth)
      SidebarResizeDivider(width: $contactListWidth, range: 220...420, edge: .trailing)
      if session.selectedRoute.hasPrefix("mailbox:") {
        MailboxView()
      } else if session.selectedThread != nil {
        TimelineView(inspectorWidth: $inspectorWidth, contactInfoVisible: $contactInfoVisible)
      } else {
        EmptyStateView(title: "No Contact Selected", subtitle: "Choose a contact or group.")
      }
    }
    .animation(.easeInOut(duration: 0.22), value: contactInfoVisible)
  }
}

private enum SidebarResizeEdge {
  case leading
  case trailing
}

private struct SidebarResizeDivider: View {
  @Binding var width: CGFloat
  let range: ClosedRange<CGFloat>
  let edge: SidebarResizeEdge
  @State private var dragStartWidth: CGFloat?
  @State private var cursorIsPushed = false

  var body: some View {
    Rectangle()
      .fill(Color.clear)
      .frame(width: 7)
      .overlay {
        Rectangle()
          .fill(Color.secondary.opacity(0.28))
          .frame(width: 1)
      }
      .contentShape(Rectangle())
      .highPriorityGesture(
        DragGesture(minimumDistance: 2)
          .onChanged { value in
            let startWidth = dragStartWidth ?? width
            dragStartWidth = startWidth
            let delta = edge == .trailing ? value.translation.width : -value.translation.width
            setWidth((startWidth + delta).clamped(to: range))
          }
          .onEnded { _ in
            dragStartWidth = nil
          }
      )
      .transaction { transaction in
        transaction.disablesAnimations = true
        transaction.animation = nil
      }
      .onHover { hovering in
        if hovering, !cursorIsPushed {
          NSCursor.resizeLeftRight.push()
          cursorIsPushed = true
        } else if !hovering, cursorIsPushed {
          NSCursor.pop()
          cursorIsPushed = false
        }
      }
      .onDisappear {
        if cursorIsPushed {
          NSCursor.pop()
          cursorIsPushed = false
        }
      }
      .help("Drag to resize sidebar")
      .accessibilityLabel("Resize sidebar")
  }

  private func setWidth(_ nextWidth: CGFloat) {
    guard abs(width - nextWidth) >= 0.5 else { return }
    var transaction = Transaction()
    transaction.disablesAnimations = true
    transaction.animation = nil
    withTransaction(transaction) {
      width = nextWidth
    }
  }
}

private enum MailContactFilter: String, CaseIterable {
  case all
  case favorites
  case individuals
  case groups

  var title: String {
    switch self {
    case .all: return "All"
    case .favorites: return "Favorites"
    case .individuals: return "Individuals"
    case .groups: return "Groups"
    }
  }
}

private enum MailContactSort: String, CaseIterable {
  case recent
  case alphabetical
  case unread

  var title: String {
    switch self {
    case .recent: return "Recent Activity"
    case .alphabetical: return "Alphabetical"
    case .unread: return "Unread First"
    }
  }
}

private struct ContactListView: View {
  @EnvironmentObject private var session: StellarSession
  @Namespace private var threadMoveNamespace
  @State private var contactFilter: MailContactFilter = .all
  @State private var contactSort: MailContactSort = .recent

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Spacer()
        Menu {
          Section("Show") {
            ForEach(MailContactFilter.allCases, id: \.self) { filter in
              Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                  contactFilter = filter
                }
              } label: {
                if contactFilter == filter {
                  Label(filter.title, systemImage: "checkmark")
                } else {
                  Text(filter.title)
                }
              }
            }
          }
          Section("Sort") {
            ForEach(MailContactSort.allCases, id: \.self) { sort in
              Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                  contactSort = sort
                }
              } label: {
                if contactSort == sort {
                  Label(sort.title, systemImage: "checkmark")
                } else {
                  Text(sort.title)
                }
              }
            }
          }
        } label: {
          Label("Favorites", systemImage: "line.3.horizontal.decrease.circle")
            .labelStyle(.titleAndIcon)
        }
        .menuStyle(.button)
        .fixedSize()
        .help("Filter and sort the Mail list")
      }
      .padding(.horizontal, 10)
      .padding(.top, 8)
      .padding(.bottom, 4)
      List(selection: $session.selectedMailThreadID) {
        if showsFavoritesSection, !favoriteThreads.isEmpty {
          Section("Favorites") {
            ForEach(favoriteThreads) { thread in
              mailThreadRow(thread)
            }
          }
        }
        if showsIndividualsSection {
          Section("Individuals") {
            ForEach(individualThreads) { thread in
              mailThreadRow(thread)
            }
          }
        }
        if showsGroupsSection {
          Section("Groups") {
            ForEach(groupThreads) { thread in
              mailThreadRow(thread)
            }
          }
        }
      }
      .listStyle(.sidebar)
      .animation(.spring(response: 0.30, dampingFraction: 0.86), value: favoriteThreadIDs)
      .animation(.spring(response: 0.30, dampingFraction: 0.86), value: individualThreadIDs)
      .animation(.spring(response: 0.30, dampingFraction: 0.86), value: groupThreadIDs)
      .animation(.spring(response: 0.30, dampingFraction: 0.86), value: contactFilter)
      .animation(.spring(response: 0.30, dampingFraction: 0.86), value: contactSort)
    }
  }

  private func mailThreadRow(_ thread: ThreadItem) -> some View {
    SidebarThreadRow(thread: thread, showsTemporalDistance: true)
      .matchedGeometryEffect(id: thread.id, in: threadMoveNamespace, properties: .position)
      .tag(thread.id)
      .onTapGesture { session.selectThread(thread) }
  }

  private var favoriteThreads: [ThreadItem] {
    sortedThreads(uniqueThreads(session.snapshot.favorites + session.snapshot.individuals.filter { $0.favorite } + session.snapshot.groups.filter { $0.favorite }))
  }

  private var individualThreads: [ThreadItem] {
    sortedThreads(session.snapshot.individuals.filter { !favoriteThreadIDs.contains($0.id) && !$0.favorite })
  }

  private var groupThreads: [ThreadItem] {
    sortedThreads(session.snapshot.groups.filter { !favoriteThreadIDs.contains($0.id) && !$0.favorite })
  }

  private var favoriteThreadIDs: [String] {
    favoriteThreads.map(\.id)
  }

  private var individualThreadIDs: [String] {
    individualThreads.map(\.id)
  }

  private var groupThreadIDs: [String] {
    groupThreads.map(\.id)
  }

  private func uniqueThreads(_ threads: [ThreadItem]) -> [ThreadItem] {
    var seen = Set<String>()
    return threads.filter { thread in
      if seen.contains(thread.id) {
        return false
      }
      seen.insert(thread.id)
      return true
    }
  }

  private var showsFavoritesSection: Bool {
    contactFilter == .all || contactFilter == .favorites
  }

  private var showsIndividualsSection: Bool {
    contactFilter == .all || contactFilter == .individuals
  }

  private var showsGroupsSection: Bool {
    contactFilter == .all || contactFilter == .groups
  }

  private func sortedThreads(_ threads: [ThreadItem]) -> [ThreadItem] {
    threads.sorted { lhs, rhs in
      switch contactSort {
      case .recent:
        let lhsTime = FriendlyTime.sortTimestamp(lhs.latest_at)
        let rhsTime = FriendlyTime.sortTimestamp(rhs.latest_at)
        if lhsTime != rhsTime { return lhsTime > rhsTime }
        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
      case .alphabetical:
        let order = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
        if order != .orderedSame { return order == .orderedAscending }
        return FriendlyTime.sortTimestamp(lhs.latest_at) > FriendlyTime.sortTimestamp(rhs.latest_at)
      case .unread:
        if lhs.unread_count != rhs.unread_count { return lhs.unread_count > rhs.unread_count }
        return FriendlyTime.sortTimestamp(lhs.latest_at) > FriendlyTime.sortTimestamp(rhs.latest_at)
      }
    }
  }

}

private struct MessageListRow: View {
  let message: MessageItem

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      TransportMark(message: message)
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(message.contact_name)
            .font(.body.weight(message.read ? .regular : .semibold))
          if message.in_inbox {
            Text("Inbox")
              .font(.caption2.weight(.semibold))
              .padding(.horizontal, 6)
              .padding(.vertical, 1)
              .background(Capsule().fill(Color.accentColor.opacity(0.15)))
          }
          Spacer()
          Text(friendlyTime(message.received_at))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .help(fullTimestamp(message.received_at))
        }
        Text(message.subject.isEmpty ? message.preview : message.subject)
          .lineLimit(1)
        Text(message.displayBody)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
    .padding(.vertical, 4)
  }
}

private struct MessageReaderView: View {
  @EnvironmentObject private var session: StellarSession
  let message: MessageItem?
  let emptyTitle: String
  let animationNamespace: Namespace.ID

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let message {
        HStack(alignment: .center, spacing: 12) {
          Button { session.openInbox(focusing: message.id) } label: {
            Image(systemName: "chevron.left")
          }
          .buttonStyle(.borderless)
          .help("Back to Inbox")
          Text(message.subject.isEmpty ? message.contact_name : message.subject)
            .font(.title2.weight(.semibold))
            .lineLimit(1)
          Spacer()
          Button { session.openTimeline(for: message) } label: {
            Image(systemName: "bubble.left.and.bubble.right")
          }
          .buttonStyle(.borderless)
          .help("Show this message in Mail")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        Divider()
        ZStack {
          MessageReaderCard(message: message, animationNamespace: animationNamespace)
            .frame(maxWidth: 560)
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      } else {
        EmptyStateView(title: emptyTitle, subtitle: "Select a message.")
      }
    }
  }
}

private struct InboxView: View {
  @EnvironmentObject private var session: StellarSession
  let animationNamespace: Namespace.ID

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ScrollViewReader { proxy in
        ScrollView {
          if session.snapshot.inbox.isEmpty {
            EmptyStateView(title: "Inbox Is Clear", subtitle: "Inbox cards will appear here.")
              .frame(maxWidth: .infinity, minHeight: 420)
          } else {
            LazyVStack(spacing: 32) {
              ForEach(inboxStackCards) { message in
                InboxStackCard(
                  message: message,
                  stackDepth: inboxStackDepth(for: message),
                  isFocused: isFocusedStack(message),
                  animationNamespace: animationNamespace
                )
                .id(inboxStackID(for: message))
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity, alignment: .center)
                .zIndex(inboxStackZIndex(for: message))
              }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
          }
        }
        .onAppear {
          if let target = focusedStackID {
            proxy.scrollTo(target, anchor: .center)
          }
        }
        .onChange(of: session.focusedMessageID) { target in
          if target != nil, let stackID = focusedStackID {
            withAnimation { proxy.scrollTo(stackID, anchor: .center) }
          }
        }
      }
    }
  }

  private var inboxStackCards: [MessageItem] {
    let grouped = Dictionary(grouping: session.snapshot.inbox, by: { inboxStackKey(for: $0) })
    return grouped.values.compactMap { messages in
      messages.sorted { $0.received_at > $1.received_at }.first
    }
    .sorted { $0.received_at > $1.received_at }
  }

  private var focusedStackID: String? {
    guard let focusedMessage = session.activeMessage else { return nil }
    return inboxStackID(for: focusedMessage)
  }

  private func inboxStackDepth(for message: MessageItem) -> Int {
    inboxStackMessages(for: message).count
  }

  private func inboxStackMessages(for message: MessageItem) -> [MessageItem] {
    let key = inboxStackKey(for: message)
    return session.snapshot.inbox
      .filter { inboxStackKey(for: $0) == key }
      .sorted { $0.received_at > $1.received_at }
  }

  private func isFocusedStack(_ message: MessageItem) -> Bool {
    guard let focusedMessage = session.activeMessage else { return false }
    return inboxStackKey(for: focusedMessage) == inboxStackKey(for: message)
  }

  private func inboxStackZIndex(for message: MessageItem) -> Double {
    guard let draggingMessageID = session.draggingMessageID else {
      return isFocusedStack(message) ? 1 : 0
    }
    if message.id == draggingMessageID {
      return 1000
    }
    if inboxStackMessages(for: message).contains(where: { $0.id == draggingMessageID }) {
      return 1000
    }
    return 0
  }

  private func inboxStackID(for message: MessageItem) -> String {
    "inbox-stack:\(inboxStackKey(for: message))"
  }

  private func inboxStackKey(for message: MessageItem) -> String {
    message.thread_id.isEmpty ? message.id : message.thread_id
  }
}

private struct MailboxView: View {
  @EnvironmentObject private var session: StellarSession

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HeaderView(title: session.selectedMailbox?.title ?? session.selectedMailboxID?.capitalized ?? "Mailbox", subtitle: "\(session.mailboxMessages.count) messages")
      Divider()
      List(session.mailboxMessages) { message in
        MailboxMessageRow(message: message)
          .tag(message.id)
      }
      .listStyle(.inset)
    }
  }
}

private struct MailboxMessageRow: View {
  @EnvironmentObject private var session: StellarSession
  let message: MessageItem

  var body: some View {
    Button {
      session.selectMessage(message)
      session.openTimeline(for: message)
    } label: {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        TransportMark(message: message)
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(message.contact_name)
              .font(.body.weight(message.read ? .regular : .semibold))
            if message.starred {
              Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
            }
            Spacer()
            Text(friendlyTime(message.received_at))
              .font(.caption)
              .foregroundStyle(.secondary)
              .help(fullTimestamp(message.received_at))
          }
          Text(message.subject.isEmpty ? message.preview : message.subject)
            .lineLimit(1)
          Text(message.displayBody)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }
      .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
    .contextMenu { MessageContextMenu(message: message) }
  }
}

private struct DraftsView: View {
  @EnvironmentObject private var session: StellarSession

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HeaderView(title: "Drafts", subtitle: "\(session.snapshot.drafts.count) saved drafts")
      Divider()
      List(session.snapshot.drafts) { draft in
        VStack(alignment: .leading, spacing: 5) {
          HStack {
            Text(draft.subject.isEmpty ? "Untitled Draft" : draft.subject)
              .font(.body.weight(.semibold))
            Spacer()
            Text(friendlyTime(draft.updated_at))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Text(draft.to)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
      }
      .listStyle(.inset)
    }
  }
}

private struct EventsView: View {
  @EnvironmentObject private var session: StellarSession

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HeaderView(title: "Events", subtitle: "\(session.snapshot.events.count) backend events")
      Divider()
      List(session.snapshot.events) { event in
        VStack(alignment: .leading, spacing: 5) {
          HStack {
            Text(event.kind.isEmpty ? "Event" : event.kind)
              .font(.body.weight(.semibold))
            Spacer()
            Text(friendlyTime(event.created_at))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Text(event.message)
            .font(.callout)
            .textSelection(.enabled)
        }
        .padding(.vertical, 5)
      }
      .listStyle(.inset)
    }
  }
}

private struct MessageReaderCard: View {
  @EnvironmentObject private var session: StellarSession
  let message: MessageItem
  var animationNamespace: Namespace.ID? = nil

  var body: some View {
    CardStackFrame(
      depth: 1,
      tint: message.isSimpleX ? .green : .red,
      isSelected: true,
      width: message.cardWidth,
      minHeight: message.cardMinHeight
    ) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline) {
          Text(message.contact_name)
            .font(.headline)
          Spacer(minLength: 10)
          Text(friendlyTime(message.received_at))
            .font(.caption)
            .foregroundStyle(.secondary)
            .help(fullTimestamp(message.received_at))
        }
        if !message.subject.isEmpty {
          Text(message.subject)
            .font(.subheadline.weight(.semibold))
        }
        Text(message.displayBody.isEmpty ? "No preview" : message.displayBody)
          .font(.body)
          .foregroundStyle(.primary)
          .lineLimit(message.cardBodyLineLimit)
        if let attachment = message.attachment {
          AttachmentPreview(attachment: attachment)
            .frame(maxWidth: 420, alignment: .leading)
        }
        Spacer(minLength: 8)
        HStack {
          TransportPill(message: message)
          if message.attachments > 0 {
            Label("\(message.attachments)", systemImage: "paperclip")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer(minLength: 0)
          Button { session.archive(message) } label: {
            Image(systemName: "archivebox")
          }
            .help("Archive")
            .buttonStyle(.borderless)
        }
      }
    }
    .matchedInboxCardGeometry(message.id, in: animationNamespace)
    .draggableMessageCard(message)
    .contextMenu { MessageContextMenu(message: message) }
  }
}

private struct InboxStackCard: View {
  @EnvironmentObject private var session: StellarSession
  let message: MessageItem
  let stackDepth: Int
  let isFocused: Bool
  let animationNamespace: Namespace.ID

  var body: some View {
    ZStack(alignment: .top) {
      StaticCardStackBackplates(
        depth: stackDepth,
        tint: messageTint,
        width: message.inboxCardWidth,
        minHeight: message.inboxCardMinHeight
      )
      CardStackFrame(
        depth: 1,
        tint: messageTint,
        isSelected: isFocused,
        width: message.inboxCardWidth,
        minHeight: message.inboxCardMinHeight
      ) {
        InboxCardContent(message: message, actionsVisible: true)
      }
      .matchedInboxCardGeometry(message.id, in: animationNamespace)
      .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .draggableMessageCard(message)
      .onTapGesture { session.openInboxMessage(message) }
      .contextMenu { MessageContextMenu(message: message) }
      if stackDepth > 3 {
        Text("\(stackDepth)")
          .font(.caption.weight(.bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(Capsule().fill(messageTint.opacity(0.86)))
          .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
          .offset(x: 8, y: -8)
      }
    }
  }

  private var messageTint: Color {
    message.isSimpleX ? .green : .red
  }
}

private struct InboxCardContent: View {
  @EnvironmentObject private var session: StellarSession
  let message: MessageItem
  let actionsVisible: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(message.contact_name)
          .font(.headline)
        if message.starred {
          Image(systemName: "star.fill")
            .font(.caption)
            .foregroundStyle(.yellow)
        }
        Spacer(minLength: 10)
        Text(friendlyTime(message.received_at))
          .font(.caption)
          .foregroundStyle(.secondary)
          .help(fullTimestamp(message.received_at))
      }
      if !message.subject.isEmpty {
        Text(message.subject)
          .font(.subheadline.weight(.semibold))
          .lineLimit(2)
      }
      Text(message.displayBody.isEmpty ? "No preview" : message.displayBody)
        .font(message.isLongBlock ? .body : .callout)
        .foregroundStyle(.primary)
        .lineLimit(message.inboxCardBodyLineLimit)
      Spacer(minLength: 8)
      HStack(spacing: 8) {
        TransportPill(message: message)
        if message.attachments > 0 {
          Label("\(message.attachments)", systemImage: "paperclip")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        if actionsVisible {
          Spacer(minLength: 0)
          Button { session.archive(message) } label: {
            Image(systemName: "archivebox")
          }
          .help("Archive")
          .buttonStyle(.borderless)
        }
      }
    }
  }
}

private struct TimelineViewportHeightPreferenceKey: PreferenceKey {
  static let defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

private struct TimelineBottomMaxYPreferenceKey: PreferenceKey {
  static let defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

private struct TimelineContentMinYPreferenceKey: PreferenceKey {
  static let defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

private struct TimelineMessageFramePreferenceKey: PreferenceKey {
  static let defaultValue: [String: CGRect] = [:]

  static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { _, next in next })
  }
}

private struct SeenMessageEdges {
  var top: Bool = false
  var bottom: Bool = false
}

private struct TimelineView: View {
  @EnvironmentObject private var session: StellarSession
  @Binding var inspectorWidth: CGFloat
  @Binding var contactInfoVisible: Bool
  @State private var isAtTimelineEnd = true
  @State private var isAttachmentTargeted = false
  @State private var timelineViewportHeight: CGFloat = 0
  @State private var timelineBottomMaxY: CGFloat = 0
  @State private var timelineContentMinY: CGFloat = 0
  @State private var visibleMessageFrames: [String: CGRect] = [:]
  private let timelineBottomID = "timeline-bottom-anchor"
  private let timelineCoordinateSpace = "timeline-scroll-space"

  var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 0) {
        if let thread = session.selectedThread {
          ThreadTimelineHeader(
            thread: thread,
            subtitle: timelineSubtitle(thread),
            contactInfoVisible: contactInfoVisible
          ) {
            withAnimation(.easeInOut(duration: 0.22)) {
              contactInfoVisible.toggle()
            }
          }
        }
        Divider()
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
              Color.clear
                .frame(height: 0)
                .background {
                  GeometryReader { geometry in
                    Color.clear.preference(
                      key: TimelineContentMinYPreferenceKey.self,
                      value: geometry.frame(in: .named(timelineCoordinateSpace)).minY
                    )
                  }
                }
              ForEach(session.timelineMessages) { message in
                MessageBubble(message: message)
                  .id(message.id)
                  .background {
                    GeometryReader { geometry in
                      Color.clear.preference(
                        key: TimelineMessageFramePreferenceKey.self,
                        value: [message.id: geometry.frame(in: .named(timelineCoordinateSpace))]
                      )
                    }
                  }
                  .onAppear {
                    session.rememberTimelineScrollPosition(threadID: session.selectedThreadID, messageID: message.id)
                  }
              }
              Color.clear
                .frame(height: 18)
                .id(timelineBottomID)
                .background {
                  GeometryReader { geometry in
                    Color.clear.preference(
                      key: TimelineBottomMaxYPreferenceKey.self,
                      value: geometry.frame(in: .named(timelineCoordinateSpace)).maxY
                    )
                  }
                }
                .onAppear {
                  updateTimelineEndVisibility()
                }
                .onDisappear {
                  setTimelineEndVisible(false)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
          }
          .coordinateSpace(name: timelineCoordinateSpace)
          .background {
            GeometryReader { geometry in
              Color.clear.preference(
                key: TimelineViewportHeightPreferenceKey.self,
                value: geometry.size.height
              )
            }
          }
          .overlay(alignment: .bottom) {
            if isAttachmentTargeted {
              RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
                .overlay {
                  RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.55), lineWidth: 1.5)
                }
                .padding(10)
                .allowsHitTesting(false)
            }
            if !isAtTimelineEnd {
              Button {
                scrollToTimelineEnd(proxy)
              } label: {
                Image(systemName: "arrow.down.circle.fill")
                  .font(.system(size: 38, weight: .semibold))
                  .symbolRenderingMode(.hierarchical)
                  .foregroundStyle(Color.accentColor)
                  .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 3)
              }
              .buttonStyle(.plain)
              .help("Jump to newest message")
              .accessibilityLabel("Jump to newest message")
              .transition(.scale.combined(with: .opacity))
              .padding(.bottom, 14)
            }
          }
          .onDrop(of: [UTType.fileURL], isTargeted: $isAttachmentTargeted) { providers in
            session.attachDroppedFiles(providers)
          }
          .onAppear {
            isAtTimelineEnd = session.timelineShouldFollowEnd(for: session.selectedThread)
            scrollToTimelineTarget(proxy)
            evaluateSeenMessages()
          }
          .onPreferenceChange(TimelineViewportHeightPreferenceKey.self) { height in
            timelineViewportHeight = height
            updateTimelineEndVisibility()
            evaluateSeenMessages()
          }
          .onPreferenceChange(TimelineBottomMaxYPreferenceKey.self) { maxY in
            timelineBottomMaxY = maxY
            updateTimelineEndVisibility()
          }
          .onPreferenceChange(TimelineContentMinYPreferenceKey.self) { minY in
            timelineContentMinY = minY
            updateTimelineEndVisibility()
          }
          .onPreferenceChange(TimelineMessageFramePreferenceKey.self) { frames in
            visibleMessageFrames = frames
            evaluateSeenMessages()
          }
          .onChange(of: session.selectedThreadID) { _ in
            visibleMessageFrames = [:]
            isAtTimelineEnd = session.timelineShouldFollowEnd(for: session.selectedThread)
            scrollToTimelineTarget(proxy, animated: false)
          }
          .onChange(of: session.applicationFocusGeneration) { _ in
            evaluateSeenMessages()
          }
          .onChange(of: session.focusedMessageID) { _ in
            scrollToTimelineTarget(proxy)
          }
          .onChange(of: session.timelineEndID(for: session.selectedThread)) { _ in
            if isAtTimelineEnd || session.timelineShouldFollowEnd(for: session.selectedThread) {
              scrollToTimelineEnd(proxy)
            }
          }
          .onChange(of: session.timelineMessages.map(\.id).joined(separator: "|")) { _ in
            if isAtTimelineEnd || session.timelineShouldFollowEnd(for: session.selectedThread) {
              scrollToTimelineEnd(proxy)
            }
            evaluateSeenMessages()
          }
        }
        Divider()
        ComposerView()
          .padding(14)
      }
      if contactInfoVisible {
        SidebarResizeDivider(width: $inspectorWidth, range: 220...380, edge: .leading)
          .transition(.move(edge: .trailing).combined(with: .opacity))
        ContactInspectorView()
          .frame(width: inspectorWidth)
          .background(.bar)
          .transition(.move(edge: .trailing).combined(with: .opacity))
      }
    }
  }

  private func scrollToTimelineTarget(_ proxy: ScrollViewProxy, animated: Bool = true) {
    guard let target = session.timelineScrollTarget(for: session.selectedThread) else { return }
    if session.focusedMessageID != target,
       target == session.timelineEndID(for: session.selectedThread),
       session.timelineShouldFollowEnd(for: session.selectedThread) {
      scrollToTimelineEnd(proxy, animated: animated)
      return
    }
    Task { @MainActor in
      try? await Task.sleep(nanoseconds: 20_000_000)
      if animated {
        withAnimation {
          proxy.scrollTo(target, anchor: session.focusedMessageID == target ? .center : .bottom)
        }
      } else {
        proxy.scrollTo(target, anchor: session.focusedMessageID == target ? .center : .bottom)
      }
    }
  }

  private func scrollToTimelineEnd(_ proxy: ScrollViewProxy, animated: Bool = true) {
    guard let target = session.timelineEndID(for: session.selectedThread) else { return }
    setTimelineEndVisible(true)
    session.rememberTimelineScrollPosition(threadID: session.selectedThreadID, messageID: target)
    Task { @MainActor in
      try? await Task.sleep(nanoseconds: 20_000_000)
      performScrollToTimelineEnd(proxy, animated: animated)
      try? await Task.sleep(nanoseconds: 120_000_000)
      performScrollToTimelineEnd(proxy, animated: false)
    }
  }

  private func performScrollToTimelineEnd(_ proxy: ScrollViewProxy, animated: Bool) {
    if animated {
      withAnimation(.easeOut(duration: 0.28)) {
        proxy.scrollTo(timelineBottomID, anchor: .bottom)
      }
    } else {
      proxy.scrollTo(timelineBottomID, anchor: .bottom)
    }
  }

  private func setTimelineEndVisible(_ visible: Bool) {
    isAtTimelineEnd = visible
    session.rememberTimelineAtEnd(threadID: session.selectedThreadID, isAtEnd: visible)
  }

  private func updateTimelineEndVisibility() {
    guard timelineViewportHeight > 0, timelineBottomMaxY > 0 else { return }
    let distanceFromEnd = timelineBottomMaxY - timelineViewportHeight
    let tolerance: CGFloat = timelineContentMinY > 0 ? 24 : 16
    setTimelineEndVisible(distanceFromEnd <= tolerance)
  }

  private func evaluateSeenMessages() {
    session.markVisibleTimelineMessagesSeen(
      threadID: session.selectedThreadID,
      visibleFrames: visibleMessageFrames,
      viewportHeight: timelineViewportHeight
    )
  }

  private func timelineSubtitle(_ thread: ThreadItem) -> String {
    let count = thread.messages.count
    let paths = [
      thread.hasSimpleXPath ? "SimpleX" : nil,
      thread.hasEmailPath ? "email" : nil
    ].compactMap { $0 }.joined(separator: " + ")
    return "\(count) timeline item\(count == 1 ? "" : "s")" + (paths.isEmpty ? "" : " - \(paths)")
  }
}

private struct MessageBubble: View {
  @EnvironmentObject private var session: StellarSession
  @State private var showingDetails = false
  let message: MessageItem

  var body: some View {
    HStack {
      if message.from_self { Spacer(minLength: 80) }
      VStack(alignment: .leading, spacing: 7) {
        if !message.subject.isEmpty {
          Text(message.subject)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.primary)
        }
        Text(message.displayBody.isEmpty ? "No content" : message.displayBody)
          .font(message.isLongBlock ? .body : .callout)
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
        if let attachment = message.attachment {
          AttachmentPreview(attachment: attachment)
        }
        HStack(alignment: .center, spacing: 7) {
          Spacer(minLength: 6)
          if message.isSending {
            ProgressView()
              .controlSize(.mini)
              .scaleEffect(0.62)
            Text("Sending...")
              .font(.caption2)
              .foregroundStyle(.secondary)
          } else if message.isSendError {
            Label("Not sent", systemImage: "exclamationmark.triangle.fill")
              .font(.caption2)
              .foregroundStyle(.red)
          }
          TransportMark(message: message)
            .font(.caption2.weight(.semibold))
          Text(friendlyTime(message.received_at))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .help(fullTimestamp(message.received_at))
          Menu {
            Button { showingDetails = true } label: {
              Label("Details", systemImage: "info.circle")
            }
            Divider()
            MessageContextMenu(message: message)
          } label: {
            Image(systemName: "ellipsis.vertical")
              .font(.caption.weight(.bold))
              .foregroundStyle(.secondary)
              .frame(width: 18, height: 18)
          }
          .menuStyle(.borderlessButton)
          .fixedSize()
          .help("Message options")
          .popover(isPresented: $showingDetails, arrowEdge: message.from_self ? .trailing : .leading) {
            MessageDetailsView(message: message)
              .padding(14)
              .frame(width: 300)
          }
        }
      }
      .padding(.horizontal, message.isLongBlock ? 15 : 12)
      .padding(.vertical, message.isLongBlock ? 12 : 9)
      .frame(maxWidth: message.isLongBlock ? 620 : 430, alignment: .leading)
      .background(messageBackground)
      .overlay(alignment: .topTrailing) {
        if message.in_inbox {
          InboxSplitPill(message: message)
            .offset(x: 8, y: -8)
        }
      }
      .opacity(message.in_inbox ? 0.62 : 1.0)
      .shadow(color: Color.black.opacity(0.10), radius: 5, x: 0, y: 2)
      .contextMenu { MessageContextMenu(message: message) }
      .onTapGesture { session.selectMessage(message) }
      if !message.from_self { Spacer(minLength: 80) }
    }
    .draggableMessageCard(message)
  }

  private var messageBackground: some View {
    TelegramBubbleShape(isFromSelf: message.from_self)
      .fill(messageFill)
  }

  private var messageTint: Color {
    if message.from_self {
      return .accentColor
    }
    return message.isSimpleX ? .green : .red
  }

  private var messageFill: Color {
    session.bubbleFill(for: message)
  }
}

private struct AttachmentPreview: View {
  let attachment: AttachmentItem

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let image = attachment.nsImage {
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
          .frame(maxWidth: 360, maxHeight: 260)
          .clipShape(RoundedRectangle(cornerRadius: 9))
          .overlay {
            RoundedRectangle(cornerRadius: 9)
              .stroke(Color.primary.opacity(0.10), lineWidth: 1)
          }
      } else if attachment.isVideo || attachment.isAudio {
        if attachment.isVideo, let url = attachment.temporaryURL {
          InlineVideoAttachmentView(url: url)
        } else if attachment.isAudio, let url = attachment.temporaryURL {
          InlineAudioAttachmentView(url: url)
        } else {
          ExternalAttachmentOpenButton(attachment: attachment)
        }
      }
      HStack(spacing: 8) {
        Image(systemName: attachment.isImage ? "photo" : (attachment.isVideo ? "film" : (attachment.isAudio ? "waveform" : "doc")))
          .foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 1) {
          Text(attachment.name.isEmpty ? "Attachment" : attachment.name)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
          Text("\(attachment.mime.isEmpty ? "file" : attachment.mime) · \(formatBytes(attachment.size))")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        if attachment.isVideo || attachment.isAudio {
          Spacer(minLength: 8)
          ExternalAttachmentOpenIconButton(attachment: attachment)
        }
      }
      .padding(.horizontal, 9)
      .padding(.vertical, 7)
      .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.48)))
      .overlay {
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.primary.opacity(0.10), lineWidth: 1)
      }
      .fixedSize(horizontal: false, vertical: true)
    }
  }
}

private struct InlineVideoAttachmentView: View {
  let url: URL

  var body: some View {
    NativeVideoPlayerView(url: url)
      .frame(width: 360, height: 220)
      .clipShape(RoundedRectangle(cornerRadius: 9))
      .overlay {
        RoundedRectangle(cornerRadius: 9)
          .stroke(Color.primary.opacity(0.10), lineWidth: 1)
      }
  }
}

private struct InlineAudioAttachmentView: View {
  let url: URL

  var body: some View {
    NativeVideoPlayerView(url: url)
      .frame(width: 360, height: 58)
      .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.06)))
      .clipShape(RoundedRectangle(cornerRadius: 9))
      .overlay {
        RoundedRectangle(cornerRadius: 9)
          .stroke(Color.primary.opacity(0.10), lineWidth: 1)
      }
  }
}

private struct NativeVideoPlayerView: NSViewRepresentable {
  let url: URL

  func makeNSView(context: Context) -> AVPlayerView {
    let view = AVPlayerView()
    view.controlsStyle = .floating
    view.videoGravity = .resizeAspect
    view.player = AVPlayer(url: url)
    return view
  }

  func updateNSView(_ nsView: AVPlayerView, context: Context) {
    if (nsView.player?.currentItem?.asset as? AVURLAsset)?.url != url {
      nsView.player?.pause()
      nsView.player = AVPlayer(url: url)
    }
  }

  static func dismantleNSView(_ nsView: AVPlayerView, coordinator: ()) {
    nsView.player?.pause()
    nsView.player = nil
  }
}

private struct ExternalAttachmentOpenButton: View {
  let attachment: AttachmentItem

  var body: some View {
    Button {
      if let url = attachment.temporaryURL {
        NSWorkspace.shared.open(url)
      }
    } label: {
      HStack(spacing: 10) {
        Image(systemName: attachment.isAudio ? "waveform.circle.fill" : "doc")
          .font(.title2)
          .foregroundStyle(.secondary)
        Text(attachment.isAudio ? "Open audio attachment" : "Open attachment")
          .font(.caption.weight(.semibold))
      }
      .frame(width: 360, height: attachment.isAudio ? 48 : 96)
      .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.06)))
      .overlay {
        RoundedRectangle(cornerRadius: 9)
          .stroke(Color.primary.opacity(0.10), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
    .help("Open attachment")
  }
}

private struct ExternalAttachmentOpenIconButton: View {
  let attachment: AttachmentItem

  var body: some View {
    Button {
      if let url = attachment.temporaryURL {
        NSWorkspace.shared.open(url)
      }
    } label: {
      Image(systemName: "arrow.up.forward.square")
        .font(.caption.weight(.bold))
        .frame(width: 26, height: 24)
    }
    .buttonStyle(.plain)
    .foregroundStyle(.secondary)
    .background(Capsule().fill(Color.primary.opacity(0.06)))
    .help("Open attachment externally")
  }
}

private struct InboxSplitPill: View {
  @EnvironmentObject private var session: StellarSession
  let message: MessageItem

  var body: some View {
    HStack(spacing: 0) {
      Button {
        session.openInbox(focusing: message.id)
      } label: {
        Image(systemName: "tray.full")
          .font(.caption.weight(.bold))
          .frame(width: 27, height: 22)
      }
      .buttonStyle(.plain)
      .help("Show in Inbox")

      Divider()
        .frame(height: 14)

      Button {
        session.archive(message)
      } label: {
        Image(systemName: "xmark")
          .font(.caption2.weight(.bold))
          .frame(width: 22, height: 22)
      }
      .buttonStyle(.plain)
      .help("Remove from Inbox")
    }
    .foregroundStyle(Color.accentColor)
    .background(.regularMaterial, in: Capsule())
    .overlay {
      Capsule()
        .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
    }
    .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
    .fixedSize()
  }
}

private struct TelegramBubbleShape: Shape {
  let isFromSelf: Bool

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let radius: CGFloat = 16
    let tailWidth: CGFloat = 7
    let tailHeight: CGFloat = 10
    let bubbleRect = isFromSelf
      ? CGRect(x: rect.minX, y: rect.minY, width: rect.width - tailWidth, height: rect.height)
      : CGRect(x: rect.minX + tailWidth, y: rect.minY, width: rect.width - tailWidth, height: rect.height)
    path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: radius, height: radius))
    if isFromSelf {
      path.move(to: CGPoint(x: bubbleRect.maxX - 2, y: bubbleRect.maxY - 16))
      path.addQuadCurve(
        to: CGPoint(x: rect.maxX, y: bubbleRect.maxY - 4),
        control: CGPoint(x: rect.maxX - 1, y: bubbleRect.maxY - 9)
      )
      path.addQuadCurve(
        to: CGPoint(x: bubbleRect.maxX - 8, y: bubbleRect.maxY - tailHeight),
        control: CGPoint(x: bubbleRect.maxX - 2, y: bubbleRect.maxY - 3)
      )
    } else {
      path.move(to: CGPoint(x: bubbleRect.minX + 2, y: bubbleRect.maxY - 16))
      path.addQuadCurve(
        to: CGPoint(x: rect.minX, y: bubbleRect.maxY - 4),
        control: CGPoint(x: rect.minX + 1, y: bubbleRect.maxY - 9)
      )
      path.addQuadCurve(
        to: CGPoint(x: bubbleRect.minX + 8, y: bubbleRect.maxY - tailHeight),
        control: CGPoint(x: bubbleRect.minX + 2, y: bubbleRect.maxY - 3)
      )
    }
    return path
  }
}

private struct MessageDetailsView: View {
  let message: MessageItem

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Details")
        .font(.headline)
      detailRow("From", message.from_self ? "You" : message.contact_name)
      detailRow("Transport", message.isSimpleX ? "SimpleX" : "Email")
      detailRow("Received", friendlyTime(message.received_at))
      if !message.subject.isEmpty {
        detailRow("Subject", message.subject)
      }
      detailRow("Status", message.read ? "Read" : "Unread")
      if message.in_inbox {
        detailRow("Inbox", "Still in Inbox")
      }
      if message.attachments > 0 {
        detailRow("Attachments", "\(message.attachments)")
      }
    }
  }

  private func detailRow(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(value)
        .font(.callout)
        .textSelection(.enabled)
    }
  }
}

private struct MessageContextMenu: View {
  @EnvironmentObject private var session: StellarSession
  let message: MessageItem

  var body: some View {
    Button { session.archive(message) } label: {
      Label("Archive", systemImage: "archivebox")
    }
    Button { session.markRead(message, read: !message.read) } label: {
      Label(message.read ? "Mark Unread" : "Mark Read", systemImage: message.read ? "envelope.badge" : "envelope.open")
    }
    Button { session.toggleStar(message) } label: {
      Label(message.starred ? "Unstar" : "Star", systemImage: message.starred ? "star.slash" : "star")
    }
    Divider()
    Button(role: .destructive) { session.delete(message) } label: {
      Label("Delete", systemImage: "trash")
    }
  }
}

private struct ComposerView: View {
  @EnvironmentObject private var session: StellarSession
  @State private var isAttachmentTargeted = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if session.selectedTransport == .email {
        TextField("Subject", text: $session.composeSubject)
          .textFieldStyle(.roundedBorder)
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
      if let attachment = session.pendingAttachment {
        PendingAttachmentPill(attachment: attachment) {
          session.removePendingAttachment()
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
      ZStack(alignment: .bottom) {
        TextEditor(text: $session.composeBody)
          .font(.body)
          .scrollIndicators(.automatic)
          .padding(.bottom, 30)
          .frame(minHeight: 58, idealHeight: 72, maxHeight: 118)
        HStack(alignment: .center, spacing: 8) {
          TransportMiniToggle(
            transport: $session.selectedTransport,
            isEnabled: session.canSwitchComposerTransport
          )
          Spacer()
          Button {
            session.sendComposedMessage()
          } label: {
            Image(systemName: "paperplane.fill")
              .font(.body.weight(.semibold))
              .frame(width: 28, height: 22)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
          .tint(session.selectedTransport == .email ? .red.opacity(0.86) : .accentColor)
          .disabled(!session.canSend || session.isBusy)
          .help(session.pendingAttachment != nil && session.selectedTransport == .email ? "Attachments send by SimpleX" : (session.selectedTransport == .email ? "Send by email" : "Send by SimpleX"))
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 7)
      }
      .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.secondary.opacity(0.18)))
      .overlay {
        if isAttachmentTargeted {
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .stroke(Color.accentColor.opacity(0.70), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.accentColor.opacity(0.08)))
            .allowsHitTesting(false)
        }
      }
      .onDrop(of: [UTType.fileURL], isTargeted: $isAttachmentTargeted) { providers in
        session.attachDroppedFiles(providers)
      }
    }
    .animation(.easeOut(duration: 0.16), value: session.selectedTransport)
    .animation(.easeOut(duration: 0.16), value: session.pendingAttachment)
  }
}

private struct PendingAttachmentPill: View {
  let attachment: PendingAttachment
  let remove: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "paperclip")
        .foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 1) {
        Text(attachment.name)
          .font(.caption.weight(.semibold))
          .lineLimit(1)
        Text("\(attachment.typeDescription) · \(attachment.displaySize)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Button(action: remove) {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .help("Remove attachment")
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(.regularMaterial, in: Capsule())
    .overlay {
      Capsule()
        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
    }
    .fixedSize(horizontal: true, vertical: false)
  }
}

private struct TransportMiniToggle: View {
  @Binding var transport: Transport
  let isEnabled: Bool

  private var isSecure: Bool { transport == .simplex }

  var body: some View {
    Button {
      guard isEnabled else { return }
      transport = isSecure ? .email : .simplex
    } label: {
      HStack(spacing: 6) {
        Image(systemName: isSecure ? "lock.fill" : "lock.open")
          .font(.caption.weight(.bold))
          .foregroundStyle(isSecure ? .green : .red)
          .frame(width: 14, height: 14)
        ZStack(alignment: isSecure ? .trailing : .leading) {
          Capsule()
            .fill(isSecure ? Color.green.opacity(0.50) : Color.red.opacity(0.32))
            .overlay(
              Capsule()
                .stroke(Color.primary.opacity(0.18), lineWidth: 0.5)
            )
          Circle()
            .fill(Color(nsColor: .controlBackgroundColor))
            .shadow(color: Color.black.opacity(0.18), radius: 1.5, x: 0, y: 0.8)
            .padding(2)
        }
        .frame(width: 26, height: 14)
      }
      .padding(.horizontal, 3)
      .padding(.vertical, 2)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .fixedSize()
    .opacity(isEnabled ? 1 : 0.48)
    .disabled(!isEnabled)
    .help(isEnabled ? (isSecure ? "SimpleX secure transport" : "Email transport") : "Add both SimpleX and email contact information to switch transports")
    .accessibilityLabel("Transport")
    .accessibilityValue(isSecure ? "SimpleX" : "Email")
  }
}

private struct ContactInspectorView: View {
  @EnvironmentObject private var session: StellarSession
  @State private var simpleXAddressVisible = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Contact")
        .font(.headline)
      Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
        GridRow {
          Text("Name")
            .foregroundStyle(.secondary)
          TextField("Name", text: $session.contactDraftName)
            .textFieldStyle(.roundedBorder)
        }
        GridRow {
          Text("Email")
            .foregroundStyle(.secondary)
          TextField("Email address", text: $session.contactDraftEmail)
            .textFieldStyle(.roundedBorder)
        }
        GridRow {
          Text("SimpleX")
            .foregroundStyle(.secondary)
          HStack(spacing: 6) {
            TextField("SimpleX address or connection", text: $session.contactDraftSimpleX)
              .textFieldStyle(.roundedBorder)
            Button {
              simpleXAddressVisible.toggle()
            } label: {
              Image(systemName: simpleXAddressVisible ? "eye.slash" : "eye")
                .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .help(simpleXAddressVisible ? "Hide SimpleX binding" : "Show SimpleX binding")
          }
        }
      }
      if simpleXAddressVisible {
        Text(session.contactDraftSimpleX.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No SimpleX binding" : session.contactDraftSimpleX)
          .font(.caption.monospaced())
          .textSelection(.enabled)
          .foregroundStyle(.secondary)
          .padding(8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
      }
      Button {
        session.saveContactBinding()
      } label: {
        Label("Save Contact", systemImage: "person.crop.circle.badge.checkmark")
      }
      .buttonStyle(.bordered)
      if let thread = session.selectedThread {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Label(
              session.effectiveTemporalDistance(for: thread).map { TemporalDistance.label($0) } ?? "Auto",
              systemImage: thread.temporal_distance_seconds == nil ? "clock" : "clock.badge.checkmark"
            )
            .font(.callout.weight(.semibold))
            Spacer()
            Button { session.decreaseTemporalDistance(for: thread) } label: {
              Image(systemName: "minus")
                .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .help("Decrease temporal distance")
            Button { session.increaseTemporalDistance(for: thread) } label: {
              Image(systemName: "plus")
                .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .help("Increase temporal distance")
          }
          if let automatic = session.automaticTemporalDistance(for: thread) {
            HStack(spacing: 6) {
              Text("Automatic")
                .foregroundStyle(.secondary)
              Text(TemporalDistance.label(automatic))
            }
            .font(.caption)
          }
          Button { session.setTemporalDistance(for: thread, seconds: nil) } label: {
            Label("Use Automatic", systemImage: "wand.and.stars")
          }
          .buttonStyle(.bordered)
          .fixedSize()
        }
      }
      Divider()
      if let thread = session.selectedThread {
        Label(thread.hasSimpleXPath ? "SimpleX address bound" : "No SimpleX address", systemImage: thread.hasSimpleXPath ? "lock.fill" : "lock.slash")
          .foregroundStyle(thread.hasSimpleXPath ? .green : .secondary)
        Label(thread.hasEmailPath ? "Email bound" : "No email path", systemImage: thread.hasEmailPath ? "lock.open" : "envelope.badge")
          .foregroundStyle(thread.hasEmailPath ? .red : .secondary)
      }
      Spacer()
    }
    .padding(14)
  }
}

private struct ThreadTimelineHeader: View {
  @EnvironmentObject private var session: StellarSession
  let thread: ThreadItem
  let subtitle: String
  let contactInfoVisible: Bool
  let toggleContactInfo: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(thread.displayName)
          .font(.title2.weight(.semibold))
          .lineLimit(1)
        Button {
          session.toggleFavorite(for: thread)
        } label: {
          Image(systemName: thread.favorite ? "star.fill" : "star")
            .font(.title3.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(thread.favorite ? Color.yellow : Color.secondary)
            .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help(thread.favorite ? "Remove from Favorites" : "Add to Favorites")
        .accessibilityLabel(thread.favorite ? "Remove from Favorites" : "Add to Favorites")
        Spacer()
        Button {
          toggleContactInfo()
        } label: {
          Image(systemName: "person.text.rectangle")
            .font(.title3.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(contactInfoVisible ? Color.accentColor : Color.secondary)
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help(contactInfoVisible ? "Hide contact" : "Show contact")
        .accessibilityLabel(contactInfoVisible ? "Hide contact" : "Show contact")
      }
      Text(subtitle)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
  }
}

private struct HeaderView: View {
  let title: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.title2.weight(.semibold))
      Text(subtitle)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
  }
}

private struct TransportMark: View {
  let message: MessageItem

  var body: some View {
    Image(systemName: message.isSimpleX ? "lock.fill" : "lock.open")
      .font(.caption.weight(.bold))
      .foregroundStyle(message.isSimpleX ? .green : .red)
      .help(message.isSimpleX ? "SimpleX secure transport" : "Email open-lock transport")
  }
}

private struct TransportPill: View {
  let message: MessageItem

  var body: some View {
    Label(message.isSimpleX ? "SimpleX" : "Email", systemImage: message.isSimpleX ? "lock.fill" : "lock.open")
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(Capsule().fill((message.isSimpleX ? Color.green : Color.red).opacity(0.12)))
      .foregroundStyle(message.isSimpleX ? .green : .red)
  }
}

private struct SettingsView: View {
  @EnvironmentObject private var session: StellarSession

  var body: some View {
    TabView {
      generalPreferences
        .tabItem {
          Label("General", systemImage: "gearshape")
        }
      appearancePreferences
        .tabItem {
          Label("Appearance", systemImage: "paintpalette")
        }
      emailPreferences
        .tabItem {
          Label("Email", systemImage: "envelope")
        }
      deliveryPreferences
        .tabItem {
          Label("Delivery", systemImage: "network")
        }
      simplexPreferences
        .tabItem {
          Label("SimpleX", systemImage: "lock.fill")
        }
    }
  }

  private var generalPreferences: some View {
    Form {
      Section("Mail Root") {
        HStack {
          TextField("Mail root", text: $session.mailRoot)
            .textFieldStyle(.roundedBorder)
            .frame(width: 360)
          Button { session.chooseMailRoot() } label: {
            Label("Choose", systemImage: "folder")
          }
        }
      }
      Section("Filtering") {
        HStack {
          Button { session.classifySpam() } label: {
            Label("Classify Spam", systemImage: "line.3.horizontal.decrease.circle")
          }
          Button { session.openEvents() } label: {
            Label("Events", systemImage: "waveform.path.ecg")
          }
        }
      }
      Section("Reading") {
        Toggle("Mark messages read when seen", isOn: Binding(
          get: { session.markMessagesReadWhenSeen },
          set: { session.markMessagesReadWhenSeen = $0; session.persistSeenPreferences() }
        ))
        Toggle("Mark all earlier messages seen", isOn: Binding(
          get: { session.markEarlierMessagesSeen },
          set: { session.markEarlierMessagesSeen = $0; session.persistSeenPreferences() }
        ))
        .padding(.leading, 22)
        .disabled(!session.markMessagesReadWhenSeen)
      }
      Section("Temporal Distance") {
        Toggle("Show temporal distance", isOn: Binding(
          get: { session.showTemporalDistance },
          set: { session.showTemporalDistance = $0; session.persistTemporalDistancePreferences() }
        ))
        .fixedSize()
        Toggle("Detect temporal distance automatically", isOn: Binding(
          get: { session.detectTemporalDistanceAutomatically },
          set: { session.detectTemporalDistanceAutomatically = $0; session.persistTemporalDistancePreferences() }
        ))
        .fixedSize()
      }
    }
    .formStyle(.grouped)
    .padding(.top, 8)
  }

  private var appearancePreferences: some View {
    Form {
      Section("Chat Bubbles") {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
          GridRow {
            BubbleColorPickerRow(title: "My SimpleX", color: Binding(
              get: { session.bubbleSelfSimpleXColor },
              set: { session.bubbleSelfSimpleXColor = $0; session.persistBubbleColors() }
            ))
            BubbleColorPickerRow(title: "My Email", color: Binding(
              get: { session.bubbleSelfEmailColor },
              set: { session.bubbleSelfEmailColor = $0; session.persistBubbleColors() }
            ))
          }
          GridRow {
            BubbleColorPickerRow(title: "Others SimpleX", color: Binding(
              get: { session.bubbleOtherSimpleXColor },
              set: { session.bubbleOtherSimpleXColor = $0; session.persistBubbleColors() }
            ))
            BubbleColorPickerRow(title: "Others Email", color: Binding(
              get: { session.bubbleOtherEmailColor },
              set: { session.bubbleOtherEmailColor = $0; session.persistBubbleColors() }
            ))
          }
        }
        HStack {
          Button { session.resetBubbleColors() } label: {
            Label("Reset", systemImage: "arrow.counterclockwise")
          }
          .fixedSize()
        }
      }
    }
    .formStyle(.grouped)
    .padding(.top, 8)
  }

  private var emailPreferences: some View {
    Form {
      Section("Email") {
        HStack {
          TextField("Domain", text: $session.settingsDomainDraft)
            .textFieldStyle(.roundedBorder)
            .frame(width: 220)
          Button { session.saveEmailDomain() } label: {
            Label("Save", systemImage: "checkmark")
          }
          Button { session.verifyEmailDomain() } label: {
            Label("Verify", systemImage: "checkmark.seal")
          }
        }
        HStack {
          TextField("Test recipient", text: $session.settingsTestRecipientDraft)
            .textFieldStyle(.roundedBorder)
            .frame(width: 260)
          Button { session.saveTestRecipient() } label: {
            Label("Save", systemImage: "person.crop.circle.badge.checkmark")
          }
        }
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
          GridRow {
            Text("Domain")
              .foregroundStyle(.secondary)
            Text(session.snapshot.settings.domain_configured ? "configured" : "missing")
          }
          GridRow {
            Text("TLS")
              .foregroundStyle(.secondary)
            Text(session.snapshot.settings.ssl_ready ? "ready" : "not ready")
          }
          GridRow {
            Text("Folders")
              .foregroundStyle(.secondary)
            Text(session.snapshot.settings.folders_ready ? "ready" : "missing")
          }
        }
        HStack {
          Button { session.runBackendAction("settings-setup-folders", status: "Mail folders checked") } label: {
            Label("Setup Folders", systemImage: "folder.badge.gearshape")
          }
          Button { session.setupTLSForCurrentServer() } label: {
            Label("Setup TLS", systemImage: "lock.shield")
          }
        }
      }
      TLSSetupWalkthroughView()
    }
    .formStyle(.grouped)
    .padding(.top, 8)
  }

  private var deliveryPreferences: some View {
    Form {
      Section("Daemon") {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
          GridRow {
            Text("Manager")
              .foregroundStyle(.secondary)
            Text(session.snapshot.settings.daemon.manager.isEmpty ? "unknown" : session.snapshot.settings.daemon.manager)
          }
          GridRow {
            Text("Installed")
              .foregroundStyle(.secondary)
            Text(session.snapshot.settings.daemon.installed ? "yes" : "no")
          }
          GridRow {
            Text("Running")
              .foregroundStyle(.secondary)
            Text(session.snapshot.settings.daemon.running ? "yes" : "no")
          }
        }
        HStack {
          Button { session.runBackendAction("settings-set-daemon-installed", args: ["on"], status: "Daemon installed") } label: {
            Label("Install", systemImage: "square.and.arrow.down")
          }
          Button { session.setDaemonRunning(true) } label: {
            Label("Start", systemImage: "play.fill")
          }
          Button { session.setDaemonRunning(false) } label: {
            Label("Stop", systemImage: "stop.fill")
          }
          Toggle("Launch at Login", isOn: Binding(
            get: { session.snapshot.settings.daemon.startup_enabled },
            set: { session.setDaemonStartup($0) }
          ))
          .fixedSize()
        }
      }
      Section("Remote Mail Server") {
        RemoteServerWalkthroughView()
      }
    }
    .formStyle(.grouped)
    .padding(.top, 8)
  }

  private var simplexPreferences: some View {
    Form {
      Section("SimpleX") {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
          GridRow {
            Text("Install")
              .foregroundStyle(.secondary)
            Text(session.bootstrap.install_state)
          }
          GridRow {
            Text("Profile")
              .foregroundStyle(.secondary)
            Text(session.bootstrap.profile_ready ? "ready" : "missing")
          }
          GridRow {
            Text("Transport")
              .foregroundStyle(.secondary)
            Text(session.bootstrap.hook_ready ? "ready" : "not configured")
          }
          GridRow {
            Text("Binary")
              .foregroundStyle(.secondary)
            Text(session.bootstrap.binary_path.isEmpty ? session.snapshot.simplex.system_root : session.bootstrap.binary_path)
              .lineLimit(2)
          }
          GridRow {
            Text("Hook")
              .foregroundStyle(.secondary)
            Text(session.bootstrap.hook_path.isEmpty ? "none" : session.bootstrap.hook_path)
              .lineLimit(2)
          }
        }
        HStack {
          Button { session.installSimpleX() } label: {
            Label("Install CLI", systemImage: "square.and.arrow.down")
          }
          Button { session.provisionSimpleX() } label: {
            Label("Provision Identity", systemImage: "person.badge.key")
          }
          Button { session.configureSimpleXLocalTransport() } label: {
            Label("Enable Local Transport", systemImage: "externaldrive.connected.to.line.below")
          }
          Button { session.tickSimpleX() } label: {
            Label("Check", systemImage: "arrow.clockwise")
          }
        }
      }
    }
    .formStyle(.grouped)
    .padding(.top, 8)
  }
}

private enum SetupStepState: Equatable {
  case locked
  case active
  case complete

  var symbol: String {
    switch self {
    case .locked: return "lock"
    case .active: return "circle"
    case .complete: return "checkmark.circle.fill"
    }
  }

  var tint: Color {
    switch self {
    case .locked: return .secondary
    case .active: return .accentColor
    case .complete: return .green
    }
  }
}

private struct RemoteSetupStep<Content: View>: View {
  let number: Int
  let title: String
  let detail: String
  let state: SetupStepState
  let content: Content

  init(number: Int, title: String, detail: String, state: SetupStepState, @ViewBuilder content: () -> Content) {
    self.number = number
    self.title = title
    self.detail = detail
    self.state = state
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        ZStack {
          Circle()
            .fill(state.tint.opacity(state == .complete ? 0.18 : 0.10))
            .frame(width: 24, height: 24)
          Text("\(number)")
            .font(.caption.weight(.bold))
            .foregroundStyle(state.tint)
        }
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Text(title)
              .font(.callout.weight(.semibold))
            Image(systemName: state.symbol)
              .font(.caption.weight(.semibold))
              .foregroundStyle(state.tint)
          }
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      content
        .padding(.leading, 34)
        .opacity(state == .locked ? 0.54 : 1)
    }
    .padding(.vertical, 8)
  }
}

private struct RemoteStatusPill: View {
  let label: String
  let status: String
  let message: String

  private var normalizedStatus: String {
    let trimmed = status.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "idle" : trimmed
  }

  private var tint: Color {
    switch normalizedStatus {
    case "ok": return .green
    case "bad", "error", "failed": return .red
    case "idle": return .secondary
    default: return .accentColor
    }
  }

  var body: some View {
    Text("\(label): \(normalizedStatus)")
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Capsule().fill(tint.opacity(0.12)))
      .overlay(Capsule().stroke(tint.opacity(0.25), lineWidth: 1))
      .foregroundStyle(tint)
      .help(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "\(label): \(normalizedStatus)" : message)
      .fixedSize()
  }
}

private struct TLSSetupWalkthroughView: View {
  @EnvironmentObject private var session: StellarSession

  private var domainText: String {
    let draft = session.settingsDomainDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    if !draft.isEmpty { return draft }
    return session.snapshot.settings.email_domain.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var smtpHost: String {
    if let status = session.tlsWizardStatus, !status.smtp_host.isEmpty {
      return status.smtp_host
    }
    return domainText.isEmpty ? "smtp.domain" : "smtp.\(domainText)"
  }

  private var missingDNS: [String] {
    guard let status = session.tlsWizardStatus else {
      return session.snapshot.settings.domain_configured ? ["refresh DNS checks"] : ["set the receiving domain"]
    }
    var missing: [String] = []
    if !session.tlsWizardUsesDynamicIP && !status.checks.root_a_ok {
      missing.append("A/AAAA for \(domainText.isEmpty ? "@" : domainText)")
    }
    if !status.checks.smtp_a_ok {
      missing.append("A/AAAA or CNAME for \(smtpHost)")
    }
    if !status.checks.mx_ok {
      missing.append("MX @ priority 10 -> \(smtpHost)")
    }
    return missing
  }

  private var domainState: SetupStepState {
    session.snapshot.settings.domain_configured ? .complete : .active
  }

  private var dnsState: SetupStepState {
    guard session.snapshot.settings.domain_configured else { return .locked }
    return session.tlsWizardDNSReady ? .complete : .active
  }

  private var toolsState: SetupStepState {
    guard session.snapshot.settings.domain_configured && session.tlsWizardDNSReady else { return .locked }
    return session.tlsWizardStatus?.checks.certbot_installed == true ? .complete : .active
  }

  private var certificateState: SetupStepState {
    guard session.snapshot.settings.domain_configured && session.tlsWizardDNSReady else { return .locked }
    return session.snapshot.settings.ssl_ready ? .complete : .active
  }

  var body: some View {
    Section("TLS Walkthrough") {
      VStack(alignment: .leading, spacing: 6) {
        RemoteSetupStep(
          number: 1,
          title: "Domain Is Set",
          detail: domainText.isEmpty ? "Set the receiving domain before checking DNS." : "Using domain \(domainText).",
          state: domainState
        ) {
          HStack(spacing: 8) {
            Button { session.saveEmailDomain() } label: {
              Label("Set Domain", systemImage: "checkmark")
            }
            .fixedSize()
            Button { session.verifyEmailDomain() } label: {
              Label("Verify DNS", systemImage: "checkmark.seal")
            }
            .fixedSize()
          }
        }

        RemoteSetupStep(
          number: 2,
          title: "Configure DNS Records",
          detail: session.tlsWizardDNSReady ? "Required DNS records were detected." : "Add the mail host record first, then add MX with a hostname target, not an IP.",
          state: dnsState
        ) {
          VStack(alignment: .leading, spacing: 8) {
            Picker("IP address mode", selection: $session.tlsWizardIPMode) {
              Text("Stable IP").tag("stable")
              Text("Dynamic IP (DDNS)").tag("dynamic")
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .onChange(of: session.tlsWizardIPMode) { _ in
              session.refreshTLSWizardStatus()
            }
            HStack(spacing: 8) {
              Button { session.refreshTLSWizardStatus() } label: {
                Label(session.isRefreshingTLSWizard ? "Checking DNS" : "Refresh Checks", systemImage: "arrow.clockwise")
              }
              .fixedSize()
              .disabled(!session.snapshot.settings.domain_configured || session.isRefreshingTLSWizard || session.isBusy)
              Text(dnsHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 6) {
              ForEach(dnsRecords) { record in
                TLSDNSRecordRow(record: record, domain: domainText)
              }
            }
            if !missingDNS.isEmpty {
              Text("Waiting on: \(missingDNS.joined(separator: "; ")).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            }
            if !session.tlsWizardError.isEmpty {
              Text(session.tlsWizardError)
                .font(.caption)
                .foregroundStyle(.red)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }

        RemoteSetupStep(
          number: 3,
          title: "Prepare TLS Tooling",
          detail: toolsDetail,
          state: toolsState
        ) {
          Text(session.tlsWizardUsesDynamicIP ? "Dynamic mode expects your DDNS updater to keep \(smtpHost) current." : "Stable mode expects \(smtpHost) to resolve to the active mail server.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
        }

        RemoteSetupStep(
          number: 4,
          title: "Run TLS Setup",
          detail: session.snapshot.settings.ssl_ready ? "TLS certificate is ready." : "Provision TLS after DNS points at the active mail server.",
          state: certificateState
        ) {
          HStack(spacing: 8) {
            Button { session.setupTLSForCurrentServer() } label: {
              Label("Set Up TLS", systemImage: "lock.shield")
            }
            .fixedSize()
            .disabled(!session.snapshot.settings.domain_configured || !session.tlsWizardDNSReady || session.snapshot.settings.ssl_ready || session.isBusy)
            Text(session.snapshot.settings.ssl_ready ? "Ready" : "Not ready")
              .font(.caption)
              .foregroundStyle(session.snapshot.settings.ssl_ready ? .green : .secondary)
          }
        }
      }
      .task {
        if session.snapshot.settings.domain_configured && session.tlsWizardStatus == nil {
          session.refreshTLSWizardStatus()
        }
      }
    }
  }

  private var dnsHelpText: String {
    if session.tlsWizardUsesDynamicIP {
      return "Use dynamic mode when the server IP changes. The SMTP host may be CNAME or A/AAAA; MX still points to \(smtpHost)."
    }
    return "Use stable mode when the server IP stays fixed. Add A/AAAA for the root and SMTP host; MX points to \(smtpHost)."
  }

  private var toolsDetail: String {
    if session.tlsWizardStatus?.checks.certbot_installed == true {
      return "Certbot is installed. Setup can continue."
    }
    return "Certbot and supporting tools will be installed automatically during setup."
  }

  private var dnsRecords: [TLSDNSRecord] {
    guard let status = session.tlsWizardStatus else {
      if session.tlsWizardUsesDynamicIP {
        return [
          TLSDNSRecord(type: "A", name: domainText.isEmpty ? "@" : domainText, value: "(optional: current public IP)", priority: nil),
          TLSDNSRecord(type: "CNAME", name: smtpHost, value: "your-ddns-hostname.example.net", priority: nil),
          TLSDNSRecord(type: "MX", name: domainText.isEmpty ? "@" : domainText, value: smtpHost, priority: 10)
        ]
      }
      return [
        TLSDNSRecord(type: "A", name: domainText.isEmpty ? "@" : domainText, value: "(server public IP)", priority: nil),
        TLSDNSRecord(type: "A", name: smtpHost, value: "(server public IP)", priority: nil),
        TLSDNSRecord(type: "MX", name: domainText.isEmpty ? "@" : domainText, value: smtpHost, priority: 10)
      ]
    }
    if session.tlsWizardUsesDynamicIP {
      return [
        TLSDNSRecord(type: "A", name: domainText.isEmpty ? "@" : domainText, value: "(optional: current public IP)", priority: nil),
        TLSDNSRecord(type: "CNAME", name: smtpHost, value: "your-ddns-hostname.example.net", priority: nil),
        TLSDNSRecord(type: "MX", name: domainText.isEmpty ? "@" : domainText, value: smtpHost, priority: 10)
      ]
    }
    return status.suggested_records.isEmpty ? [
      TLSDNSRecord(type: "A", name: domainText.isEmpty ? "@" : domainText, value: status.expected_ip.isEmpty ? "(server public IP)" : status.expected_ip, priority: nil),
      TLSDNSRecord(type: "A", name: smtpHost, value: status.expected_ip.isEmpty ? "(server public IP)" : status.expected_ip, priority: nil),
      TLSDNSRecord(type: "MX", name: domainText.isEmpty ? "@" : domainText, value: smtpHost, priority: 10)
    ] : status.suggested_records
  }
}

private struct TLSDNSRecordRow: View {
  let record: TLSDNSRecord
  let domain: String

  private var displayName: String {
    let trimmed = record.name.trimmingCharacters(in: .whitespacesAndNewlines)
    return !domain.isEmpty && trimmed == domain ? "@" : trimmed
  }

  private var recordText: String {
    let type = record.type.uppercased()
    if type == "MX" {
      return "MX  \(displayName)  \(record.priority ?? 10) \(record.value)"
    }
    return "\(type)  \(displayName)  \(record.value)"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(recordText)
        .font(.system(.caption, design: .monospaced))
        .textSelection(.enabled)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
      if record.type.uppercased() == "MX" {
        Text("MX target must be a hostname. DNS forms often split this into Host/Name \(displayName), Priority \(record.priority ?? 10), Target/Value \(record.value).")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

private struct RemoteServerWalkthroughView: View {
  @EnvironmentObject private var session: StellarSession

  private var targetState: SetupStepState {
    session.remoteDraftConfigured && session.remotePortDraftValid ? .complete : .active
  }

  private var authState: SetupStepState {
    guard session.remoteDraftConfigured else { return .locked }
    return session.remotePasswordAvailable ? .complete : .active
  }

  private var deployState: SetupStepState {
    guard session.remoteReadyForDeploy else { return .locked }
    return session.snapshot.settings.remote.last_deploy_status == "ok" ? .complete : .active
  }

  private var testState: SetupStepState {
    guard session.remoteReadyForDeploy else { return .locked }
    return session.snapshot.settings.remote.last_test_status == "ok" ? .complete : .active
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      RemoteSetupStep(
        number: 1,
        title: "SSH Target",
        detail: session.remoteDraftConfigured ? "Remote login and key are ready to save." : "Enter the server login and SSH key.",
        state: targetState
      ) {
        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            TextField("user@203.0.113.8", text: $session.remoteHostDraft)
              .textFieldStyle(.roundedBorder)
              .frame(width: 190)
            TextField("~/.ssh/id_ed25519", text: $session.remoteKeyPathDraft)
              .textFieldStyle(.roundedBorder)
              .frame(width: 220)
            TextField("Port", text: $session.remotePortDraft)
              .textFieldStyle(.roundedBorder)
              .frame(width: 70)
          }
          if !session.remotePortDraftValid {
            Text("SSH port must be 1-65535.")
              .font(.caption)
              .foregroundStyle(.red)
          }
          Button { session.saveRemoteTarget() } label: {
            Label("Save Target", systemImage: "checkmark")
          }
          .fixedSize()
          .disabled(!session.remotePortDraftValid || session.isBusy)
        }
      }

      RemoteSetupStep(
        number: 2,
        title: "SSH Authentication",
        detail: authDetail,
        state: authState
      ) {
        VStack(alignment: .leading, spacing: 8) {
          Toggle("SSH key has password", isOn: Binding(
            get: { session.remoteKeyHasPassword },
            set: { next in
              session.remoteKeyHasPassword = next
              if !next {
                session.remoteKeySavePassword = false
                session.remoteKeyPasswordDraft = ""
              }
            }
          ))
          .fixedSize()
          if session.remoteKeyHasPassword {
            HStack(spacing: 6) {
              Group {
                if session.remotePasswordVisible {
                  TextField("SSH key password", text: $session.remoteKeyPasswordDraft)
                } else {
                  SecureField("SSH key password", text: $session.remoteKeyPasswordDraft)
                }
              }
              .textFieldStyle(.roundedBorder)
              .frame(width: 260)
              Button {
                session.remotePasswordVisible.toggle()
              } label: {
                Image(systemName: session.remotePasswordVisible ? "eye.slash" : "eye")
                  .frame(width: 18, height: 18)
              }
              .buttonStyle(.borderless)
              .help(session.remotePasswordVisible ? "Hide SSH key password" : "Show SSH key password")
            }
            Toggle("Save securely on this \(session.snapshot.settings.remote_auth.secrets_device_label)", isOn: $session.remoteKeySavePassword)
              .fixedSize()
              .disabled(!session.snapshot.settings.remote_auth.secrets_supported)
            if !session.snapshot.settings.remote_auth.secrets_supported {
              Text("Secure credential save is unavailable on this system.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          Button { session.saveRemoteAuth() } label: {
            Label("Save Authentication", systemImage: "key")
          }
          .fixedSize()
          .disabled(!session.remoteDraftConfigured || !session.remotePortDraftValid || !session.remotePasswordAvailable || session.isBusy)
        }
      }

      RemoteSetupStep(
        number: 3,
        title: "Deploy And Verify",
        detail: session.snapshot.settings.remote.last_deploy_message.isEmpty ? "Install Stellar on the server, then verify receiver health." : session.snapshot.settings.remote.last_deploy_message,
        state: deployState
      ) {
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 8) {
            Button { session.deployRemoteServer() } label: {
              Label("Deploy Remote Server", systemImage: "shippingbox.and.arrow.backward")
            }
            .fixedSize()
            .disabled(!session.remoteReadyForDeploy || session.isBusy)
            Button { session.verifyRemote() } label: {
              Label("Verify Remote Setup", systemImage: "network")
            }
            .fixedSize()
            .disabled(!session.remoteReadyForDeploy || session.isBusy)
          }
          HStack(spacing: 6) {
            RemoteStatusPill(label: "Deploy", status: session.snapshot.settings.remote.last_deploy_status, message: session.snapshot.settings.remote.last_deploy_message)
            RemoteStatusPill(label: "Verify", status: session.snapshot.settings.remote.last_verify_status, message: session.snapshot.settings.remote.last_verify_message)
          }
        }
      }

      RemoteSetupStep(
        number: 4,
        title: "Test And Sync",
        detail: session.snapshot.settings.remote.last_test_message.isEmpty ? "Send a test email and pull remote mail into local Stellar." : session.snapshot.settings.remote.last_test_message,
        state: testState
      ) {
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 8) {
            Button { session.sendRemoteTestEmail() } label: {
              Label("Send Test Email", systemImage: "paperplane")
            }
            .fixedSize()
            .disabled(!session.remoteReadyForDeploy || session.isBusy)
            Button { session.syncRemote() } label: {
              Label("Check Remote Mail", systemImage: "arrow.triangle.2.circlepath")
            }
            .fixedSize()
            .disabled(!session.remoteReadyForDeploy || session.isBusy)
          }
          HStack(spacing: 6) {
            RemoteStatusPill(label: "Test", status: session.snapshot.settings.remote.last_test_status, message: session.snapshot.settings.remote.last_test_message)
            RemoteStatusPill(label: "Sync", status: session.snapshot.settings.remote.last_sync_status, message: session.snapshot.settings.remote.last_sync_message)
          }
        }
      }

      Text(session.remoteStatusSummary)
        .font(.caption)
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.leading, 34)
    }
  }

  private var authDetail: String {
    if !session.remoteDraftConfigured {
      return "Save the remote target first."
    }
    if !session.remoteKeyHasPassword {
      return "Passwordless SSH key selected."
    }
    if session.remotePasswordAvailable {
      return "SSH key password is available for remote actions."
    }
    return "Enter the SSH key password or enable secure save."
  }
}

private struct BubbleColorPickerRow: View {
  let title: String
  @Binding var color: Color

  var body: some View {
    ColorPicker(title, selection: $color, supportsOpacity: false)
      .fixedSize()
  }
}

private struct EmptyStateView: View {
  let title: String
  let subtitle: String

  var body: some View {
    VStack(spacing: 8) {
      Text(title)
        .font(.headline)
      Text(subtitle)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private enum SeedData {
  static let email = MessageItem(
    id: "seed-email-1",
    backend_kind: "email",
    transport: "email",
    lock: "open",
    thread_id: "alice-ledger",
    contact_name: "Alice Ledger",
    email: "alice@example.org",
    simplex_address: "simplex://alice-ledger",
    list: "accepted",
    subject: "Longer email-style note",
    body: "This longer email-style message is rendered in the same continuous contact timeline as short chat messages. It stays visible here while its Inbox pill points back to the Inbox card.",
    preview: "This longer email-style message is rendered in the same continuous contact timeline.",
    received_at: "2026-04-20T10:00:00Z",
    in_inbox: true
  )

  static let simplex = MessageItem(
    id: "seed-simplex-1",
    backend_kind: "simplex",
    transport: "simplex",
    lock: "closed",
    thread_id: "alice-ledger",
    contact_name: "Alice Ledger",
    email: "alice@example.org",
    simplex_address: "simplex://alice-ledger",
    body: "Short secure reply.",
    preview: "Short secure reply.",
    received_at: "2026-04-20T10:03:00Z",
    from_self: true
  )

  static let groupMessage = MessageItem(
    id: "seed-simplex-group",
    backend_kind: "simplex",
    transport: "simplex",
    lock: "closed",
    thread_id: "river-stone",
    contact_name: "River Stone",
    contact_kind: "group",
    simplex_address: "simplex://river-stone",
    body: "Group update landed over SimpleX.",
    preview: "Group update landed over SimpleX.",
    received_at: "2026-04-20T11:00:00Z",
    in_inbox: true
  )

  static let alice = ThreadItem(
    id: "alice-ledger",
    name: "Alice Ledger",
    email: "alice@example.org",
    simplex_address: "simplex://alice-ledger",
    favorite: true,
    unread_count: 1,
    latest_at: "2026-04-20T10:03:00Z",
    messages: [email, simplex]
  )

  static let river = ThreadItem(
    id: "river-stone",
    kind: "group",
    name: "River Stone",
    simplex_address: "simplex://river-stone",
    favorite: true,
    unread_count: 1,
    latest_at: "2026-04-20T11:00:00Z",
    messages: [groupMessage]
  )

  static let snapshot = Snapshot(
    root: defaultMailRoot(),
    inbox: [email, groupMessage],
    favorites: [alice, river],
    individuals: [alice],
    groups: [river],
    threads: [river, alice],
    messages: [email, simplex, groupMessage],
    mailboxes: [
      MailboxItem(id: "accepted", title: "Accepted", count: 1, unread: 1),
      MailboxItem(id: "archive", title: "Archive"),
      MailboxItem(id: "sent", title: "Sent")
    ],
    drafts: [],
    events: [],
    overview: Overview(counts: OverviewCounts(inbox_messages: 2, new_messages: 0, archive_messages: 0, trash_messages: 0, drafts: 0, sent: 0)),
    simplex: SimpleXSnapshot(install_state: "missing")
  )
}
