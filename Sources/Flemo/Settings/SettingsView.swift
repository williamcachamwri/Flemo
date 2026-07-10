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

    private var allPermissionsGranted: Bool {
        permissions.accessibilityGranted
            && permissions.inputMonitoringGranted
            && permissions.automationGranted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsStatusPanel(
                icon: "bolt.horizontal.circle.fill",
                title: allPermissionsGranted ? "Ready" : "Needs access",
                subtitle: allPermissionsGranted
                    ? "Flemo can watch for triggers and place emoji inline."
                    : "Grant the missing macOS permissions to enable inline suggestions.",
                status: allPermissionsGranted ? "Online" : "Action needed",
                statusColor: allPermissionsGranted ? .green : .orange
            )

            HStack(spacing: 10) {
                PermissionStatusTile(
                    icon: "lock.shield",
                    title: "Accessibility",
                    detail: "Cursor and focused text",
                    granted: permissions.accessibilityGranted
                ) {
                    permissions.requestAccessibility()
                }

                PermissionStatusTile(
                    icon: "keyboard.badge.eye",
                    title: "Input Monitor",
                    detail: "Trigger and navigation keys",
                    granted: permissions.inputMonitoringGranted
                ) {
                    permissions.requestInputMonitoring()
                }

                PermissionStatusTile(
                    icon: "applescript",
                    title: "Automation",
                    detail: "Browser URLs for rules",
                    granted: permissions.automationGranted
                ) {
                    permissions.requestAutomation()
                }
            }

            SettingsPanel(title: "System", subtitle: "Startup and management") {
                SettingControlRow(icon: "power", title: "Launch at Login", subtitle: "Start Flemo when macOS signs in") {
                    Toggle("", isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .labelsHidden()
                    .controlSize(.small)
                }

                SettingsDivider()

                SettingControlRow(icon: "gearshape.2", title: "Permissions Guide", subtitle: "Open the macOS helper") {
                    SmallActionButton(title: "Open", icon: "arrow.up.right") {
                        permissions.showPermissionGuide()
                    }
                }

                SettingsDivider()

                SettingControlRow(icon: "face.smiling", title: "Emoji Board", subtitle: "Manage searchable keywords") {
                    SmallActionButton(title: "Open", icon: "arrow.up.right") {
                        (NSApplication.shared.delegate as? AppDelegate)?.toggleEmojiBoard()
                    }
                }
            }
        }
        .onAppear {
            launchAtLogin.refresh()
            permissions.refreshStatus()
        }
    }
}

private struct SettingsStatusPanel: View {
    let icon: String
    let title: String
    let subtitle: String
    let status: String
    let statusColor: Color

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                statusColor.opacity(0.24),
                                Color.cyan.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: icon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(statusColor)
            }
            .frame(width: 46, height: 46)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.13), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.94))

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.68))
                    .lineLimit(2)
            }

            Spacer()

            StatusPill(title: status, color: statusColor)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct PermissionStatusTile: View {
    let icon: String
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(granted ? .green : .orange)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.secondary.opacity(0.10))
                    )

                Spacer()

                Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(granted ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.92))
                    .lineLimit(1)

                Text(detail)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.62))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if granted {
                Text("Granted")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule(style: .continuous).fill(Color.green.opacity(0.12)))
            } else {
                Button(action: action) {
                    Label("Grant", systemImage: "arrow.up.right")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule(style: .continuous).fill(Color.accentColor))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(granted ? 0.12 : 0.18), lineWidth: 1)
        )
    }
}

private struct StatusPill: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(color.opacity(0.12)))
    }
}

private struct SettingsPanel<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.92))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.62))
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            SettingsDivider()

            content
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct SettingControlRow<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.74))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )

            RowText(title: title, subtitle: subtitle)

            Spacer()

            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

private struct SmallActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.primary.opacity(0.88))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
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
                SkinTonePreferencePicker(
                    personTone: $appState.personSkinTone,
                    manTone: $appState.manSkinTone,
                    womanTone: $appState.womanSkinTone
                )
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

    @Namespace static var personNS
    @Namespace static var manNS
    @Namespace static var womanNS

    var swatchNamespace: Namespace.ID {
        switch self {
        case .person: return SkinTonePreviewCharacter.personNS
        case .man: return SkinTonePreviewCharacter.manNS
        case .woman: return SkinTonePreviewCharacter.womanNS
        }
    }
}

private struct SkinTonePreferencePicker: View {
    @Binding var personTone: EmojiSkinTone
    @Binding var manTone: EmojiSkinTone
    @Binding var womanTone: EmojiSkinTone
    @State private var focusedCharacter: SkinTonePreviewCharacter = .person

    private var focusedToneBinding: Binding<EmojiSkinTone> {
        switch focusedCharacter {
        case .person: return $personTone
        case .man: return $manTone
        case .woman: return $womanTone
        }
    }

    private var focusedEmoji: String {
        focusedToneBinding.wrappedValue.applied(to: focusedCharacter.baseEmoji)
    }

    private func tone(for character: SkinTonePreviewCharacter) -> EmojiSkinTone {
        switch character {
        case .person: return personTone
        case .man: return manTone
        case .woman: return womanTone
        }
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
                        .id(focusedToneBinding.wrappedValue.id + focusedCharacter.id)
                        .transition(.softBlurSwap)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 154)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(spacing: 9) {
                    ForEach(SkinTonePreviewCharacter.allCases) { character in
                        SkinToneCharacterButton(
                            character: character,
                            skinTone: tone(for: character),
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

            Text(focusedCharacter.title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                ForEach(EmojiSkinTone.allCases) { tone in
                    SkinToneSwatchButton(
                        tone: tone,
                        isSelected: focusedToneBinding.wrappedValue == tone,
                        namespace: focusedCharacter.swatchNamespace
                    ) {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.76, blendDuration: 0.10)) {
                            focusedToneBinding.wrappedValue = tone
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.78, blendDuration: 0.10), value: focusedCharacter)
        .animation(.spring(response: 0.36, dampingFraction: 0.78, blendDuration: 0.10), value: personTone)
        .animation(.spring(response: 0.36, dampingFraction: 0.78, blendDuration: 0.10), value: manTone)
        .animation(.spring(response: 0.36, dampingFraction: 0.78, blendDuration: 0.10), value: womanTone)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ShortcutHeroPanel()

            HStack(spacing: 10) {
                ShortcutFeatureTile(
                    icon: "face.smiling",
                    title: "Quick Board",
                    subtitle: "Open near cursor",
                    keys: ["⇧", "⌘", "E"]
                )

                ShortcutFeatureTile(
                    icon: "return",
                    title: "Insert",
                    subtitle: "Use selected emoji",
                    keys: ["Tab"]
                )
            }

            SettingsPanel(title: "Inline Suggestions", subtitle: "When the popup is visible") {
                ShortcutCommandRow(icon: "return", title: "Insert selected emoji", keys: ["Tab"])
                SettingsDivider()
                ShortcutCommandRow(icon: "arrow.left.arrow.right", title: "Move selection", keys: ["←", "→"])
                SettingsDivider()
                ShortcutCommandRow(icon: "escape", title: "Dismiss suggestions", keys: ["Esc"])
            }

            SettingsPanel(title: "Board", subtitle: "From anywhere in macOS") {
                ShortcutCommandRow(icon: "face.smiling", title: "Open quick emoji board", keys: ["⇧", "⌘", "E"])
                SettingsDivider()
                ShortcutCommandRow(icon: "magnifyingglass", title: "Search and insert", keys: ["Type", "Return"])
            }
        }
    }
}

private struct ShortcutHeroPanel: View {
    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.24),
                                Color.cyan.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "command.circle.fill")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(.accentColor)
            }
            .frame(width: 46, height: 46)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.13), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text("Keyboard Flow")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.94))

                Text("Fast paths for inline suggestions and the emoji board.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.68))
                    .lineLimit(2)
            }

            Spacer()

            HStack(spacing: 5) {
                KeyCap("⌘")
                KeyCap("E")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct ShortcutFeatureTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let keys: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.78))
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.secondary.opacity(0.09))
                    )

                Spacer()

                HStack(spacing: 5) {
                    ForEach(keys, id: \.self) { key in
                        KeyCap(key)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.92))
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.62))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct ShortcutCommandRow: View {
    let icon: String
    let title: String
    let keys: [String]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.74))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary.opacity(0.88))

            Spacer()

            HStack(spacing: 5) {
                ForEach(keys, id: \.self) { key in
                    KeyCap(key)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

private struct KeyCap: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(.primary.opacity(0.88))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(minWidth: 28, minHeight: 24)
            .padding(.horizontal, text.count > 2 ? 7 : 0)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.black.opacity(0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
    }
}

private struct RulesSettingsPane: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var permissions = AccessibilityPermissionManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !permissions.automationGranted {
                SettingsCallout(
                    icon: "applescript",
                    title: "Automation required",
                    subtitle: "Site rules need browser URL access.",
                    tint: .orange
                ) {
                    permissions.requestAutomation()
                }
            }

            HStack(spacing: 10) {
                RuleSummaryTile(
                    icon: "network",
                    title: "Sites",
                    value: "\(appState.ignoredSiteRules.count)",
                    subtitle: "Domains"
                )

                RuleSummaryTile(
                    icon: "app.dashed",
                    title: "Apps",
                    value: "\(appState.ignoredAppRules.count)",
                    subtitle: "Applications"
                )
            }

            RulePanel(
                title: "Ignored Sites",
                subtitle: "Silence Flemo on matching domains",
                icon: "network",
                actionTitle: "Add Site",
                actionIcon: "plus"
            ) {
                addSite()
            } content: {
                if appState.ignoredSiteRules.isEmpty {
                    RuleEmptyState(
                        icon: "network",
                        title: "No ignored sites",
                        subtitle: "Add domains where inline suggestions should stay quiet."
                    )
                } else {
                    ForEach(appState.ignoredSiteRules.indices, id: \.self) { index in
                        let rule = appState.ignoredSiteRules[index]
                        ModernRuleRow(icon: "network", title: rule.domain, subtitle: "Domain and subdomains") {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                appState.removeIgnoredSite(rule)
                            }
                        }

                        if index < appState.ignoredSiteRules.count - 1 {
                            SettingsDivider()
                        }
                    }
                }
            }

            RulePanel(
                title: "Ignored Apps",
                subtitle: "Disable suggestions inside selected apps",
                icon: "app.dashed",
                actionTitle: "Add App",
                actionIcon: "plus"
            ) {
                addApp()
            } content: {
                if appState.ignoredAppRules.isEmpty {
                    RuleEmptyState(
                        icon: "app.dashed",
                        title: "No ignored apps",
                        subtitle: "Choose apps where Flemo should not react to typing."
                    )
                } else {
                    ForEach(appState.ignoredAppRules.indices, id: \.self) { index in
                        let rule = appState.ignoredAppRules[index]
                        ModernRuleRow(icon: "app.dashed", title: rule.name, subtitle: rule.bundleIdentifier) {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                appState.removeIgnoredApp(rule)
                            }
                        }

                        if index < appState.ignoredAppRules.count - 1 {
                            SettingsDivider()
                        }
                    }
                }
            }
        }
        .onAppear {
            permissions.refreshStatus()
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

private struct SettingsCallout: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(tint.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.92))
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.66))
            }

            Spacer()

            SmallActionButton(title: "Grant", icon: "arrow.up.right", action: action)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct RuleSummaryTile: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.78))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.09))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.94))
                Text(subtitle)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.60))
                    .textCase(.uppercase)
            }

            Spacer()

            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary.opacity(0.64))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule(style: .continuous).fill(Color.secondary.opacity(0.08)))
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct RulePanel<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let actionTitle: String
    let actionIcon: String
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.72))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.92))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.62))
                }

                Spacer()

                SmallActionButton(title: actionTitle, icon: actionIcon, action: action)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            SettingsDivider()

            VStack(spacing: 0) {
                content
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct RuleEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.56))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.secondary.opacity(0.07))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.82))
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.62))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
    }
}

private struct ModernRuleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let remove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.72))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(isHovered ? 0.12 : 0.07))
                )

            RowText(title: title, subtitle: subtitle)

            Spacer()

            Button(action: remove) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isHovered ? .red.opacity(0.90) : .secondary.opacity(0.70))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.secondary.opacity(isHovered ? 0.12 : 0.08)))
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
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

    private var maxTopCount: Int {
        max(snapshot.topEmoji.map { $0.count }.max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatsHeroPanel(snapshot: snapshot)

            HStack(spacing: 10) {
                StatsMetricTile(icon: "sum", title: "Inserts", value: "\(snapshot.totalUsage)")
                StatsMetricTile(icon: "number.square", title: "Tracked", value: "\(snapshot.trackedEmojiCount)")
                StatsMetricTile(icon: "crown", title: "Top Count", value: "\(snapshot.topEmoji.first?.count ?? 0)")
            }

            StatsTopEmojiPanel(snapshot: snapshot, maxCount: maxTopCount) {
                snapshot = FrequencyTracker.shared.statsSnapshot(limit: 6)
            }
        }
        .onAppear {
            snapshot = FrequencyTracker.shared.statsSnapshot(limit: 6)
        }
    }
}

private struct StatsHeroPanel: View {
    let snapshot: FrequencyStatsSnapshot

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.24),
                                Color.green.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.accentColor)
            }
            .frame(width: 46, height: 46)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.13), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text("Usage Snapshot")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.94))

                Text(snapshot.totalUsage == 0
                    ? "Emoji usage appears after inserts."
                    : "Flemo uses this history to surface better suggestions.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.68))
                    .lineLimit(2)
            }

            Spacer()

            StatusPill(
                title: snapshot.totalUsage == 0 ? "No data" : "Learning",
                color: snapshot.totalUsage == 0 ? .secondary : .green
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct StatsMetricTile: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.78))
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.secondary.opacity(0.09))
                    )

                Spacer()
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.94))
                    .lineLimit(1)

                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.60))
                    .textCase(.uppercase)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct StatsTopEmojiPanel: View {
    let snapshot: FrequencyStatsSnapshot
    let maxCount: Int
    let refresh: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "flame")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.72))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Top Emoji")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.92))
                    Text("Most used suggestions")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.62))
                }

                Spacer()

                SmallActionButton(title: "Refresh", icon: "arrow.clockwise", action: refresh)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            SettingsDivider()

            if snapshot.topEmoji.isEmpty {
                StatsEmptyState()
            } else {
                ForEach(snapshot.topEmoji.indices, id: \.self) { index in
                    ModernEmojiUsageRow(stat: snapshot.topEmoji[index], maxCount: maxCount)

                    if index < snapshot.topEmoji.count - 1 {
                        SettingsDivider()
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct ModernEmojiUsageRow: View {
    let stat: EmojiUsageStat
    let maxCount: Int

    private var progress: CGFloat {
        guard maxCount > 0 else { return 0 }
        return CGFloat(stat.count) / CGFloat(maxCount)
    }

    var body: some View {
        let colors = EmojiColorExtractor.shared.colors(for: stat.emoji.character)

        HStack(spacing: 12) {
            Text(stat.emoji.character)
                .font(.system(size: 24))
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    colors[0].opacity(0.28),
                                    colors[1].opacity(0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(displayName(for: stat.emoji))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.90))
                        .lineLimit(1)

                    Spacer()

                    Text("\(stat.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.72))
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.secondary.opacity(0.10))

                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        colors[0].opacity(0.82),
                                        colors[1].opacity(0.68)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, proxy.size.width * min(progress, 1)))
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func displayName(for emoji: Emoji) -> String {
        emoji.name
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

private struct StatsEmptyState: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.56))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.07))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("No usage yet")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.82))
                Text("Inserted emoji will show up here.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.62))
            }

            Spacer()
        }
        .padding(14)
    }
}

private struct AboutSettingsPane: View {
    @State private var showingUpdateSheet = false
    @ObservedObject private var updater = UpdateChecker.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AboutIdentityPanel(version: versionString)

            HStack(spacing: 10) {
                AboutMetricTile(icon: "tag", title: "Version", value: versionString)
                AboutMetricTile(icon: "face.smiling", title: "Emoji", value: "\(EmojiDataLoader.shared.allEmojis.count)")
                AboutMetricTile(icon: "shippingbox", title: "Bundle", value: bundleShortName)
            }

            SettingsPanel(title: "Project", subtitle: "Release and source") {
                SettingControlRow(
                    icon: "doc.text",
                    title: "Release Notes",
                    subtitle: updater.latestRelease.map { "Latest v\($0.version)" } ?? "Browse version history"
                ) {
                    SmallActionButton(title: "View", icon: "arrow.up.right") {
                        showingUpdateSheet = true
                        updater.check()
                    }
                }

                SettingsDivider()

                SettingControlRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: "GitHub",
                    subtitle: "williamcachamwri/Flemo"
                ) {
                    SmallActionButton(title: "Open", icon: "arrow.up.right") {
                        if let url = URL(string: "https://github.com/williamcachamwri/Flemo") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }

                SettingsDivider()

                SettingControlRow(icon: "doc.on.doc", title: "Bundle Identifier", subtitle: bundleIdentifier) {
                    Text(bundleIdentifier)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.68))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 180, alignment: .trailing)
                }
            }
        }
        .sheet(isPresented: $showingUpdateSheet) {
            ReleaseNotesView()
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

    private var bundleShortName: String {
        bundleIdentifier
            .split(separator: ".")
            .last
            .map(String.init) ?? "app"
    }
}

private struct AboutIdentityPanel: View {
    let version: String

    var body: some View {
        HStack(spacing: 14) {
            AppLogoImage(size: 58)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 5)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Flemo")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.96))

                    Text("v\(version)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.72))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule(style: .continuous).fill(Color.secondary.opacity(0.10)))
                }

                Text("Inline emoji picker for macOS")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.68))
            }

            Spacer()
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.black.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct AboutMetricTile: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.78))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.60))
                    .textCase(.uppercase)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
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
        EmojiColorExtractor.shared.colors(for: emoji.character)
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

private struct PermissionBanner: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.7))
                }

                Spacer()

                Button(action: action) {
                    Text("Grant")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.24), lineWidth: 1)
        )
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
