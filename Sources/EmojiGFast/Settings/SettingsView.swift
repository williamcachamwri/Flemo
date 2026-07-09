import SwiftUI

private enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case emojis
    case keybinds
    case stats
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .emojis: "Emojis"
        case .keybinds: "Keybinds"
        case .stats: "Stats"
        case .about: "About"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape.fill"
        case .emojis: "face.smiling.fill"
        case .keybinds: "keyboard.fill"
        case .stats: "list.bullet.rectangle.fill"
        case .about: "info.circle.fill"
        }
    }

    var colors: [Color] {
        switch self {
        case .general: [Color(red: 0.62, green: 0.64, blue: 0.67), Color(red: 0.38, green: 0.40, blue: 0.43)]
        case .emojis: [Color(red: 1.00, green: 0.78, blue: 0.20), Color(red: 1.00, green: 0.47, blue: 0.06)]
        case .keybinds: [Color(red: 0.10, green: 0.10, blue: 0.11), Color.black]
        case .stats: [Color(red: 0.16, green: 0.87, blue: 0.91), Color(red: 0.04, green: 0.58, blue: 0.68)]
        case .about: [Color(red: 0.74, green: 0.74, blue: 0.76), Color(red: 0.48, green: 0.48, blue: 0.50)]
        }
    }
}

struct SettingsView: View {
    @State private var selectedPane: SettingsPane = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Rectangle()
                .fill(SettingsColors.divider)
                .frame(width: 1)

            content
        }
        .frame(minWidth: 860, minHeight: 580)
        .background(SettingsColors.content)
        .preferredColorScheme(.dark)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                WindowDot(color: Color(red: 1.0, green: 0.28, blue: 0.32))
                WindowDot(color: Color(red: 1.0, green: 0.78, blue: 0.08))
                WindowDot(color: Color(red: 0.28, green: 0.29, blue: 0.31))
            }
            .padding(.top, 26)
            .padding(.leading, 22)

            VStack(spacing: 7) {
                ForEach(SettingsPane.allCases) { pane in
                    SidebarRow(
                        pane: pane,
                        isSelected: selectedPane == pane
                    ) {
                        selectedPane = pane
                    }
                }
            }
            .padding(.top, 34)
            .padding(.horizontal, 14)

            Spacer()
            PermissionCompactStatus()
                .padding(.horizontal, 14)
                .padding(.bottom, 18)
        }
        .frame(width: 238)
        .background(SettingsColors.sidebar)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(selectedPane.title)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(SettingsColors.primaryText)
                    .padding(.top, 24)

                switch selectedPane {
                case .general:
                    GeneralPane()
                case .emojis:
                    EmojisPane()
                case .keybinds:
                    KeybindsPane()
                case .stats:
                    StatsPane()
                case .about:
                    AboutPane()
                }
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(SettingsColors.content)
    }
}

private struct GeneralPane: View {
    @ObservedObject private var permissions = AccessibilityPermissionManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup {
                SettingsRow(title: "Accessibility") {
                    StatusPill(isOn: permissions.accessibilityGranted)
                }

                SettingsRow(title: "Input Monitoring") {
                    StatusPill(isOn: permissions.inputMonitoringGranted)
                }

                SettingsRow(title: "Permissions") {
                    HStack(spacing: 10) {
                        ActionButton(title: "Refresh", systemImage: "arrow.clockwise") {
                            permissions.refreshStatus()
                        }
                        ActionButton(title: "Open Guide", systemImage: "lock.shield") {
                            permissions.showPermissionGuide()
                        }
                    }
                }
            }

            SettingsGroup {
                SettingsRow(title: "Local usage ranking") {
                    ActionButton(title: "Reset", systemImage: "arrow.counterclockwise", role: .destructive) {
                        FrequencyTracker.shared.resetAll()
                    }
                }
            }
        }
    }
}

private struct EmojisPane: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup {
                SettingsRow(title: "Inline suggestions") {
                    Toggle("", isOn: $appState.inlineTriggerEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                SettingsRow(title: "Trigger character") {
                    TextField("", text: triggerBinding)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .frame(width: 48, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(SettingsColors.control)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(SettingsColors.stroke, lineWidth: 1)
                        )
                }

                SettingsRow(title: "Minimum keyword length") {
                    Stepper(value: $appState.minTriggerLength, in: 1...5) {
                        Text("\(appState.minTriggerLength)")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .frame(width: 24, alignment: .trailing)
                    }
                    .frame(width: 118)
                }

                SettingsRow(title: "Command-number selection") {
                    Toggle("", isOn: $appState.numberShortcutEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            InlinePreview(trigger: appState.triggerCharacter)
        }
    }

    private var triggerBinding: Binding<String> {
        Binding(
            get: { appState.triggerCharacter },
            set: { newValue in
                let cleaned = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                appState.triggerCharacter = cleaned.isEmpty
                    ? Constants.defaultTriggerCharacter
                    : String(cleaned.prefix(1))
            }
        )
    }
}

private struct KeybindsPane: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup {
                ShortcutRow(title: "Insert selected emoji", shortcut: "Tab")
                ShortcutRow(title: "Move through suggestions", shortcut: "< / >")
                ShortcutRow(title: "Dismiss suggestions", shortcut: "Esc")
            }

            SettingsGroup {
                ShortcutRow(title: "Emoji Board", shortcut: "Cmd E")
                if appState.numberShortcutEnabled {
                    ShortcutRow(title: "Pick by number", shortcut: "Cmd 0-9")
                }
            }
        }
    }
}

private struct StatsPane: View {
    @State private var snapshot = FrequencyTracker.shared.statsSnapshot(limit: 8)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup {
                MetricRow(title: "Total emoji inserts", value: "\(snapshot.totalUsage)")
                MetricRow(title: "Tracked emojis", value: "\(snapshot.trackedEmojiCount)")
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Favourites")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(SettingsColors.primaryText)

                SettingsGroup {
                    if snapshot.topEmoji.isEmpty {
                        SettingsRow(title: "No usage yet") {
                            Text("0")
                                .foregroundStyle(SettingsColors.secondaryText)
                        }
                    } else {
                        ForEach(snapshot.topEmoji) { stat in
                            HStack(spacing: 12) {
                                Text(stat.emoji.character)
                                    .font(.system(size: 25))
                                    .frame(width: 38, height: 38)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(SettingsColors.control)
                                    )

                                Text(displayName(for: stat.emoji))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(SettingsColors.primaryText)
                                    .lineLimit(1)

                                Spacer()

                                Text("\(stat.count)")
                                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(SettingsColors.secondaryText)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 58)
                            .rowDivider()
                        }
                    }
                }
            }

            ActionButton(title: "Refresh Stats", systemImage: "arrow.clockwise") {
                snapshot = FrequencyTracker.shared.statsSnapshot(limit: 8)
            }
        }
    }

    private func displayName(for emoji: Emoji) -> String {
        emoji.name
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

private struct AboutPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup {
                SettingsRow(title: "Version") {
                    Text(versionString)
                        .foregroundStyle(SettingsColors.secondaryText)
                }

                SettingsRow(title: "Emoji library") {
                    Text("\(EmojiDataLoader.shared.allEmojis.count)")
                        .foregroundStyle(SettingsColors.secondaryText)
                }

                SettingsRow(title: "Bundle identifier") {
                    Text(bundleIdentifier)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(SettingsColors.secondaryText)
                        .lineLimit(1)
                }
            }
        }
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "Development"
        let build = info?["CFBundleVersion"] as? String
        if let build, !build.isEmpty {
            return "\(version) (\(build))"
        }
        return version
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.emoji-g-fast"
    }
}

private struct SidebarRow: View {
    let pane: SettingsPane
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconTile(icon: pane.icon, colors: pane.colors)

                Text(pane.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SettingsColors.primaryText)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? SettingsColors.selected : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct IconTile: View {
    let icon: String
    let colors: [Color]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 28, height: 28)
    }
}

private struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(SettingsColors.group)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(SettingsColors.stroke, lineWidth: 1)
        )
    }
}

private struct SettingsRow<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SettingsColors.primaryText)
                .lineLimit(1)

            Spacer(minLength: 16)
            trailing
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 58)
        .rowDivider()
    }
}

private struct MetricRow: View {
    let title: String
    let value: String

    var body: some View {
        SettingsRow(title: title) {
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(SettingsColors.secondaryText)
        }
    }
}

private struct ShortcutRow: View {
    let title: String
    let shortcut: String

    var body: some View {
        SettingsRow(title: title) {
            Text(shortcut)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(SettingsColors.primaryText)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(
                    Capsule(style: .continuous)
                        .fill(SettingsColors.control)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(SettingsColors.stroke, lineWidth: 1)
                )
        }
    }
}

private struct InlinePreview: View {
    let trigger: String
    private let previewEmojis = EmojiSearchEngine.shared.search(keyword: "cat", maxResults: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live search preview")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(SettingsColors.primaryText)

            HStack(spacing: 14) {
                Text("\(trigger)cat")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(SettingsColors.primaryText)

                HStack(spacing: 10) {
                    ForEach(previewEmojis.prefix(4)) { emoji in
                        Text(emoji.character)
                            .font(.system(size: 22))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.42))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

                Spacer()
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(SettingsColors.group)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(SettingsColors.stroke, lineWidth: 1)
            )
        }
    }
}

private struct PermissionCompactStatus: View {
    @ObservedObject private var permissions = AccessibilityPermissionManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            CompactStatusLine(title: "Accessibility", isOn: permissions.accessibilityGranted)
            CompactStatusLine(title: "Input Monitoring", isOn: permissions.inputMonitoringGranted)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
    }
}

private struct CompactStatusLine: View {
    let title: String
    let isOn: Bool

    var body: some View {
        HStack(spacing: 7) {
            StatusDot(isOn: isOn)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SettingsColors.secondaryText)
            Spacer(minLength: 0)
        }
    }
}

private struct StatusPill: View {
    let isOn: Bool

    var body: some View {
        HStack(spacing: 7) {
            StatusDot(isOn: isOn)
            Text(isOn ? "Granted" : "Missing")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(isOn ? SettingsColors.success : SettingsColors.warning)
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(
            Capsule(style: .continuous)
                .fill((isOn ? SettingsColors.success : SettingsColors.warning).opacity(0.14))
        )
    }
}

private struct StatusDot: View {
    let isOn: Bool

    var body: some View {
        Circle()
            .fill(isOn ? SettingsColors.success : SettingsColors.warning)
            .frame(width: 8, height: 8)
    }
}

private struct ActionButton: View {
    enum Role {
        case normal
        case destructive
    }

    let title: String
    let systemImage: String
    var role: Role = .normal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(role == .destructive ? Color(red: 1.0, green: 0.42, blue: 0.38) : SettingsColors.primaryText)
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(SettingsColors.control)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(SettingsColors.stroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct WindowDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 16, height: 16)
    }
}

private extension View {
    func rowDivider() -> some View {
        overlay(alignment: .bottom) {
            Rectangle()
                .fill(SettingsColors.divider)
                .frame(height: 1)
                .padding(.leading, 18)
        }
    }
}

private enum SettingsColors {
    static let sidebar = Color(red: 0.135, green: 0.145, blue: 0.158)
    static let content = Color(red: 0.105, green: 0.110, blue: 0.120)
    static let group = Color(red: 0.112, green: 0.118, blue: 0.128)
    static let control = Color(red: 0.190, green: 0.198, blue: 0.210)
    static let selected = Color(red: 0.205, green: 0.210, blue: 0.225)
    static let stroke = Color.white.opacity(0.18)
    static let divider = Color.white.opacity(0.10)
    static let primaryText = Color.white.opacity(0.92)
    static let secondaryText = Color.white.opacity(0.62)
    static let success = Color(red: 0.27, green: 0.87, blue: 0.42)
    static let warning = Color(red: 1.00, green: 0.66, blue: 0.20)
}
