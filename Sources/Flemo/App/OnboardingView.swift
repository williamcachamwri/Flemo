import AppKit
import Combine
import SwiftUI

struct OnboardingView: View {
    @StateObject private var permissions = AccessibilityPermissionManager.shared
    @ObservedObject private var appState = AppState.shared
    @State private var testInput = "`cat"
    @State private var isAnimating = false
    @State private var selectedIndex = 0

    private let statusTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            OnboardingMaterialView()
            animatedBackdrop

            VStack(spacing: 0) {
                header

                HStack(spacing: 18) {
                    heroPanel
                    permissionPanel
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)

                testPanel
                    .padding(.horizontal, 22)
                    .padding(.top, 16)

                Spacer(minLength: 14)

                footer
            }
        }
        .frame(width: 660, height: 520)
        .onAppear {
            permissions.refreshStatus()
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
        .onReceive(statusTimer) { _ in
            permissions.refreshStatus()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            OnboardingLogoImage(size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("Flemo")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Inline emoji that follows your typing.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.72))
            }

            Spacer()

            Button {
                closeOnboarding()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.secondary.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var heroPanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )

            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(Array(heroEmojis.enumerated()), id: \.element.character) { index, emoji in
                        Text(emoji.character)
                            .font(.system(size: 24))
                            .rotationEffect(.degrees(time * 28 + Double(index * 32)))
                            .offset(
                                x: cos(time + Double(index)) * 86,
                                y: sin(time * 0.9 + Double(index)) * 42
                            )
                            .opacity(0.18)
                    }
                }
            }

            VStack(spacing: 18) {
                InlineSuggestionPillView(
                    entries: previewEntries,
                    selectedIndex: selectedIndex,
                    layout: appState.inlineSuggestionLayout,
                    label: previewLabel,
                    theme: appState.popupTheme,
                    baseHeight: 54,
                    emojiHandler: { _ in }
                )
                .offset(y: isAnimating ? -3 : 3)

                Text(previewLabel)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.90))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )
            }
        }
        .frame(width: 298, height: 210)
    }

    private var permissionPanel: some View {
        VStack(spacing: 10) {
            PermissionCard(
                icon: "lock.shield",
                title: "Accessibility",
                detail: "Cursor bounds and focused text",
                granted: permissions.accessibilityGranted
            ) {
                permissions.requestAccessibility()
            }

            PermissionCard(
                icon: "keyboard.badge.eye",
                title: "Input Monitoring",
                detail: "Trigger text and arrow keys",
                granted: permissions.inputMonitoringGranted
            ) {
                permissions.requestInputMonitoring()
            }

            Button {
                permissions.showPermissionGuide()
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("Open Permission Guide")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.primary.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.11))
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var testPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Try it here")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                Text("Real search preview")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.72))
            }

            HStack(spacing: 12) {
                TextField("Type \(appState.triggerCharacter)cat", text: $testInput)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.16))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .onChange(of: testInput) { _, _ in
                        selectedIndex = 0
                    }

                InlineSuggestionPillView(
                    entries: testEntries,
                    selectedIndex: selectedIndex,
                    layout: appState.inlineSuggestionLayout,
                    label: extractedLabel,
                    theme: appState.popupTheme,
                    baseHeight: 48,
                    emojiHandler: { emoji in
                        testInput = emoji.character
                    }
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var footer: some View {
        HStack {
            Label("Tab inserts, arrows move, Esc dismisses.", systemImage: "sparkle.magnifyingglass")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary.opacity(0.72))

            Spacer()

            Button {
                closeOnboarding()
            } label: {
                Text("Get Started")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
    }

    private var animatedBackdrop: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 230, height: 230)
                .blur(radius: 44)
                .offset(x: isAnimating ? -260 : -210, y: isAnimating ? -140 : -110)

            Circle()
                .fill(Color.cyan.opacity(0.10))
                .frame(width: 210, height: 210)
                .blur(radius: 42)
                .offset(x: isAnimating ? 250 : 210, y: isAnimating ? 170 : 130)
        }
    }

    private var heroEmojis: [Emoji] {
        EmojiSearchEngine.shared.search(keyword: "sparkle", maxResults: 6)
    }

    private var previewKeyword: String {
        "cat"
    }

    private var previewLabel: String {
        appState.triggerCharacter + previewKeyword
    }

    private var previewEntries: [InlineSuggestionEntry] {
        EmojiSearchEngine.shared.search(keyword: previewKeyword, maxResults: AppState.inlineVisibleCount)
            .enumerated()
            .map { offset, emoji in
                InlineSuggestionEntry(
                    absoluteIndex: offset,
                    item: SuggestionItem(
                        emoji: emoji,
                        shortcutIndex: appState.numberShortcutEnabled ? offset : nil
                    )
                )
            }
    }

    private var extractedKeyword: String {
        guard let trigger = appState.triggerCharacter.first,
              let index = testInput.lastIndex(of: trigger)
        else { return "" }
        return String(testInput[testInput.index(after: index)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var extractedLabel: String {
        appState.triggerCharacter + extractedKeyword
    }

    private var testEntries: [InlineSuggestionEntry] {
        let keyword = extractedKeyword
        let emojis: [Emoji]
        if keyword.count >= appState.minTriggerLength {
            emojis = EmojiSearchEngine.shared.search(keyword: keyword, maxResults: AppState.inlineVisibleCount)
        } else if appState.inlinePanelOpenMode == .recents {
            emojis = EmojiSearchEngine.shared.search(keyword: "", maxResults: AppState.inlineVisibleCount)
        } else {
            emojis = []
        }

        return emojis.enumerated().map { offset, emoji in
            InlineSuggestionEntry(
                absoluteIndex: offset,
                item: SuggestionItem(
                    emoji: emoji,
                    shortcutIndex: appState.numberShortcutEnabled ? offset : nil
                )
            )
        }
    }

    private func closeOnboarding() {
        NSApplication.shared.keyWindow?.close()
    }
}

private struct OnboardingLogoImage: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "face.smiling.fill")
            .font(.system(size: size * 0.72, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [.accentColor, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
    }
}

private struct PermissionCard: View {
    let icon: String
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(granted ? .green : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(detail)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.68))
            }

            Spacer()

            Button(action: action) {
                Text(granted ? "Granted" : "Grant")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(granted ? .green : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(granted ? Color.green.opacity(0.12) : Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct OnboardingMaterialView: NSViewRepresentable {
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
