import SwiftUI

struct TransactionRow: View {
    @Environment(AppViewModel.self) private var viewModel
    let transaction: Transaction
    let currency: String
    var isEmbedded = false

    var body: some View {
        rowContent
            .padding(.horizontal, isEmbedded ? 0 : 14)
            .padding(.vertical, isEmbedded ? 8 : 10)
            .modifier(TransactionRowSurface(isEmbedded: isEmbedded))
            .contentShape(.rect)
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            let cat = AppCategory.category(for: transaction.category, type: transaction.type)
            Image(systemName: cat.icon)
                .font(.caption)
                .foregroundStyle(cat.color)
                .frame(width: 34, height: 34)
                .background(cat.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

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
    }
}

private struct TransactionRowSurface: ViewModifier {
    let isEmbedded: Bool

    func body(content: Content) -> some View {
        if isEmbedded {
            content
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.04), radius: 10, y: 6)
        }
    }
}
