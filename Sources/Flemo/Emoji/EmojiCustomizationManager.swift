import Combine
import Foundation

class EmojiCustomizationManager: ObservableObject {
    static let shared = EmojiCustomizationManager()

    private let storage = StorageManager.shared
    private let lock = NSRecursiveLock()
    @Published private(set) var customAliases: [String: [String]] = [:]
    @Published private(set) var favorites: Set<String> = []

    private init() {
        customAliases = storage.loadCustomAliases()
        favorites = Set(storage.loadFavorites())
    }

    func customAliases(for character: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return customAliases[character] ?? []
    }

    func isFavorite(_ character: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return favorites.contains(character)
    }

    func toggleFavorite(_ character: String) {
        lock.lock()
        if favorites.contains(character) {
            favorites.remove(character)
        } else {
            favorites.insert(character)
        }
        storage.saveFavorites(Array(favorites))
        lock.unlock()
    }

    func addAlias(_ keyword: String, for character: String) {
        let trimmed = keyword.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lock.lock()
        var current = customAliases[character] ?? []
        guard !current.contains(trimmed) else {
            lock.unlock()
            return
        }
        current.append(trimmed)
        customAliases[character] = current
        storage.saveCustomAliases(customAliases)
        lock.unlock()
    }

    func removeAlias(_ keyword: String, for character: String) {
        lock.lock()
        var current = customAliases[character] ?? []
        current.removeAll { $0 == keyword.lowercased() }
        if current.isEmpty {
            customAliases[character] = nil
        } else {
            customAliases[character] = current
        }
        storage.saveCustomAliases(customAliases)
        lock.unlock()
    }
}
