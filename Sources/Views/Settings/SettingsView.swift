import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var exportItem: ExportShareItem?
    @State private var showCSVImport = false
    @State private var showResetConfirm = false
    @State private var importResult: (success: Bool, count: Int)?
    @State private var exportSuccess = false
    @State private var exportFileName = "clearspend_export"
    @State private var showFileNamePrompt = false
    @State private var pendingResetAfterExport = false
    @State private var ratesRefreshed = false
    @State private var developerTapCount = 0
    @State private var showDeveloperControls = false
    @State private var showDeveloperUnlockAlert = false

    // Editable budget fields
    @State private var incomeText: String = ""
    @State private var essentialsText: String = ""
    @State private var savingsText: String = ""
    @State private var payDayVal: Int = 1
    @State private var budgetSaveTimer: Task<Void, Never>?

    private let currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "HKD", "SGD", "KRW", "BRL"]
    private let languages: [(String, String)] = [
        ("en", "English"), ("ja", "日本語"), ("zh", "中文"),
    ]

    private var timeOptions: [String] {
        stride(from: 0, to: 24, by: 1).flatMap { h in
            [String(format: "%02d:00", h), String(format: "%02d:30", h)]
        }
    }

    var body: some View {
        Form {
            appearanceSection
            budgetSection
            preferencesSection
            analysisSection
            dataSection
            accountSection
            if showDeveloperControls || viewModel.isDeveloperMode {
                developerSection
            }
            legalSection
        }
        .navigationTitle(viewModel.settingsTitle)
        .keyboardDoneButton(viewModel.loc("Done"))
        .sheet(item: $exportItem, onDismiss: {
            exportSuccess = true
        }) { item in
            ActivityView(activityItems: [item.url])
        }
        .alert(viewModel.loc("Export Successful"), isPresented: $exportSuccess) {
            Button(viewModel.loc("OK"), role: .cancel) {
                if pendingResetAfterExport {
                    viewModel.restoreDefaults()
                    pendingResetAfterExport = false
                }
            }
        } message: {
            Text("\(viewModel.loc("File saved as")) \(exportFileName).csv")
        }
        .alert(importResult?.success == true ? viewModel.loc("Import Successful") : viewModel.loc("Import Failed"), isPresented: Binding(
            get: { importResult != nil },
            set: { if !$0 { importResult = nil } }
        )) {
            Button(viewModel.loc("OK"), role: .cancel) {}
        } message: {
            if let r = importResult, r.success {
                Text("\(viewModel.loc("Imported")) \(r.count) \(viewModel.loc("transactions successfully."))")
            } else {
                Text(viewModel.loc("The file could not be read. Check the format and try again."))
            }
        }
        .alert(viewModel.loc("Export & Reset"), isPresented: $showResetConfirm) {
            Button(viewModel.loc("Export CSV & Reset")) { exportAndReset() }
            Button(viewModel.loc("Reset Without Export"), role: .destructive) { viewModel.restoreDefaults() }
            Button(viewModel.cancelLabel, role: .cancel) {}
        } message: {
            Text(viewModel.loc("Save your data as CSV before resetting? All local data will be cleared."))
        }
        .alert(viewModel.devModeEnabled, isPresented: $showDeveloperUnlockAlert) {
            Button(viewModel.okLabel, role: .cancel) {}
        } message: {
            Text(viewModel.developerUnlockMessage)
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section(viewModel.appearanceSection) {
            themePicker
            colorModePicker
            fontPicker
            weekStartPicker
        }
    }

    private var themePicker: some View {
        HStack(spacing: 12) {
            Text(viewModel.themeLabel)
            Spacer()
            ForEach(AppTheme.allCases, id: \.self) { theme in
                Button {
                    viewModel.theme = theme
                    savePreferences()
                } label: {
                    Circle()
                        .fill(theme.primaryColor)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .strokeBorder(.primary, lineWidth: viewModel.theme == theme ? 3 : 0)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var colorModePicker: some View {
        Picker(viewModel.colorModeLabel, selection: Binding(
            get: { viewModel.colorMode },
            set: { viewModel.colorMode = $0; savePreferences() }
        )) {
            ForEach(AppColorMode.allCases, id: \.self) { mode in
                Text(viewModel.loc(mode.label)).tag(mode)
            }
        }
    }

    private var fontPicker: some View {
        Picker(viewModel.fontLabel, selection: Binding(
            get: { viewModel.font },
            set: { viewModel.font = $0; savePreferences() }
        )) {
            ForEach(AppFont.allCases, id: \.self) { font in
                Text(viewModel.loc(font.label)).tag(font)
            }
        }
    }

    private var weekStartPicker: some View {
        Picker(viewModel.weekStartsLabel, selection: Binding(
            get: { viewModel.currentBudget?.startOfWeek ?? "sunday" },
            set: { savePreference("start_of_week", $0) }
        )) {
            Text(viewModel.sundayLabel).tag("sunday")
            Text(viewModel.mondayLabel).tag("monday")
        }
    }

    // MARK: - Budget

    private var budgetSection: some View {
        Section(viewModel.budgetSection) {
            HStack {
                Text(viewModel.currency == "JPY" ? "¥" : "$").foregroundStyle(.secondary)
                TextField(viewModel.monthlyIncomeLabel, text: $incomeText)
                    .keyboardType(.decimalPad)
            }
            .onChange(of: incomeText) { _ in scheduleBudgetSave() }

            HStack {
                Text(viewModel.currency == "JPY" ? "¥" : "$").foregroundStyle(.secondary)
                TextField(viewModel.essentialsLabel, text: $essentialsText)
                    .keyboardType(.decimalPad)
            }
            .onChange(of: essentialsText) { _ in scheduleBudgetSave() }

            HStack {
                Text(viewModel.currency == "JPY" ? "¥" : "$").foregroundStyle(.secondary)
                TextField(viewModel.savingsGoalLabel, text: $savingsText)
                    .keyboardType(.decimalPad)
            }
            .onChange(of: savingsText) { _ in scheduleBudgetSave() }

            Stepper("\(viewModel.payDayLabel): \(payDayVal)", value: $payDayVal, in: 1...31)
                .onChange(of: payDayVal) { _ in saveBudgetNow() }
        }
        .onAppear {
            if let budget = viewModel.currentBudget {
                incomeText = String(format: "%.0f", budget.monthlyIncome)
                essentialsText = budget.monthlyEssentials.map { String(format: "%.0f", $0) } ?? ""
                savingsText = budget.monthlySavingsGoal.map { String(format: "%.0f", $0) } ?? ""
                payDayVal = budget.payDay ?? 1
            }
        }
        .onChange(of: viewModel.currentBudget?.id) { _ in
            if let budget = viewModel.currentBudget {
                incomeText = String(format: "%.0f", budget.monthlyIncome)
                essentialsText = budget.monthlyEssentials.map { String(format: "%.0f", $0) } ?? ""
                savingsText = budget.monthlySavingsGoal.map { String(format: "%.0f", $0) } ?? ""
                payDayVal = budget.payDay ?? 1
            }
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        Section(viewModel.preferencesSection) {
            Picker(viewModel.currencyLabel, selection: Binding(
                get: { viewModel.currency },
                set: { viewModel.currency = $0; savePreferences() }
            )) {
                ForEach(currencies, id: \.self) { c in
                    Text("\(c) (\(CurrencyFormat.currencySymbol(for: c)))").tag(c)
                }
            }
            Picker(viewModel.languageLabel, selection: Binding(
                get: { viewModel.language },
                set: { viewModel.language = $0; savePreferences() }
            )) {
                ForEach(languages, id: \.0) { code, name in
                    Text(name).tag(code)
                }
            }
        }
    }

    // MARK: - Analysis Scheduling

    @State private var showAutoAnalysisHelp = false

    @ViewBuilder
    private var analysisSection: some View {
        if viewModel.isPro {
            Section {
                Toggle(viewModel.autoAnalysisLabel, isOn: Binding(
                    get: { viewModel.currentBudget?.autoAnalysisEnabled ?? false },
                    set: { savePreference("auto_analysis_enabled", $0) }
                ))
                if viewModel.currentBudget?.autoAnalysisEnabled == true {
                HStack {
                    Text(viewModel.dailyTabLabel).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { viewModel.currentBudget?.dailyAnalysisTime ?? "21:00" },
                        set: { savePreference("daily_analysis_time", $0) }
                    )) {
                        ForEach(timeOptions, id: \.self) { Text($0).tag($0) }
                    }
                }
                HStack {
                    Text(viewModel.weeklyTabLabel).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { viewModel.currentBudget?.weeklyAnalysisTime ?? "09:00" },
                        set: { savePreference("weekly_analysis_time", $0) }
                    )) {
                        ForEach(timeOptions, id: \.self) { Text($0).tag($0) }
                    }
                }
                HStack {
                    Text(viewModel.monthlyTabLabel).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { viewModel.currentBudget?.monthlyAnalysisTime ?? "09:00" },
                        set: { savePreference("monthly_analysis_time", $0) }
                    )) {
                        ForEach(timeOptions, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
        } header: {
            HStack {
                Text(viewModel.analysisSectionLabel)
                Spacer()
                Button {
                    showAutoAnalysisHelp = true
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundStyle(viewModel.theme.primaryColor)
                }
            }
        }
        .alert(viewModel.loc("Auto Analysis Help"), isPresented: $showAutoAnalysisHelp) {
            Button(viewModel.loc("OK"), role: .cancel) {}
        } message: {
            Text(viewModel.loc("Auto Analysis automatically generates daily, weekly, and monthly AI spending insights at your scheduled times. Enable it and set your preferred times below."))
        }
    }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section(viewModel.dataSectionLabel) {
            Button {
                pendingResetAfterExport = false
                showFileNamePrompt = true
            } label: {
                Label(viewModel.exportCSVLabel, systemImage: "square.and.arrow.up")
            }
            Button {
                showCSVImport = true
            } label: {
                Label(viewModel.loc("Import CSV"), systemImage: "square.and.arrow.down")
            }
            Button {
                Task {
                    await viewModel.refreshExchangeRates()
                    ratesRefreshed = true
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    ratesRefreshed = false
                }
            } label: {
                Label(
                    ratesRefreshed ? viewModel.loc("Exchange rates updated") : viewModel.loc("Refresh Exchange Rates"),
                    systemImage: ratesRefreshed ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath"
                )
            }
            .disabled(ratesRefreshed)
        }
        .fileImporter(isPresented: $showCSVImport, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            if case .success(let url) = result {
                importCSV(from: url)
            }
        }
        .alert(viewModel.loc("Export CSV"), isPresented: $showFileNamePrompt) {
            TextField(viewModel.loc("File name"), text: $exportFileName)
            Button(viewModel.loc("Export")) { exportCSV() }
            Button(viewModel.cancelLabel, role: .cancel) {}
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Section(viewModel.accountSectionLabel) {
            Button {
                registerDeveloperTap()
            } label: {
                HStack {
                    Label(viewModel.appVersionLabel, systemImage: "info.circle")
                    Spacer()
                    Text(appVersionString)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label(viewModel.loc("Export & Reset"), systemImage: "arrow.counterclockwise")
            }
        }
    }

    private var developerSection: some View {
        Section(viewModel.developerToolsLabel) {
            Toggle(isOn: Binding(
                get: { viewModel.isDeveloperMode },
                set: { viewModel.setDeveloperMode($0) }
            )) {
                Label(viewModel.developerProAccessLabel, systemImage: viewModel.isDeveloperMode ? "crown.fill" : "crown")
            }

            Text(viewModel.isDeveloperMode ? viewModel.devModeUnlimited : viewModel.developerModeDisabledMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var legalSection: some View {
        Section {
            Link(destination: URL(string: "https://tomorintakamatsu.github.io/clearspend-privacy/privacy-policy.pdf")!) {
                Label(viewModel.loc("Privacy Policy"), systemImage: "hand.raised.fill")
            }
            Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                Label(viewModel.loc("Terms of Use (EULA)"), systemImage: "doc.text.fill")
            }
        }
    }

    // MARK: - Actions

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    private func registerDeveloperTap() {
        guard !showDeveloperControls else { return }
        developerTapCount += 1
        if developerTapCount >= 5 {
            developerTapCount = 0
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                showDeveloperControls = true
            }
            showDeveloperUnlockAlert = true
        }
    }

    private func scheduleBudgetSave() {
        budgetSaveTimer?.cancel()
        budgetSaveTimer = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            saveBudgetNow()
        }
    }

    private func saveBudgetNow() {
        guard let income = Double(incomeText.replacingOccurrences(of: ",", with: "")), income > 0,
              viewModel.currentBudget != nil else { return }
        // Only update the budget fields that changed; updateBudgetLocally preserves nil fields
        viewModel.updateBudgetLocally(BudgetData(
            monthlyIncome: income,
            monthlyEssentials: Double(essentialsText.replacingOccurrences(of: ",", with: "")),
            monthlySavingsGoal: Double(savingsText.replacingOccurrences(of: ",", with: "")),
            payDay: payDayVal
        ))
    }

    private func savePreferences() {
        guard let budget = viewModel.currentBudget else { return }
        let data = BudgetData(
            monthlyIncome: budget.monthlyIncome,
            monthlyEssentials: budget.monthlyEssentials,
            monthlySavingsGoal: budget.monthlySavingsGoal,
            payDay: budget.payDay,
            currency: viewModel.currency,
            language: viewModel.language,
            theme: viewModel.theme.rawValue,
            colorMode: viewModel.colorMode.rawValue,
            font: viewModel.font.rawValue
        )
        viewModel.updateBudgetLocally(data)
        viewModel.savePreferencesToDisk()
    }

    private func savePreference(_ key: String, _ value: Any) {
        guard let budget = viewModel.currentBudget else { return }
        var update = BudgetData(
            monthlyIncome: budget.monthlyIncome,
            monthlyEssentials: budget.monthlyEssentials,
            monthlySavingsGoal: budget.monthlySavingsGoal,
            payDay: budget.payDay,
            currency: budget.currency,
            language: budget.language,
            theme: budget.theme,
            colorMode: budget.colorMode,
            font: budget.font
        )
        switch key {
        case "start_of_week": update.startOfWeek = value as? String
        case "auto_analysis_enabled": update.autoAnalysisEnabled = value as? Bool
        case "daily_analysis_time": update.dailyAnalysisTime = value as? String
        case "weekly_analysis_time": update.weeklyAnalysisTime = value as? String
        case "monthly_analysis_time": update.monthlyAnalysisTime = value as? String
        default: break
        }
        viewModel.updateBudgetLocally(update)
    }

    private func exportAndReset() {
        pendingResetAfterExport = true
        showFileNamePrompt = true
    }

    private func exportCSV() {
        var csv = viewModel.loc("Date,Type,Category,Amount,Note,Merchant,OriginalCurrency,OriginalAmount,ExchangeRate") + "\n"
        for tx in viewModel.transactions {
            let note = (tx.note ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let merchant = (tx.merchant ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let origCur = tx.originalCurrency ?? ""
            let origAmt = tx.originalAmount.map { String(format: "%.2f", $0) } ?? ""
            let xrate = tx.exchangeRate.map { String(format: "%.4f", $0) } ?? ""
            csv += "\(tx.date),\(tx.type.rawValue),\(tx.category ?? ""),\(tx.amount),\"\(note)\",\"\(merchant)\",\(origCur),\(origAmt),\(xrate)\n"
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(exportFileName).csv")
        try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
        exportItem = ExportShareItem(url: tempURL)
    }

    private func importCSV(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            importResult = (false, 0)
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            importResult = (false, 0)
            return
        }
        let lines = content.components(separatedBy: "\n").dropFirst()
        var count = 0
        for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            let cols = line.components(separatedBy: ",")
            guard cols.count >= 4 else { continue }
            let date = cols[0].trimmingCharacters(in: .whitespaces)
            let type: Transaction.TransactionType = cols[1].trimmingCharacters(in: .whitespaces).lowercased() == "income" ? .income : .expense
            let category = cols[2].trimmingCharacters(in: .whitespaces)
            let amount = Double(cols[3].trimmingCharacters(in: .whitespaces)) ?? 0
            let note = cols.count > 4 ? cols[4].replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespaces) : nil
            let merchant = cols.count > 5 ? cols[5].replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespaces) : nil
            let origCurrency: String? = {
                guard cols.count > 6 else { return nil }
                let c = cols[6].trimmingCharacters(in: .whitespaces)
                return c.isEmpty ? nil : c
            }()
            let origAmount = cols.count > 7 ? Double(cols[7].trimmingCharacters(in: .whitespaces)) : nil
            let exchangeRate = cols.count > 8 ? Double(cols[8].trimmingCharacters(in: .whitespaces)) : nil
            guard amount > 0 else { continue }
            let txn = Transaction(
                id: "import-\(UUID().uuidString)", amount: amount, type: type,
                category: category.isEmpty ? nil : category,
                note: note, date: date, merchant: merchant,
                isRecurring: false, tags: nil,
                originalCurrency: origCurrency,
                originalAmount: origAmount,
                exchangeRate: exchangeRate,
                baseCurrency: origCurrency != nil ? viewModel.currency : nil
            )
            viewModel.transactions.append(txn)
            count += 1
        }
        viewModel.saveLocalData()
        importResult = count > 0 ? (true, count) : (false, 0)
    }

}

struct ExportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// UIKit UIActivityViewController wrapped for SwiftUI
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
