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

    private let keywordColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    private var usageText: String {
        let count = FrequencyTracker.shared.usageCount(for: emoji.character)
        return count > 0 ? "Used \(count) time\(count == 1 ? "" : "s")" : "Never used"
    }

    private var defaultKeywords: [String] { emoji.keywords }
    private var customKeywords: [String] { customization.customAliases(for: emoji.character) }
    private var isFavorite: Bool { customization.isFavorite(emoji.character) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            header
            divider
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    customSection
                    defaultSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.secondary.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(emoji.character, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.secondary.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")

            favoriteStar
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 6)
    }

    private var favoriteStar: some View {
        Button {
            customization.toggleFavorite(emoji.character)
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isFavorite ? .yellow : .secondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.secondary.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .help("Favorite")
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 7) {
            Button {
                onUse()
            } label: {
                Text(emoji.character)
                    .font(.system(size: 68))
            }
            .buttonStyle(.plain)

            Text(emoji.name)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.primary.opacity(0.92))

            Text(usageText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary.opacity(0.68))

            Text("Click the emoji to insert")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.vertical, 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
            .padding(.horizontal, 20)
    }

    // MARK: Custom section

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Custom",
                count: customKeywords.count,
                expanded: customExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { customExpanded.toggle() }
            }

            if customExpanded {
                HStack(spacing: 8) {
                    TextField("Add keyword...", text: $newAlias)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .textFieldStyle(.plain)
                        .tint(.accentColor)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.secondary.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .focused($aliasFieldFocused)
                        .onSubmit { commitAlias() }

                    addButton
                }

                if !customKeywords.isEmpty {
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
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.accentColor))
        }
        .buttonStyle(.plain)
    }

    private func commitAlias() {
        let trimmed = newAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        customization.addAlias(trimmed, for: emoji.character)
        newAlias = ""
    }

    // MARK: Default section

    private var defaultSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Default",
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
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.7))
                    .rotationEffect(.degrees(expanded ? 90 : 0))

                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.88))

                Spacer()

                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
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

// MARK: - Chips

private struct KeywordChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.primary.opacity(0.82))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
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
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .foregroundColor(isHovered ? .white : .accentColor)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(isHovered ? 0.28 : 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
        .onTapGesture { onRemove() }
        .help("Remove keyword")
    }
}
