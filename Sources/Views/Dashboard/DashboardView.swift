import SwiftUI

struct DashboardView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Binding var showAddSheet: Bool
    @State private var showSignInSheet = false
    @State private var showHelp = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection

                if viewModel.isGuestMode {
                    HStack(spacing: 10) {
                        Image(systemName: "person.fill.questionmark")
                            .foregroundStyle(viewModel.theme.primaryColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.loc("Guest Mode"))
                                .font(.subheadline.weight(.semibold))
                            Text(viewModel.loc("Sign in to save your data and unlock all features."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            showSignInSheet = true
                        } label: {
                            Text(viewModel.loc("Sign In"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(viewModel.theme.primaryColor, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }

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
            .padding(.bottom, 100)
        }
        .navigationTitle(viewModel.loc("ClearSpend"))
        .refreshable {
            await viewModel.refreshAll()
        }
        .overlay {
            if viewModel.isLoadingData && viewModel.transactions.isEmpty {
                ProgressView()
            }
        }
        .sheet(isPresented: $showSignInSheet) {
            SignInView()
                .environment(viewModel)
        }
        .onChange(of: viewModel.isAuthenticating) { _, new in
            if !new, !viewModel.isGuestMode { showSignInSheet = false }
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(Date.FormatStyle.dateTime.weekday(.wide).month(.wide).day().locale(locale)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .sheet(isPresented: $showHelp) {
            NavigationStack {
                helpView
            }
        }
    }

    private var helpView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(viewModel.loc("How ClearSpend Works"))
                    .font(.title2.weight(.bold))

                helpSection(
                    icon: "dollarsign.circle.fill",
                    title: viewModel.loc("Balance"),
                    body: helpText("balance", "This month's income minus expenses. Positive means you're in the green; negative means you're overspending.")
                )
                helpSection(
                    icon: "shield.checkered",
                    title: viewModel.loc("Safe to Spend Today"),
                    body: helpText("safe_daily", "(Monthly income − essentials − savings goal − already spent) ÷ days remaining. If you spend more than this per day, you'll run out before month-end.")
                )
                helpSection(
                    icon: "chart.pie.fill",
                    title: viewModel.loc("Top Categories"),
                    body: helpText("categories", "Your spending this month broken down by category. Instantly see where your money goes.")
                )
                helpSection(
                    icon: "sparkles",
                    title: viewModel.loc("AI Analysis"),
                    body: helpText("ai", "AI analyzes your spending patterns and provides daily, weekly, and monthly insights. Free tier includes limited uses.")
                )
                helpSection(
                    icon: "creditcard.fill",
                    title: viewModel.loc("Subscriptions"),
                    body: helpText("subscriptions", "Auto-detects App Store subscriptions on this device and shows monthly and yearly totals.")
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

    private func helpText(_ id: String, _ en: String) -> String {
        switch viewModel.language {
        case "ja": return viewModel.loc("help_\(id)")
        case "zh": return viewModel.loc("help_\(id)")
        default: return en
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
