import Foundation
import os.log

struct GIFItem: Codable, Identifiable {
    let id: String
    let title: String
    let url: URL
    let previewURL: URL
    var isFavorite: Bool = false
    var customKeywords: [String] = []
}

class GIFSearchEngine {
    static let shared = GIFSearchEngine()
    private let log = OSLog(subsystem: "com.emoji-g-fast", category: "GIF")
    private var cachedResults: [String: [GIFItem]] = [:]
    private var favorites: [GIFItem] = []

    private init() {
        favorites = StorageManager.shared.loadFavoriteGIFs()
    }

    func search(keyword: String, maxResults: Int = 10) async -> [GIFItem] {
        let lower = keyword.lowercased().trimmingCharacters(in: .whitespaces)
        if lower.isEmpty { return favorites }

        if let cached = cachedResults[lower], !cached.isEmpty {
            return Array(cached.prefix(maxResults))
        }

        let favoritesMatch = favorites.filter {
            $0.title.lowercased().contains(lower) ||
            $0.customKeywords.contains { $0.lowercased().contains(lower) }
        }
        if !favoritesMatch.isEmpty {
            return Array(favoritesMatch.prefix(maxResults))
        }

        let apiKey = AppSettings.shared.giphyAPIKey
        guard !apiKey.isEmpty else { return [] }

        do {
            let items = try await searchGiphy(keyword: lower, apiKey: apiKey)
            cachedResults[lower] = items
            return Array(items.prefix(maxResults))
        } catch {
            os_log(.error, log: log, "GIF search failed: %{public}@", error.localizedDescription)
            return []
        }
    }

    private func searchGiphy(keyword: String, apiKey: String) async throws -> [GIFItem] {
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let urlStr = "https://api.giphy.com/v1/gifs/search?api_key=\(apiKey)&q=\(encoded)&limit=25"
        guard let url = URL(string: urlStr) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(GiphyResponse.self, from: data)
        return decoded.data.map { gifData in
            GIFItem(
                id: gifData.id,
                title: gifData.title,
                url: URL(string: gifData.images.original.url)!,
                previewURL: URL(string: gifData.images.fixedWidthStill.url)!
            )
        }
    }

    func addFavorite(_ gif: GIFItem) {
        var gif = gif
        gif.isFavorite = true
        if !favorites.contains(where: { $0.id == gif.id }) {
            favorites.append(gif)
            StorageManager.shared.saveFavoriteGIFs(favorites)
        }
    }

    func removeFavorite(_ gif: GIFItem) {
        favorites.removeAll { $0.id == gif.id }
        StorageManager.shared.saveFavoriteGIFs(favorites)
    }

    func updateCustomKeywords(gifId: String, keywords: [String]) {
        if let idx = favorites.firstIndex(where: { $0.id == gifId }) {
            favorites[idx].customKeywords = keywords
            StorageManager.shared.saveFavoriteGIFs(favorites)
        }
    }

    func getFavorites() -> [GIFItem] { favorites }
}

struct GiphyResponse: Codable {
    let data: [GiphyGIFData]
}

struct GiphyGIFData: Codable {
    let id: String
    let title: String
    let images: GiphyImages
}

struct GiphyImages: Codable {
    let original: GiphyImageURL
    let fixedWidthStill: GiphyImageURL

    enum CodingKeys: String, CodingKey {
        case original
        case fixedWidthStill = "fixed_width_still"
    }
}

struct GiphyImageURL: Codable {
    let url: String
}
