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
            theme: appState.popupTheme,
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

    var id: String { item.emoji.character }
}

struct InlineSuggestionPillView: View {
    let entries: [InlineSuggestionEntry]
    let selectedIndex: Int
    let layout: InlineSuggestionLayout
    let label: String
    let theme: PopupTheme
    let baseHeight: CGFloat
    let emojiHandler: (Emoji) -> Void

    var body: some View {
        let metrics = popupMetrics()
        let themeStyle = popupThemeStyle()

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: metrics.spacing) {
                ForEach(entries) { entry in
                    SuggestionPillButton(
                        emoji: entry.item.emoji,
                        isSelected: entry.absoluteIndex == selectedIndex,
                        itemSize: metrics.itemSize,
                        fontSize: metrics.fontSize,
                        selectedFill: themeStyle.selectionFill
                    ) {
                        emojiHandler(entry.item.emoji)
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.72).combined(with: .opacity),
                        removal: .scale(scale: 0.86).combined(with: .opacity)
                    ))
                }

                if entries.isEmpty {
                    Text("No results")
                        .font(.system(size: metrics.labelFontSize, weight: .semibold, design: .rounded))
                        .foregroundColor(themeStyle.secondaryText)
                        .frame(height: metrics.itemSize)
                        .padding(.horizontal, 10)
                }
            }
            .frame(height: metrics.iconRowHeight)
            .padding(.horizontal, metrics.horizontalPadding)

            if layout == .descriptive {
                Rectangle()
                    .fill(themeStyle.divider)
                    .frame(height: 1)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .transition(.opacity)

                Text(label)
                    .font(.system(size: metrics.labelFontSize, weight: .semibold, design: .rounded))
                    .foregroundColor(themeStyle.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: metrics.labelWidth, height: metrics.labelHeight, alignment: .leading)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .id(label)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .padding(.vertical, metrics.verticalPadding)
        .frame(width: metrics.width, height: metrics.height, alignment: .leading)
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                .fill(themeStyle.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                .stroke(themeStyle.border, lineWidth: 1)
        )
        .shadow(color: themeStyle.shadow, radius: 16, y: 8)
        .padding(metrics.outerPadding)
        .animation(.spring(response: 0.24, dampingFraction: 0.88), value: selectedIndex)
        .animation(.spring(response: 0.30, dampingFraction: 0.80, blendDuration: 0.08), value: entriesSignature)
        .animation(.spring(response: 0.24, dampingFraction: 0.88), value: label)
        .animation(.spring(response: 0.34, dampingFraction: 0.84, blendDuration: 0.08), value: layout)
        .animation(.easeInOut(duration: 0.18), value: theme)
    }

    private var entriesSignature: String {
        entries.map { $0.item.emoji.character }.joined(separator: "")
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

    private func popupThemeStyle() -> PopupThemeStyle {
        switch theme {
        case .nativeDark:
            return PopupThemeStyle(
                background: AnyShapeStyle(Color(red: 0.075, green: 0.078, blue: 0.085).opacity(0.92)),
                border: Color.white.opacity(0.24),
                divider: Color.white.opacity(0.12),
                secondaryText: Color.white.opacity(0.72),
                selectionFill: Color.white.opacity(0.14),
                shadow: Color.black.opacity(0.22)
            )
        case .glass:
            return PopupThemeStyle(
                background: AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.26),
                            Color(red: 0.18, green: 0.42, blue: 0.95).opacity(0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ),
                border: Color.white.opacity(0.34),
                divider: Color.white.opacity(0.20),
                secondaryText: Color.white.opacity(0.82),
                selectionFill: Color.white.opacity(0.20),
                shadow: Color.black.opacity(0.18)
            )
        case .midnight:
            return PopupThemeStyle(
                background: AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.03, green: 0.05, blue: 0.12).opacity(0.96),
                            Color(red: 0.08, green: 0.11, blue: 0.26).opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ),
                border: Color(red: 0.36, green: 0.48, blue: 0.95).opacity(0.28),
                divider: Color(red: 0.36, green: 0.48, blue: 0.95).opacity(0.18),
                secondaryText: Color(red: 0.82, green: 0.86, blue: 1.0).opacity(0.78),
                selectionFill: Color(red: 0.36, green: 0.48, blue: 0.95).opacity(0.20),
                shadow: Color.black.opacity(0.30)
            )
        case .frost:
            return PopupThemeStyle(
                background: AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.14, blue: 0.18).opacity(0.88),
                            Color(red: 0.18, green: 0.20, blue: 0.26).opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ),
                border: Color(red: 0.70, green: 0.75, blue: 0.85).opacity(0.20),
                divider: Color(red: 0.70, green: 0.75, blue: 0.85).opacity(0.10),
                secondaryText: Color(red: 0.75, green: 0.78, blue: 0.88).opacity(0.80),
                selectionFill: Color(red: 0.55, green: 0.60, blue: 0.75).opacity(0.20),
                shadow: Color(red: 0.10, green: 0.12, blue: 0.18).opacity(0.35)
            )
        case .neon:
            return PopupThemeStyle(
                background: AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.02, blue: 0.06).opacity(0.96),
                            Color(red: 0.06, green: 0.03, blue: 0.14).opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ),
                border: Color(red: 0.30, green: 0.60, blue: 1.0).opacity(0.35),
                divider: Color(red: 0.80, green: 0.20, blue: 1.0).opacity(0.20),
                secondaryText: Color(red: 0.40, green: 0.70, blue: 1.0).opacity(0.80),
                selectionFill: Color(red: 0.30, green: 0.60, blue: 1.0).opacity(0.18),
                shadow: Color(red: 0.15, green: 0.05, blue: 0.30).opacity(0.35)
            )
        case .crimson:
            return PopupThemeStyle(
                background: AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.03, blue: 0.05).opacity(0.94),
                            Color(red: 0.18, green: 0.05, blue: 0.08).opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ),
                border: Color(red: 0.75, green: 0.30, blue: 0.35).opacity(0.30),
                divider: Color(red: 0.65, green: 0.25, blue: 0.30).opacity(0.15),
                secondaryText: Color(red: 0.85, green: 0.55, blue: 0.55).opacity(0.72),
                selectionFill: Color(red: 0.70, green: 0.25, blue: 0.30).opacity(0.22),
                shadow: Color(red: 0.08, green: 0.02, blue: 0.03).opacity(0.40)
            )
        case .mono:
            return PopupThemeStyle(
                background: AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.94),
                            Color(red: 0.12, green: 0.12, blue: 0.13).opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ),
                border: Color(red: 0.50, green: 0.50, blue: 0.52).opacity(0.22),
                divider: Color(red: 0.50, green: 0.50, blue: 0.52).opacity(0.10),
                secondaryText: Color(red: 0.55, green: 0.55, blue: 0.58).opacity(0.75),
                selectionFill: Color(red: 0.55, green: 0.55, blue: 0.58).opacity(0.18),
                shadow: Color(red: 0.02, green: 0.02, blue: 0.03).opacity(0.35)
            )
        case .aurora:
            return PopupThemeStyle(
                background: AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.06, blue: 0.10).opacity(0.94),
                            Color(red: 0.06, green: 0.12, blue: 0.08).opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ),
                border: Color(red: 0.20, green: 0.80, blue: 0.60).opacity(0.25),
                divider: Color(red: 0.50, green: 0.30, blue: 0.90).opacity(0.15),
                secondaryText: Color(red: 0.50, green: 0.85, blue: 0.75).opacity(0.75),
                selectionFill: Color(red: 0.20, green: 0.80, blue: 0.60).opacity(0.18),
                shadow: Color(red: 0.02, green: 0.06, blue: 0.08).opacity(0.35)
            )
        }
    }
}

struct SuggestionPillButton: View {
    let emoji: Emoji
    let isSelected: Bool
    let itemSize: CGFloat
    let fontSize: CGFloat
    let selectedFill: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(emoji.character)
                .font(.system(size: fontSize))
                .frame(width: itemSize, height: itemSize)
                .background(
                    Circle()
                        .fill(isSelected ? selectedFill : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(emoji.name)
    }
}

private struct PopupThemeStyle {
    let background: AnyShapeStyle
    let border: Color
    let divider: Color
    let secondaryText: Color
    let selectionFill: Color
    let shadow: Color
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
