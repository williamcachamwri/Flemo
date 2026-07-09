import SwiftUI

struct EmojiBoardView: View {
    @State private var searchText = ""
    @State private var selectedCategory: String = "All"
    var onSelect: (Emoji) -> Void

    private var categories: [String] {
        let cats = Set(EmojiDataLoader.shared.allEmojis.map { $0.category })
        return ["All"] + cats.sorted()
    }

    private var filteredEmojis: [Emoji] {
        if searchText.isEmpty {
            if selectedCategory == "All" {
                return EmojiDataLoader.shared.allEmojis
            }
            return EmojiDataLoader.shared.allEmojis.filter { $0.category == selectedCategory }
        }
        return EmojiSearchEngine.shared.search(keyword: searchText, maxResults: 50)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search emoji...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(categories, id: \.self) { cat in
                        Button(action: { selectedCategory = cat }) {
                            Text(cat)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(selectedCategory == cat ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                                .foregroundColor(selectedCategory == cat ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.bottom, 4)

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                    ForEach(filteredEmojis) { emoji in
                        Text(emoji.character)
                            .font(.largeTitle)
                            .frame(width: 44, height: 44)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .onTapGesture { onSelect(emoji) }
                            .help(emoji.name)
                    }
                }
                .padding(8)
            }
        }
        .frame(minWidth: 400, minHeight: 400)
    }
}
