import Foundation

class EmojiSearchEngine {
    static let shared = EmojiSearchEngine()
    private let dataLoader = EmojiDataLoader.shared

    private struct IndexedEmoji {
        let emoji: Emoji
        let name: String
        let keywords: [String]
        let acronyms: [String]
    }

    private let indexed: [IndexedEmoji]

    private init() {
        indexed = dataLoader.allEmojis.map { emoji in
            let name = emoji.name.lowercased()
            let keywords = emoji.keywords.map { $0.lowercased() }
            let acronyms = keywords.map { Self.acronym(for: $0) }
            return IndexedEmoji(emoji: emoji, name: name, keywords: keywords, acronyms: acronyms)
        }
    }

    func search(keyword: String, maxResults: Int = 10) -> [Emoji] {
        let lowerKeyword = keyword.lowercased().trimmingCharacters(in: .whitespaces)
        guard !lowerKeyword.isEmpty else {
            return topFrequentlyUsed(limit: maxResults)
        }

        var scored: [(Emoji, Int)] = []

        let customization = EmojiCustomizationManager.shared
        for item in indexed {
            let score = scoreEmoji(item, keyword: lowerKeyword, customization: customization)
            if score > 0 {
                let freqScore = FrequencyTracker.shared.frequencyScore(for: item.emoji.character)
                let adjustedScore = score + freqScore
                scored.append((item.emoji, adjustedScore))
            }
        }

        scored.sort { $0.1 > $1.1 }
        let preferred = EmojiSkinToneNormalizer.preferredEmojis(
            from: scored.map { $0.0 },
            skinTone: AppSettings.shared.preferredSkinTone
        )
        return Array(preferred.prefix(maxResults))
    }

    private func scoreEmoji(
        _ item: IndexedEmoji,
        keyword: String,
        customization: EmojiCustomizationManager
    ) -> Int {
        var score = 0
        let name = item.name

        if name == keyword { score += 100 }
        if name.hasPrefix(keyword) { score += 80 }
        if name.contains(keyword) { score += 50 }
        if fuzzyMatch(name, pattern: keyword) { score += 30 }

        for kw in item.keywords {
            if kw == keyword { score += 90 }
            if kw.hasPrefix(keyword) { score += 60 }
            if kw.contains(keyword) { score += 40 }
            if fuzzyMatch(kw, pattern: keyword) { score += 20 }
        }

        for acro in item.acronyms where keyword == acro { score += 70 }

        for kw in customization.customAliases(for: item.emoji.character) {
            let alias = kw.lowercased()
            if alias == keyword { score += 95 }
            if alias.hasPrefix(keyword) { score += 65 }
            if alias.contains(keyword) { score += 45 }
            if fuzzyMatch(alias, pattern: keyword) { score += 25 }
        }

        if customization.isFavorite(item.emoji.character) { score += 6 }

        return score
    }

    private func topFrequentlyUsed(limit: Int) -> [Emoji] {
        let freq = FrequencyTracker.shared.topEmojiCharacters(limit: limit * 8)
        var result: [Emoji] = []
        var seen = Set<String>()
        for char in freq {
            if let emoji = dataLoader.allEmojis.first(where: { $0.character == char }) {
                let preferred = EmojiSkinToneNormalizer.preferredReplacement(
                    for: emoji,
                    in: dataLoader.allEmojis,
                    skinTone: AppSettings.shared.preferredSkinTone
                )
                let key = EmojiSkinToneNormalizer.baseKey(for: preferred.character)
                guard !seen.contains(key) else { continue }
                result.append(preferred)
                seen.insert(key)
                if result.count >= limit { break }
            }
        }
        if result.isEmpty {
            result = Array(dataLoader.preferredEmojis(skinTone: AppSettings.shared.preferredSkinTone).prefix(limit))
        }
        return result
    }

    private func fuzzyMatch(_ text: String, pattern: String) -> Bool {
        let textChars = Array(text)
        let patternChars = Array(pattern)
        var ti = 0, pi = 0
        while ti < textChars.count && pi < patternChars.count {
            if textChars[ti] == patternChars[pi] { pi += 1 }
            ti += 1
        }
        return pi == patternChars.count
    }

    private static func acronym(for text: String) -> String {
        text.split(separator: " ").compactMap { $0.first }.map { String($0) }.joined().lowercased()
    }
}
