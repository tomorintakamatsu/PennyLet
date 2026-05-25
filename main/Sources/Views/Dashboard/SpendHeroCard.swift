import SwiftUI

struct SpendHeroCard: View {
    @Environment(AppViewModel.self) private var viewModel
    let summary: SpendSummary
    let currency: String
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(viewModel.loc("Safe to Spend Today"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.70))
                    Text(viewModel.loc("Daily spending lane"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Image(systemName: "shield.lefthalf.filled")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
            }

            Text(CurrencyFormat.format(summary.safeDaily, currency: currency))
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            progressBar

            HStack {
                Label("\(summary.daysLeft)" + viewModel.loc("d left"), systemImage: "calendar")
                Spacer()
                Text("\(Int(summary.spendPercent))" + viewModel.loc("% used"))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.64))
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: theme.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 86, weight: .semibold))
                .foregroundStyle(.white.opacity(0.08))
                .offset(x: 16, y: 18)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: theme.primaryColor.opacity(0.26), radius: 20, y: 10)
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
