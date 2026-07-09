import SwiftUI

struct GIFBoardView: View {
    @State private var searchText = ""
    @State private var results: [GIFItem] = []
    @State private var showFavorites = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    var onSelect: (GIFItem) -> Void

    private let engine = GIFSearchEngine.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search GIF...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit { performSearch() }
                    .onChange(of: searchText) { errorMessage = nil }
                if !searchText.isEmpty {
                    Button(action: { searchText = ""; results = []; errorMessage = nil }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                }
                Button(action: performSearch) {
                    Image(systemName: "arrow.right.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(searchText.isEmpty)

                Toggle(isOn: $showFavorites) {
                    Image(systemName: "star.fill").foregroundColor(.yellow)
                }
                .toggleStyle(.button)
                .help("Show favorites only")
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(8)

            if isLoading {
                ProgressView("Searching...")
                    .frame(maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
                    Text(error).font(.caption).foregroundColor(.secondary)
                    Text("Add a GIPHY API key in Settings → General")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                        ForEach(displayedItems) { gif in
                            GIFCellView(gif: gif)
                                .onTapGesture { onSelect(gif) }
                                .contextMenu {
                                    Button("Insert as Link") { onSelect(gif) }
                                    if gif.isFavorite {
                                        Button("Remove from Favorites") {
                                            engine.removeFavorite(gif)
                                            refreshResults()
                                        }
                                    } else {
                                        Button("Add to Favorites") {
                                            engine.addFavorite(gif)
                                            refreshResults()
                                        }
                                    }
                                }
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear { refreshResults() }
    }

    private var displayedItems: [GIFItem] {
        showFavorites ? engine.getFavorites() : results
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        let kw = searchText
        Task {
            let items = await engine.search(keyword: kw, maxResults: 30)
            await MainActor.run {
                results = items
                isLoading = false
                if items.isEmpty && AppSettings.shared.giphyAPIKey.isEmpty {
                    errorMessage = "No results. Did you set a GIPHY API key?"
                }
            }
        }
    }

    private func refreshResults() {
        if showFavorites {
            results = engine.getFavorites()
        }
    }
}

struct GIFCellView: View {
    let gif: GIFItem

    var body: some View {
        AsyncImage(url: gif.previewURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            case .failure:
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 120)
                    .overlay(Image(systemName: "photo").foregroundColor(.secondary))
            case .empty:
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 120)
                    .overlay(ProgressView().scaleEffect(0.5))
            @unknown default:
                EmptyView()
            }
        }
        .overlay(alignment: .topTrailing) {
            if gif.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
                    .padding(4)
            }
        }
    }
}
