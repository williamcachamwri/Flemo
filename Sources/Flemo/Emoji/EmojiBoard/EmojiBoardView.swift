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
        GridItem(.adaptive(minimum: 42, maximum: 48), spacing: 6)
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

    var body: some View {
        ZStack {
            EmojiBoardMaterialView()
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.22),
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

                Divider()
                    .background(Color.white.opacity(0.06))

                content
            }
        }
        .frame(width: 620, height: 520)
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
            HStack(spacing: 8) {
                Image(systemName: "face.smiling.fill")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.accentColor, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 22, height: 22)

                Text("Emoji")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(categories, id: \.self) { category in
                        CategoryNavItem(
                            icon: icon(for: category),
                            title: shortTitle(for: category),
                            count: count(for: category),
                            isSelected: selectedCategory == category && searchText.isEmpty
                        ) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                selectedCategory = category
                                searchText = ""
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 0)
        }
        .frame(width: 154)
        .background(Color.secondary.opacity(0.04))
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
                .transition(.opacity)
            } else {
                gridContent
            }
        }
    }

    private var gridContent: some View {
        let results = filteredEmojis
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                SearchField(text: $searchText)

                Button {
                    NSApplication.shared.keyWindow?.close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.secondary.opacity(0.10)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .background(Color.white.opacity(0.06))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(searchText.isEmpty ? selectedCategory : "Search Results")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("\(results.count) emoji")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.7))
                }

                Spacer()

                if let hoveredEmoji {
                    Text(hoveredEmoji.name)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                        .frame(maxWidth: 180, alignment: .trailing)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(results) { emoji in
                        EmojiCell(
                            emoji: emoji,
                            isHovered: hoveredEmoji?.character == emoji.character,
                            isFavorite: customization.isFavorite(emoji.character)
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedEmoji = emoji
                            }
                        }
                        .onHover { hovering in
                            hoveredEmoji = hovering ? emoji : (hoveredEmoji?.character == emoji.character ? nil : hoveredEmoji)
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

    private func shortTitle(for category: String) -> String {
        switch category {
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
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.75))

            TextField("Search emoji...", text: $text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.secondary.opacity(0.10))
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : .primary.opacity(0.85))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text("\(count)")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white.opacity(0.72) : .secondary.opacity(0.58))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.secondary.opacity(isHovered ? 0.10 : 0.0)))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
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
                .font(.system(size: 26))
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.secondary.opacity(isHovered ? 0.18 : 0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(isHovered ? 0.16 : 0.04), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.yellow)
                            .padding(3)
                    }
                }
        }
        .buttonStyle(.plain)
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
