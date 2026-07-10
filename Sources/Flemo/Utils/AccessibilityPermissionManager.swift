import Cocoa
import ApplicationServices
import os.log

class AccessibilityPermissionManager: NSObject, ObservableObject {
    static let shared = AccessibilityPermissionManager()
    private let log = OSLog(subsystem: "com.flemo.app", category: "Permission")
    @Published var accessibilityGranted: Bool = false
    @Published var inputMonitoringGranted: Bool = false
    @Published var automationGranted: Bool = false

    override private init() {
        super.init()
        refreshStatus()
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(accessibilityStatusChanged),
            name: NSNotification.Name("com.apple.accessibility.api"), object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appDidActivate),
            name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
    }

    @objc private func accessibilityStatusChanged() {
        refreshStatus()
    }

    @objc private func appDidActivate() {
        refreshStatus()
    }

    @discardableResult
    func refreshStatus() -> (accessibility: Bool, inputMonitoring: Bool, automation: Bool) {
        let ax = hasAccessibility()
        let im = hasInputMonitoring()
        let am = hasAutomation()
        let update = {
            self.accessibilityGranted = ax
            self.inputMonitoringGranted = im
            self.automationGranted = am
        }
        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
        if ax { os_log(.info, log: log, "Accessibility granted") }
        if im { os_log(.info, log: log, "Input monitoring granted") }
        if am { os_log(.info, log: log, "Automation granted") }
        return (ax, im, am)
    }

    func hasAccessibility() -> Bool {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: false] as NSDictionary)
    }

    func hasInputMonitoring() -> Bool {
        CGPreflightListenEventAccess()
    }

    func requestAccessibility() {
        guard !hasAccessibility() else {
            refreshStatus()
            return
        }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true] as NSDictionary
        AXIsProcessTrustedWithOptions(opts)
        refreshStatus()
    }

    func requestInputMonitoring() {
        guard !hasInputMonitoring() else {
            refreshStatus()
            return
        }
        _ = CGRequestListenEventAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
        refreshStatus()
    }

    func hasAutomation() -> Bool {
        let script = NSAppleScript(source: """
            tell application id "com.apple.finder"
                return name
            end tell
            """)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        return error == nil
    }

    func requestAutomation() {
        guard !hasAutomation() else {
            refreshStatus()
            return
        }
        let script = NSAppleScript(source: """
            tell application id "com.apple.finder"
                return name
            end tell
            """)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        refreshStatus()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    func showPermissionGuide() {
        let alert = NSAlert()
        alert.messageText = "Flemo Needs Permissions"
        alert.informativeText = """
        To detect keystrokes and show inline emoji suggestions, Flemo needs THREE permissions:

        1. Accessibility — for reading text and cursor position:
           System Settings → Privacy & Security → Accessibility
           → Add /Applications/Flemo.app, toggle ON.

        2. Input Monitoring — for detecting keyboard events:
           System Settings → Privacy & Security → Input Monitoring
           → Add /Applications/Flemo.app, toggle ON.

        3. Automation — for reading the browser URL to apply site rules:
           System Settings → Privacy & Security → Automation
           → Add /Applications/Flemo.app, check all browsers.

        After granting all, return to Flemo. It will retry automatically.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Accessibility")
        alert.addButton(withTitle: "Open Input Monitoring")
        alert.addButton(withTitle: "Open Automation")
        alert.addButton(withTitle: "Later")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(u)
            }
        } else if response == .alertSecondButtonReturn {
            if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                NSWorkspace.shared.open(u)
            }
        } else if response == .alertThirdButtonReturn {
            if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                NSWorkspace.shared.open(u)
            }
        }
    }

    func statusDescription() -> String {
        let ax = hasAccessibility() ? "✅" : "❌"
        let im = hasInputMonitoring() ? "✅" : "❌"
        let am = hasAutomation() ? "✅" : "❌"
        return "Accessibility: \(ax)\nInput Monitoring: \(im)\nAutomation: \(am)"
    }
}
