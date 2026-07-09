import SwiftUI

private enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case trigger
    case shortcuts
    case features

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .trigger: "Trigger"
        case .shortcuts: "Shortcuts"
        case .features: "Features"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "API, permissions, data"
        case .trigger: "Inline search behavior"
        case .shortcuts: "Boards and quick select"
        case .features: "Emoji, GIF, selection"
        }
    }

    var icon: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .trigger: "text.cursor"
        case .shortcuts: "command"
        case .features: "sparkles"
        }
    }
}

struct SettingsView: View {
    @State private var selectedPane: SettingsPane = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .frame(width: 720, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.16))
                    Image(systemName: "face.smiling.inverse")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text("EmojiGFast")
                        .font(.headline)
                    Text("Inline emoji picker")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 6)

            VStack(spacing: 6) {
                ForEach(SettingsPane.allCases) { pane in
                    SidebarButton(pane: pane, isSelected: selectedPane == pane) {
                        selectedPane = pane
                    }
                }
            }

            Spacer()
            PermissionMiniCard()
        }
        .padding(16)
        .frame(width: 206)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(selectedPane.title, systemImage: selectedPane.icon)
                        .font(.system(size: 24, weight: .semibold))
                    Text(selectedPane.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)

                switch selectedPane {
                case .general:
                    GeneralSettingsPane()
                case .trigger:
                    TriggerSettingsPane()
                case .shortcuts:
                    ShortcutSettingsPane()
                case .features:
                    FeatureToggleSettingsPane()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SidebarButton: View {
    let pane: SettingsPane
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: pane.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 22)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(pane.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(pane.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.13) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.22) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct GeneralSettingsPane: View {
    @State private var gifInsertionMode: GIFInsertionMode = AppSettings.shared.gifInsertionMode
    @State private var giphyAPIKey: String = AppSettings.shared.giphyAPIKey

    var body: some View {
        VStack(spacing: 14) {
            SettingsSection(title: "GIPHY", subtitle: "GIF search and insertion", systemImage: "photo.stack") {
                SettingsRow(icon: "key.fill", title: "API key", subtitle: "Required only when GIF search is enabled.") {
                    HStack(spacing: 8) {
                        SecureField("GIPHY API key", text: $giphyAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 230)
                        Button {
                            AppSettings.shared.giphyAPIKey = giphyAPIKey
                        } label: {
                            Label("Save", systemImage: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                SettingsRow(icon: "link", title: "GIF insertion", subtitle: "Choose whether selected GIFs paste as links or files.") {
                    Picker("", selection: $gifInsertionMode) {
                        ForEach(GIFInsertionMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                    .onChange(of: gifInsertionMode) { _, newValue in
                        AppSettings.shared.gifInsertionMode = newValue
                    }
                }
            }

            SettingsSection(title: "Maintenance", subtitle: "Local app data", systemImage: "externaldrive") {
                SettingsRow(icon: "chart.bar.xaxis", title: "Emoji frequency", subtitle: "Clear ranking data used by search results.") {
                    Button(role: .destructive) {
                        FrequencyTracker.shared.resetAll()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }

            SettingsSection(title: "Permissions", subtitle: "Keyboard monitoring and cursor access", systemImage: "lock.shield") {
                PermissionStatusRows()
            }
        }
    }
}

private struct TriggerSettingsPane: View {
    @ObservedObject var appState: AppState = AppState.shared

    var body: some View {
        VStack(spacing: 14) {
            SettingsSection(title: "Inline Trigger", subtitle: "Controls the popup that appears while typing", systemImage: "text.cursor") {
                SettingsRow(icon: "quote.opening", title: "Trigger character", subtitle: "Default is the backtick character.") {
                    TextField("`", text: $appState.triggerCharacter)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 58)
                }

                SettingsRow(icon: "number", title: "Minimum keyword length", subtitle: "Suggestions appear after this many characters.") {
                    Stepper("\(appState.minTriggerLength)", value: $appState.minTriggerLength, in: 1...5)
                        .frame(width: 88)
                }
            }
        }
    }
}

private struct ShortcutSettingsPane: View {
    var body: some View {
        VStack(spacing: 14) {
            SettingsSection(title: "Boards", subtitle: "Quick access windows", systemImage: "rectangle.grid.2x2") {
                ShortcutRow(icon: "face.smiling", title: "Emoji Board", shortcut: "⌘ E")
                ShortcutRow(icon: "photo.on.rectangle", title: "GIF Board", shortcut: "⌘ G")
            }

            SettingsSection(title: "Inline Selection", subtitle: "While the suggestion pill is visible", systemImage: "arrow.left.arrow.right") {
                ShortcutRow(icon: "arrow.left.and.right", title: "Move selection", shortcut: "← / →")
                ShortcutRow(icon: "checkmark.circle", title: "Choose selected emoji", shortcut: "Tab")
            }
        }
    }
}

private struct FeatureToggleSettingsPane: View {
    @ObservedObject var appState: AppState = AppState.shared

    var body: some View {
        VStack(spacing: 14) {
            SettingsSection(title: "Features", subtitle: "Enable or disable app behavior", systemImage: "switch.2") {
                ToggleRow(
                    icon: "text.bubble",
                    title: "Inline trigger",
                    subtitle: "Show the pill while typing a keyword.",
                    isOn: $appState.inlineTriggerEnabled
                )
                ToggleRow(
                    icon: "sparkles",
                    title: "GIF support",
                    subtitle: "Allow GIF search and insertion.",
                    isOn: $appState.gifFeatureEnabled
                )
                ToggleRow(
                    icon: "command",
                    title: "Number shortcuts",
                    subtitle: "Use command-number for quick selection.",
                    isOn: $appState.numberShortcutEnabled
                )
            }
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let content: Content

    init(title: String, subtitle: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

private struct SettingsRow<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let trailing: Trailing

    init(icon: String, title: String, subtitle: String, @ViewBuilder trailing: () -> Trailing) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 50)
        }
    }
}

private struct ToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        SettingsRow(icon: icon, title: title, subtitle: subtitle) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

private struct ShortcutRow: View {
    let icon: String
    let title: String
    let shortcut: String

    var body: some View {
        SettingsRow(icon: icon, title: title, subtitle: "Configured in the menu bar app.") {
            Text(shortcut)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                )
        }
    }
}

private struct PermissionStatusRows: View {
    @ObservedObject private var permissions = AccessibilityPermissionManager.shared

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: permissions.accessibilityGranted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill",
                title: "Accessibility",
                subtitle: "Used to read cursor position and active input bounds."
            ) {
                StatusPill(isOn: permissions.accessibilityGranted)
            }

            SettingsRow(
                icon: permissions.inputMonitoringGranted ? "keyboard.badge.eye.fill" : "keyboard.badge.ellipsis",
                title: "Input Monitoring",
                subtitle: "Used to detect trigger text and arrow navigation."
            ) {
                StatusPill(isOn: permissions.inputMonitoringGranted)
            }

            HStack {
                Button {
                    permissions.refreshStatus()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    permissions.showPermissionGuide()
                } label: {
                    Label("Open Guide", systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding(14)
        }
    }
}

private struct PermissionMiniCard: View {
    @ObservedObject private var permissions = AccessibilityPermissionManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                StatusDot(isOn: permissions.accessibilityGranted)
                Text("Accessibility")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 6) {
                StatusDot(isOn: permissions.inputMonitoringGranted)
                Text("Input Monitoring")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
    }
}

private struct StatusPill: View {
    let isOn: Bool

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(isOn: isOn)
            Text(isOn ? "Granted" : "Missing")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill((isOn ? Color.green : Color.orange).opacity(0.14))
        )
        .foregroundStyle(isOn ? Color.green : Color.orange)
    }
}

private struct StatusDot: View {
    let isOn: Bool

    var body: some View {
        Circle()
            .fill(isOn ? Color.green : Color.orange)
            .frame(width: 8, height: 8)
    }
}
