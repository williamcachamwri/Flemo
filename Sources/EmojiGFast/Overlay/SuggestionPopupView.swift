import SwiftUI

struct SuggestionPopupView: View {
    @ObservedObject var appState: AppState
    var emojiHandler: (Emoji) -> Void

    var body: some View {
        let visibleItems = visibleSuggestions()
        let metrics = popupMetrics()

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
        .padding(.horizontal, metrics.horizontalPadding)
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
        let height = min(max(appState.inlinePopupHeight, 40), 62)
        let width = height * 4.1
        let itemSize = min(max(height * 0.76, 30), height - 10)
        let spacing = max(7, height * 0.17)
        let verticalPadding = max(5, (height - itemSize) / 2)
        let horizontalPadding = max(9, (width - itemSize * 4 - spacing * 3) / 2)
        let fontSize = min(max(height * 0.52, 22), 30)

        return PopupMetrics(
            width: width,
            height: height,
            itemSize: itemSize,
            spacing: spacing,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            fontSize: fontSize,
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
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let fontSize: CGFloat
    let outerPadding: CGFloat
}
