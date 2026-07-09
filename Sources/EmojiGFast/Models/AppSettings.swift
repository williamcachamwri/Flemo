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

    var gifFeatureEnabled: Bool {
        get { current.gifFeatureEnabled }
        set { current.gifFeatureEnabled = newValue; persist() }
    }

    var numberShortcutEnabled: Bool {
        get { current.numberShortcutEnabled }
        set { current.numberShortcutEnabled = newValue; persist() }
    }

    var gifInsertionMode: GIFInsertionMode {
        get { current.gifInsertionMode }
        set { current.gifInsertionMode = newValue; persist() }
    }

    var emojiBoardShortcut: ShortcutKey {
        get { current.emojiBoardShortcut }
        set { current.emojiBoardShortcut = newValue; persist() }
    }

    var gifBoardShortcut: ShortcutKey {
        get { current.gifBoardShortcut }
        set { current.gifBoardShortcut = newValue; persist() }
    }

    var giphyAPIKey: String {
        get { current.giphyAPIKey }
        set { current.giphyAPIKey = newValue; persist() }
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
                gifFeatureEnabled: true,
                numberShortcutEnabled: true,
                gifInsertionMode: .link,
                emojiBoardShortcut: ShortcutKey(keyCode: 0x00, modifiers: 0x0100),
                gifBoardShortcut: ShortcutKey(keyCode: 0x05, modifiers: 0x0100),
                giphyAPIKey: ""
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
            gifFeatureEnabled: true,
            numberShortcutEnabled: true,
            gifInsertionMode: .link,
            emojiBoardShortcut: ShortcutKey(keyCode: 0x00, modifiers: 0x0100),
            gifBoardShortcut: ShortcutKey(keyCode: 0x05, modifiers: 0x0100),
            giphyAPIKey: ""
        )
        persist()
    }
}
