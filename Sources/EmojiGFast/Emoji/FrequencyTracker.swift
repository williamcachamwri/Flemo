import Foundation

class FrequencyTracker {
    static let shared = FrequencyTracker()

    private let storage = StorageManager.shared
    private var cache: [String: Int] = [:]

    private init() {
        loadCache()
    }

    private func loadCache() {
        cache = storage.loadFrequencyData()
    }

    func recordUsage(emoji: Emoji) {
        let current = cache[emoji.character, default: 0]
        cache[emoji.character] = current + 1
        storage.saveFrequencyData(cache)
    }

    func frequencyScore(for character: String) -> Int {
        guard let count = cache[character] else { return 0 }
        return min(count * 3, 50)
    }

    func topEmojiCharacters(limit: Int) -> [String] {
        cache.sorted { $0.value > $1.value }.prefix(limit).map { $0.key }
    }

    func resetAll() {
        cache.removeAll()
        storage.saveFrequencyData(cache)
    }
}
