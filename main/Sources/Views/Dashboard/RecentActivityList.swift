import SwiftUI

struct RecentActivityList: View {
    @Environment(AppViewModel.self) private var viewModel
    let transactions: [Transaction]
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(viewModel.loc("Recent Activity"), systemImage: "waveform.path.ecg")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    TransactionListView()
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.loc("View All"))
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(viewModel.theme.primaryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(viewModel.theme.primaryColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                }
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
                    ForEach(Array(transactions.enumerated()), id: \.element.id) { index, tx in
                        TransactionRow(transaction: tx, currency: currency, isEmbedded: true)
                        if index < transactions.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(18)
        .premiumPanel(tint: viewModel.theme.primaryColor)
    }
}
