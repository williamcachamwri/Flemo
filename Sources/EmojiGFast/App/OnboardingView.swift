import SwiftUI
import Combine

struct OnboardingView: View {
    @StateObject private var perm = AccessibilityPermissionManager.shared
    @ObservedObject private var appState = AppState.shared
    @State private var testInput = ""
    @State private var suggestions: [Emoji] = []
    @State private var showTest = false
    @State private var selectedEmoji: Emoji?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "face.smiling")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Welcome to EmojiGFast")
                .font(.title2).bold()

            Text("Quick emoji & GIF inserter for macOS")

            Divider()

            // Step 1: Permission
            GroupBox("Step 1: Grant Accessibility Access") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: perm.accessibilityGranted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(perm.accessibilityGranted ? .green : .secondary)
                        Text("Accessibility Permission")
                        Spacer()
                        if !perm.accessibilityGranted {
                            Button("Grant") { perm.requestAccessibility() }
                                .controlSize(.small)
                        }
                    }

                    if perm.accessibilityGranted {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("Permission granted! Inline trigger is active.")
                                .foregroundColor(.green)
                        }
                    } else {
                        Text("Required to detect keystrokes and show suggestions system-wide.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(8)
            }

            if perm.accessibilityGranted {
                // Step 2: Test
                GroupBox("Step 2: Try It") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type in any app:  `dog  (backtick + keyword)")
                            .font(.caption).foregroundColor(.secondary)

                        TextField("Or test here: type ` followed by keyword...", text: $testInput)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: testInput) { _, newVal in
                                updateSuggestions(from: newVal)
                            }

                        if !suggestions.isEmpty {
                            Text("Suggested emoji:").font(.caption)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 4) {
                                ForEach(suggestions.prefix(12)) { emoji in
                                    Text(emoji.character)
                                        .font(.title)
                                        .frame(width: 40, height: 40)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .onTapGesture {
                                            selectedEmoji = emoji
                                            testInput = emoji.character
                                            suggestions = []
                                        }
                                }
                            }
                        }

                        if let emoji = selectedEmoji {
                            HStack {
                                Text("Selected: \(emoji.character) \(emoji.name)")
                                    .foregroundColor(.secondary)
                                Button("Copy") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(emoji.character, forType: .string)
                                }.controlSize(.small)
                            }
                        }
                    }
                    .padding(8)
                }

                // Step 3: Quick reference
                GroupBox("Quick Reference") {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Type `keyword to trigger suggestions", systemImage: "keyboard")
                        Label("⌘ + 0-9 to select suggestion #", systemImage: "command")
                        Label("Click menu bar icon → Emoji Board / GIF Board", systemImage: "menubar.rectangle")
                        Label("Press Esc to dismiss suggestions", systemImage: "escape")
                    }
                    .font(.caption)
                    .padding(8)
                }
            }

            Button("Get Started") {
                closeOnboarding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!perm.accessibilityGranted)
        }
        .padding(24)
        .frame(width: 480)
    }

    private func updateSuggestions(from text: String) {
        guard let trigger = appState.triggerCharacter.first,
              text.contains(trigger) else {
            suggestions = []
            return
        }
        if let idx = text.lastIndex(of: trigger) {
            let after = text[text.index(after: idx)...].trimmingCharacters(in: .whitespaces)
            if after.count >= appState.minTriggerLength {
                suggestions = EmojiSearchEngine.shared.search(keyword: after, maxResults: 12)
            } else {
                suggestions = []
            }
        }
    }

    private func closeOnboarding() {
        if let w = NSApplication.shared.windows.first(where: { $0.title == "Welcome" }) {
            w.close()
        }
    }
}
