import SwiftUI

struct TopCategoriesList: View {
    @Environment(AppViewModel.self) private var viewModel
    let breakdown: [CategoryBreakdown]
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(viewModel.loc("Top Categories"), systemImage: "chart.pie.fill")
                    .font(.headline)
                Spacer()
                Text(viewModel.loc("This month"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

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
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.quaternary)
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [cat.color, cat.color.opacity(0.45)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(geo.size.width * CGFloat(pct), 4), height: 8)
                            }
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
        .premiumPanel(tint: viewModel.theme.primaryColor)
    }
}
