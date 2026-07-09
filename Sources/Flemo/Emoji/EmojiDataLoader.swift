import Foundation

struct Emoji: Codable {
    let character: String
    let name: String
    let category: String
    let keywords: [String]
}

class EmojiDataLoader {
    static let shared = EmojiDataLoader()
    private(set) var allEmojis: [Emoji] = []
    private var normalizedCache: [String: [Emoji]] = [:]

    private init() {
        if let loaded = Self.loadFromBundle() {
            allEmojis = loaded
        } else {
            allEmojis = Self.fallbackEmojis()
        }
    }

    func preferredEmojis(skinTone: EmojiSkinTone) -> [Emoji] {
        if let cached = normalizedCache[skinTone.rawValue] { return cached }
        let normalized = EmojiSkinToneNormalizer.preferredEmojis(from: allEmojis, skinTone: skinTone)
        normalizedCache[skinTone.rawValue] = normalized
        return normalized
    }

    private static func loadFromBundle() -> [Emoji]? {
        // Try Bundle.main (.app bundle)
        if let url = Bundle.main.url(forResource: "emoji-data", withExtension: "json") {
            return load(from: url)
        }
        // Try relative to executable
        if let execURL = Bundle.main.executableURL {
            let relURL = execURL.deletingLastPathComponent()
                .appendingPathComponent("emoji-data.json")
            if FileManager.default.fileExists(atPath: relURL.path) {
                return load(from: relURL)
            }
        }
        return nil
    }

    private static func load(from url: URL) -> [Emoji]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Emoji].self, from: data)
    }

    static func fallbackEmojis() -> [Emoji] {
        [
            Emoji(character: "😀", name: "grinning face", category: "Smileys", keywords: ["grinning", "face", "happy", "smile"]),
            Emoji(character: "😂", name: "face with tears of joy", category: "Smileys", keywords: ["tears", "joy", "laugh", "cry", "happy"]),
            Emoji(character: "😍", name: "smiling face with heart-eyes", category: "Smileys", keywords: ["heart", "eyes", "love", "crush"]),
            Emoji(character: "🤩", name: "star-struck", category: "Smileys", keywords: ["star", "struck", "excited"]),
            Emoji(character: "😎", name: "smiling face with sunglasses", category: "Smileys", keywords: ["cool", "sunglasses", "sun"]),
            Emoji(character: "👍", name: "thumbs up", category: "Gestures", keywords: ["thumbs", "up", "like", "approve"]),
            Emoji(character: "🙏", name: "folded hands", category: "Gestures", keywords: ["pray", "please", "thanks", "hope"]),
            Emoji(character: "🔥", name: "fire", category: "Objects", keywords: ["fire", "hot", "lit", "burn"]),
            Emoji(character: "✨", name: "sparkles", category: "Objects", keywords: ["sparkles", "shiny", "magic", "star"]),
            Emoji(character: "❤️", name: "red heart", category: "Symbols", keywords: ["heart", "love", "red"]),
            Emoji(character: "🎉", name: "party popper", category: "Objects", keywords: ["party", "celebrate", "confetti"]),
            Emoji(character: "🚀", name: "rocket", category: "Travel", keywords: ["rocket", "space", "launch", "ship"]),
            Emoji(character: "✅", name: "check mark button", category: "Symbols", keywords: ["check", "done", "complete"]),
            Emoji(character: "⭐", name: "star", category: "Symbols", keywords: ["star", "gold", "rating"]),
            Emoji(character: "💡", name: "light bulb", category: "Objects", keywords: ["bulb", "light", "idea"]),
            Emoji(character: "📝", name: "memo", category: "Objects", keywords: ["memo", "note", "write", "document"]),
            Emoji(character: "💀", name: "skull", category: "Smileys", keywords: ["skull", "death", "dead"]),
            Emoji(character: "🐶", name: "dog face", category: "Animals", keywords: ["dog", "pet", "animal", "puppy"]),
            Emoji(character: "🐱", name: "cat face", category: "Animals", keywords: ["cat", "pet", "animal", "kitten"]),
            Emoji(character: "👋", name: "waving hand", category: "Gestures", keywords: ["wave", "hello", "bye", "hand"]),
        ]
    }
}
