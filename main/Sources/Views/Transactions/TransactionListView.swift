import SwiftUI

struct TransactionListView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var searchText = ""
    @State private var filter: FilterType = .all
    @State private var pendingDelete: Transaction?
    @State private var listOpacity = 0.0

    enum FilterType: String, CaseIterable { case all, income, expense }

    var filtered: [Transaction] {
        var result = viewModel.transactions
        switch filter {
        case .income: result = result.filter { $0.type == .income }
        case .expense: result = result.filter { $0.type == .expense }
        case .all: break
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                ($0.merchant ?? "").localizedCaseInsensitiveContains(q) ||
                ($0.note ?? "").localizedCaseInsensitiveContains(q) ||
                ($0.category ?? "").localizedCaseInsensitiveContains(q)
            }
        }
        return result
    }

    var groupedByDate: [(String, [Transaction])] {
        let grouped = Dictionary(grouping: filtered) { $0.date }
        return grouped.sorted { $0.key > $1.key }
    }

    private var filteredTotal: Double {
        filtered.reduce(0) { $0 + $1.signedAmount }
    }

    var body: some View {
        List {
            Section {
                ActivitySummaryCard(
                    count: filtered.count,
                    total: filteredTotal,
                    currency: viewModel.currency,
                    filterName: viewModel.loc(filter.rawValue.capitalized)
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            ForEach(Array(groupedByDate.enumerated()), id: \.element.0) { sectionIndex, group in
                let (date, items) = group
                Section {
                    ForEach(Array(items.enumerated()), id: \.element.id) { itemIndex, tx in
                        TransactionRow(transaction: tx, currency: viewModel.currency)
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .staggeredEntrance(index: itemIndex)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteTransaction(tx) }
                                } label: {
                                    Label(viewModel.loc("Delete"), systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text(formattedDate(date))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        let total = items.reduce(0) { $0 + $1.signedAmount }
                        Text(CurrencyFormat.formatSigned(total, currency: viewModel.currency))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
                }
            }
        }
        .listStyle(.plain)
        .clearSpendScreenBackground(theme: viewModel.theme)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: filter)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: searchText)
        .searchable(text: $searchText, prompt: viewModel.loc("Search transactions"))
        .navigationTitle(viewModel.loc("Activity"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Picker(viewModel.loc("Filter"), selection: $filter) {
                    ForEach(FilterType.allCases, id: \.self) { f in
                        Text(viewModel.loc(f.rawValue.capitalized)).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
        .overlay {
            if filtered.isEmpty && !viewModel.isLoadingData {
                ContentUnavailableView(
                    searchText.isEmpty ? viewModel.loc("No Transactions") : viewModel.loc("No Results"),
                    systemImage: searchText.isEmpty ? "tray" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? viewModel.loc("Add your first transaction") : viewModel.loc("Try a different search"))
                )
            }
        }
    }

    private func formattedDate(_ dateStr: String) -> String {
        guard let date = Date.fromDateString(dateStr) ?? Date.fromISOString(dateStr) else {
            return dateStr
        }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().locale(dateLocale))
    }

    private var dateLocale: Locale {
        switch viewModel.language {
        case "ja": return Locale(identifier: "ja_JP")
        case "zh": return Locale(identifier: "zh_Hans")
        default: return Locale(identifier: "en_US")
        }
    }
}

private struct ActivitySummaryCard: View {
    @Environment(AppViewModel.self) private var viewModel
    let count: Int
    let total: Double
    let currency: String
    let filterName: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "list.bullet.rectangle.portrait.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(filterName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.68))
                Text("\(count) \(viewModel.loc(count == 1 ? "transaction" : "transactions"))")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Text(CurrencyFormat.formatSigned(total, currency: currency))
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: viewModel.theme.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: viewModel.theme.primaryColor.opacity(0.20), radius: 18, y: 10)
    }
}
