import Cocoa

class MenuBarManager {
    private var statusItem: NSStatusItem!
    private weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setupMenuBar()
    }

    private func setupMenuBar() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "face.smiling", accessibilityDescription: "Flemo")
        }

        let menu = NSMenu()

        func item(
            _ title: String,
            action: Selector,
            key: String = "",
            modifiers: NSEvent.ModifierFlags = [.command]
        ) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
            if !key.isEmpty {
                i.keyEquivalentModifierMask = modifiers
            }
            i.target = appDelegate
            return i
        }

        menu.addItem(item(
            "Quick Emoji Board",
            action: #selector(AppDelegate.toggleQuickEmojiBoard),
            key: "e",
            modifiers: [.command, .shift]
        ))
        menu.addItem(item("Emoji Library", action: #selector(AppDelegate.toggleEmojiBoard)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(item("Welcome / Onboarding", action: #selector(AppDelegate.showOnboarding)))
        menu.addItem(item("Check for Updates...", action: #selector(AppDelegate.checkForUpdates)))

        let versionItem = NSMenuItem(title: versionString, action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(item("Settings...", action: #selector(AppDelegate.openSettings), key: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(item("Quit", action: #selector(AppDelegate.quit), key: "q"))

        statusItem.menu = menu
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "Development"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "Version \(version) (\($0))" } ?? "Version \(version)"
    }
}
