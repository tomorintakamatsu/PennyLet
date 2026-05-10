import SwiftUI

struct TopCategoriesList: View {
    @Environment(AppViewModel.self) private var viewModel
    let breakdown: [CategoryBreakdown]
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.loc("Top Categories"))
                .font(.headline)

            if breakdown.isEmpty {
                Text(viewModel.loc("No spending this month"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(breakdown.prefix(5)) { item in
                    let cat = item.category
                    let total = breakdown.reduce(0) { $0 + $1.amount }
                    let pct = total > 0 ? item.amount / total : 0

                    HStack(spacing: 12) {
                        Image(systemName: cat.icon)
                            .font(.caption)
                            .foregroundStyle(cat.color)
                            .frame(width: 28, height: 28)
                            .background(cat.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                        Text(viewModel.loc(cat.label))
                            .font(.subheadline)
                            .frame(width: 100, alignment: .leading)

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(cat.color.opacity(0.3))
                                .frame(width: max(geo.size.width * CGFloat(pct), 4), height: 8)
                        }
                        .frame(height: 8)

                        Text(CurrencyFormat.format(item.amount, currency: currency))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .trailing)
                    }
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
