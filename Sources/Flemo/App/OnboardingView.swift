import AppKit
import Combine
import SwiftUI

struct OnboardingView: View {
    @StateObject private var permissions = AccessibilityPermissionManager.shared
    @ObservedObject private var appState = AppState.shared
    @State private var step = 0
    @State private var testInput = ""
    @State private var isAnimating = false
    @State private var selectedIndex = 0

    private let totalSteps = 3
    private let statusTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            OnboardingMaterialView()
            ambientGlow

            VStack(spacing: 0) {
                topBar
                stepContent
                navigation
            }
        }
        .frame(width: 660, height: 520)
        .onAppear {
            permissions.refreshStatus()
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
        .onReceive(statusTimer) { _ in
            permissions.refreshStatus()
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        ZStack {
            stepIndicator
            HStack {
                Spacer()
                closeButton
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var stepIndicator: some View {
        HStack(spacing: 7) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index == step ? Color.accentColor : Color.secondary.opacity(0.22))
                    .frame(width: index == step ? 22 : 6, height: 6)
                    .animation(.spring(response: 0.34, dampingFraction: 0.82), value: step)
            }
        }
    }

    private var closeButton: some View {
        Button {
            closeOnboarding()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.secondary.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.escape, modifiers: [])
    }

    // MARK: Step content

    @ViewBuilder
    private var stepContent: some View {
        currentStep
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 48)
            .id(step)
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                )
            )
    }

    @ViewBuilder
    private var currentStep: some View {
        switch step {
        case 0: welcomeStep
        case 1: permissionsStep
        default: tryItStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 26) {
            WelcomeMark()

            VStack(spacing: 9) {
                Text("Flemo")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Inline emoji that follows your typing.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.72))
                    .multilineTextAlignment(.center)
            }

            triggerHint
        }
    }

    private var triggerHint: some View {
        HStack(spacing: 8) {
            triggerKey
            Text("type a word to summon emoji anywhere")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary.opacity(0.68))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(Color.secondary.opacity(0.10))
        )
    }

    private var triggerKey: some View {
        Text(appState.triggerCharacter)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(.primary.opacity(0.9))
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
    }

    private var permissionsStep: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("Grant access")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Flemo needs these to read your typing and place suggestions inline.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

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

                PermissionCard(
                    icon: "applescript",
                    title: "Automation",
                    detail: "Browser URLs for site rules",
                    granted: permissions.automationGranted
                ) {
                    permissions.requestAutomation()
                }
            }
            .frame(maxWidth: 360)

            if !permissions.accessibilityGranted || !permissions.inputMonitoringGranted || !permissions.automationGranted {
                Button {
                    permissions.showPermissionGuide()
                } label: {
                    Text("Not sure? Open the permission guide")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            } else {
                Label("All set — you can continue.", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.green)
            }
        }
    }

    private var tryItStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Try it out")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Type below — suggestions update live.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 12) {
                TextField("Type \(appState.triggerCharacter)cat", text: $testInput)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
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
            .padding(16)
            .frame(maxWidth: 380)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )

            Label("Tab inserts · arrows move · Esc dismisses", systemImage: "sparkle.magnifyingglass")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary.opacity(0.68))
        }
    }

    // MARK: Navigation

    private var navigation: some View {
        HStack {
            backButton
            Spacer()
            primaryButton
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var backButton: some View {
        if step > 0 {
            Button {
                goBack()
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.secondary.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var primaryButton: some View {
        Button {
            advance()
        } label: {
            HStack(spacing: 6) {
                Text(step == totalSteps - 1 ? "Finish" : "Continue")
                Image(systemName: step == totalSteps - 1 ? "checkmark" : "arrow.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.accentColor)
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: [])
    }

    // MARK: Ambient

    private var ambientGlow: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 240, height: 240)
                .blur(radius: 50)
                .offset(x: isAnimating ? -200 : -160, y: isAnimating ? -150 : -120)

            Circle()
                .fill(Color.cyan.opacity(0.10))
                .frame(width: 220, height: 220)
                .blur(radius: 48)
                .offset(x: isAnimating ? 200 : 160, y: isAnimating ? 160 : 130)
        }
        .allowsHitTesting(false)
    }

    // MARK: Search helpers

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
                item: SuggestionItem(emoji: emoji)
            )
        }
    }

    // MARK: Actions

    private func advance() {
        if step < totalSteps - 1 {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                step += 1
            }
        } else {
            closeOnboarding()
        }
    }

    private func goBack() {
        guard step > 0 else { return }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
            step -= 1
        }
    }

    private func closeOnboarding() {
        NSApplication.shared.keyWindow?.close()
    }
}

// MARK: - Welcome mark

private struct WelcomeMark: View {
    var body: some View {
        Group {
            if let image = Self.appIcon {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.accentColor, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "face.smiling.fill")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: 86, height: 86)
        .shadow(color: Color.accentColor.opacity(0.40), radius: 22, y: 8)
    }

    private static var appIcon: NSImage? {
        let urls = [
            Bundle.main.url(forResource: "Flemo", withExtension: "icns"),
            Bundle.main.resourceURL?.appendingPathComponent("Flemo.icns"),
            Bundle.main.executableURL?
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources/Flemo.icns")
        ]
        return urls.compactMap { $0 }.compactMap { NSImage(contentsOf: $0) }.first
    }
}

// MARK: - Permission card

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
                            .fill(granted ? Color.green.opacity(0.14) : Color.accentColor)
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

// MARK: - Vibrancy material

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
