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
                    .background(viewModel.theme.primaryColor, in: Circle())
                    .shadow(color: viewModel.theme.primaryColor.opacity(0.4), radius: 10, y: 4)
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
        List {
            NavigationLink {
                SubscriptionTrackerView()
            } label: {
                Label(viewModel.loc("Subscriptions"), systemImage: "creditcard.fill")
            }

            NavigationLink {
                BudgetHealthView()
            } label: {
                Label(viewModel.loc("Budget Health"), systemImage: "heart.fill")
            }
        }
        .navigationTitle(viewModel.moreTab)
    }
}
