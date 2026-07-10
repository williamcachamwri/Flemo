import Foundation

class StorageManager {
    static let shared = StorageManager()

    private let defaults = UserDefaults.standard

    private let frequencyKey = "emoji_frequency"
    private let settingsKey = "app_settings"
    private let customAliasesKey = "emoji_custom_aliases"
    private let favoritesKey = "emoji_favorites"

    func loadFrequencyData() -> [String: Int] {
        guard let data = defaults.data(forKey: frequencyKey),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return dict
    }

    func saveFrequencyData(_ data: [String: Int]) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: frequencyKey)
    }

    func loadSettings() -> AppSettingsData? {
        guard let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AppSettingsData.self, from: data) else {
            return nil
        }
        return settings
    }

    func saveSettings(_ settings: AppSettingsData) {
        guard let encoded = try? JSONEncoder().encode(settings) else { return }
        defaults.set(encoded, forKey: settingsKey)
    }

    func loadCustomAliases() -> [String: [String]] {
        guard let data = defaults.data(forKey: customAliasesKey),
              let dict = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return dict
    }

    func saveCustomAliases(_ data: [String: [String]]) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: customAliasesKey)
    }

    func loadFavorites() -> [String] {
        defaults.stringArray(forKey: favoritesKey) ?? []
    }

    func saveFavorites(_ data: [String]) {
        defaults.set(data, forKey: favoritesKey)
    }
}

struct AppSettingsData: Codable {
    var triggerCharacter: String
    var minTriggerLength: Int
    var inlineTriggerEnabled: Bool
    var emojiBoardShortcut: ShortcutKey
    var inlinePanelOpenMode: InlinePanelOpenMode
    var inlineSuggestionLayout: InlineSuggestionLayout
    var popupTheme: PopupTheme
    var personSkinTone: EmojiSkinTone
    var manSkinTone: EmojiSkinTone
    var womanSkinTone: EmojiSkinTone
    var ignoredSiteRules: [IgnoredSiteRule]
    var ignoredAppRules: [IgnoredAppRule]

    init(
        triggerCharacter: String,
        minTriggerLength: Int,
        inlineTriggerEnabled: Bool,
        emojiBoardShortcut: ShortcutKey,
        inlinePanelOpenMode: InlinePanelOpenMode = .recents,
        inlineSuggestionLayout: InlineSuggestionLayout = .sleek,
        popupTheme: PopupTheme = .nativeDark,
        personSkinTone: EmojiSkinTone = .standard,
        manSkinTone: EmojiSkinTone = .standard,
        womanSkinTone: EmojiSkinTone = .standard,
        ignoredSiteRules: [IgnoredSiteRule] = [],
        ignoredAppRules: [IgnoredAppRule] = []
    ) {
        self.triggerCharacter = triggerCharacter
        self.minTriggerLength = minTriggerLength
        self.inlineTriggerEnabled = inlineTriggerEnabled
        self.emojiBoardShortcut = emojiBoardShortcut
        self.inlinePanelOpenMode = inlinePanelOpenMode
        self.inlineSuggestionLayout = inlineSuggestionLayout
        self.popupTheme = popupTheme
        self.personSkinTone = personSkinTone
        self.manSkinTone = manSkinTone
        self.womanSkinTone = womanSkinTone
        self.ignoredSiteRules = ignoredSiteRules
        self.ignoredAppRules = ignoredAppRules
    }

    private enum CodingKeys: String, CodingKey {
        case triggerCharacter
        case minTriggerLength
        case inlineTriggerEnabled
        case emojiBoardShortcut
        case inlinePanelOpenMode
        case inlineSuggestionLayout
        case popupTheme
        case personSkinTone
        case manSkinTone
        case womanSkinTone
        case ignoredSiteRules
        case ignoredAppRules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        triggerCharacter = try container.decodeIfPresent(String.self, forKey: .triggerCharacter) ?? "`"
        minTriggerLength = try container.decodeIfPresent(Int.self, forKey: .minTriggerLength) ?? 2
        inlineTriggerEnabled = try container.decodeIfPresent(Bool.self, forKey: .inlineTriggerEnabled) ?? true
        emojiBoardShortcut = try container.decodeIfPresent(ShortcutKey.self, forKey: .emojiBoardShortcut)
            ?? ShortcutKey(keyCode: 0x00, modifiers: 0x0100)
        inlinePanelOpenMode = try container.decodeIfPresent(InlinePanelOpenMode.self, forKey: .inlinePanelOpenMode) ?? .recents
        inlineSuggestionLayout = try container.decodeIfPresent(InlineSuggestionLayout.self, forKey: .inlineSuggestionLayout) ?? .sleek
        popupTheme = try container.decodeIfPresent(PopupTheme.self, forKey: .popupTheme) ?? .nativeDark
        personSkinTone = try container.decodeIfPresent(EmojiSkinTone.self, forKey: .personSkinTone) ?? .standard
        manSkinTone = try container.decodeIfPresent(EmojiSkinTone.self, forKey: .manSkinTone) ?? .standard
        womanSkinTone = try container.decodeIfPresent(EmojiSkinTone.self, forKey: .womanSkinTone) ?? .standard
        ignoredSiteRules = try container.decodeIfPresent([IgnoredSiteRule].self, forKey: .ignoredSiteRules) ?? []
        ignoredAppRules = try container.decodeIfPresent([IgnoredAppRule].self, forKey: .ignoredAppRules) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(triggerCharacter, forKey: .triggerCharacter)
        try container.encode(minTriggerLength, forKey: .minTriggerLength)
        try container.encode(inlineTriggerEnabled, forKey: .inlineTriggerEnabled)
        try container.encode(emojiBoardShortcut, forKey: .emojiBoardShortcut)
        try container.encode(inlinePanelOpenMode, forKey: .inlinePanelOpenMode)
        try container.encode(inlineSuggestionLayout, forKey: .inlineSuggestionLayout)
        try container.encode(popupTheme, forKey: .popupTheme)
        try container.encode(personSkinTone, forKey: .personSkinTone)
        try container.encode(manSkinTone, forKey: .manSkinTone)
        try container.encode(womanSkinTone, forKey: .womanSkinTone)
        try container.encode(ignoredSiteRules, forKey: .ignoredSiteRules)
        try container.encode(ignoredAppRules, forKey: .ignoredAppRules)
    }
}

struct ShortcutKey: Codable {
    var keyCode: UInt16
    var modifiers: UInt
}

enum InlinePanelOpenMode: String, Codable, CaseIterable, Identifiable {
    case recents = "Recents"
    case search = "Search"

    var id: String { rawValue }
}

enum InlineSuggestionLayout: String, Codable, CaseIterable, Identifiable {
    case sleek = "Sleek"
    case descriptive = "Descriptive"

    var id: String { rawValue }
}

enum PopupTheme: String, Codable, CaseIterable, Identifiable {
    case nativeDark = "Native Dark"
    case glass = "Glass"
    case midnight = "Midnight"

    var id: String { rawValue }
}

struct IgnoredSiteRule: Codable, Identifiable, Equatable {
    var id: String
    var domain: String

    init(id: String = UUID().uuidString, domain: String) {
        self.id = id
        self.domain = domain
    }
}

struct IgnoredAppRule: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var bundleIdentifier: String
    var path: String

    init(
        id: String = UUID().uuidString,
        name: String,
        bundleIdentifier: String,
        path: String
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
    }
}
