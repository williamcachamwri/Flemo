import Foundation

struct EmojiUsageStat: Identifiable {
    let id: String
    let emoji: Emoji
    let count: Int
}

struct FrequencyStatsSnapshot {
    let totalUsage: Int
    let trackedEmojiCount: Int
    let topEmoji: [EmojiUsageStat]
}

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

    func usageCount(for character: String) -> Int {
        cache[character] ?? 0
    }

    func topEmojiCharacters(limit: Int) -> [String] {
        cache.sorted { $0.value > $1.value }.prefix(limit).map { $0.key }
    }

    func statsSnapshot(limit: Int = 8) -> FrequencyStatsSnapshot {
        let emojis = EmojiDataLoader.shared.allEmojis
        let total = cache.values.reduce(0, +)
        let top = cache
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .prefix(limit)
            .map { character, count in
                let emoji = emojis.first { $0.character == character }
                    ?? Emoji(character: character, name: "Saved emoji", category: "Usage", keywords: [])
                return EmojiUsageStat(id: character, emoji: emoji, count: count)
            }

        return FrequencyStatsSnapshot(
            totalUsage: total,
            trackedEmojiCount: cache.count,
            topEmoji: top
        )
    }

    func resetAll() {
        cache.removeAll()
        storage.saveFrequencyData(cache)
    }
}
