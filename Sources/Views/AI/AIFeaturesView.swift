import SwiftUI
import Charts

struct AIFeaturesView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedTab = 0
    @State private var tabLoading: [Bool] = [false, false, false, false]
    @State private var tabErrors: [String?] = [nil, nil, nil, nil]

    private var tabResults: [AppViewModel.AIResult?] {
        [viewModel.currentDailyResult, viewModel.currentWeeklyResult, viewModel.currentMonthlyResult, viewModel.currentForecastResult]
    }
    @State private var showUpgradeSheet = false
    @State private var showUsageAlert = false
    @State private var showGuestUpgradePrompt = false
    @State private var showSignInSheet = false
    @State private var signInRegisterMode = false
    @State private var selectedHistoryItem: AnalysisHistory?

    private var tabLabels: [String] {
        var tabs = [viewModel.dailyTabLabel, viewModel.weeklyTabLabel, viewModel.monthlyTabLabel]
        if viewModel.isPro { tabs.append(viewModel.loc("Forecast")) }
        return tabs
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(viewModel.loc("Analysis"), selection: $selectedTab) {
                ForEach(tabLabels.indices, id: \.self) { i in
                    Text(tabLabels[i]).tag(i)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            TabView(selection: $selectedTab) {
                dailyTab.tag(0)
                weeklyTab.tag(1)
                monthlyTab.tag(2)
                if viewModel.isPro { forecastTab.tag(3) }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle(viewModel.aiInsightsTitle)
        .onAppear {
            if let sub = viewModel.initialAISubTab {
                selectedTab = sub
                viewModel.initialAISubTab = nil
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeView()
        }
        .alert(viewModel.usageExhaustedProTitle, isPresented: $showUsageAlert) {
            Button(viewModel.okLabel, role: .cancel) {}
        } message: {
            Text(viewModel.usageExhaustedProMessage)
        }
        .sheet(isPresented: $showGuestUpgradePrompt) {
            GuestUpgradeModal(showSignInSheet: $showSignInSheet, signInRegisterMode: $signInRegisterMode)
                .environment(viewModel)
        }
        .sheet(isPresented: $showSignInSheet) {
            SignInView(startInRegisterMode: signInRegisterMode)
                .environment(viewModel)
        }
        .onChange(of: viewModel.isAuthenticating) { _, new in
            if !new, !viewModel.isGuestMode { showSignInSheet = false }
        }
        .sheet(item: $selectedHistoryItem) { item in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let date = item.analysisDate ?? item.createdDate {
                            Text(formatDate(date))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(viewModel.theme.primaryColor)
                        }
                        Text(item.content)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if viewModel.isPro {
                            let charts = viewModel.chartsForHistory(item)
                            if !charts.category.isEmpty {
                                categoryChartView(charts.category)
                            }
                            if !charts.daily.isEmpty {
                                dailyChartView(charts.daily)
                            }
                        }
                    }
                    .padding(20)
                }
                .navigationTitle(viewModel.resultLabel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(role: .destructive) {
                            Task {
                                let id = item.id
                                selectedHistoryItem = nil
                                await viewModel.deleteAnalysisHistoryById(id)
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(viewModel.clearLabel) { selectedHistoryItem = nil }
                    }
                }
            }
        }
    }

    // MARK: - Daily Tab

    private var dailyTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                usageBadge(feature: "daily")

                if tabLoading[0] {
                    loadingView
                } else if let result = tabResults[0] {
                    resultView(result, tab: 0)
                } else if !viewModel.canUseFeature("daily") {
                    exhaustedView
                } else {
                    emptyView(
                        title: viewModel.dailyAnalysisTitle,
                        subtitle: viewModel.dailyAnalysisSubtitle,
                        feature: "daily"
                    ) {
                        await generate(for: 0) { try await viewModel.generateDailyAnalysis() }
                    }
                }

                if let e = tabErrors[0] {
                    errorView(e)
                }

                historySection(type: "daily")
            }
            .padding(20)
        }
    }

    // MARK: - Weekly Tab

    private var weeklyTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                usageBadge(feature: "recap")

                if tabLoading[1] {
                    loadingView
                } else if let result = tabResults[1] {
                    resultView(result, tab: 1)
                } else if !viewModel.canUseFeature("recap") {
                    exhaustedView
                } else {
                    emptyView(
                        title: viewModel.weeklyRecapTitle,
                        subtitle: viewModel.weeklyRecapSubtitle,
                        feature: "recap"
                    ) {
                        await generate(for: 1) { try await viewModel.generateWeeklyAnalysis() }
                    }
                }

                if let e = tabErrors[1] {
                    errorView(e)
                }

                historySection(type: "weekly")
            }
            .padding(20)
        }
    }

    // MARK: - Monthly Tab

    private var monthlyTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.canUseFeature("insight") == false && !viewModel.isPro {
                    upgradePrompt
                } else {
                    usageBadge(feature: "insight")

                    if tabLoading[2] {
                        loadingView
                    } else if let result = tabResults[2] {
                        resultView(result, tab: 2)
                    } else if !viewModel.canUseFeature("insight") {
                        exhaustedView
                    } else {
                        emptyView(
                            title: viewModel.monthlyInsightTitle,
                            subtitle: viewModel.monthlyInsightSubtitle,
                            feature: "insight"
                        ) {
                            await generate(for: 2) { try await viewModel.generateMonthlyAnalysis() }
                        }
                    }

                    if let e = tabErrors[2] {
                        errorView(e)
                    }

                    historySection(type: "monthly")
                }
            }
            .padding(20)
        }
    }

    // MARK: - Forecast Tab

    private var forecastTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                usageBadge(feature: "forecast")

                if tabLoading[3] {
                    loadingView
                } else if let result = tabResults[3] {
                    resultView(result, tab: 3)
                } else if !viewModel.canUseFeature("forecast") {
                    exhaustedView
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundStyle(viewModel.theme.primaryColor)
                        Text(viewModel.loc("Spending Forecast"))
                            .font(.title3.weight(.semibold))
                        Text(viewModel.loc("See AI-predicted spending for next month based on your history."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button {
                            handleGenerate(feature: "forecast") {
                                await generate(for: 3) { try await viewModel.generateForecast() }
                            }
                        } label: {
                            Label(viewModel.generateLabel, systemImage: "wand.and.stars")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(viewModel.theme.primaryColor, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }

                if let e = tabErrors[3] {
                    errorView(e)
                }

                historySection(type: "forecast")
            }
            .padding(20)
        }
    }

    // MARK: - Components

    private func usageBadge(feature: String) -> some View {
        let remaining = viewModel.remainingUses(feature)
        let limit = viewModel.usageLimit(feature)
        let used = limit - remaining
        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: remaining > 0 ? "circle.grid.3x3.fill" : "circle.slash")
                    .font(.system(size: 10))
                Text(viewModel.isPro
                    ? "\(used)/\(limit)"
                    : "\(remaining)/\(limit)")
            }
            .font(.caption2)
            .foregroundStyle(remaining > 0 ? Color.secondary : Color.orange)
            ProgressView(value: Double(used), total: Double(limit))
                .tint(remaining > 0 ? viewModel.theme.primaryColor : Color.orange)
                .scaleEffect(x: 1, y: 0.5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var exhaustedView: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.isPro ? "hourglass" : "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(viewModel.isPro ? .orange : .yellow)
            Text(viewModel.isPro
                ? viewModel.loc("Monthly Limit Reached")
                : viewModel.loc("Free Uses Exhausted"))
                .font(.title3.weight(.semibold))
            Text(viewModel.isPro
                ? viewModel.loc("Please wait until the first of next month for your usage to refresh.")
                : viewModel.loc("Upgrade to ClearSpend Pro for more analyses and unlimited access."))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if !viewModel.isPro {
                Button {
                    showUpgradeOrGuestPrompt()
                } label: {
                    Text(viewModel.upgradeToProLabel)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.yellow, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(viewModel.generatingLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func resultView(_ r: AppViewModel.AIResult, tab: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(viewModel.theme.primaryColor)
                Text(viewModel.resultLabel)
                    .font(.headline)
                Spacer()
                Button(viewModel.clearLabel) {
                    switch tab {
                    case 0: viewModel.currentDailyResult = nil
                    case 1: viewModel.currentWeeklyResult = nil
                    case 2: viewModel.currentMonthlyResult = nil
                    case 3: viewModel.currentForecastResult = nil
                    default: break
                    }
                }
                .font(.caption)
            }
            Text(r.text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.isPro {
                if !r.categoryChart.isEmpty {
                    categoryChartView(r.categoryChart)
                }
                if !r.dailyChart.isEmpty {
                    dailyChartView(r.dailyChart)
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Charts (Pro only)

    private let chartColors: [Color] = [
        Color(red: 0.94, green: 0.35, blue: 0.31),
        Color(red: 0.18, green: 0.67, blue: 0.95),
        Color(red: 0.96, green: 0.61, blue: 0.14),
        Color(red: 0.33, green: 0.73, blue: 0.35),
        Color(red: 0.64, green: 0.27, blue: 0.83),
        Color(red: 0.96, green: 0.20, blue: 0.49),
        Color(red: 0.00, green: 0.69, blue: 0.69),
        Color(red: 0.55, green: 0.55, blue: 0.85),
    ]

    private func categoryChartView(_ data: [(name: String, amount: Double)]) -> some View {
        let grouped = groupSmallCategories(data)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.caption)
                    .foregroundStyle(viewModel.theme.primaryColor)
                Text(viewModel.loc("Category Breakdown"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Chart(grouped, id: \.name) { item in
                SectorMark(
                    angle: .value("Amount", item.amount),
                    angularInset: 1
                )
                .foregroundStyle(by: .value("Category", item.name))
            }
            .chartForegroundStyleScale(
                domain: grouped.map(\.name),
                range: grouped.indices.map { chartColors[$0 % chartColors.count] }
            )
            .chartLegend(position: .bottom, spacing: 8)
            .frame(height: 220)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func dailyChartView(_ data: [(day: String, amount: Double)]) -> some View {
        let topItems = Array(data.sorted(by: { $0.amount > $1.amount }).prefix(8))
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.caption)
                    .foregroundStyle(viewModel.theme.primaryColor)
                Text(viewModel.loc("Weekly Trend"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Chart(topItems, id: \.day) { item in
                BarMark(
                    x: .value("Category", item.day),
                    y: .value("Amount", item.amount)
                )
                .foregroundStyle(by: .value("Category", item.day))
            }
            .chartForegroundStyleScale(
                domain: topItems.map(\.day),
                range: topItems.indices.map { chartColors[$0 % chartColors.count] }
            )
            .chartLegend(.hidden)
            .frame(height: 200)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func groupSmallCategories(_ data: [(name: String, amount: Double)]) -> [(name: String, amount: Double)] {
        let total = data.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return data }
        var result: [(name: String, amount: Double)] = []
        var otherAmount: Double = 0
        for item in data.sorted(by: { $0.amount > $1.amount }) {
            if item.amount / total < 0.04 && result.count >= 7 {
                otherAmount += item.amount
            } else {
                result.append(item)
            }
        }
        if otherAmount > 0 {
            result.append((name: viewModel.loc("Other"), amount: otherAmount))
        }
        return result
    }

    private func emptyView(title: String, subtitle: String, feature: String, action: @escaping () async -> Void) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(viewModel.theme.primaryColor)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                handleGenerate(feature: feature, action: action)
            } label: {
                Label(viewModel.generateLabel, systemImage: "wand.and.stars")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(viewModel.theme.primaryColor, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func historySection(type: String) -> some View {
        let filtered = viewModel.analysisHistory.filter { $0.type == type }
        if !filtered.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.historyLabel)
                    .font(.headline)
                    .padding(.top, 8)

                ForEach(filtered) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        if let date = item.analysisDate ?? item.createdDate {
                            Text(formatDate(date))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(viewModel.theme.primaryColor)
                        }
                        Text(item.content)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                    .onTapGesture { selectedHistoryItem = item }
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteAnalysisHistory(item) }
                        } label: {
                            Label(viewModel.deleteLabel, systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var upgradePrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)
            Text(viewModel.monthlyInsightRequiresPro)
                .font(.title3.weight(.semibold))
            Text(viewModel.upgradeDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                showUpgradeOrGuestPrompt()
            } label: {
                Text(viewModel.upgradeToProLabel)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.yellow, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Actions

    private func showUpgradeOrGuestPrompt() {
        if viewModel.isGuestMode {
            showGuestUpgradePrompt = true
        } else {
            showUpgradeSheet = true
        }
    }

    private func handleGenerate(feature: String, action: @escaping () async -> Void) {
        if viewModel.canUseFeature(feature) {
            Task { await action() }
        } else if viewModel.isPro {
            showUsageAlert = true
        } else {
            showUpgradeOrGuestPrompt()
        }
    }

    private func generate(for tab: Int, operation: @escaping () async throws -> AppViewModel.AIResult) async {
        tabLoading[tab] = true
        tabErrors[tab] = nil
        // Clear current before generating new
        switch tab {
        case 0: viewModel.currentDailyResult = nil
        case 1: viewModel.currentWeeklyResult = nil
        case 2: viewModel.currentMonthlyResult = nil
        case 3: viewModel.currentForecastResult = nil
        default: break
        }
        do {
            _ = try await operation()
        } catch {
            tabErrors[tab] = error.localizedDescription
        }
        tabLoading[tab] = false
    }

    private var dateLocale: Locale {
        switch viewModel.language {
        case "ja": return Locale(identifier: "ja_JP")
        case "zh": return Locale(identifier: "zh_Hans")
        default: return Locale(identifier: "en_US")
        }
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) {
            return date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(dateLocale))
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: iso) {
            return date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(dateLocale))
        }
        return iso
    }
}
