import AppKit
import Combine
import SwiftUI

struct OnboardingView: View {
    @StateObject private var permissions = AccessibilityPermissionManager.shared
    @ObservedObject private var appState = AppState.shared
    @State private var step = 0
    @State private var testInput = ""
    @State private var testEntries: [InlineSuggestionEntry] = []
    @State private var isAnimating = false
    @State private var selectedIndex = 0
    @FocusState private var tryInputFocused: Bool

    private let totalSteps = 3
    private let statusTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            OnboardingMaterialView()
            if step == 0 {
                ambientGlow
            }

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
            guard step == 1 else { return }
            permissions.refreshStatus()
        }
        .onChange(of: step) { _, newStep in
            if newStep == totalSteps - 1 {
                prepareTryItStep()
            }
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
        EmojiBurstView()
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
        VStack(spacing: 18) {
            VStack(spacing: 5) {
                Text("Try Flemo")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text("A tiny inline test before you start.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.70))
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text(appState.triggerCharacter)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.90))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.secondary.opacity(0.10))
                        )

                    TextField("cat, party, fire", text: $testInput)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .textFieldStyle(.plain)
                        .focused($tryInputFocused)
                        .onChange(of: testInput) { _, _ in
                            selectedIndex = 0
                            refreshTryResults()
                        }

                    if !testInput.isEmpty {
                        Button {
                            setTryInput("")
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.70))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.black.opacity(0.075))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(tryInputFocused ? Color.accentColor.opacity(0.30) : Color.white.opacity(0.08), lineWidth: 1)
                )

                HStack(spacing: 7) {
                    ForEach(tryExamples) { example in
                        TryExampleChip(example: example, trigger: appState.triggerCharacter) {
                            setTryInput(appState.triggerCharacter + example.keyword)
                            tryInputFocused = true
                        }
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 5) {
                        TryKeyCap("←")
                        TryKeyCap("→")
                        TryKeyCap("Return")
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.055))

                HStack(spacing: 14) {
                    InlineSuggestionPillView(
                        entries: testEntries,
                        selectedIndex: selectedIndex,
                        navigationActive: !testEntries.isEmpty,
                        layout: appState.inlineSuggestionLayout,
                        label: extractedLabel,
                        theme: appState.popupTheme,
                        baseHeight: 42,
                        emojiHandler: { emoji in
                            setTryInput(emoji.character)
                        }
                    )
                    .offset(x: -4)

                    Spacer(minLength: 0)

                    TryResultSummary(emoji: selectedTestEmoji, label: extractedLabel)
                }
                .frame(height: 58)
            }
            .padding(16)
            .frame(maxWidth: 500)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.085), lineWidth: 1)
            )
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
        keyword(from: testInput)
    }

    private func keyword(from input: String) -> String {
        guard let trigger = appState.triggerCharacter.first,
              let index = input.lastIndex(of: trigger)
        else { return "" }
        return String(input[input.index(after: index)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var extractedLabel: String {
        appState.triggerCharacter + extractedKeyword
    }

    private func makeTryEntries(for input: String) -> [InlineSuggestionEntry] {
        let keyword = keyword(from: input)
        let emojis: [Emoji]
        if keyword.count >= appState.minTriggerLength {
            emojis = EmojiSearchEngine.shared.search(
                keyword: keyword,
                maxResults: AppState.inlineVisibleCount,
                personSkinTone: appState.personSkinTone,
                manSkinTone: appState.manSkinTone,
                womanSkinTone: appState.womanSkinTone,
                gestureSkinTone: appState.gestureSkinTone
            )
        } else if appState.inlinePanelOpenMode == .recents {
            emojis = EmojiSearchEngine.shared.search(
                keyword: "",
                maxResults: AppState.inlineVisibleCount,
                personSkinTone: appState.personSkinTone,
                manSkinTone: appState.manSkinTone,
                womanSkinTone: appState.womanSkinTone,
                gestureSkinTone: appState.gestureSkinTone
            )
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

    private func refreshTryResults() {
        let nextEntries = makeTryEntries(for: testInput)
        testEntries = nextEntries
        selectedIndex = min(selectedIndex, max(nextEntries.count - 1, 0))
    }

    private var selectedTestEmoji: Emoji? {
        testEntries.first { $0.absoluteIndex == selectedIndex }?.item.emoji ?? testEntries.first?.item.emoji
    }

    private var tryExamples: [TryExample] {
        [
            TryExample(keyword: "cat", label: "cat"),
            TryExample(keyword: "party", label: "party"),
            TryExample(keyword: "fire", label: "fire")
        ]
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

    private func prepareTryItStep() {
        if testInput.isEmpty {
            setTryInput(appState.triggerCharacter + "cat")
        } else {
            refreshTryResults()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            tryInputFocused = true
        }
    }

    private func setTryInput(_ value: String) {
        testInput = value
        selectedIndex = 0
        testEntries = makeTryEntries(for: value)
    }

    private func closeOnboarding() {
        NSApplication.shared.keyWindow?.close()
    }
}

// MARK: - Try it out

private struct TryExample: Identifiable {
    let keyword: String
    let label: String

    var id: String { keyword }
}

private struct TryExampleChip: View {
    let example: TryExample
    let trigger: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(trigger + example.label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.78))

                Image(systemName: "arrow.up.left")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.58))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.09))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TryResultSummary: View {
    let emoji: Emoji?
    let label: String

    var body: some View {
        HStack(spacing: 9) {
            Text(emoji?.character ?? "–")
                .font(.system(size: 24))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(emoji?.name.capitalized ?? "No match")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.84))
                    .lineLimit(1)

                Text(label.isEmpty ? "recent" : label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.62))
                    .lineLimit(1)
            }
        }
        .frame(width: 162, alignment: .leading)
    }
}

private struct TryKeyCap: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundColor(.secondary.opacity(0.72))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

// MARK: - Emoji burst welcome

private struct EmojiBurstView: View {
    @State private var burstPhase = false
    @State private var floatPhase = false
    @State private var ringPhase = false
    @State private var textPhase = false
    @ObservedObject private var appState = AppState.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            VStack(spacing: 0) {
                ZStack {
                    BurstHalo(
                        expanded: burstPhase,
                        rotating: ringPhase,
                        reduceMotion: reduceMotion
                    )

                    ForEach(BurstParticle.all) { particle in
                        BurstEmoji(
                            particle: particle,
                            expanded: burstPhase,
                            floating: floatPhase,
                            reduceMotion: reduceMotion
                        )
                    }

                    WelcomeMark()
                        .scaleEffect(burstPhase ? 1 : 0.88)
                        .opacity(burstPhase ? 1 : 0)
                        .animation(
                            reduceMotion ? nil : .spring(response: 0.58, dampingFraction: 0.74),
                            value: burstPhase
                        )
                }
                .frame(width: w, height: min(max(h * 0.66, 286), 312))

                VStack(spacing: 11) {
                    VStack(spacing: 5) {
                        Text("Flemo")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("Emoji suggestions, right where you type.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.74))
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 8) {
                        Text(appState.triggerCharacter)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary.opacity(0.92))
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.black.opacity(0.18))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                            )

                        Text("type a word to summon emoji anywhere")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.68))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.secondary.opacity(0.10))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .opacity(textPhase ? 1 : 0)
                .offset(y: textPhase ? 0 : 8)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.42),
                    value: textPhase
                )

                Spacer(minLength: 0)
            }
            .frame(width: w)
        }
        .onAppear {
            if reduceMotion {
                burstPhase = true
                textPhase = true
                return
            }

            withAnimation(.spring(response: 0.58, dampingFraction: 0.74, blendDuration: 0.08)) {
                burstPhase = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                withAnimation(.easeOut(duration: 0.42)) {
                    textPhase = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
                withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                    floatPhase = true
                }

                withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                    ringPhase = true
                }
            }
        }
    }
}

private struct BurstEmoji: View {
    let particle: BurstParticle
    let expanded: Bool
    let floating: Bool
    let reduceMotion: Bool

    var body: some View {
        let drift = reduceMotion || !expanded
            ? CGSize.zero
            : (floating ? particle.drift : CGSize(width: -particle.drift.width, height: -particle.drift.height))
        let scale = expanded ? (floating ? particle.floatScale : 1.0) : 0.12

        Text(particle.character)
            .font(.system(size: particle.size))
            .scaleEffect(scale)
            .rotationEffect(.degrees(expanded ? particle.rotation + (floating ? particle.rotationDrift : -particle.rotationDrift) : 0))
            .offset(
                x: expanded ? particle.offset.width + drift.width : 0,
                y: expanded ? particle.offset.height + drift.height : 0
            )
            .opacity(expanded ? particle.opacity : 0)
            .blur(radius: expanded ? particle.blur : 7)
            .shadow(color: .black.opacity(particle.shadowOpacity), radius: particle.shadowRadius, y: particle.shadowY)
            .zIndex(particle.depth)
            .animation(
                reduceMotion ? nil : .spring(response: 0.64, dampingFraction: 0.72, blendDuration: 0.08).delay(particle.delay),
                value: expanded
            )
            .animation(
                reduceMotion ? nil : .easeInOut(duration: particle.floatDuration).repeatForever(autoreverses: true).delay(particle.delay),
                value: floating
            )
            .accessibilityHidden(true)
    }
}

private struct BurstHalo: View {
    let expanded: Bool
    let rotating: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.accentColor.opacity(0.26),
                            Color.cyan.opacity(0.11),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: 170
                    )
                )
                .frame(width: 340, height: 340)
                .scaleEffect(expanded ? 1 : 0.54)
                .opacity(expanded ? 1 : 0)

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.22),
                            Color.cyan.opacity(0.22),
                            Color.accentColor.opacity(0.26),
                            Color.white.opacity(0.0)
                        ],
                        center: .center
                    ),
                    lineWidth: 1
                )
                .frame(width: 176, height: 176)
                .rotationEffect(.degrees(rotating ? 360 : 0))
                .opacity(expanded ? 0.92 : 0)

            Circle()
                .stroke(
                    Color.white.opacity(0.11),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 9], dashPhase: rotating ? 18 : 0)
                )
                .frame(width: 246, height: 246)
                .rotationEffect(.degrees(rotating ? -360 : 0))
                .opacity(expanded ? 0.62 : 0)

            ForEach(BurstSpark.all) { spark in
                Circle()
                    .fill(spark.color)
                    .frame(width: spark.size, height: spark.size)
                    .offset(
                        x: expanded ? spark.offset.width : 0,
                        y: expanded ? spark.offset.height : 0
                    )
                    .opacity(expanded ? spark.opacity : 0)
                    .blur(radius: spark.blur)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.62, dampingFraction: 0.78).delay(spark.delay),
                        value: expanded
                    )
            }
        }
        .scaleEffect(expanded ? 1 : 0.82)
        .animation(
            reduceMotion ? nil : .spring(response: 0.66, dampingFraction: 0.78),
            value: expanded
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct BurstParticle: Identifiable {
    let id: Int
    let character: String
    let offset: CGSize
    let drift: CGSize
    let size: CGFloat
    let rotation: Double
    let rotationDrift: Double
    let delay: Double
    let opacity: Double
    let blur: CGFloat
    let depth: Double
    let floatScale: CGFloat
    let floatDuration: Double

    var shadowOpacity: Double {
        depth > 1 ? 0.24 : 0.14
    }

    var shadowRadius: CGFloat {
        depth > 1 ? 11 : 7
    }

    var shadowY: CGFloat {
        depth > 1 ? 6 : 3
    }

    static let all: [BurstParticle] = [
        BurstParticle(id: 0, character: "✨", offset: CGSize(width: -126, height: -84), drift: CGSize(width: -4, height: 5), size: 24, rotation: -18, rotationDrift: 5, delay: 0.02, opacity: 0.90, blur: 0, depth: 2, floatScale: 1.04, floatDuration: 3.0),
        BurstParticle(id: 1, character: "😀", offset: CGSize(width: -76, height: -110), drift: CGSize(width: 3, height: -4), size: 28, rotation: -9, rotationDrift: -3, delay: 0.06, opacity: 0.94, blur: 0, depth: 3, floatScale: 1.03, floatDuration: 3.4),
        BurstParticle(id: 2, character: "💬", offset: CGSize(width: 8, height: -124), drift: CGSize(width: -2, height: 5), size: 25, rotation: 8, rotationDrift: 4, delay: 0.10, opacity: 0.88, blur: 0, depth: 2, floatScale: 1.05, floatDuration: 3.2),
        BurstParticle(id: 3, character: "😍", offset: CGSize(width: 84, height: -104), drift: CGSize(width: 4, height: -3), size: 28, rotation: 14, rotationDrift: -4, delay: 0.14, opacity: 0.94, blur: 0, depth: 3, floatScale: 1.03, floatDuration: 3.5),
        BurstParticle(id: 4, character: "⚡️", offset: CGSize(width: 134, height: -56), drift: CGSize(width: -3, height: 4), size: 24, rotation: 18, rotationDrift: 5, delay: 0.18, opacity: 0.88, blur: 0, depth: 2, floatScale: 1.05, floatDuration: 2.9),
        BurstParticle(id: 5, character: "🚀", offset: CGSize(width: 116, height: 28), drift: CGSize(width: 4, height: 3), size: 28, rotation: -10, rotationDrift: -5, delay: 0.22, opacity: 0.93, blur: 0, depth: 3, floatScale: 1.04, floatDuration: 3.1),
        BurstParticle(id: 6, character: "🔥", offset: CGSize(width: 58, height: 88), drift: CGSize(width: -2, height: 5), size: 26, rotation: 15, rotationDrift: 4, delay: 0.26, opacity: 0.90, blur: 0, depth: 2, floatScale: 1.05, floatDuration: 3.3),
        BurstParticle(id: 7, character: "✅", offset: CGSize(width: -22, height: 102), drift: CGSize(width: 3, height: -3), size: 25, rotation: -7, rotationDrift: -4, delay: 0.30, opacity: 0.88, blur: 0, depth: 2, floatScale: 1.04, floatDuration: 3.6),
        BurstParticle(id: 8, character: "🙌", offset: CGSize(width: -94, height: 72), drift: CGSize(width: -4, height: 3), size: 26, rotation: -15, rotationDrift: 5, delay: 0.34, opacity: 0.90, blur: 0, depth: 2, floatScale: 1.03, floatDuration: 3.0),
        BurstParticle(id: 9, character: "⭐️", offset: CGSize(width: -138, height: 12), drift: CGSize(width: 3, height: 5), size: 25, rotation: 11, rotationDrift: -3, delay: 0.38, opacity: 0.84, blur: 0, depth: 1, floatScale: 1.05, floatDuration: 3.4),
        BurstParticle(id: 10, character: "💡", offset: CGSize(width: -48, height: -58), drift: CGSize(width: 2, height: 3), size: 20, rotation: 9, rotationDrift: 3, delay: 0.18, opacity: 0.62, blur: 0.35, depth: 1, floatScale: 1.03, floatDuration: 3.7),
        BurstParticle(id: 11, character: "😎", offset: CGSize(width: 54, height: -46), drift: CGSize(width: -3, height: -2), size: 21, rotation: -8, rotationDrift: -3, delay: 0.22, opacity: 0.66, blur: 0.35, depth: 1, floatScale: 1.04, floatDuration: 3.2)
    ]
}

private struct BurstSpark: Identifiable {
    let id: Int
    let offset: CGSize
    let size: CGFloat
    let color: Color
    let opacity: Double
    let blur: CGFloat
    let delay: Double

    static let all: [BurstSpark] = [
        BurstSpark(id: 0, offset: CGSize(width: -104, height: -20), size: 5, color: Color.white.opacity(0.76), opacity: 0.62, blur: 0.4, delay: 0.12),
        BurstSpark(id: 1, offset: CGSize(width: -36, height: -138), size: 4, color: Color.cyan.opacity(0.72), opacity: 0.56, blur: 0.4, delay: 0.20),
        BurstSpark(id: 2, offset: CGSize(width: 98, height: -82), size: 5, color: Color.accentColor.opacity(0.72), opacity: 0.56, blur: 0.5, delay: 0.26),
        BurstSpark(id: 3, offset: CGSize(width: 152, height: 8), size: 4, color: Color.white.opacity(0.66), opacity: 0.48, blur: 0.4, delay: 0.30),
        BurstSpark(id: 4, offset: CGSize(width: 24, height: 130), size: 5, color: Color.cyan.opacity(0.62), opacity: 0.50, blur: 0.5, delay: 0.34),
        BurstSpark(id: 5, offset: CGSize(width: -138, height: 64), size: 4, color: Color.accentColor.opacity(0.62), opacity: 0.48, blur: 0.4, delay: 0.38)
    ]
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
        .frame(width: 92, height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.48),
                            Color.white.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.24), radius: 18, y: 10)
        .shadow(color: Color.accentColor.opacity(0.30), radius: 26, y: 8)
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
