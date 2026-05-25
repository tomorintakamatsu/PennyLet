import SwiftUI

struct ContentView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedTab = 0
    @State private var showAddSheet = false
    @State private var showSettings = false
    @State private var showUpgrade = false
    @State private var fabScale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    DashboardView(showAddSheet: $showAddSheet)
                        .toolbar { settingsButton }
                }
                .tabItem { Label(viewModel.homeTab, systemImage: "house.fill") }
                .tag(0)

                NavigationStack {
                    TransactionListView()
                        .toolbar { settingsButton }
                }
                .tabItem { Label(viewModel.activityTab, systemImage: "list.bullet") }
                .tag(1)

                NavigationStack {
                    GoalsView()
                        .toolbar { settingsButton }
                }
                .tabItem { Label(viewModel.goalsTab, systemImage: "target") }
                .tag(2)

                NavigationStack {
                    AIFeaturesView()
                        .toolbar { settingsButton }
                }
                .tabItem { Label(viewModel.aiTab, systemImage: "sparkles") }
                .tag(3)

                NavigationStack {
                    MoreView()
                        .toolbar { settingsButton }
                }
                .tabItem { Label(viewModel.moreTab, systemImage: "ellipsis.circle.fill") }
                .tag(4)
            }
            .id(viewModel.language)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedTab)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    fabScale = 0.85
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) {
                        fabScale = 1
                    }
                    showAddSheet = true
                }
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(
                            colors: [viewModel.theme.primaryColor, viewModel.theme.accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.35), lineWidth: 1)
                    }
                    .shadow(color: viewModel.theme.primaryColor.opacity(0.35), radius: 18, y: 8)
                    .scaleEffect(fabScale)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 90)
        }
        .sheet(isPresented: $showAddSheet) {
            AddTransactionView()
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToAITab)) { notif in
            selectedTab = 3
            // Pass sub-tab type via viewModel
            if let type = notif.object as? String {
                switch type {
                case "weekly": viewModel.initialAISubTab = 1
                case "monthly": viewModel.initialAISubTab = 2
                default: viewModel.initialAISubTab = 0
                }
            }
        }
        .onChange(of: viewModel.navigateToTab) { _, new in
            if let tab = new { selectedTab = min(tab, 4) }
        }
        .onChange(of: viewModel.isPro) { _, _ in }
    }

    private var settingsButton: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if !viewModel.isPro {
                Button {
                    showUpgrade = true
                } label: {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MoreView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MoreHeaderCard()

                VStack(spacing: 12) {
                    NavigationLink {
                        SubscriptionTrackerView()
                    } label: {
                        MoreDestinationCard(
                            icon: "creditcard.fill",
                            title: viewModel.loc("Subscriptions"),
                            subtitle: viewModel.loc("Track recurring charges and renewal dates."),
                            tint: viewModel.theme.primaryColor,
                            metric: "\(viewModel.recurringSubscriptions.filter(\.isActive).count)"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        BudgetHealthView()
                    } label: {
                        MoreDestinationCard(
                            icon: "heart.fill",
                            title: viewModel.loc("Budget Health"),
                            subtitle: viewModel.loc("See pacing, category pressure, and monthly health."),
                            tint: .pink,
                            metric: "\(Int(viewModel.spendSummary.spendPercent))%"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .navigationTitle(viewModel.moreTab)
        .background(
            LinearGradient(
                colors: [
                    viewModel.theme.primaryColor.opacity(0.10),
                    viewModel.theme.accentColor.opacity(0.08),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

private struct MoreHeaderCard: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.loc("Money cockpit"))
                        .font(.title2.weight(.bold))
                    Text(viewModel.loc("Subscriptions and deeper budget checks live here. Settings stays in the top corner."))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 10) {
                MiniMoreStat(
                    title: viewModel.loc("Safe today"),
                    value: CurrencyFormat.format(viewModel.spendSummary.safeDaily, currency: viewModel.currency)
                )
                MiniMoreStat(
                    title: viewModel.loc("Tracked subs"),
                    value: "\(viewModel.recurringSubscriptions.filter(\.isActive).count)"
                )
            }
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(
            LinearGradient(
                colors: [
                    viewModel.theme.primaryColor,
                    viewModel.theme.primaryColor.opacity(0.78),
                    viewModel.theme.accentColor.opacity(0.86)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(alignment: .topTrailing) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 86))
                .foregroundStyle(.white.opacity(0.10))
                .offset(x: 18, y: -14)
        }
        .shadow(color: viewModel.theme.primaryColor.opacity(0.24), radius: 22, y: 12)
    }
}

private struct MiniMoreStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))
            Text(value)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MoreDestinationCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let metric: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.22), tint.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(spacing: 5) {
                Text(metric)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 16, y: 8)
    }
}
