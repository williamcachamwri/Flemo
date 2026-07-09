import SwiftUI

struct SuggestionPopupView: View {
    @ObservedObject var appState: AppState
    var emojiHandler: (Emoji) -> Void

    var body: some View {
        InlineSuggestionPillView(
            entries: visibleSuggestions(),
            selectedIndex: appState.selectedSuggestionIndex,
            layout: appState.inlineSuggestionLayout,
            label: appState.currentSuggestionLabel,
            baseHeight: appState.inlinePopupHeight,
            emojiHandler: emojiHandler
        )
    }

    private func visibleSuggestions() -> [InlineSuggestionEntry] {
        let start = min(appState.visibleSuggestionStart, max(appState.suggestions.count - 1, 0))
        let end = min(start + AppState.inlineVisibleCount, appState.suggestions.count)
        guard start < end else { return [] }
        return Array(appState.suggestions[start..<end].enumerated()).map { offset, item in
            InlineSuggestionEntry(absoluteIndex: start + offset, item: item)
        }
    }
}

struct InlineSuggestionEntry: Identifiable {
    let absoluteIndex: Int
    let item: SuggestionItem

    var id: UUID { item.id }
}

struct InlineSuggestionPillView: View {
    let entries: [InlineSuggestionEntry]
    let selectedIndex: Int
    let layout: InlineSuggestionLayout
    let label: String
    let baseHeight: CGFloat
    let emojiHandler: (Emoji) -> Void

    var body: some View {
        let metrics = popupMetrics()

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: metrics.spacing) {
                ForEach(entries) { entry in
                    SuggestionPillButton(
                        emoji: entry.item.emoji,
                        isSelected: entry.absoluteIndex == selectedIndex,
                        itemSize: metrics.itemSize,
                        fontSize: metrics.fontSize
                    ) {
                        emojiHandler(entry.item.emoji)
                    }
                }

                if entries.isEmpty {
                    Text("No results")
                        .font(.system(size: metrics.labelFontSize, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                        .frame(height: metrics.itemSize)
                        .padding(.horizontal, 10)
                }
            }
            .frame(height: metrics.iconRowHeight)
            .padding(.horizontal, metrics.horizontalPadding)

            if layout == .descriptive {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .transition(.opacity)

                Text(label)
                    .font(.system(size: metrics.labelFontSize, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: metrics.labelWidth, height: metrics.labelHeight, alignment: .leading)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .padding(.vertical, metrics.verticalPadding)
        .frame(width: metrics.width, height: metrics.height, alignment: .leading)
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                .fill(Color(red: 0.075, green: 0.078, blue: 0.085).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
        .padding(metrics.outerPadding)
        .animation(.spring(response: 0.24, dampingFraction: 0.88), value: selectedIndex)
        .animation(.spring(response: 0.34, dampingFraction: 0.84, blendDuration: 0.08), value: layout)
    }

    private func popupMetrics() -> PopupMetrics {
        let basePillHeight = min(max(baseHeight, 42), 58)
        let itemSize = min(max(basePillHeight * 0.72, 28), 38)
        let spacing = max(8, basePillHeight * 0.16)
        let iconRowHeight = max(itemSize, basePillHeight - 12)
        let labelHeight = layout == .descriptive ? max(30, basePillHeight * 0.58) : 0
        let verticalPadding = max(6, (basePillHeight - iconRowHeight) / 2)
        let minIconWidth = itemSize * CGFloat(AppState.inlineVisibleCount)
            + spacing * CGFloat(AppState.inlineVisibleCount - 1)
        let width = minIconWidth + 28
        let horizontalPadding = max(9, (width - minIconWidth) / 2)
        let fontSize = min(max(basePillHeight * 0.50, 22), 30)
        let totalHeight = iconRowHeight + verticalPadding * 2 + labelHeight
            + (layout == .descriptive ? 1 : 0)
        let labelFontSize = min(max(baseHeight * 0.28, 13), 16)

        return PopupMetrics(
            width: width,
            height: totalHeight,
            itemSize: itemSize,
            spacing: spacing,
            iconRowHeight: iconRowHeight,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            fontSize: fontSize,
            labelHeight: labelHeight,
            labelFontSize: labelFontSize,
            labelWidth: width - horizontalPadding * 2,
            cornerRadius: layout == .descriptive ? 26 : totalHeight / 2,
            outerPadding: 4
        )
    }
}

struct SuggestionPillButton: View {
    let emoji: Emoji
    let isSelected: Bool
    let itemSize: CGFloat
    let fontSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(emoji.character)
                .font(.system(size: fontSize))
                .frame(width: itemSize, height: itemSize)
                .background(
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(emoji.name)
    }
}

private struct PopupMetrics {
    let width: CGFloat
    let height: CGFloat
    let itemSize: CGFloat
    let spacing: CGFloat
    let iconRowHeight: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let fontSize: CGFloat
    let labelHeight: CGFloat
    let labelFontSize: CGFloat
    let labelWidth: CGFloat
    let cornerRadius: CGFloat
    let outerPadding: CGFloat
}
