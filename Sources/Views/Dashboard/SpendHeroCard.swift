import SwiftUI

struct SpendHeroCard: View {
    @Environment(AppViewModel.self) private var viewModel
    let summary: SpendSummary
    let currency: String
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 14) {
            Text(viewModel.loc("Safe to Spend Today"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))

            Text(CurrencyFormat.format(summary.safeDaily, currency: currency))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            progressBar
                .padding(.horizontal, 8)

            HStack {
                Label("\(summary.daysLeft)" + viewModel.loc("d left"), systemImage: "calendar")
                Spacer()
                Text("\(Int(summary.spendPercent))" + viewModel.loc("% used"))
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.5))
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: theme.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .shadow(color: theme.primaryColor.opacity(0.3), radius: 15, y: 8)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white.opacity(0.2))
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white)
                    .frame(width: geo.size.width * CGFloat(min(summary.spendPercent / 100, 1)), height: 8)
            }
        }
        .frame(height: 8)
    }
}

