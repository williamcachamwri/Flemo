import AppKit
import SwiftUI

struct EmojiBoardView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var customization = EmojiCustomizationManager.shared
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var hoveredEmoji: Emoji?
    @State private var selectedEmoji: Emoji?
    @State private var categoryCounts: [String: Int] = [:]

    var onSelect: (Emoji) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 46, maximum: 52), spacing: 8)
    ]

    private var categories: [String] {
        let available = Set(displayEmojis.map { $0.category })
        let preferred = [
            "All",
            "Favorites",
            "Smileys & Emotion",
            "People & Body",
            "Animals & Nature",
            "Food & Drink",
            "Travel & Places",
            "Activities",
            "Objects",
            "Symbols",
            "Flags"
        ]
        let extra = available.subtracting(preferred).sorted()
        return preferred.filter { $0 == "All" || $0 == "Favorites" || available.contains($0) } + extra
    }

    private var displayEmojis: [Emoji] {
        EmojiDataLoader.shared.preferredEmojis(
            personSkinTone: appState.personSkinTone,
            manSkinTone: appState.manSkinTone,
            womanSkinTone: appState.womanSkinTone
        )
    }

    private var filteredEmojis: [Emoji] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keyword.isEmpty {
            return EmojiSearchEngine.shared.search(keyword: keyword, maxResults: 700)
        }

        if selectedCategory == "Favorites" {
            return displayEmojis.filter { customization.isFavorite($0.character) }
        }

        if selectedCategory == "All" {
            return displayEmojis
        }

        return displayEmojis.filter { $0.category == selectedCategory }
    }

    private var activeTitle: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? title(for: selectedCategory)
            : "Search Results"
    }

    var body: some View {
        ZStack {
            EmojiBoardMaterialView()
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.24),
                                    Color.white.opacity(0.06)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            HStack(spacing: 0) {
                sidebar

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1)

                content
            }
        }
        .frame(width: 680, height: 540)
        .onAppear { rebuildCounts() }
        .onChange(of: appState.personSkinTone) { _, _ in rebuildCounts() }
        .onChange(of: appState.manSkinTone) { _, _ in rebuildCounts() }
        .onChange(of: appState.womanSkinTone) { _, _ in rebuildCounts() }
    }

    private func rebuildCounts() {
        let emojis = EmojiDataLoader.shared.preferredEmojis(
            personSkinTone: appState.personSkinTone,
            manSkinTone: appState.manSkinTone,
            womanSkinTone: appState.womanSkinTone
        )
        var counts: [String: Int] = ["All": emojis.count]
        for emoji in emojis {
            counts[emoji.category, default: 0] += 1
        }
        categoryCounts = counts
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.bottom, 10)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(categories, id: \.self) { category in
                        CategoryNavItem(
                            icon: icon(for: category),
                            title: title(for: category),
                            count: count(for: category),
                            isSelected: selectedCategory == category && searchText.isEmpty
                        ) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                                selectedCategory = category
                                searchText = ""
                                hoveredEmoji = nil
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }

            Spacer(minLength: 0)

            SidebarMetricPill(
                icon: "star.fill",
                value: "\(count(for: "Favorites"))",
                label: "Favorites"
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
        .frame(width: 168)
        .background(
            LinearGradient(
                colors: [
                    Color.secondary.opacity(0.065),
                    Color.black.opacity(0.035)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.30),
                                Color.cyan.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "face.smiling.fill")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(width: 32, height: 32)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 1) {
                Text("Flemo")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Emoji Library")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.62))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private var content: some View {
        Group {
            if let selected = selectedEmoji {
                EmojiDetailView(
                    emoji: selected,
                    onUse: { onSelect(selected) },
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedEmoji = nil }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.99)))
            } else {
                gridContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var gridContent: some View {
        let results = filteredEmojis
        let hoverAliases = hoveredEmoji.map { aliases(for: $0, limit: 4) } ?? []

        return VStack(spacing: 0) {
            BoardSearchHeader(
                title: activeTitle,
                subtitle: countText(results.count),
                searchText: $searchText
            ) {
                NSApplication.shared.keyWindow?.close()
            }

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            EmojiHoverPreview(
                emoji: hoveredEmoji,
                aliases: hoverAliases,
                fallbackTitle: activeTitle,
                fallbackSubtitle: countText(results.count)
            )
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(results) { emoji in
                        EmojiCell(
                            emoji: emoji,
                            isHovered: hoveredEmoji?.character == emoji.character,
                            isFavorite: customization.isFavorite(emoji.character)
                        ) {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedEmoji = emoji
                            }
                        }
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.12)) {
                                hoveredEmoji = hovering
                                    ? emoji
                                    : (hoveredEmoji?.character == emoji.character ? nil : hoveredEmoji)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
    }

    private func count(for category: String) -> Int {
        if category == "Favorites" {
            return displayEmojis.filter { customization.isFavorite($0.character) }.count
        }
        return categoryCounts[category] ?? 0
    }

    private func countText(_ count: Int) -> String {
        "\(count) emoji"
    }

    private func title(for category: String) -> String {
        switch category {
        case "All": return "All Emoji"
        case "Smileys & Emotion": return "Smileys"
        case "People & Body": return "People"
        case "Animals & Nature": return "Nature"
        case "Food & Drink": return "Food"
        case "Travel & Places": return "Travel"
        default: return category
        }
    }

    private func icon(for category: String) -> String {
        switch category {
        case "All": return "sparkles"
        case "Favorites": return "star.fill"
        case "Smileys & Emotion": return "face.smiling"
        case "People & Body": return "figure.wave"
        case "Animals & Nature": return "leaf"
        case "Food & Drink": return "fork.knife"
        case "Travel & Places": return "airplane"
        case "Activities": return "gamecontroller"
        case "Objects": return "shippingbox"
        case "Symbols": return "heart"
        case "Flags": return "flag"
        default: return "circle.grid.2x2"
        }
    }

    private func aliases(for emoji: Emoji, limit: Int) -> [String] {
        var seen = Set<String>()
        return (customization.customAliases(for: emoji.character) + emoji.keywords)
            .filter { keyword in
                let lowered = keyword.lowercased()
                guard !seen.contains(lowered) else { return false }
                seen.insert(lowered)
                return true
            }
            .prefix(limit)
            .map { $0 }
    }
}

private struct BoardSearchHeader: View {
    let title: String
    let subtitle: String
    @Binding var searchText: String
    let close: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.64))
                    .lineLimit(1)
            }
            .frame(width: 136, alignment: .leading)

            SearchField(text: $searchText)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.secondary.opacity(0.10)))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

private struct SearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    private var borderColor: Color {
        isFocused ? Color.accentColor.opacity(0.42) : Color.white.opacity(isHovered ? 0.18 : 0.10)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isFocused ? .accentColor : .secondary.opacity(0.72))
                .frame(width: 16)

            TextField("Search emoji", text: $text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .textFieldStyle(.plain)
                .focused($isFocused)
                .tint(.accentColor)

            if !text.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.12)) { text = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.72))
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(isFocused ? 0.13 : 0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: Color.accentColor.opacity(isFocused ? 0.16 : 0.0), radius: 10, y: 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
    }
}

private struct EmojiHoverPreview: View {
    let emoji: Emoji?
    let aliases: [String]
    let fallbackTitle: String
    let fallbackSubtitle: String

    var body: some View {
        HStack(spacing: 12) {
            if let emoji {
                emojiTile(emoji)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(displayName(for: emoji))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary.opacity(0.94))
                            .lineLimit(1)

                        Text(emoji.category)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.72))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule(style: .continuous).fill(Color.secondary.opacity(0.10)))
                    }

                    HStack(spacing: 6) {
                        usageBadge(for: emoji)

                        ForEach(aliases.prefix(3), id: \.self) { alias in
                            Text(alias)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary.opacity(0.78))
                                .lineLimit(1)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule(style: .continuous).fill(Color.secondary.opacity(0.08)))
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.10))
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.72))
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(fallbackTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.90))
                    Text(fallbackSubtitle)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.64))
                }
            }

            Spacer(minLength: 0)
        }
        .frame(height: 64)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .animation(.spring(response: 0.24, dampingFraction: 0.88), value: emoji?.character)
    }

    private func emojiTile(_ emoji: Emoji) -> some View {
        let colors = EmojiColorExtractor.shared.colors(for: emoji.character)
        return Text(emoji.character)
            .font(.system(size: 31))
            .frame(width: 48, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                colors[0].opacity(0.28),
                                colors[1].opacity(0.16),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
    }

    private func usageBadge(for emoji: Emoji) -> some View {
        let count = FrequencyTracker.shared.usageCount(for: emoji.character)
        return Label(count == 0 ? "No uses" : "\(count) uses", systemImage: "chart.bar.fill")
            .labelStyle(.titleAndIcon)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.secondary.opacity(0.72))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule(style: .continuous).fill(Color.secondary.opacity(0.08)))
    }

    private func displayName(for emoji: Emoji) -> String {
        emoji.name
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

private struct SidebarMetricPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.yellow.opacity(0.90))

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.primary.opacity(0.90))

            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary.opacity(0.64))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct CategoryNavItem: View {
    let icon: String
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var backgroundStyle: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.accentColor,
                        Color.cyan.opacity(0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(Color.secondary.opacity(isHovered ? 0.11 : 0.0))
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .secondary.opacity(0.78))
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.white.opacity(isSelected ? 0.16 : isHovered ? 0.08 : 0.04))
                    )

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .white : .primary.opacity(0.84))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text("\(count)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white.opacity(0.76) : .secondary.opacity(0.58))
                    .lineLimit(1)
                    .frame(minWidth: 25)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(isSelected ? 0.15 : isHovered ? 0.07 : 0.04))
                    )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(backgroundStyle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.18 : 0.0), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered && !isSelected ? 1.015 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
    }
}

private struct EmojiCell: View {
    let emoji: Emoji
    let isHovered: Bool
    let isFavorite: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(emoji.character)
                .font(.system(size: isHovered ? 29 : 27))
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(isHovered ? 0.18 : 0.075))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(isHovered ? 0.20 : 0.05), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.yellow)
                            .padding(4)
                    }
                }
                .shadow(color: .black.opacity(isHovered ? 0.22 : 0.0), radius: 9, y: 5)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.06 : 1.0)
        .zIndex(isHovered ? 1 : 0)
        .help(emoji.name)
    }
}

private struct EmojiBoardMaterialView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 20
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .hudWindow
    }
}
