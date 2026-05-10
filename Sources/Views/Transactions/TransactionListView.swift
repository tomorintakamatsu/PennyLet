import SwiftUI

struct TransactionListView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var searchText = ""
    @State private var filter: FilterType = .all
    @State private var pendingDelete: Transaction?

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

    var body: some View {
        List {
            ForEach(groupedByDate, id: \.0) { date, items in
                Section {
                    ForEach(items) { tx in
                        TransactionRow(transaction: tx, currency: viewModel.currency)
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
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
                            .foregroundStyle(.secondary)
                        Spacer()
                        let total = items.reduce(0) { $0 + $1.signedAmount }
                        Text(CurrencyFormat.formatSigned(total, currency: viewModel.currency))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: viewModel.loc("Search transactions"))
        .navigationTitle(viewModel.loc("Activity"))
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
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}
