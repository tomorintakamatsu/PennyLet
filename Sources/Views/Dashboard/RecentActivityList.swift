import SwiftUI

struct RecentActivityList: View {
    @Environment(AppViewModel.self) private var viewModel
    let transactions: [Transaction]
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewModel.loc("Recent Activity"))
                    .font(.headline)
                Spacer()
                NavigationLink(viewModel.loc("View All")) {
                    TransactionListView()
                }
                .font(.subheadline)
            }

            if transactions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(viewModel.loc("No transactions yet"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 4) {
                    ForEach(transactions) { tx in
                        TransactionRow(transaction: tx, currency: currency)
                    }
                }
            }
        }
    }
}
