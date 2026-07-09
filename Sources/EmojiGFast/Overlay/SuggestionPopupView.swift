import SwiftUI

struct SuggestionPopupView: View {
    @ObservedObject var appState: AppState
    var emojiHandler: (Emoji) -> Void

    var body: some View {
        let visibleItems = visibleSuggestions()
        let metrics = popupMetrics()

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: metrics.spacing) {
                ForEach(visibleItems, id: \.item.id) { entry in
                    SuggestionPillButton(
                        emoji: entry.item.emoji,
                        isSelected: entry.absoluteIndex == appState.selectedSuggestionIndex,
                        itemSize: metrics.itemSize,
                        fontSize: metrics.fontSize
                    ) {
                        emojiHandler(entry.item.emoji)
                    }
                }

                if appState.suggestions.isEmpty {
                    Text("No results")
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.72))
                        .frame(height: metrics.itemSize)
                        .padding(.horizontal, 10)
                }
            }
            .frame(height: metrics.iconRowHeight)
            .padding(.horizontal, metrics.horizontalPadding)

            if appState.inlineSuggestionLayout == .descriptive {
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
                    .padding(.horizontal, metrics.horizontalPadding)

                Text(selectedSuggestionToken())
                    .font(.system(size: metrics.labelFontSize, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(height: metrics.labelHeight, alignment: .leading)
                    .padding(.horizontal, metrics.horizontalPadding)
            }
        }
        .padding(.vertical, metrics.verticalPadding)
        .frame(width: metrics.width, height: metrics.height, alignment: .leading)
        .fixedSize()
        .background(
            Capsule(style: .continuous)
                .fill(Color(red: 0.075, green: 0.078, blue: 0.085).opacity(0.91))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: max(1, metrics.height * 0.018))
        )
        .padding(metrics.outerPadding)
        .animation(.spring(response: 0.22, dampingFraction: 0.86), value: appState.selectedSuggestionIndex)
        .animation(.easeInOut(duration: 0.16), value: appState.visibleSuggestionStart)
        .animation(.easeInOut(duration: 0.12), value: appState.inlinePopupHeight)
        .animation(.easeInOut(duration: 0.14), value: appState.inlineSuggestionLayout)
        .animation(.easeInOut(duration: 0.14), value: appState.inlineSuggestionScale)
    }

    private func visibleSuggestions() -> [(absoluteIndex: Int, item: SuggestionItem)] {
        let start = min(appState.visibleSuggestionStart, max(appState.suggestions.count - 1, 0))
        let end = min(start + AppState.inlineVisibleCount, appState.suggestions.count)
        guard start < end else { return [] }
        return Array(appState.suggestions[start..<end].enumerated()).map { offset, item in
            (absoluteIndex: start + offset, item: item)
        }
    }

    private func popupMetrics() -> PopupMetrics {
        let baseHeight = min(max(appState.inlinePopupHeight, 40), 62)
        let scaledHeight = min(max(baseHeight * CGFloat(appState.inlineSuggestionScale), 34), 78)
        let itemSize = min(max(scaledHeight * 0.76, 26), scaledHeight - 10)
        let spacing = max(6, scaledHeight * 0.16)
        let iconRowHeight = max(itemSize, scaledHeight - 10)
        let labelHeight = appState.inlineSuggestionLayout == .descriptive ? max(24, scaledHeight * 0.48) : 0
        let verticalPadding = max(4, (scaledHeight - iconRowHeight) / 2)
        let minIconWidth = itemSize * CGFloat(AppState.inlineVisibleCount)
            + spacing * CGFloat(AppState.inlineVisibleCount - 1)
        let baseWidth = scaledHeight * (appState.inlineSuggestionLayout == .descriptive ? 4.55 : 4.1)
        let width = max(baseWidth, minIconWidth + 18)
        let horizontalPadding = max(9, (width - minIconWidth) / 2)
        let fontSize = min(max(scaledHeight * 0.52, 20), 34)
        let height = iconRowHeight + verticalPadding * 2 + labelHeight
            + (appState.inlineSuggestionLayout == .descriptive ? 1 : 0)
        let labelFontSize = min(max(scaledHeight * 0.31, 12), 18)

        return PopupMetrics(
            width: width,
            height: height,
            itemSize: itemSize,
            spacing: spacing,
            iconRowHeight: iconRowHeight,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            fontSize: fontSize,
            labelHeight: labelHeight,
            labelFontSize: labelFontSize,
            outerPadding: 4
        )
    }

    private func selectedSuggestionToken() -> String {
        guard appState.suggestions.indices.contains(appState.selectedSuggestionIndex) else {
            return ""
        }
        let emoji = appState.suggestions[appState.selectedSuggestionIndex].emoji
        let rawToken = emoji.keywords.first ?? emoji.name
        let token = rawToken
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return ":\(token):"
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
    let outerPadding: CGFloat
}
