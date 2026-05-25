import SwiftUI

struct DashboardView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Binding var showAddSheet: Bool
    @State private var showHelp = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection

                SpendHeroCard(summary: viewModel.spendSummary, currency: viewModel.currency, theme: viewModel.theme)
                    .cardEntrance()
                QuickStatsRow(summary: viewModel.spendSummary, currency: viewModel.currency)
                    .cardEntrance()
                TopCategoriesList(breakdown: viewModel.categoryBreakdown, currency: viewModel.currency)
                    .cardEntrance()
                RecentActivityList(transactions: viewModel.recentTransactions, currency: viewModel.currency)
                    .cardEntrance()

                if viewModel.transactions.isEmpty && !viewModel.isLoadingData {
                    Text(viewModel.loc("No transactions yet"))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 100)
        }
        .clearSpendScreenBackground(theme: viewModel.theme)
        .navigationTitle(viewModel.loc("PennyLet"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.refreshAll()
        }
        .overlay {
            if viewModel.isLoadingData && viewModel.transactions.isEmpty {
                ProgressView()
            }
        }
    }

    private var locale: Locale {
        switch viewModel.language {
        case "ja": return Locale(identifier: "ja_JP")
        case "zh": return Locale(identifier: "zh_Hans")
        default: return Locale(identifier: "en_US")
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.loc("PennyLet"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Text(Date.now.formatted(Date.FormatStyle.dateTime.weekday(.wide).month(.wide).day().locale(locale)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(viewModel.theme.primaryColor)
                    .frame(width: 42, height: 42)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(viewModel.theme.primaryColor.opacity(0.12), lineWidth: 1)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showHelp) {
            NavigationStack {
                helpView
            }
        }
    }

    private var helpView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(viewModel.loc("How PennyLet Works"))
                    .font(.title2.weight(.bold))

                helpSection(
                    icon: "dollarsign.circle.fill",
                    title: viewModel.loc("Balance"),
                    body: viewModel.loc("This month's income minus expenses. Positive means you're in the green; negative means you're overspending.")
                )
                helpSection(
                    icon: "shield.checkered",
                    title: viewModel.loc("Safe to Spend Today"),
                    body: viewModel.loc("(Monthly income − essentials − savings goal − already spent) ÷ days remaining. If you spend more than this per day, you'll run out before month-end.")
                )
                helpSection(
                    icon: "chart.pie.fill",
                    title: viewModel.loc("Top Categories"),
                    body: viewModel.loc("Your spending this month broken down by category. Instantly see where your money goes.")
                )
                helpSection(
                    icon: "sparkles",
                    title: viewModel.loc("AI Analysis"),
                    body: viewModel.loc("AI analyzes your spending patterns and provides daily, weekly, and monthly insights. Free tier includes limited uses.")
                )
                helpSection(
                    icon: "creditcard.fill",
                    title: viewModel.loc("Subscriptions"),
                    body: viewModel.loc("Auto-detects App Store subscriptions on this device and shows monthly and yearly totals.")
                )
            }
            .padding(24)
        }
        .navigationTitle(viewModel.loc("Help"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(viewModel.loc("Done")) { showHelp = false }
            }
        }
    }

    private func helpSection(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(viewModel.theme.primaryColor)
                    .frame(width: 24)
                Text(title)
                    .font(.headline)
            }
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
