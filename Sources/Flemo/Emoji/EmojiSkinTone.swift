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
            if let preferred = preferredEmoji(from: group, skinTone: skinTone) {
                result.append(preferred)
            } else if !hasSkinToneModifier(emoji.character) {
                result.append(emoji)
            }
        }

        return result
    }

    static func preferredEmojis(
        from emojis: [Emoji],
        personSkinTone: EmojiSkinTone,
        manSkinTone: EmojiSkinTone,
        womanSkinTone: EmojiSkinTone,
        gestureSkinTone: EmojiSkinTone? = nil
    ) -> [Emoji] {
        let grouped = Dictionary(grouping: emojis) { baseKey(for: $0.character) }
        var seen = Set<String>()
        var result: [Emoji] = []
        let resolvedGestureSkinTone = gestureSkinTone ?? personSkinTone

        for emoji in emojis {
            let key = baseKey(for: emoji.character)
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            let group = grouped[key] ?? [emoji]
            let tone = skinToneFor(
                group: group,
                key: key,
                person: personSkinTone,
                gesture: resolvedGestureSkinTone,
                man: manSkinTone,
                woman: womanSkinTone
            )
            if let preferred = preferredEmoji(from: group, skinTone: tone) {
                result.append(preferred)
            } else if !hasSkinToneModifier(emoji.character) {
                result.append(emoji)
            }
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
        return preferredEmoji(from: group, skinTone: skinTone) ?? normalizedFallback(for: emoji)
    }

    static func preferredReplacement(
        for emoji: Emoji,
        in allEmojis: [Emoji],
        personSkinTone: EmojiSkinTone,
        manSkinTone: EmojiSkinTone,
        womanSkinTone: EmojiSkinTone,
        gestureSkinTone: EmojiSkinTone? = nil
    ) -> Emoji {
        let key = baseKey(for: emoji.character)
        let group = allEmojis.filter { baseKey(for: $0.character) == key }
        let tone = skinToneFor(
            group: group,
            key: key,
            person: personSkinTone,
            gesture: gestureSkinTone ?? personSkinTone,
            man: manSkinTone,
            woman: womanSkinTone
        )
        return preferredEmoji(from: group, skinTone: tone) ?? normalizedFallback(for: emoji)
    }

    static func baseKey(for character: String) -> String {
        cacheLock.lock()
        if let cached = baseKeyCache[character] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let key = String(String.UnicodeScalarView(character.unicodeScalars.filter { !isSkinToneModifier($0) }))

        cacheLock.lock()
        baseKeyCache[character] = key
        cacheLock.unlock()

        return key
    }

    private static let cacheLock = NSLock()
    private static var baseKeyCache: [String: String] = [:]

    private static func skinToneFor(
        group: [Emoji],
        key: String,
        person: EmojiSkinTone,
        gesture: EmojiSkinTone,
        man: EmojiSkinTone,
        woman: EmojiSkinTone
    ) -> EmojiSkinTone {
        let descriptor = group
            .map { "\($0.character) \($0.name) \($0.keywords.joined(separator: " "))" }
            .joined(separator: " ")
            .lowercased()

        if key.hasPrefix("👩") || key.contains("♀") || descriptor.hasToken("woman") || descriptor.hasToken("female") || descriptor.hasToken("girl") {
            return woman
        }
        if key.hasPrefix("👨") { return man }
        if key.contains("♂") || descriptor.hasToken("man") || descriptor.hasToken("male") || descriptor.hasToken("boy") {
            return man
        }
        if isHandBodyGroup(key: key, descriptor: descriptor) {
            return gesture
        }
        if isGestureGroup(key: key, descriptor: descriptor) {
            return gesture
        }
        return person
    }

    private static func isGestureGroup(key: String, descriptor: String) -> Bool {
        let gestureTerms = [
            "waving", "wave", "thumb", "thumbs", "clapping", "clap",
            "folded hands", "pray", "prayer", "raised hand", "hand with",
            "ok hand", "victory hand", "crossed fingers", "love-you gesture",
            "sign of the horns", "call me hand", "pinched fingers", "pinching hand",
            "pushing hand", "palm", "salute", "handshake", "heart hands"
        ]

        if gestureTerms.contains(where: { descriptor.contains($0) }) {
            return true
        }

        return [
            "☝", "✌", "👆", "👇", "👈", "👉", "👊", "👋", "👌", "👍", "👎",
            "👏", "👐", "🖐", "🖕", "🖖", "🙌", "🙏", "🤌", "🤏", "🤘",
            "🤙", "🤚", "🤛", "🤜", "🤞", "🤟", "🫰", "🫱", "🫲", "🫳",
            "🫴", "🫵", "🫶", "🫷", "🫸"
        ].contains { key.hasPrefix($0) }
    }

    private static func isHandBodyGroup(key: String, descriptor: String) -> Bool {
        let bodyTerms = [
            "biceps", "muscle", "arm", "leg", "foot", "feet", "ear", "nose",
            "mechanical arm", "mechanical leg", "nail polish", "writing hand",
            "selfie", "body"
        ]

        if bodyTerms.contains(where: { descriptor.contains($0) }) {
            return true
        }

        return ["✍", "👂", "👃", "💅", "💪", "🤳", "🦵", "🦶", "🦻", "🦾", "🦿"].contains { key.hasPrefix($0) }
    }

    private static func preferredEmoji(from group: [Emoji], skinTone: EmojiSkinTone) -> Emoji? {
        group.first { matches($0.character, skinTone: skinTone) }
            ?? group.first { !hasSkinToneModifier($0.character) }
    }

    private static func matches(_ character: String, skinTone: EmojiSkinTone) -> Bool {
        let presentModifiers = skinToneModifierValues(in: character)

        guard let modifier = skinTone.modifierScalarValue else {
            return presentModifiers.isEmpty
        }

        return presentModifiers == Set([modifier])
    }

    private static func hasSkinToneModifier(_ character: String) -> Bool {
        !skinToneModifierValues(in: character).isEmpty
    }

    private static func skinToneModifierValues(in character: String) -> Set<UInt32> {
        Set(character.unicodeScalars.compactMap { scalar in
            isSkinToneModifier(scalar) ? scalar.value : nil
        })
    }

    private static func isSkinToneModifier(_ scalar: UnicodeScalar) -> Bool {
        (0x1F3FB...0x1F3FF).contains(scalar.value)
    }

    private static func normalizedFallback(for emoji: Emoji) -> Emoji {
        guard hasSkinToneModifier(emoji.character) else { return emoji }
        return Emoji(
            character: baseKey(for: emoji.character),
            name: cleanedSkinToneName(emoji.name),
            category: emoji.category,
            keywords: emoji.keywords.filter { !isSkinToneKeyword($0) }
        )
    }

    private static func cleanedSkinToneName(_ name: String) -> String {
        name
            .replacingOccurrences(of: ": light skin tone", with: "")
            .replacingOccurrences(of: ": medium-light skin tone", with: "")
            .replacingOccurrences(of: ": medium skin tone", with: "")
            .replacingOccurrences(of: ": medium-dark skin tone", with: "")
            .replacingOccurrences(of: ": dark skin tone", with: "")
    }

    private static func isSkinToneKeyword(_ keyword: String) -> Bool {
        let lowered = keyword.lowercased()
        return lowered == "skin tone"
            || lowered == "light skin tone"
            || lowered == "medium-light skin tone"
            || lowered == "medium skin tone"
            || lowered == "medium-dark skin tone"
            || lowered == "dark skin tone"
    }
}

private extension EmojiSkinTone {
    var modifierScalarValue: UInt32? {
        modifier?.unicodeScalars.first?.value
    }
}

private extension String {
    func hasToken(_ token: String) -> Bool {
        split { !$0.isLetter && !$0.isNumber }.contains { $0 == token }
    }
}
