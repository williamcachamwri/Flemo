import AppKit
import Foundation

final class RulesManager {
    static let shared = RulesManager()

    private let browserBundleIdentifiers: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "company.thebrowser.Browser",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera"
    ]

    private var cachedBundleIdentifier = ""
    private var cachedHost = ""
    private var cachedAt = Date.distantPast
    private let cacheDuration: TimeInterval = 0.8

    static func normalizeDomain(_ rawValue: String) -> String {
        var value = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if value.hasPrefix("http://") || value.hasPrefix("https://") {
            if let host = URL(string: value)?.host {
                value = host
            }
        }

        value = value
            .replacingOccurrences(of: "www.", with: "")
            .split(separator: "/").first.map(String.init) ?? value
        value = value.split(separator: ":").first.map(String.init) ?? value
        return value.filter { !$0.isWhitespace }
    }

    func shouldSuppressInput(appState: AppState) -> Bool {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else { return false }
        let bundleIdentifier = frontmostApp.bundleIdentifier ?? ""
        let appName = frontmostApp.localizedName ?? ""

        if appState.ignoredAppRules.contains(where: { rule in
            rule.bundleIdentifier == bundleIdentifier || (!appName.isEmpty && rule.name == appName)
        }) {
            return true
        }

        guard !appState.ignoredSiteRules.isEmpty,
              browserBundleIdentifiers.contains(bundleIdentifier),
              let host = currentBrowserHost(bundleIdentifier: bundleIdentifier)
        else {
            return false
        }

        return appState.ignoredSiteRules.contains { rule in
            host == rule.domain || host.hasSuffix("." + rule.domain)
        }
    }

    func appRule(from applicationURL: URL) -> IgnoredAppRule? {
        guard let bundle = Bundle(url: applicationURL) else { return nil }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? applicationURL.deletingPathExtension().lastPathComponent
        guard let bundleIdentifier = bundle.bundleIdentifier else { return nil }
        return IgnoredAppRule(
            name: name,
            bundleIdentifier: bundleIdentifier,
            path: applicationURL.path
        )
    }

    private func currentBrowserHost(bundleIdentifier: String) -> String? {
        if cachedBundleIdentifier == bundleIdentifier,
           Date().timeIntervalSince(cachedAt) < cacheDuration {
            return cachedHost.isEmpty ? nil : cachedHost
        }

        let urlString: String?
        if bundleIdentifier == "com.apple.Safari" {
            urlString = runAppleScript("""
                tell application id "\(bundleIdentifier)"
                    if not (exists front window) then return ""
                    return URL of current tab of front window
                end tell
                """)
        } else {
            urlString = runAppleScript("""
                tell application id "\(bundleIdentifier)"
                    if not (exists front window) then return ""
                    return URL of active tab of front window
                end tell
                """)
        }

        let host = Self.normalizeDomain(urlString ?? "")
        cachedBundleIdentifier = bundleIdentifier
        cachedHost = host
        cachedAt = Date()
        return host.isEmpty ? nil : host
    }

    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return result?.stringValue
    }
}
