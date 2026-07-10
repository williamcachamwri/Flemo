import Foundation

struct GitHubRelease: Decodable {
    let tagName: String
    let name: String
    let body: String
    let htmlUrl: String
    let publishedAt: String
    let prerelease: Bool
    let assets: [GitHubAsset]

    var version: String { tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName }
    var formattedDate: String {
        let iso = ISO8601DateFormatter()
        guard let date = iso.date(from: publishedAt) else { return publishedAt }
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case prerelease
        case assets
    }
}

struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
    }
}

final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var latestRelease: GitHubRelease?
    @Published var isLoading = false
    @Published var error: String?

    private let repo = "williamcachamwri/Flemo"

    func check() {
        isLoading = true
        error = nil
        latestRelease = nil

        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            error = "Invalid URL"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Flemo/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, err in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let err {
                    self?.error = err.localizedDescription
                    return
                }
                guard let data,
                      let http = response as? HTTPURLResponse,
                      http.statusCode == 200
                else {
                    self?.error = "No data from GitHub"
                    return
                }
                do {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                    self?.latestRelease = release
                } catch {
                    self?.error = error.localizedDescription
                }
            }
        }.resume()
    }

    func downloadURL(for release: GitHubRelease) -> URL? {
        let isDebug = Bundle.main.bundleIdentifier == "com.flemo.debug"
        let prefix = isDebug ? "Flemo-Debug" : "Flemo-Release"
        for asset in release.assets where asset.name.hasPrefix(prefix) && asset.name.hasSuffix(".zip") {
            return URL(string: asset.browserDownloadUrl)
        }
        return URL(string: release.htmlUrl)
    }

    private var currentVersion: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let b = info?["CFBundleVersion"] as? String ?? "0"
        return "\(v)+\(b)"
    }
}
