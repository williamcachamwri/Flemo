import Foundation

class AppSettings {
    static let shared = AppSettings()

    private let storage = StorageManager.shared
    private let lock = NSLock()

    var triggerCharacter: String {
        get { read(\.triggerCharacter) }
        set { update { $0.triggerCharacter = newValue } }
    }

    var minTriggerLength: Int {
        get { read(\.minTriggerLength) }
        set { update { $0.minTriggerLength = newValue } }
    }

    var inlineTriggerEnabled: Bool {
        get { read(\.inlineTriggerEnabled) }
        set { update { $0.inlineTriggerEnabled = newValue } }
    }

    var emojiBoardShortcut: ShortcutKey {
        get { read(\.emojiBoardShortcut) }
        set { update { $0.emojiBoardShortcut = newValue } }
    }

    var inlinePanelOpenMode: InlinePanelOpenMode {
        get { read(\.inlinePanelOpenMode) }
        set { update { $0.inlinePanelOpenMode = newValue } }
    }

    var inlineSuggestionLayout: InlineSuggestionLayout {
        get { read(\.inlineSuggestionLayout) }
        set { update { $0.inlineSuggestionLayout = newValue } }
    }

    var popupTheme: PopupTheme {
        get { read(\.popupTheme) }
        set { update { $0.popupTheme = newValue } }
    }

    var personSkinTone: EmojiSkinTone {
        get { read(\.personSkinTone) }
        set { update { $0.personSkinTone = newValue } }
    }

    var manSkinTone: EmojiSkinTone {
        get { read(\.manSkinTone) }
        set { update { $0.manSkinTone = newValue } }
    }

    var womanSkinTone: EmojiSkinTone {
        get { read(\.womanSkinTone) }
        set { update { $0.womanSkinTone = newValue } }
    }

    var ignoredSiteRules: [IgnoredSiteRule] {
        get { read(\.ignoredSiteRules) }
        set { update { $0.ignoredSiteRules = newValue } }
    }

    var ignoredAppRules: [IgnoredAppRule] {
        get { read(\.ignoredAppRules) }
        set { update { $0.ignoredAppRules = newValue } }
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
                emojiBoardShortcut: ShortcutKey(keyCode: 0x00, modifiers: 0x0100),
                inlinePanelOpenMode: .recents,
                inlineSuggestionLayout: .sleek,
                popupTheme: .nativeDark,
                personSkinTone: .standard,
                manSkinTone: .standard,
                womanSkinTone: .standard,
            )
        }
    }

    private func read<Value>(_ keyPath: KeyPath<AppSettingsData, Value>) -> Value {
        lock.lock()
        defer { lock.unlock() }
        return current[keyPath: keyPath]
    }

    private func update(_ change: (inout AppSettingsData) -> Void) {
        lock.lock()
        change(&current)
        storage.saveSettings(current)
        lock.unlock()
    }

    func resetToDefaults() {
        let defaults = AppSettingsData(
            triggerCharacter: "`",
            minTriggerLength: 2,
            inlineTriggerEnabled: true,
            emojiBoardShortcut: ShortcutKey(keyCode: 0x00, modifiers: 0x0100),
            inlinePanelOpenMode: .recents,
            inlineSuggestionLayout: .sleek,
            popupTheme: .nativeDark,
            personSkinTone: .standard,
            manSkinTone: .standard,
            womanSkinTone: .standard,
            ignoredSiteRules: [],
            ignoredAppRules: []
        )

        lock.lock()
        current = defaults
        storage.saveSettings(current)
        lock.unlock()
    }
}
