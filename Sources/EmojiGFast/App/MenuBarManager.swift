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
            button.image = NSImage(systemSymbolName: "face.smiling", accessibilityDescription: "EmojiGFast")
        }

        let menu = NSMenu()

        func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
            i.target = appDelegate
            return i
        }

        menu.addItem(item("Emoji Board", action: #selector(AppDelegate.toggleEmojiBoard), key: "e"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(item("Welcome / Onboarding", action: #selector(AppDelegate.showOnboarding)))
        menu.addItem(item("Check Permissions", action: #selector(AppDelegate.checkPermissions)))
        menu.addItem(item("Request Permissions", action: #selector(AppDelegate.requestPermissions)))
        menu.addItem(item("Settings...", action: #selector(AppDelegate.openSettings), key: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(item("Quit", action: #selector(AppDelegate.quit), key: "q"))

        statusItem.menu = menu
    }
}
