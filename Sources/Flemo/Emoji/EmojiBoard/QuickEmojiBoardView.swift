import AppKit
import SwiftUI

struct QuickEmojiBoardView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var customization = EmojiCustomizationManager.shared
    @State private var searchText = ""
    @State private var selectedCategory = QuickEmojiCategory.recents
    @State private var selectedIndex = 0
    @State private var displayedResults: [Emoji] = []
    @State private var searchGeneration = 0
    @FocusState private var searchFocused: Bool

    var onSelect: (Emoji) -> Void
    var onDismiss: () -> Void

    private let columnCount = 6
    private let columns = Array(repeating: GridItem(.fixed(38), spacing: 7), count: 6)

    private var displayEmojis: [Emoji] {
        EmojiDataLoader.shared.preferredEmojis(
            personSkinTone: appState.personSkinTone,
            manSkinTone: appState.manSkinTone,
            womanSkinTone: appState.womanSkinTone,
            gestureSkinTone: appState.gestureSkinTone
        )
    }

    private var selectedEmoji: Emoji? {
        guard displayedResults.indices.contains(selectedIndex) else { return displayedResults.first }
        return displayedResults[selectedIndex]
    }

    private var resultSignature: String {
        displayedResults.prefix(80).map { $0.character }.joined()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.085, green: 0.086, blue: 0.090),
                            Color(red: 0.060, green: 0.062, blue: 0.066)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 0) {
                searchHeader

                if displayedResults.isEmpty {
                    emptyState
                } else {
                    selectionPreview
                        .padding(.bottom, 8)

                    resultsGrid
                }

                categoryRail
            }
            .padding(8)
        }
        .frame(width: 318, height: 456)
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
        )
        .background(
            QuickEmojiBoardKeyMonitor { event in
                handleKey(event)
            }
        )
        .onAppear {
            refreshResults(debounce: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                searchFocused = true
            }
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
            refreshResults(debounce: true)
        }
        .onChange(of: selectedCategory) { _, _ in
            selectedIndex = 0
            refreshResults(debounce: false)
        }
        .onChange(of: appState.personSkinTone) { _, _ in
            refreshResults(debounce: false)
        }
        .onChange(of: appState.gestureSkinTone) { _, _ in
            refreshResults(debounce: false)
        }
        .onChange(of: appState.manSkinTone) { _, _ in
            refreshResults(debounce: false)
        }
        .onChange(of: appState.womanSkinTone) { _, _ in
            refreshResults(debounce: false)
        }
        .onChange(of: resultSignature) { _, _ in
            selectedIndex = min(selectedIndex, max(displayedResults.count - 1, 0))
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(searchFocused ? .white.opacity(0.88) : .secondary.opacity(0.82))

            TextField("Search", text: $searchText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { insertSelectedEmoji() }

            Text("\(displayedResults.count)")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.58))
                .monospacedDigit()
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.075)))

            if !searchText.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                        searchText = ""
                        selectedIndex = 0
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.72))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(searchFocused ? 0.34 : 0.24))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.accentColor.opacity(searchFocused ? 0.74 : 0.28), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(searchFocused ? 0.14 : 0), radius: 8, y: 4)
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.16), value: searchFocused)
    }

    private var selectionPreview: some View {
        Group {
            if let emoji = selectedEmoji {
                QuickEmojiSelectionPreview(
                    emoji: emoji,
                    aliases: aliases(for: emoji, limit: 3),
                    isFavorite: customization.isFavorite(emoji.character)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
        }
    }

    private var resultsGrid: some View {
        ScrollView(showsIndicators: true) {
            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(Array(displayedResults.enumerated()), id: \.element.character) { index, emoji in
                    QuickEmojiCell(
                        emoji: emoji,
                        isSelected: index == selectedIndex,
                        isFavorite: customization.isFavorite(emoji.character)
                    ) {
                        select(emoji)
                    }
                    .onHover { hovering in
                        if hovering {
                            selectedIndex = index
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.030))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.065), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.46))

            Text("No emoji found")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.secondary.opacity(0.68))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
    }

    private var categoryRail: some View {
        HStack(spacing: 4) {
            ForEach(QuickEmojiCategory.allCases) { category in
                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                        selectedCategory = category
                        searchText = ""
                        searchFocused = true
                    }
                } label: {
                    Image(systemName: category.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundColor(
                            selectedCategory == category && searchText.isEmpty
                                ? .white
                                : .white.opacity(0.60)
                        )
                        .frame(width: 23, height: 23)
                        .contentShape(Circle())
                        .background(
                            Circle()
                                .fill(selectedCategory == category && searchText.isEmpty
                                      ? Color.white.opacity(0.16)
                                      : Color.clear)
                        )
                        .overlay(
                            Circle()
                                .stroke(selectedCategory == category && searchText.isEmpty
                                        ? Color.white.opacity(0.14)
                                        : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(category.title)
            }
        }
        .padding(.horizontal, 5)
        .padding(.top, 7)
        .padding(.bottom, 1)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        if !event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
            return false
        }

        switch event.keyCode {
        case 53:
            onDismiss()
            return true
        case 36, 48, 76:
            insertSelectedEmoji()
            return true
        case 123:
            moveSelection(by: -1)
            return true
        case 124:
            moveSelection(by: 1)
            return true
        case 125:
            moveSelection(by: columnCount)
            return true
        case 126:
            moveSelection(by: -columnCount)
            return true
        default:
            return false
        }
    }

    private func moveSelection(by delta: Int) {
        guard !displayedResults.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.08)) {
            selectedIndex = min(max(selectedIndex + delta, 0), displayedResults.count - 1)
        }
    }

    private func insertSelectedEmoji() {
        guard let emoji = selectedEmoji else { return }
        select(emoji)
    }

    private func select(_ emoji: Emoji) {
        onSelect(emoji)
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

    private func refreshResults(debounce: Bool) {
        searchGeneration += 1
        let generation = searchGeneration
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = selectedCategory
        let personTone = appState.personSkinTone
        let gestureTone = appState.gestureSkinTone
        let manTone = appState.manSkinTone
        let womanTone = appState.womanSkinTone

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + (debounce ? 0.055 : 0)) {
            let next = Self.makeResults(
                keyword: keyword,
                category: category,
                personTone: personTone,
                gestureTone: gestureTone,
                manTone: manTone,
                womanTone: womanTone
            )

            DispatchQueue.main.async {
                guard generation == searchGeneration else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    displayedResults = next
                    selectedIndex = min(selectedIndex, max(next.count - 1, 0))
                }
            }
        }
    }

    private static func makeResults(
        keyword: String,
        category: QuickEmojiCategory,
        personTone: EmojiSkinTone,
        gestureTone: EmojiSkinTone,
        manTone: EmojiSkinTone,
        womanTone: EmojiSkinTone
    ) -> [Emoji] {
        let source = EmojiDataLoader.shared.preferredEmojis(
            personSkinTone: personTone,
            manSkinTone: manTone,
            womanSkinTone: womanTone,
            gestureSkinTone: gestureTone
        )

        if !keyword.isEmpty {
            let results = EmojiSearchEngine.shared.search(
                keyword: keyword,
                maxResults: 72,
                personSkinTone: personTone,
                manSkinTone: manTone,
                womanSkinTone: womanTone,
                gestureSkinTone: gestureTone
            )
            return Array(dedupe(results).prefix(72))
        }

        switch category {
        case .recents:
            let frequent = EmojiSearchEngine.shared.search(
                keyword: "",
                maxResults: 18,
                personSkinTone: personTone,
                manSkinTone: manTone,
                womanSkinTone: womanTone,
                gestureSkinTone: gestureTone
            )
            return Array(dedupe(curatedDefaults(from: source) + frequent).prefix(72))
        case .favorites:
            return Array(source.filter { EmojiCustomizationManager.shared.isFavorite($0.character) }.prefix(72))
        default:
            guard let libraryCategory = category.libraryCategory else { return Array(source.prefix(72)) }
            return Array(source.filter { $0.category == libraryCategory }.prefix(72))
        }
    }

    private static func curatedDefaults(from source: [Emoji]) -> [Emoji] {
        var byBaseKey: [String: Emoji] = [:]
        for emoji in source {
            byBaseKey[EmojiSkinToneNormalizer.baseKey(for: emoji.character)] = emoji
        }
        return curatedQuickCharacters.compactMap { byBaseKey[EmojiSkinToneNormalizer.baseKey(for: $0)] }
    }

    private static func dedupe(_ emojis: [Emoji]) -> [Emoji] {
        var seen = Set<String>()
        return emojis.filter { emoji in
            let key = EmojiSkinToneNormalizer.baseKey(for: emoji.character)
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private static let curatedQuickCharacters = [
        "😱", "😀", "🤔", "🐶", "🐈‍⬛", "🐱",
        "🐕", "💡", "🐎", "🔧", "😭", "💀",
        "👍", "👋", "🙂", "😯", "🫠", "😉",
        "😊", "😇", "🥰", "😍", "🤩", "😘",
        "😂", "🤣", "😅", "😎", "🙌", "💪",
        "🎉", "🔥", "✨", "❤️", "✅", "⭐",
        "🚀", "💬", "📝", "🍔", "🍟", "☁️",
        "🏃", "👠", "🏁", "⚡️", "⬆️", "⬇️"
    ]
}

private enum QuickEmojiCategory: String, CaseIterable, Identifiable {
    case recents
    case favorites
    case smileys
    case people
    case nature
    case food
    case travel
    case activities
    case objects
    case symbols
    case flags

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recents: return "Recent"
        case .favorites: return "Favorites"
        case .smileys: return "Smileys"
        case .people: return "People"
        case .nature: return "Nature"
        case .food: return "Food"
        case .travel: return "Travel"
        case .activities: return "Activities"
        case .objects: return "Objects"
        case .symbols: return "Symbols"
        case .flags: return "Flags"
        }
    }

    var symbol: String {
        switch self {
        case .recents: return "clock.arrow.circlepath"
        case .favorites: return "star.fill"
        case .smileys: return "face.smiling"
        case .people: return "person.fill"
        case .nature: return "leaf.fill"
        case .food: return "fork.knife"
        case .travel: return "car.fill"
        case .activities: return "soccerball"
        case .objects: return "lightbulb.fill"
        case .symbols: return "command"
        case .flags: return "flag.fill"
        }
    }

    var libraryCategory: String? {
        switch self {
        case .recents, .favorites:
            return nil
        case .smileys:
            return "Smileys & Emotion"
        case .people:
            return "People & Body"
        case .nature:
            return "Animals & Nature"
        case .food:
            return "Food & Drink"
        case .travel:
            return "Travel & Places"
        case .activities:
            return "Activities"
        case .objects:
            return "Objects"
        case .symbols:
            return "Symbols"
        case .flags:
            return "Flags"
        }
    }
}

private struct QuickEmojiSelectionPreview: View {
    let emoji: Emoji
    let aliases: [String]
    let isFavorite: Bool

    var body: some View {
        let colors = EmojiColorExtractor.shared.colors(for: emoji.character)

        HStack(spacing: 10) {
            Text(emoji.character)
                .font(.system(size: 31))
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    colors[0].opacity(0.30),
                                    colors[1].opacity(0.16),
                                    Color.white.opacity(0.045)
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

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(displayName(for: emoji))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                        .lineLimit(1)

                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.yellow.opacity(0.92))
                    }
                }

                HStack(spacing: 5) {
                    detailPill(emoji.category, icon: "folder.fill")
                    usagePill

                    ForEach(aliases.prefix(2), id: \.self) { alias in
                        detailPill(alias, icon: nil)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(height: 58)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            colors[0].opacity(0.12),
                            Color.white.opacity(0.045),
                            Color.black.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 10, y: 5)
        .animation(.spring(response: 0.24, dampingFraction: 0.88), value: emoji.character)
    }

    private var usagePill: some View {
        let count = FrequencyTracker.shared.usageCount(for: emoji.character)
        return detailPill(count == 0 ? "new" : "\(count)", icon: "chart.bar.fill")
    }

    private func detailPill(_ text: String, icon: String?) -> some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .black))
            }
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 9, weight: .bold, design: .rounded))
        .foregroundColor(.white.opacity(0.58))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.070)))
    }

    private func displayName(for emoji: Emoji) -> String {
        emoji.name
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

private struct QuickEmojiCell: View {
    let emoji: Emoji
    let isSelected: Bool
    let isFavorite: Bool
    let action: () -> Void

    var body: some View {
        let colors = EmojiColorExtractor.shared.colors(for: emoji.character)

        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Text(emoji.character)
                    .font(.system(size: 24))
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                isSelected
                                    ? LinearGradient(
                                        colors: [
                                            colors[0].opacity(0.26),
                                            colors[1].opacity(0.14),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [Color.clear, Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? Color.white.opacity(0.18) : Color.clear, lineWidth: 1)
                    )
                    .scaleEffect(isSelected ? 1.09 : 1)
                    .shadow(color: isSelected ? .black.opacity(0.16) : .clear, radius: 8, y: 4)

                if isFavorite {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 5, height: 5)
                        .offset(x: -5, y: 5)
                }
            }
        }
        .buttonStyle(.plain)
        .help(emoji.name)
        .animation(.spring(response: 0.20, dampingFraction: 0.84), value: isSelected)
    }
}

private struct QuickEmojiBoardKeyMonitor: NSViewRepresentable {
    let handle: (NSEvent) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.handle = handle
        let coordinator = context.coordinator
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak coordinator] event in
            coordinator?.handle?(event) == true ? nil : event
        }
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.handle = handle
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor {
            NSEvent.removeMonitor(monitor)
            coordinator.monitor = nil
        }
    }

    final class Coordinator {
        var handle: ((NSEvent) -> Bool)?
        var monitor: Any?
    }
}

final class QuickEmojiBoardPanel: NSPanel {
    init<V: View>(contentView: NSHostingView<V>) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 318, height: 456),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        worksWhenModal = true
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isReleasedWhenClosed = false

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.layer?.masksToBounds = false
        self.contentView = contentView
    }

    func show(belowAXRect axRect: CGRect) {
        guard let anchor = cocoaRect(fromAXRect: axRect) else {
            showNearFocusedScreen()
            return
        }
        show(nearCocoaRect: anchor)
    }

    func show(near anchor: TypingAnchorBounds) {
        switch anchor.coordinateSpace {
        case .accessibility:
            show(belowAXRect: anchor.rect)
        case .cocoa:
            show(nearCocoaRect: anchor.rect)
        }
    }

    func showNearFocusedScreen() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let frame = screen.visibleFrame
        let anchor = CGRect(
            x: frame.minX + min(max(frame.width * 0.08, 72), 160),
            y: frame.minY + min(max(frame.height * 0.12, 96), 180),
            width: 1,
            height: 20
        )
        show(nearCocoaRect: anchor)
    }

    private func show(nearCocoaRect anchor: CGRect) {
        let contentSize = fittingContentSize()
        let panelWidth = contentSize.width
        let panelHeight = contentSize.height
        let gap: CGFloat = 9

        guard let screen = screen(containingCocoaPoint: NSPoint(x: anchor.midX, y: anchor.midY))
            ?? NSScreen.main
            ?? NSScreen.screens.first
        else { return }

        var x = anchor.minX - 20
        var y = anchor.minY - panelHeight - gap

        let frame = screen.visibleFrame
        if x + panelWidth > frame.maxX { x = frame.maxX - panelWidth - 10 }
        if x < frame.minX { x = frame.minX + 10 }
        if y < frame.minY { y = anchor.maxY + gap }
        if y + panelHeight > frame.maxY { y = frame.maxY - panelHeight - 10 }
        if y < frame.minY { y = frame.minY + 10 }

        setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        displayIfNeeded()
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }

    private func fittingContentSize() -> CGSize {
        contentView?.layoutSubtreeIfNeeded()
        let size = contentView?.fittingSize ?? .zero
        if size.width.isFinite, size.height.isFinite,
           size.width > 0, size.height > 0 {
            return size
        }
        return CGSize(width: 318, height: 456)
    }

    private func cocoaRect(fromAXRect axRect: CGRect) -> CGRect? {
        let probe = CGPoint(x: axRect.midX, y: axRect.midY)
        let screen = screen(containingAXPoint: probe) ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen, let displayBounds = cgDisplayBounds(for: screen) else { return nil }

        let width = max(axRect.width, 1)
        let height = max(axRect.height, 1)
        let x = screen.frame.minX + (axRect.minX - displayBounds.minX)
        let y = screen.frame.maxY - ((axRect.minY - displayBounds.minY) + height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func screen(containingAXPoint point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let bounds = cgDisplayBounds(for: screen) else { return false }
            return bounds.contains(point)
        }
    }

    private func screen(containingCocoaPoint point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    private func cgDisplayBounds(for screen: NSScreen) -> CGRect? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return nil }
        return CGDisplayBounds(CGDirectDisplayID(number.uint32Value))
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
