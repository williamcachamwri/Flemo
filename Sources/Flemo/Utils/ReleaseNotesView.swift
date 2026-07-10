import SwiftUI

struct ReleaseNotesView: View {
    @ObservedObject private var updater = UpdateChecker.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.06))
            content
            Divider().background(Color.white.opacity(0.06))
            footer
        }
        .frame(width: 420, height: 460)
        .background(VisualEffectBackground())
        .onAppear {
            if updater.latestRelease == nil {
                updater.check()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppIconView(size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Flemo")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("Inline emoji picker for macOS")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }

    @ViewBuilder
    private var content: some View {
        if updater.isLoading {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Spacer()
        } else if let error = updater.error {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundColor(.orange)
                Text("Could not check for updates")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(error)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") { updater.check() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
                    .padding(.top, 4)
            }
            .padding(20)
            Spacer()
        } else if let release = updater.latestRelease {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    versionCompare(release)
                    releaseNotes(release)
                }
                .padding(16)
            }
        } else {
            Spacer()
            Button("Check for Updates") { updater.check() }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.accentColor)
            Spacer()
        }
    }

    private func versionCompare(_ release: GitHubRelease) -> some View {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let isNewer = release.version.compare(current, options: .numeric) == .orderedDescending

        return HStack(spacing: 12) {
            Image(systemName: isNewer ? "arrow.down.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(isNewer ? .accentColor : .green)

            VStack(alignment: .leading, spacing: 2) {
                Text(isNewer ? "Update available" : "Up to date")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text("\(release.version) — \(release.formattedDate)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isNewer {
                Button {
                    if let url = updater.downloadURL(for: release) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("Download")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isNewer ? Color.accentColor.opacity(0.08) : Color.green.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isNewer ? Color.accentColor.opacity(0.2) : Color.green.opacity(0.2), lineWidth: 1)
        )
    }

    private func releaseNotes(_ release: GitHubRelease) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Release Notes")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(markdownToAttributed(release.body))
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack {
            Button("Close") {
                NSApplication.shared.keyWindow?.close()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.10))
            )

            Spacer()

            Button {
                updater.check()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Refresh")
        }
        .padding(16)
    }

    private func markdownToAttributed(_ text: String) -> AttributedString {
        var result = text
        // Bold: **text** or __text__
        result = result.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "$1", options: .regularExpression)
        // Italic: *text*
        result = result.replacingOccurrences(of: #"\*(.+?)\*"#, with: "$1", options: .regularExpression)
        // Headers: ## text
        result = result.replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression)
        // List markers
        result = result.replacingOccurrences(of: #"(?m)^[*-]\s+"#, with: "• ", options: .regularExpression)
        // Links [text](url)
        result = result.replacingOccurrences(of: #"\[(.+?)\]\(.+?\)"#, with: "$1", options: .regularExpression)
        // Code blocks ```
        result = result.replacingOccurrences(of: #"(?s)```.*?```"#, with: "", options: .regularExpression)
        // Inline code
        result = result.replacingOccurrences(of: "`", with: "")

        return (try? AttributedString(markdown: result, options: .init(
            allowsExtendedAttributes: true,
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        ))) ?? AttributedString(result)
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerRadius = 16
        v.layer?.masksToBounds = true
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private struct AppIconView: View {
    let size: CGFloat
    var body: some View {
        if let image = Self.icon {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        } else {
            Image(systemName: "face.smiling.fill")
                .font(.system(size: size * 0.6))
                .foregroundStyle(LinearGradient(colors: [.accentColor, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
        }
    }
    private static var icon: NSImage? {
        let urls = [
            Bundle.main.url(forResource: "Flemo", withExtension: "icns"),
            Bundle.main.resourceURL?.appendingPathComponent("Flemo.icns"),
            Bundle.main.executableURL?.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Flemo.icns"),
        ]
        return urls.compactMap { $0 }.compactMap { NSImage(contentsOf: $0) }.first
    }
}
