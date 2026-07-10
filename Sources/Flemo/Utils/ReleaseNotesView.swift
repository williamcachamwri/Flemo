import SwiftUI

struct ReleaseNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var updater = UpdateChecker.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.06))
            content
            Divider().background(Color.white.opacity(0.06))
            footer
        }
        .frame(width: 460, height: 520)
        .background(VisualEffectBackground())
        .onAppear {
            if updater.releases.isEmpty {
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
                Text(updater.releases.isEmpty ? "Loading..." : "\(updater.releases.count) releases")
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
                Text("Could not load release notes")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(error)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                Button("Retry") { updater.check() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
                    .padding(.top, 4)
            }
            .padding(20)
            Spacer()
        } else if !updater.releases.isEmpty {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(updater.releases.enumerated()), id: \.element.id) { index, release in
                        releaseSection(release)
                        if index < updater.releases.count - 1 {
                            Divider().background(Color.white.opacity(0.06))
                                .padding(.vertical, 12)
                        }
                    }
                }
                .padding(16)
            }
        } else {
            Spacer()
            Button("Check for Updates") { updater.check() }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            Spacer()
        }
    }

    private func releaseSection(_ release: GitHubRelease) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text("v\(release.version)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                Spacer()
                Text(release.formattedDate)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
            }

            if !release.body.isEmpty {
                MarkdownView(markdown: release.body)
                    .frame(maxWidth: .infinity, minHeight: 20)
            }

            if release.tagName == updater.latestRelease?.tagName,
               release.version.compare(currentVersion, options: .numeric) == .orderedDescending {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text("New version available")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                    Spacer()
                    Button {
                        if let url = updater.downloadURL(for: release) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text("Download")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.accentColor))
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.08))
                )
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Close") {
                dismiss()
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

    private func markdownString(_ text: String) -> AttributedString {
        guard let parsed = try? AttributedString(
            markdown: text,
            options: .init(
                allowsExtendedAttributes: true,
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) else {
            return AttributedString(text)
        }
        return parsed
    }

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}

private struct MarkdownView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> NSTextView {
        let tv = NSTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.textContainer?.lineFragmentPadding = 0
        tv.textContainer?.containerSize = NSSize(width: 428, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        return tv
    }

    func updateNSView(_ tv: NSTextView, context: Context) {
        do {
            let attr = try AttributedString(
                markdown: markdown,
                options: .init(allowsExtendedAttributes: true)
            )
            let ns = NSAttributedString(attr)
            let full = NSRange(location: 0, length: ns.length)
            let mutable = NSMutableAttributedString(attributedString: ns)

            let para = NSMutableParagraphStyle()
            para.lineSpacing = 3
            para.paragraphSpacing = 6
            mutable.addAttribute(.paragraphStyle, value: para, range: full)

            tv.textStorage?.setAttributedString(mutable)
        } catch {
            tv.textStorage?.setAttributedString(NSAttributedString(
                string: markdown,
                attributes: [.font: NSFont.systemFont(ofSize: 11)]
            ))
        }
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
