import SwiftUI

struct WisdomView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", stoic = "Stoic", hindu = "Hindu", saved = "Saved"
        var id: String { rawValue }
    }

    @Environment(AppStore.self) private var store
    @State private var filter: Filter = .all
    @State private var search = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if search.isEmpty {
                        QuoteCard(quote: store.dailyQuote, title: "Today's wisdom", showOriginal: store.prefs.showSanskrit)
                    }
                    Picker("Show", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)

                    let quotes = filtered
                    if quotes.isEmpty {
                        Text(filter == .saved ? "Tap the heart on any quote to save it here." : "No quotes match that search.")
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                    }
                    ForEach(quotes) { quote in
                        QuoteRow(quote: quote, showOriginal: store.prefs.showSanskrit)
                    }
                    Text("Stoic passages follow public-domain translations, lightly modernised. Sanskrit verses are translated from the original. Every quote names its source.")
                        .font(.caption)
                        .foregroundStyle(Palette.ink2)
                        .padding(.top, 8)
                }
                .padding(16)
                .animation(.snappy, value: filter)
            }
            .background(Palette.paper)
            .navigationTitle("Wisdom")
            .searchable(text: $search, prompt: "Search words or sources")
        }
    }

    private var filtered: [Quote] {
        var list = store.quotes.quotes
        switch filter {
        case .all: break
        case .stoic: list = list.filter { $0.tradition == .stoic }
        case .hindu: list = list.filter { $0.tradition == .hindu }
        case .saved: list = list.filter { store.isFavorite($0) }
        }
        let query = search.trimmed.lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.text.lowercased().contains(query) || $0.cite.lowercased().contains(query) || ($0.transliteration?.lowercased().contains(query) ?? false)
            }
        }
        return list
    }
}

struct QuoteRow: View {
    var quote: Quote
    var showOriginal: Bool

    @Environment(AppStore.self) private var store

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TraditionMark(tradition: quote.tradition)
                    Spacer()
                    Button {
                        store.toggleFavorite(quote)
                    } label: {
                        Image(systemName: store.isFavorite(quote) ? "heart.fill" : "heart")
                            .foregroundStyle(store.isFavorite(quote) ? Palette.danger : Palette.ink2)
                            .symbolEffect(.bounce, value: store.isFavorite(quote))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(store.isFavorite(quote) ? "Remove from saved" : "Save quote")
                }
                QuoteBlock(quote: quote, showOriginal: showOriginal, size: 16)
            }
        }
    }
}
