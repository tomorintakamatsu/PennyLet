import SwiftUI

struct TransactionRow: View {
    @Environment(AppViewModel.self) private var viewModel
    let transaction: Transaction
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            let cat = AppCategory.category(for: transaction.category, type: transaction.type)
            Image(systemName: cat.icon)
                .font(.caption)
                .foregroundStyle(cat.color)
                .frame(width: 34, height: 34)
                .background(cat.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant ?? transaction.note ?? viewModel.loc(cat.label))
                    .font(.subheadline.weight(.medium))
                Text(viewModel.loc(cat.label))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormat.formatSigned(transaction.signedAmount, currency: currency))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(transaction.type == .income ? .green : .primary)
                if let origCurrency = transaction.originalCurrency,
                   let origAmount = transaction.originalAmount {
                    let signedOrig = transaction.type == .expense ? -origAmount : origAmount
                    Text(CurrencyFormat.formatForeignSigned(signedOrig, currency: origCurrency))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if let date = transaction.dateValue {
                    Text(date, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
