import Foundation

class StorageManager {
    static let shared = StorageManager()

    private let defaults = UserDefaults.standard

    private let frequencyKey = "emoji_frequency"
    private let favoritesKey = "gif_favorites"
    private let settingsKey = "app_settings"

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

    func loadFavoriteGIFs() -> [GIFItem] {
        guard let data = defaults.data(forKey: favoritesKey),
              let items = try? JSONDecoder().decode([GIFItem].self, from: data) else {
            return []
        }
        return items
    }

    func saveFavoriteGIFs(_ items: [GIFItem]) {
        guard let encoded = try? JSONEncoder().encode(items) else { return }
        defaults.set(encoded, forKey: favoritesKey)
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
}

struct AppSettingsData: Codable {
    var triggerCharacter: String
    var minTriggerLength: Int
    var inlineTriggerEnabled: Bool
    var gifFeatureEnabled: Bool
    var numberShortcutEnabled: Bool
    var gifInsertionMode: GIFInsertionMode
    var emojiBoardShortcut: ShortcutKey
    var gifBoardShortcut: ShortcutKey
    var giphyAPIKey: String
}

enum GIFInsertionMode: String, Codable, CaseIterable {
    case link = "Link"
    case file = "File"
}

struct ShortcutKey: Codable {
    var keyCode: UInt16
    var modifiers: UInt
}
