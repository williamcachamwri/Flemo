import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var selectedTab = 0

    private struct TabItem {
        let icon: String
        let title: String
    }

    private let tabs: [TabItem] = [
        TabItem(icon: "gearshape", title: "General"),
        TabItem(icon: "face.smiling", title: "Emojis"),
        TabItem(icon: "keyboard", title: "Keybinds"),
        TabItem(icon: "hand.raised", title: "Rules"),
        TabItem(icon: "chart.bar.xaxis", title: "Stats"),
        TabItem(icon: "info.circle", title: "About")
    ]

    var body: some View {
        ZStack {
            VisualEffectMaterialView()
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.06)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            HStack(spacing: 0) {
                sidebar

                Divider()
                    .background(Color.white.opacity(0.06))

                content
            }
        }
        .frame(width: 720, height: 520)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                AppLogoImage(size: 22)
                Text("Flemo")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.bottom, 8)

            VStack(spacing: 2) {
                ForEach(tabs.indices, id: \.self) { idx in
                    SidebarNavItem(
                        icon: tabs[idx].icon,
                        title: tabs[idx].title,
                        isSelected: selectedTab == idx
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                            selectedTab = idx
                        }
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .frame(width: 172)
        .background(Color.secondary.opacity(0.04))
    }

    private var content: some View {
        VStack(spacing: 0) {
            HStack {
                Text(tabs[selectedTab].title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                Button {
                    NSApplication.shared.keyWindow?.close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.secondary.opacity(0.10))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()
                .background(Color.white.opacity(0.06))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    switch selectedTab {
                    case 0: GeneralSettingsPane()
                    case 1: EmojiSettingsPane()
                    case 2: KeybindsSettingsPane()
                    case 3: RulesSettingsPane()
                    case 4: StatsSettingsPane()
                    case 5: AboutSettingsPane()
                    default: EmptyView()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
    }
}

private struct GeneralSettingsPane: View {
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared
    @ObservedObject private var permissions = AccessibilityPermissionManager.shared

    var body: some View {
        VStack(spacing: 0) {
            ToggleRow(
                icon: "power",
                title: "Launch at Login",
                subtitle: "Start automatically when logging in",
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                )
            )

            Divider().background(Color.white.opacity(0.06))

            StatusRow(
                icon: "lock.shield",
                title: "Accessibility",
                subtitle: "Read focused text bounds and cursor position",
                isGranted: permissions.accessibilityGranted
            )

            StatusRow(
                icon: "keyboard.badge.eye",
                title: "Input Monitoring",
                subtitle: "Detect trigger text and arrow navigation",
                isGranted: permissions.inputMonitoringGranted
            )

            ActionRow(
                icon: "gearshape.2",
                title: "Permissions Guide",
                subtitle: "Open the macOS permission helper",
                label: "Open"
            ) {
                permissions.showPermissionGuide()
            }

            Divider().background(Color.white.opacity(0.06))

            ActionRow(
                icon: "face.smiling",
                title: "Searchable Keywords",
                subtitle: "Open the emoji board and keyword search",
                label: "Customize"
            ) {
                (NSApplication.shared.delegate as? AppDelegate)?.toggleEmojiBoard()
            }
        }
        .onAppear {
            launchAtLogin.refresh()
            permissions.refreshStatus()
        }
    }
}

private struct EmojiSettingsPane: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsGroup {
                PlainToggleRow(title: "Emojis", isOn: $appState.inlineTriggerEnabled)

                SettingsDivider()

                SettingsMenuRow(
                    title: "Inline panel opens with",
                    selection: $appState.inlinePanelOpenMode,
                    options: InlinePanelOpenMode.allCases
                )
            }

            SettingsSectionTitle("Appearance")

            SettingsGroup {
                SkinTonePreferencePicker(selection: $appState.preferredSkinTone)
                    .padding(14)
            }

            SettingsSectionTitle("Inline Suggestions")

            SettingsGroup {
                InlineSuggestionSettingsPreview()
                .padding(12)

                SettingsDivider()

                SettingsMenuRow(
                    title: "Layout",
                    selection: $appState.inlineSuggestionLayout,
                    options: InlineSuggestionLayout.allCases
                )

                SettingsDivider()

                SettingsMenuRow(
                    title: "Popup Theme",
                    selection: $appState.popupTheme,
                    options: PopupTheme.allCases
                )
            }

            SettingsGroup {
                ValueRow(icon: "quote.opening", title: "Trigger Character", subtitle: "The prefix before a keyword") {
                    TextField("", text: triggerBinding)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 46)
                }

                SettingsDivider()

                StepperRow(
                    icon: "textformat.123",
                    title: "Minimum Keyword",
                    subtitle: "Required before search starts",
                    value: $appState.minTriggerLength,
                    range: 1...5
                )

            }
        }
    }

    private var triggerBinding: Binding<String> {
        Binding(
            get: { appState.triggerCharacter },
            set: { value in
                let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
                appState.triggerCharacter = cleaned.isEmpty
                    ? Constants.defaultTriggerCharacter
                    : String(cleaned.prefix(1))
            }
        )
    }
}

private struct SettingsSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(.primary.opacity(0.92))
            .padding(.top, 2)
            .padding(.leading, 2)
    }
}

private struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .background(Color.white.opacity(0.08))
    }
}

private struct PlainToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .labelsHidden()
                .controlSize(.small)
        }
        .settingsCardRowPadding()
    }
}

private struct SettingsMenuRow<Option: Hashable & RawRepresentable>: View where Option.RawValue == String {
    let title: String
    @Binding var selection: Option
    let options: [Option]

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option.rawValue) {
                        selection = option
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Text(selection.rawValue)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.primary.opacity(0.92))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                )
            }
            .buttonStyle(.plain)
        }
        .settingsCardRowPadding()
    }
}

private struct InlineSuggestionSettingsPreview: View {
    @ObservedObject private var appState = AppState.shared

    private let previewKeyword = "cat"

    private var previewEmojis: [Emoji] {
        EmojiSearchEngine.shared.search(keyword: previewKeyword, maxResults: AppState.inlineVisibleCount)
    }

    private var previewEntries: [InlineSuggestionEntry] {
        previewEmojis.enumerated().map { offset, emoji in
            InlineSuggestionEntry(
                absoluteIndex: offset,
                item: SuggestionItem(emoji: emoji)
            )
        }
    }

    var body: some View {
        ZStack {
            previewBackground

            InlineSuggestionPillView(
                entries: previewEntries,
                selectedIndex: 0,
                layout: appState.inlineSuggestionLayout,
                label: appState.triggerCharacter + previewKeyword,
                theme: appState.popupTheme,
                baseHeight: 54,
                emojiHandler: { _ in }
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.spring(response: 0.34, dampingFraction: 0.84, blendDuration: 0.08), value: appState.inlineSuggestionLayout)
        .animation(.easeInOut(duration: 0.18), value: appState.popupTheme)
    }

    private var previewBackground: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.31, green: 0.13, blue: 0.95),
                        Color(red: 0.03, green: 0.27, blue: 0.88),
                        Color(red: 0.02, green: 0.06, blue: 0.24)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Ellipse()
                    .fill(Color.white.opacity(0.20))
                    .frame(width: proxy.size.width * 0.9, height: proxy.size.height * 0.38)
                    .rotationEffect(.degrees(-22))
                    .blur(radius: 8)
                    .offset(x: proxy.size.width * 0.12, y: -proxy.size.height * 0.08)

                Ellipse()
                    .fill(Color.black.opacity(0.20))
                    .frame(width: proxy.size.width * 1.1, height: proxy.size.height * 0.36)
                    .rotationEffect(.degrees(-16))
                    .blur(radius: 7)
                    .offset(x: -proxy.size.width * 0.12, y: proxy.size.height * 0.22)
            }
        }
    }
}

private enum SkinTonePreviewCharacter: String, CaseIterable, Identifiable {
    case person
    case man
    case woman

    var id: String { rawValue }

    var baseEmoji: String {
        switch self {
        case .person: return "🧑"
        case .man: return "👨"
        case .woman: return "👩"
        }
    }

    var title: String {
        switch self {
        case .person: return "Person"
        case .man: return "Man"
        case .woman: return "Woman"
        }
    }
}

private struct SkinTonePreferencePicker: View {
    @Binding var selection: EmojiSkinTone
    @Namespace private var swatchNamespace
    @State private var focusedCharacter: SkinTonePreviewCharacter = .person

    private var focusedEmoji: String {
        selection.applied(to: focusedCharacter.baseEmoji)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    SkinTonePreviewGrid()

                    Text(focusedEmoji)
                        .font(.system(size: 112))
                        .minimumScaleFactor(0.72)
                        .shadow(color: .black.opacity(0.26), radius: 16, y: 10)
                        .id(selection.id + focusedCharacter.id)
                        .transition(.softBlurSwap)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 154)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(spacing: 9) {
                    ForEach(SkinTonePreviewCharacter.allCases) { character in
                        SkinToneCharacterButton(
                            character: character,
                            skinTone: selection,
                            isSelected: focusedCharacter == character
                        ) {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.78, blendDuration: 0.10)) {
                                focusedCharacter = character
                            }
                        }
                    }
                }
                .frame(width: 52)
            }

            HStack(spacing: 10) {
                ForEach(EmojiSkinTone.allCases) { tone in
                    SkinToneSwatchButton(
                        tone: tone,
                        isSelected: selection == tone,
                        namespace: swatchNamespace
                    ) {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.76, blendDuration: 0.10)) {
                            selection = tone
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.78, blendDuration: 0.10), value: selection)
        .animation(.spring(response: 0.34, dampingFraction: 0.78, blendDuration: 0.10), value: focusedCharacter)
    }
}

private struct SkinToneCharacterButton: View {
    let character: SkinTonePreviewCharacter
    let skinTone: EmojiSkinTone
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(skinTone.applied(to: character.baseEmoji))
                .font(.system(size: isSelected ? 31 : 24))
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isSelected ? 0.12 : 0.04))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isSelected ? 0.28 : 0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(isSelected ? 0.22 : 0.0), radius: 8, y: 4)
                .id(skinTone.id + character.id)
                .transition(.softBlurSwap)
        }
        .buttonStyle(.plain)
        .help(character.title)
    }
}

private struct SkinToneSwatchButton: View {
    let tone: EmojiSkinTone
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tone.swatchFill)
                .frame(width: 42, height: 26)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.92), lineWidth: 2)
                            .matchedGeometryEffect(id: "selectedSkinTone", in: namespace)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.black.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(isSelected ? 0.30 : 0.08), radius: isSelected ? 12 : 4, y: isSelected ? 7 : 2)
                .scaleEffect(isSelected ? 1.08 : 1.0)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tone.rawValue)
    }
}

private struct SkinTonePreviewGrid: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.035),
                        Color.black.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Path { path in
                    for fraction in [0.25, 0.5, 0.75] {
                        let x = size.width * fraction
                        path.move(to: CGPoint(x: x, y: 8))
                        path.addLine(to: CGPoint(x: x, y: size.height - 8))
                    }

                    for fraction in [0.30, 0.70] {
                        let y = size.height * fraction
                        path.move(to: CGPoint(x: 14, y: y))
                        path.addLine(to: CGPoint(x: size.width - 14, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.08), lineWidth: 1)

                Path { path in
                    let y = size.height * 0.56
                    path.move(to: CGPoint(x: 24, y: y))
                    path.addLine(to: CGPoint(x: size.width - 24, y: y))
                }
                .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [2, 7]))
            }
        }
    }
}

private extension EmojiSkinTone {
    var swatchFill: LinearGradient {
        LinearGradient(
            colors: swatchColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var swatchColors: [Color] {
        switch self {
        case .standard:
            return [
                Color(red: 1.00, green: 0.80, blue: 0.24),
                Color(red: 0.94, green: 0.64, blue: 0.10)
            ]
        case .light:
            return [
                Color(red: 1.00, green: 0.83, blue: 0.62),
                Color(red: 0.92, green: 0.66, blue: 0.41)
            ]
        case .mediumLight:
            return [
                Color(red: 0.86, green: 0.58, blue: 0.34),
                Color(red: 0.72, green: 0.43, blue: 0.22)
            ]
        case .medium:
            return [
                Color(red: 0.66, green: 0.40, blue: 0.23),
                Color(red: 0.50, green: 0.28, blue: 0.14)
            ]
        case .mediumDark:
            return [
                Color(red: 0.43, green: 0.25, blue: 0.15),
                Color(red: 0.30, green: 0.16, blue: 0.09)
            ]
        case .dark:
            return [
                Color(red: 0.28, green: 0.18, blue: 0.13),
                Color(red: 0.17, green: 0.10, blue: 0.07)
            ]
        }
    }
}

private struct BlurSwapTransitionModifier: ViewModifier {
    let blurRadius: CGFloat
    let scale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .blur(radius: blurRadius)
            .scaleEffect(scale)
            .opacity(opacity)
    }
}

private extension AnyTransition {
    static var softBlurSwap: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: BlurSwapTransitionModifier(blurRadius: 10, scale: 0.88, opacity: 0),
                identity: BlurSwapTransitionModifier(blurRadius: 0, scale: 1, opacity: 1)
            ),
            removal: .modifier(
                active: BlurSwapTransitionModifier(blurRadius: 12, scale: 1.08, opacity: 0),
                identity: BlurSwapTransitionModifier(blurRadius: 0, scale: 1, opacity: 1)
            )
        )
    }
}

private struct KeybindsSettingsPane: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        VStack(spacing: 0) {
            ShortcutRow(icon: "return", title: "Insert Selected Emoji", shortcut: "Tab")
            ShortcutRow(icon: "arrow.left.arrow.right", title: "Move Selection", shortcut: "← / →")
            ShortcutRow(icon: "escape", title: "Dismiss Suggestions", shortcut: "Esc")

            Divider().background(Color.white.opacity(0.06))

            ShortcutRow(icon: "face.smiling", title: "Emoji Board", shortcut: "⌘E")
        }
    }
}

private struct RulesSettingsPane: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            RuleSectionTitle("Ignored Sites")
            RuleListBox {
                if appState.ignoredSiteRules.isEmpty {
                    RuleEmptyText("No ignored sites yet.")
                } else {
                    ForEach(appState.ignoredSiteRules) { rule in
                        RuleRow(icon: "network", title: rule.domain, subtitle: "Domain and subdomains") {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                appState.removeIgnoredSite(rule)
                            }
                        }
                    }
                }
            }
            HStack {
                Spacer()
                RuleActionButton(title: "Add Site...", icon: "plus") {
                    addSite()
                }
            }

            RuleSectionTitle("Ignored Apps")
            RuleListBox {
                if appState.ignoredAppRules.isEmpty {
                    RuleEmptyText("No ignored apps yet.")
                } else {
                    ForEach(appState.ignoredAppRules) { rule in
                        RuleRow(icon: "app.dashed", title: rule.name, subtitle: rule.bundleIdentifier) {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                appState.removeIgnoredApp(rule)
                            }
                        }
                    }
                }
            }
            HStack {
                Spacer()
                RuleActionButton(title: "Add App...", icon: "plus") {
                    addApp()
                }
            }
        }
    }

    private func addSite() {
        let alert = NSAlert()
        alert.messageText = "Add Ignored Site"
        alert.informativeText = "Enter a domain such as facebook.com. Flemo will stay quiet on that site and its subdomains."
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "example.com"
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            appState.addIgnoredSite(field.stringValue)
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose App to Ignore"
        panel.prompt = "Add App"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK,
              let url = panel.url,
              let rule = RulesManager.shared.appRule(from: url)
        else { return }

        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            appState.addIgnoredApp(rule)
        }
    }
}

private struct RuleSectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(.primary.opacity(0.92))
            .padding(.leading, 14)
    }
}

private struct RuleListBox<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct RuleEmptyText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(.secondary.opacity(0.72))
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RuleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(name: icon)
            RowText(title: title, subtitle: subtitle)
            Spacer()
            Button(action: remove) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.80))
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
        }
        .settingsRowPadding()
    }
}

private struct RuleActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundColor(.primary.opacity(0.9))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct StatsSettingsPane: View {
    @State private var snapshot = FrequencyTracker.shared.statsSnapshot(limit: 6)

    var body: some View {
        VStack(spacing: 0) {
            MetricRow(icon: "sum", title: "Total Emoji Inserts", value: "\(snapshot.totalUsage)")
            MetricRow(icon: "number.square", title: "Tracked Emojis", value: "\(snapshot.trackedEmojiCount)")

            Divider().background(Color.white.opacity(0.06))

            if snapshot.topEmoji.isEmpty {
                ValueRow(icon: "chart.bar.xaxis", title: "Favorites", subtitle: "No usage yet") {
                    Text("0")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            } else {
                ForEach(snapshot.topEmoji) { stat in
                    EmojiUsageRow(stat: stat)
                }
            }

            Divider().background(Color.white.opacity(0.06))

            ActionRow(icon: "arrow.clockwise", title: "Refresh Stats", subtitle: "Reload local usage data", label: "Refresh") {
                snapshot = FrequencyTracker.shared.statsSnapshot(limit: 6)
            }
        }
        .onAppear {
            snapshot = FrequencyTracker.shared.statsSnapshot(limit: 6)
        }
    }
}

private struct AboutSettingsPane: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                AppLogoImage(size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Flemo")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Inline emoji picker for macOS")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)

            Divider().background(Color.white.opacity(0.06))

            MetricRow(icon: "tag", title: "Version", value: versionString)
            MetricRow(icon: "face.smiling", title: "Emoji Library", value: "\(EmojiDataLoader.shared.allEmojis.count)")
            MetricRow(icon: "shippingbox", title: "Bundle", value: bundleIdentifier)

            Button {
                if let url = URL(string: "https://github.com/williamcachamwri/Flemo") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                ValueRow(icon: "chevron.left.forwardslash.chevron.right", title: "GitHub", subtitle: "") {
                    HStack(spacing: 4) {
                        Text("williamcachamwri/Flemo")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.7))
                            .lineLimit(1)
                        Image(systemName: "arrow.up.right.square.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "Development"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.flemo.app"
    }
}

private struct SidebarNavItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : .primary.opacity(0.85))

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.secondary.opacity(isHovered ? 0.10 : 0.0)))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

private struct ToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(name: icon)
            RowText(title: title, subtitle: subtitle)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .labelsHidden()
                .controlSize(.small)
        }
        .settingsRowPadding()
    }
}

private struct StatusRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isGranted: Bool

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(name: icon)
            RowText(title: title, subtitle: subtitle)
            Spacer()
            Text(isGranted ? "Granted" : "Missing")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(isGranted ? .green : .orange)
        }
        .settingsRowPadding()
    }
}

private struct ValueRow<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(name: icon)
            RowText(title: title, subtitle: subtitle)
            Spacer()
            content
        }
        .settingsRowPadding()
    }
}

private struct ActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let label: String
    let action: () -> Void

    var body: some View {
        ValueRow(icon: icon, title: title, subtitle: subtitle) {
            Button(action: action) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.secondary.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct StepperRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        ValueRow(icon: icon, title: title, subtitle: subtitle) {
            Stepper(value: $value, in: range) {
                Text("\(value)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 24, alignment: .trailing)
            }
            .frame(width: 84)
        }
    }
}

private struct ShortcutRow: View {
    let icon: String
    let title: String
    let shortcut: String

    var body: some View {
        ValueRow(icon: icon, title: title, subtitle: "Available while suggestions are visible") {
            Text(shortcut)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
        }
    }
}

private struct MetricRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        ValueRow(icon: icon, title: title, subtitle: "") {
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.7))
                .lineLimit(1)
        }
    }
}

private struct EmojiUsageRow: View {
    let stat: EmojiUsageStat

    var body: some View {
        HStack(spacing: 12) {
            Text(stat.emoji.character)
                .font(.system(size: 22))
                .frame(width: 28)

            Text(displayName(for: stat.emoji))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.94))
                .lineLimit(1)

            Spacer()

            Text("\(stat.count)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(emojiGradient(for: stat.emoji))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func displayName(for emoji: Emoji) -> String {
        emoji.name
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private func emojiGradient(for emoji: Emoji) -> LinearGradient {
        let colors = emojiColors(for: emoji)
        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func emojiColors(for emoji: Emoji) -> [Color] {
        let haystack = ([emoji.name, emoji.category] + emoji.keywords)
            .joined(separator: " ")
            .lowercased()

        if haystack.contains("dog") || haystack.contains("cat") || haystack.contains("animal") {
            return [
                Color(red: 0.42, green: 0.25, blue: 0.12),
                Color(red: 0.29, green: 0.18, blue: 0.10)
            ]
        }

        if haystack.contains("heart") || haystack.contains("love") {
            return [
                Color(red: 0.55, green: 0.12, blue: 0.30),
                Color(red: 0.32, green: 0.10, blue: 0.28)
            ]
        }

        if haystack.contains("fire") || haystack.contains("hot") {
            return [
                Color(red: 0.66, green: 0.22, blue: 0.09),
                Color(red: 0.42, green: 0.12, blue: 0.08)
            ]
        }

        if haystack.contains("face") || haystack.contains("smile") || haystack.contains("joy") {
            return [
                Color(red: 0.68, green: 0.43, blue: 0.09),
                Color(red: 0.42, green: 0.25, blue: 0.08)
            ]
        }

        if haystack.contains("plant") || haystack.contains("tree") || haystack.contains("leaf") {
            return [
                Color(red: 0.12, green: 0.43, blue: 0.24),
                Color(red: 0.08, green: 0.26, blue: 0.18)
            ]
        }

        if haystack.contains("water") || haystack.contains("blue") || haystack.contains("sky") {
            return [
                Color(red: 0.10, green: 0.36, blue: 0.60),
                Color(red: 0.06, green: 0.20, blue: 0.38)
            ]
        }

        if haystack.contains("food") || haystack.contains("drink") {
            return [
                Color(red: 0.55, green: 0.28, blue: 0.10),
                Color(red: 0.32, green: 0.16, blue: 0.08)
            ]
        }

        if haystack.contains("symbol") || haystack.contains("star") || haystack.contains("spark") {
            return [
                Color(red: 0.34, green: 0.16, blue: 0.56),
                Color(red: 0.16, green: 0.16, blue: 0.42)
            ]
        }

        return [
            Color(red: 0.30, green: 0.30, blue: 0.36),
            Color(red: 0.18, green: 0.18, blue: 0.23)
        ]
    }
}

private struct SettingsIcon: View {
    let name: String

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.secondary.opacity(0.7))
            .frame(width: 20)
    }
}

private struct RowText: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.6))
                    .lineLimit(1)
            }
        }
    }
}

private struct AppLogoImage: View {
    let size: CGFloat

    var body: some View {
        if let image = Self.iconImage {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
        } else {
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

    private static var iconImage: NSImage? {
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

private struct VisualEffectMaterialView: NSViewRepresentable {
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

private extension View {
    func settingsRowPadding() -> some View {
        padding(.vertical, 12)
            .padding(.horizontal, 14)
    }

    func settingsCardRowPadding() -> some View {
        padding(.vertical, 12)
            .padding(.horizontal, 14)
    }
}
