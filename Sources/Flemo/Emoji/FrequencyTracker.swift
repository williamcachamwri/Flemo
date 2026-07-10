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
    private let lock = NSLock()
    private var cache: [String: Int] = [:]

    private init() {
        loadCache()
    }

    private func loadCache() {
        cache = storage.loadFrequencyData()
    }

    func recordUsage(emoji: Emoji) {
        lock.lock()
        let current = cache[emoji.character, default: 0]
        cache[emoji.character] = current + 1
        storage.saveFrequencyData(cache)
        lock.unlock()
    }

    func frequencyScore(for character: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard let count = cache[character] else { return 0 }
        return min(count * 3, 50)
    }

    func usageCount(for character: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return cache[character] ?? 0
    }

    func topEmojiCharacters(limit: Int) -> [String] {
        lock.lock()
        let snapshot = cache
        lock.unlock()

        return snapshot.sorted { $0.value > $1.value }.prefix(limit).map { $0.key }
    }

    func statsSnapshot(limit: Int = 8) -> FrequencyStatsSnapshot {
        let emojis = EmojiDataLoader.shared.allEmojis

        lock.lock()
        let snapshot = cache
        lock.unlock()

        let total = snapshot.values.reduce(0, +)
        let top = snapshot
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
            trackedEmojiCount: snapshot.count,
            topEmoji: top
        )
    }

    func resetAll() {
        lock.lock()
        cache.removeAll()
        storage.saveFrequencyData(cache)
        lock.unlock()
    }
}
