import AppKit
import SwiftUI

struct EmojiDetailView: View {
    let emoji: Emoji
    let onUse: () -> Void
    let onBack: () -> Void

    @ObservedObject private var customization = EmojiCustomizationManager.shared
    @State private var newAlias = ""
    @State private var customExpanded = true
    @State private var defaultExpanded = true
    @FocusState private var aliasFieldFocused: Bool

    private let keywordColumns = [
        GridItem(.adaptive(minimum: 82, maximum: 118), spacing: 8)
    ]

    private var defaultKeywords: [String] { emoji.keywords }
    private var customKeywords: [String] { customization.customAliases(for: emoji.character) }
    private var isFavorite: Bool { customization.isFavorite(emoji.character) }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    DetailHero(
                        emoji: emoji,
                        customAliases: customKeywords,
                        defaultAliases: defaultKeywords,
                        isFavorite: isFavorite,
                        onUse: onUse
                    )

                    customSection
                    defaultSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 18)
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 9) {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.secondary.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help("Back")

            VStack(alignment: .leading, spacing: 1) {
                Text("Emoji Detail")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.92))
                Text(emoji.category)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.62))
            }

            Spacer()

            Button(action: onUse) {
                Label("Insert", systemImage: "return")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Capsule(style: .continuous).fill(Color.accentColor))
            }
            .buttonStyle(.plain)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(emoji.character, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.secondary.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .help("Copy")

            favoriteStar
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var favoriteStar: some View {
        Button {
            customization.toggleFavorite(emoji.character)
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isFavorite ? .yellow : .secondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.secondary.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .help("Favorite")
    }

    // MARK: Custom section

    private var customSection: some View {
        DetailSection {
            sectionHeader(
                title: "Custom Aliases",
                count: customKeywords.count,
                expanded: customExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { customExpanded.toggle() }
            }

            if customExpanded {
                HStack(spacing: 8) {
                    TextField("Add alias", text: $newAlias)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .textFieldStyle(.plain)
                        .tint(.accentColor)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.black.opacity(aliasFieldFocused ? 0.14 : 0.09))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(aliasFieldFocused ? Color.accentColor.opacity(0.38) : Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .focused($aliasFieldFocused)
                        .onSubmit { commitAlias() }

                    addButton
                }
                .padding(.top, 2)

                if customKeywords.isEmpty {
                    EmptyAliasRow(icon: "tag", text: "No custom aliases yet")
                } else {
                    LazyVGrid(columns: keywordColumns, spacing: 8) {
                        ForEach(customKeywords, id: \.self) { keyword in
                            RemovableChip(text: keyword) {
                                customization.removeAlias(keyword, for: emoji.character)
                            }
                        }
                    }
                }
            }
        }
    }

    private var addButton: some View {
        Button {
            commitAlias()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.accentColor))
        }
        .buttonStyle(.plain)
        .help("Add alias")
    }

    private func commitAlias() {
        let trimmed = newAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        customization.addAlias(trimmed, for: emoji.character)
        newAlias = ""
    }

    // MARK: Default section

    private var defaultSection: some View {
        DetailSection {
            sectionHeader(
                title: "Built-in Aliases",
                count: defaultKeywords.count,
                expanded: defaultExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { defaultExpanded.toggle() }
            }

            if defaultExpanded && !defaultKeywords.isEmpty {
                LazyVGrid(columns: keywordColumns, spacing: 8) {
                    ForEach(defaultKeywords, id: \.self) { keyword in
                        KeywordChip(text: keyword)
                    }
                }
            }
        }
    }

    // MARK: Section header

    private func sectionHeader(title: String, count: Int, expanded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.7))
                    .rotationEffect(.degrees(expanded ? 90 : 0))

                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.90))

                Spacer()

                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.64))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.secondary.opacity(0.10))
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail hero

private struct DetailHero: View {
    let emoji: Emoji
    let customAliases: [String]
    let defaultAliases: [String]
    let isFavorite: Bool
    let onUse: () -> Void

    private var usageCount: Int {
        FrequencyTracker.shared.usageCount(for: emoji.character)
    }

    private var aliasCount: Int {
        uniqueAliases.count
    }

    private var uniqueAliases: [String] {
        var seen = Set<String>()
        return (customAliases + defaultAliases)
            .filter { alias in
                let lowered = alias.lowercased()
                guard !seen.contains(lowered) else { return false }
                seen.insert(lowered)
                return true
            }
    }

    var body: some View {
        let colors = EmojiColorExtractor.shared.colors(for: emoji.character)

        HStack(spacing: 16) {
            Button(action: onUse) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )

                    Text(emoji.character)
                        .font(.system(size: 104))
                        .minimumScaleFactor(0.72)
                        .shadow(color: .black.opacity(0.25), radius: 18, y: 9)
                }
                .frame(width: 142, height: 142)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(emoji.category)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.82))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule(style: .continuous).fill(Color.white.opacity(0.14)))

                        if isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.12)))
                        }
                    }

                    Text(displayName)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.96))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    DetailMetricPill(icon: "chart.bar.fill", value: "\(usageCount)", label: "uses")
                    DetailMetricPill(icon: "tag.fill", value: "\(aliasCount)", label: "aliases")
                }

                if !uniqueAliases.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(uniqueAliases.prefix(4), id: \.self) { alias in
                            Text(alias)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.82))
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.12)))
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 174, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            colors[0].opacity(0.42),
                            colors[1].opacity(0.26),
                            Color.black.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: colors[0].opacity(0.16), radius: 20, y: 10)
    }

    private var displayName: String {
        emoji.name
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

private struct DetailMetricPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .opacity(0.72)
        }
        .foregroundColor(.white.opacity(0.86))
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.black.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct DetailSection<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Chips

private struct KeywordChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.primary.opacity(0.84))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

private struct RemovableChip: View {
    let text: String
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 5) {
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1)

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(isHovered ? .white.opacity(0.82) : .accentColor.opacity(0.68))
        }
        .foregroundColor(isHovered ? .white : .accentColor)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(isHovered ? 0.30 : 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.accentColor.opacity(isHovered ? 0.42 : 0.30), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
        .onTapGesture { onRemove() }
        .help("Remove alias")
    }
}

private struct EmptyAliasRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.58))
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary.opacity(0.62))
            Spacer()
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
    }
}
