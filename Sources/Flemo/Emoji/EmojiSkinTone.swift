import Foundation

enum EmojiSkinTone: String, Codable, CaseIterable, Identifiable {
    case standard = "Standard"
    case light = "Light"
    case mediumLight = "Medium Light"
    case medium = "Medium"
    case mediumDark = "Medium Dark"
    case dark = "Dark"

    var id: String { rawValue }

    var modifier: String? {
        switch self {
        case .standard: return nil
        case .light: return "🏻"
        case .mediumLight: return "🏼"
        case .medium: return "🏽"
        case .mediumDark: return "🏾"
        case .dark: return "🏿"
        }
    }

    func applied(to baseEmoji: String) -> String {
        baseEmoji + (modifier ?? "")
    }
}

struct EmojiSkinToneNormalizer {
    static let modifiers = ["🏻", "🏼", "🏽", "🏾", "🏿"]

    static func preferredEmojis(from emojis: [Emoji], skinTone: EmojiSkinTone) -> [Emoji] {
        let grouped = Dictionary(grouping: emojis) { baseKey(for: $0.character) }
        var seen = Set<String>()
        var result: [Emoji] = []

        for emoji in emojis {
            let key = baseKey(for: emoji.character)
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            let group = grouped[key] ?? [emoji]
            result.append(preferredEmoji(from: group, skinTone: skinTone) ?? emoji)
        }

        return result
    }

    static func preferredReplacement(
        for emoji: Emoji,
        in allEmojis: [Emoji],
        skinTone: EmojiSkinTone
    ) -> Emoji {
        let key = baseKey(for: emoji.character)
        let group = allEmojis.filter { baseKey(for: $0.character) == key }
        return preferredEmoji(from: group, skinTone: skinTone) ?? emoji
    }

    static func baseKey(for character: String) -> String {
        if let cached = baseKeyCache[character] { return cached }
        let key = modifiers.reduce(character) { partialResult, modifier in
            partialResult.replacingOccurrences(of: modifier, with: "")
        }
        baseKeyCache[character] = key
        return key
    }

    private static var baseKeyCache: [String: String] = [:]

    private static func preferredEmoji(from group: [Emoji], skinTone: EmojiSkinTone) -> Emoji? {
        group.first { matches($0.character, skinTone: skinTone) }
            ?? group.first { !hasSkinToneModifier($0.character) }
            ?? group.first
    }

    private static func matches(_ character: String, skinTone: EmojiSkinTone) -> Bool {
        let presentModifiers = Set(modifiers.filter { character.contains($0) })

        guard let modifier = skinTone.modifier else {
            return presentModifiers.isEmpty
        }

        return presentModifiers == Set([modifier])
    }

    private static func hasSkinToneModifier(_ character: String) -> Bool {
        modifiers.contains { character.contains($0) }
    }
}
