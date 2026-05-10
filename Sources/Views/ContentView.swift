import SwiftUI

struct ContentView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedTab = 0
    @State private var showAddSheet = false
    @State private var showSettings = false
    @State private var showUpgrade = false

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
                    SubscriptionTrackerView()
                        .toolbar { settingsButton }
                }
                .tabItem { Label(viewModel.loc("Subscriptions"), systemImage: "creditcard.fill") }
                .tag(4)

                NavigationStack {
                    BudgetHealthView()
                        .toolbar { settingsButton }
                }
                .tabItem { Label(viewModel.healthTab, systemImage: "heart.fill") }
                .tag(5)
            }

            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(viewModel.theme.primaryColor, in: Circle())
                    .shadow(color: viewModel.theme.primaryColor.opacity(0.4), radius: 10, y: 4)
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
            if let tab = new { selectedTab = tab }
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
