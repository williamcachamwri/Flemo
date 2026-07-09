import Foundation

class AppSettings {
    static let shared = AppSettings()

    private let storage = StorageManager.shared

    var triggerCharacter: String {
        get { current.triggerCharacter }
        set { current.triggerCharacter = newValue; persist() }
    }

    var minTriggerLength: Int {
        get { current.minTriggerLength }
        set { current.minTriggerLength = newValue; persist() }
    }

    var inlineTriggerEnabled: Bool {
        get { current.inlineTriggerEnabled }
        set { current.inlineTriggerEnabled = newValue; persist() }
    }

    var numberShortcutEnabled: Bool {
        get { current.numberShortcutEnabled }
        set { current.numberShortcutEnabled = newValue; persist() }
    }

    var emojiBoardShortcut: ShortcutKey {
        get { current.emojiBoardShortcut }
        set { current.emojiBoardShortcut = newValue; persist() }
    }

    var inlinePanelOpenMode: InlinePanelOpenMode {
        get { current.inlinePanelOpenMode }
        set { current.inlinePanelOpenMode = newValue; persist() }
    }

    var inlineSuggestionLayout: InlineSuggestionLayout {
        get { current.inlineSuggestionLayout }
        set { current.inlineSuggestionLayout = newValue; persist() }
    }

    var popupTheme: PopupTheme {
        get { current.popupTheme }
        set { current.popupTheme = newValue; persist() }
    }

    var ignoredSiteRules: [IgnoredSiteRule] {
        get { current.ignoredSiteRules }
        set { current.ignoredSiteRules = newValue; persist() }
    }

    var ignoredAppRules: [IgnoredAppRule] {
        get { current.ignoredAppRules }
        set { current.ignoredAppRules = newValue; persist() }
    }

    private var current: AppSettingsData

    private init() {
        if let saved = storage.loadSettings() {
            current = saved
        } else {
            current = AppSettingsData(
                triggerCharacter: "`",
                minTriggerLength: 2,
                inlineTriggerEnabled: true,
                numberShortcutEnabled: true,
                emojiBoardShortcut: ShortcutKey(keyCode: 0x00, modifiers: 0x0100),
                inlinePanelOpenMode: .recents,
                inlineSuggestionLayout: .sleek,
                popupTheme: .nativeDark
            )
        }
    }

    private func persist() {
        storage.saveSettings(current)
    }

    func resetToDefaults() {
        current = AppSettingsData(
            triggerCharacter: "`",
            minTriggerLength: 2,
            inlineTriggerEnabled: true,
            numberShortcutEnabled: true,
            emojiBoardShortcut: ShortcutKey(keyCode: 0x00, modifiers: 0x0100),
            inlinePanelOpenMode: .recents,
            inlineSuggestionLayout: .sleek,
            popupTheme: .nativeDark,
            ignoredSiteRules: [],
            ignoredAppRules: []
        )
        persist()
    }
}
