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

        // Try AppleScript first (exact URL)
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

        if let url = urlString, !url.isEmpty {
            let host = Self.normalizeDomain(url)
            cachedBundleIdentifier = bundleIdentifier
            cachedHost = host
            cachedAt = Date()
            return host.isEmpty ? nil : host
        }

        // Fallback: extract domain from frontmost window title
        if let host = domainFromWindowTitle(bundleIdentifier: bundleIdentifier) {
            cachedBundleIdentifier = bundleIdentifier
            cachedHost = host
            cachedAt = Date()
            return host
        }

        cachedBundleIdentifier = bundleIdentifier
        cachedHost = ""
        cachedAt = Date()
        return nil
    }

    private func domainFromWindowTitle(bundleIdentifier: String) -> String? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier == bundleIdentifier
        else { return nil }
        let appPID = frontApp.processIdentifier

        let windowInfo = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]]
        guard let windows = windowInfo else { return nil }

        for window in windows {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t, pid == appPID,
                  let title = window[kCGWindowName as String] as? String,
                  !title.isEmpty
            else { continue }

            // Skip browser chrome windows (tab overview, bookmarks, settings)
            if title == "New Tab" || title == "Settings" || title == "Bookmarks"
                || title.hasPrefix("chrome://") || title.hasPrefix("about:")
                || title.hasPrefix("chrome-extension://") { continue }

            // Try to extract domain from bracketed patterns: "Title (domain.com)" or "[domain.com]"
            if let domain = extractDomain(from: title) { return domain }

            // Check if the title itself looks like a domain
            let lower = title.lowercased()
            if looksLikeDomain(lower) { return lower }

            // For titles that are just a name, check common mapping
            if let mapped = commonSiteMapping(title: lower) { return mapped }
        }
        return nil
    }

    private func extractDomain(from title: String) -> String? {
        let patterns = [
            // "Title (github.com)" or "Title (www.github.com)"
            try? NSRegularExpression(pattern: "\\(([^)]+\\.[a-z]{2,})\\)"),
            // "Title [site.com]"
            try? NSRegularExpression(pattern: "\\[([^]]+\\.[a-z]{2,})\\]"),
            // "Title — site.com" or "Title – site.com"
            try? NSRegularExpression(pattern: "[—–]\\s*([a-z0-9.-]+\\.[a-z]{2,})"),
        ]
        for pattern in patterns.compactMap({ $0 }) {
            let range = NSRange(title.startIndex..<title.endIndex, in: title)
            if let match = pattern.firstMatch(in: title, range: range),
               let r = Range(match.range(at: 1), in: title) {
                let domain = String(title[r]).lowercased()
                    .replacingOccurrences(of: "www.", with: "")
                if domain.contains(".") { return domain }
            }
        }
        return nil
    }

    private func looksLikeDomain(_ text: String) -> Bool {
        // "github.com", "google.com", etc.
        if text.contains(".") && !text.contains(" ") {
            let parts = text.split(separator: ".")
            return parts.count >= 2 && parts.last!.count <= 6
        }
        // "http://..." or "https://..."
        if text.hasPrefix("http://") || text.hasPrefix("https://"),
           URL(string: text)?.host != nil {
            return true
        }
        return false
    }

    private func commonSiteMapping(title: String) -> String? {
        let lower = title.lowercased()
        let mappings: [(keyword: String, domain: String)] = [
            ("github", "github.com"),
            ("google docs", "docs.google.com"),
            ("google drive", "drive.google.com"),
            ("gmail", "mail.google.com"),
            ("youtube", "youtube.com"),
            ("notion", "notion.so"),
            ("slack", "slack.com"),
            ("figma", "figma.com"),
            ("linear", "linear.app"),
            ("jira", "atlassian.net"),
            ("confluence", "atlassian.net"),
            ("chatgpt", "chatgpt.com"),
            ("claude", "claude.ai"),
            ("x.com", "x.com"),
            ("twitter", "x.com"),
            ("reddit", "reddit.com"),
            ("stack overflow", "stackoverflow.com"),
            ("medium", "medium.com"),
            ("vercel", "vercel.com"),
            ("netlify", "netlify.com"),
        ]
        for (keyword, domain) in mappings {
            if lower.contains(keyword) { return domain }
        }
        return nil
    }

    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return result?.stringValue
    }
}
