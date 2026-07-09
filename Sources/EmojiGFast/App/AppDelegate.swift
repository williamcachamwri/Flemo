import Cocoa
import SwiftUI
import os.log

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager!
    private var globalInputMonitor: GlobalInputMonitor!
    private var overlayPanel: OverlayPanel!
    private var shortcutMonitor: ShortcutSelectionMonitor!
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var emojiBoardWindow: NSWindow?
    private var currentKeyword = ""
    private let log = OSLog(subsystem: "com.emoji-g-fast", category: "AppDelegate")

    let appState = AppState.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        os_log(.info, log: log, "App launched")

        DispatchQueue.main.async { [self] in
            appState.syncFromSettings()

            let pm = AccessibilityPermissionManager.shared
            pm.requestAccessibility()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pm.requestInputMonitoring()
                self.globalInputMonitor?.refreshPermissionsAndRetry()
            }

            menuBarManager = MenuBarManager(appDelegate: self)

            let overlayContent = SuggestionPopupView(appState: appState) { [weak self] emoji in
                self?.handleEmojiSelected(emoji)
            }
            overlayPanel = OverlayPanel(contentView: NSHostingView(rootView: overlayContent))

            globalInputMonitor = GlobalInputMonitor(appState: appState)
            globalInputMonitor.onTriggerDetected = { [weak self] keyword, anchorRect in
                self?.showSuggestions(for: keyword, below: anchorRect)
            }
            globalInputMonitor.onTriggerCancelled = { [weak self] in
                self?.hideSuggestions()
            }
            globalInputMonitor.onNavigateSuggestions = { [weak self] delta in
                self?.navigateSuggestions(delta: delta)
            }
            globalInputMonitor.onConfirmSuggestion = { [weak self] in
                self?.confirmSelectedSuggestion()
            }
            globalInputMonitor.start()

            shortcutMonitor = ShortcutSelectionMonitor(appState: appState)
            shortcutMonitor.start(
                emojiHandler: { [weak self] e in self?.handleEmojiSelected(e) }
            )

            showOnboardingIfNeeded()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AccessibilityPermissionManager.shared.refreshStatus()
        globalInputMonitor.refreshPermissionsAndRetry()
    }

    private func showOnboardingIfNeeded() {
        let hasSeen = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        guard !hasSeen else { return }

        let hosting = NSHostingController(rootView: OnboardingView())
        let w = NSWindow(contentViewController: hosting)
        w.title = "Welcome"
        w.styleMask = [.titled, .closable]
        w.setContentSize(NSSize(width: 480, height: 520))
        w.makeKeyAndOrderFront(nil)
        w.center()
        onboardingWindow = w

        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
    }

    @objc func showOnboarding() {
        let hosting = NSHostingController(rootView: OnboardingView())
        let w = NSWindow(contentViewController: hosting)
        w.title = "Welcome"
        w.styleMask = [.titled, .closable]
        w.setContentSize(NSSize(width: 480, height: 520))
        w.makeKeyAndOrderFront(nil)
        w.center()
    }

    private func showSuggestions(for keyword: String, below anchorRect: CGRect) {
        os_log(.info, "Show suggestions: '%{public}s'", keyword)
        let isSameKeyword = appState.isShowingSuggestions && currentKeyword == keyword
        currentKeyword = keyword
        appState.inlinePopupHeight = popupHeight(for: anchorRect)
        let results = EmojiSearchEngine.shared.search(keyword: keyword, maxResults: 10)
        if !isSameKeyword || appState.suggestions.isEmpty {
            appState.suggestions = results.enumerated().map { (i, e) in
                SuggestionItem(emoji: e, shortcutIndex: appState.numberShortcutEnabled && i < 10 ? i : nil)
            }
        }
        if isSameKeyword {
            clampVisibleSelection()
        } else {
            appState.selectedSuggestionIndex = 0
            appState.visibleSuggestionStart = 0
        }
        appState.isShowingSuggestions = !results.isEmpty
        if appState.isShowingSuggestions { showOverlayAfterLayout(below: anchorRect) }
        else { overlayPanel.hide() }
    }

    private func popupHeight(for anchorRect: CGRect) -> CGFloat {
        let rawHeight = max(anchorRect.height, 1)
        let lineHeight: CGFloat
        if anchorRect.width > 120, rawHeight <= 60 {
            lineHeight = min(max(rawHeight * 0.45, 16), 22)
        } else {
            lineHeight = rawHeight
        }

        return min(max(lineHeight * 1.55 + 12, 40), 62)
    }

    private func showOverlayAfterLayout(below anchorRect: CGRect) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.appState.isShowingSuggestions else { return }
            self.overlayPanel.show(below: anchorRect)
        }
    }

    private func hideSuggestions() {
        appState.isShowingSuggestions = false
        appState.suggestions = []
        appState.selectedSuggestionIndex = 0
        appState.visibleSuggestionStart = 0
        currentKeyword = ""
        overlayPanel.hide()
    }

    private func navigateSuggestions(delta: Int) {
        guard appState.isShowingSuggestions, !appState.suggestions.isEmpty else { return }
        let maxIndex = appState.suggestions.count - 1
        let next = min(max(appState.selectedSuggestionIndex + delta, 0), maxIndex)
        appState.selectedSuggestionIndex = next

        clampVisibleSelection()
    }

    private func clampVisibleSelection() {
        guard !appState.suggestions.isEmpty else {
            appState.selectedSuggestionIndex = 0
            appState.visibleSuggestionStart = 0
            return
        }

        let maxIndex = appState.suggestions.count - 1
        appState.selectedSuggestionIndex = min(max(appState.selectedSuggestionIndex, 0), maxIndex)

        let pageSize = AppState.inlineVisibleCount
        let maxStart = max(appState.suggestions.count - pageSize, 0)
        appState.visibleSuggestionStart = min(max(appState.visibleSuggestionStart, 0), maxStart)

        if appState.selectedSuggestionIndex < appState.visibleSuggestionStart {
            appState.visibleSuggestionStart = appState.selectedSuggestionIndex
        } else if appState.selectedSuggestionIndex >= appState.visibleSuggestionStart + pageSize {
            appState.visibleSuggestionStart = appState.selectedSuggestionIndex - pageSize + 1
        }
    }

    private func confirmSelectedSuggestion() {
        guard appState.isShowingSuggestions,
              appState.suggestions.indices.contains(appState.selectedSuggestionIndex)
        else { return }
        handleEmojiSelected(appState.suggestions[appState.selectedSuggestionIndex].emoji)
    }

    private func handleEmojiSelected(_ emoji: Emoji) {
        FrequencyTracker.shared.recordUsage(emoji: emoji)
        let k = currentKeyword
        if !k.isEmpty {
            TextInsertionHelper.shared.replaceTriggerText(
                triggerChar: appState.triggerCharacter, keyword: k, with: emoji.character)
        } else {
            TextInsertionHelper.shared.insertText(emoji.character)
        }
        hideSuggestions()
    }

    @objc func toggleEmojiBoard() {
        if let w = emojiBoardWindow, w.isVisible { w.close(); emojiBoardWindow = nil; return }
        let v = EmojiBoardView { [weak self] e in self?.handleEmojiSelected(e) }
        let w = NSWindow(contentViewController: NSHostingController(rootView: v))
        w.title = "Emoji Board"
        w.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        w.setContentSize(NSSize(width: 500, height: 600))
        w.makeKeyAndOrderFront(nil); w.center()
        emojiBoardWindow = w
    }

    @objc func openSettings() {
        if let w = settingsWindow, w.isVisible { w.makeKeyAndOrderFront(nil); return }
        let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
        w.title = "Settings"
        w.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        w.setContentSize(NSSize(width: 720, height: 520))
        w.minSize = NSSize(width: 680, height: 480)
        w.makeKeyAndOrderFront(nil); w.center()
        settingsWindow = w
    }

    @objc func checkPermissions() {
        let pm = AccessibilityPermissionManager.shared
        let desc = pm.statusDescription()
        let a = NSAlert()
        a.messageText = "Permissions Status"
        a.informativeText = desc
        a.runModal()
    }

    @objc func requestPermissions() {
        let pm = AccessibilityPermissionManager.shared
        pm.showPermissionGuide()
        pm.requestAccessibility()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pm.requestInputMonitoring()
            self.globalInputMonitor.refreshPermissionsAndRetry()
        }
    }

    @objc func quit() { NSApplication.shared.terminate(nil) }
}

class AppState: ObservableObject {
    static let shared = AppState()
    @Published var isShowingSuggestions = false
    @Published var suggestions: [SuggestionItem] = []
    @Published var triggerCharacter: String = AppSettings.shared.triggerCharacter {
        didSet { AppSettings.shared.triggerCharacter = triggerCharacter }
    }
    @Published var minTriggerLength: Int = AppSettings.shared.minTriggerLength {
        didSet { AppSettings.shared.minTriggerLength = minTriggerLength }
    }
    @Published var inlineTriggerEnabled: Bool = AppSettings.shared.inlineTriggerEnabled {
        didSet { AppSettings.shared.inlineTriggerEnabled = inlineTriggerEnabled }
    }
    @Published var numberShortcutEnabled: Bool = AppSettings.shared.numberShortcutEnabled {
        didSet { AppSettings.shared.numberShortcutEnabled = numberShortcutEnabled }
    }
    @Published var selectedSuggestionIndex: Int = 0
    @Published var visibleSuggestionStart: Int = 0
    @Published var inlinePopupHeight: CGFloat = 62

    static let inlineVisibleCount = 4

    func syncFromSettings() {
        triggerCharacter = AppSettings.shared.triggerCharacter
        minTriggerLength = AppSettings.shared.minTriggerLength
        inlineTriggerEnabled = AppSettings.shared.inlineTriggerEnabled
        numberShortcutEnabled = AppSettings.shared.numberShortcutEnabled
    }
}

struct SuggestionItem: Identifiable {
    let id = UUID()
    let emoji: Emoji
    let shortcutIndex: Int?
}

extension Emoji: Identifiable {
    var id: String { character }
}
