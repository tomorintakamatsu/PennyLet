import SwiftUI

struct WelcomeView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var step = 0
    @State private var monthlyIncome = ""
    @State private var monthlyEssentials = ""
    @State private var monthlySavings = ""
    @State private var payDay = 1
    @State private var selectedCurrency = "USD"
    @State private var selectedLanguage = "en"
    @State private var selectedTheme: AppTheme = .sage
    @State private var selectedColorMode: AppColorMode = .system
    @State private var selectedFont: AppFont = .inter
    @State private var isSaving = false
    @State private var onboardingError: String?
    @State private var showCSVImport = false
    @State private var csvImportResult: (success: Bool, count: Int)?
    private let currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "HKD", "SGD", "KRW", "BRL"]
    private let languages = ["en", "ja", "zh"]

    var body: some View {
        VStack {
            TabView(selection: $step) {
                splashStep.tag(0)
                preferencesStep.tag(1)
                budgetStep.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            if let error = onboardingError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            HStack {
                if step > 0 {
                    Button(viewModel.loc("Back")) { withAnimation { step -= 1 } }
                }
                Spacer()
                Button(step == 2 ? (isSaving ? viewModel.loc("Saving...") : viewModel.loc("Get Started")) : viewModel.loc("Next")) {
                    if step == 2 {
                        saveAndContinue()
                    } else {
                        onboardingError = nil
                        withAnimation { step += 1 }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
        .clearSpendScreenBackground(theme: selectedTheme)
    }

    private var splashStep: some View {
        VStack(spacing: 20) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(viewModel.loc("Welcome to PennyLet"))
                .font(.title.weight(.bold))
            Text(viewModel.loc("Track your spending, build healthy budgets, and reach your financial goals."))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Text(viewModel.loc("Your data is stored locally on this device."))
                .font(.caption)
                .foregroundStyle(.tertiary)

            Picker(viewModel.loc("Language"), selection: $selectedLanguage) {
                ForEach(languages, id: \.self) { code in
                    Text(viewModel.languageDisplayName(for: code)).tag(code)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)
            .onChange(of: selectedLanguage) { _, new in
                viewModel.language = new
                viewModel.savePreferencesToDisk()
            }

            Button {
                showCSVImport = true
            } label: {
                Label(viewModel.loc("Import CSV"), systemImage: "square.and.arrow.down")
                    .font(.subheadline)
                    .foregroundStyle(viewModel.theme.primaryColor)
            }

            Text(viewModel.loc("Skip manual setup by importing a CSV file of your transactions."))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .fileImporter(isPresented: $showCSVImport, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            if case .success(let url) = result {
                importCSV(from: url)
            }
        }
        .alert(csvImportResult?.success == true ? viewModel.loc("Import Successful") : viewModel.loc("Import Failed"), isPresented: Binding(
            get: { csvImportResult != nil },
            set: { if !$0 { csvImportResult = nil } }
        )) {
            Button(viewModel.loc("OK"), role: .cancel) {}
        } message: {
            if let r = csvImportResult, r.success {
                Text("\(viewModel.loc("Imported")) \(r.count) \(viewModel.loc("transactions successfully."))")
            } else {
                Text(viewModel.loc("The file could not be read. Check the format and try again."))
            }
        }
    }

    private var preferencesStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(viewModel.loc("Preferences"))
                    .font(.title2.weight(.bold))

                preferenceSection(viewModel.loc("Theme")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(AppTheme.allCases, id: \.self) { theme in
                                Button {
                                    selectedTheme = theme
                                } label: {
                                    VStack(spacing: 4) {
                                        Circle()
                                            .fill(theme.primaryColor)
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(.white, lineWidth: selectedTheme == theme ? 2 : 0)
                                            )
                                        Text(viewModel.loc(theme.label))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(width: 52)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                preferenceSection(viewModel.loc("Appearance")) {
                    Picker(viewModel.loc("Color Mode"), selection: $selectedColorMode) {
                        ForEach(AppColorMode.allCases, id: \.self) { mode in
                            Text(viewModel.loc(mode.label)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker(viewModel.loc("Font"), selection: $selectedFont) {
                        ForEach(AppFont.allCases, id: \.self) { font in
                            Text(viewModel.loc(font.label)).tag(font)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                preferenceSection(viewModel.loc("Currency")) {
                    Picker(viewModel.loc("Currency"), selection: $selectedCurrency) {
                        ForEach(currencies, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                    .onChange(of: selectedCurrency) { _, new in
                        viewModel.currency = new
                        viewModel.savePreferencesToDisk()
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .onChange(of: selectedTheme) { _, new in
            viewModel.theme = new
            viewModel.savePreferencesToDisk()
        }
        .onChange(of: selectedColorMode) { _, new in
            viewModel.colorMode = new
            viewModel.savePreferencesToDisk()
        }
        .onChange(of: selectedFont) { _, new in
            viewModel.font = new
            viewModel.savePreferencesToDisk()
        }
    }

    private var budgetStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(viewModel.loc("Your Budget"))
                    .font(.title2.weight(.bold))

                labeledField(viewModel.loc("Monthly Income"), value: $monthlyIncome, icon: "arrow.down.forward", hint: viewModel.loc("After tax"))
                    .keyboardType(.decimalPad)

                labeledField(viewModel.loc("Essential Bills"), value: $monthlyEssentials, icon: "house.fill", hint: viewModel.loc("Rent, utilities, etc."))
                    .keyboardType(.decimalPad)

                labeledField(viewModel.loc("Savings Goal"), value: $monthlySavings, icon: "banknote.fill", hint: viewModel.loc("Monthly target"))
                    .keyboardType(.decimalPad)

                HStack {
                    Label(viewModel.loc("Pay Day"), systemImage: "calendar")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $payDay) {
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    }
                }

            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private var analysisTimeOptions: [String] {
        stride(from: 0, to: 24, by: 1).flatMap { hour in
            [String(format: "%02d:00", hour), String(format: "%02d:30", hour)]
        }
    }

    private func preferenceSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func labeledField(_ label: String, value: Binding<String>, icon: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text("$")
                    .foregroundStyle(.secondary)
                TextField(hint, text: value)
                    .font(.title3)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func importCSV(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            csvImportResult = (false, 0)
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            csvImportResult = (false, 0)
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
            let note = cols.count > 4 ? cols[4].trimmingCharacters(in: .whitespaces) : nil
            let merchant = cols.count > 5 ? cols[5].trimmingCharacters(in: .whitespaces) : nil
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
        csvImportResult = count > 0 ? (true, count) : (false, 0)
    }

    private func saveAndContinue() {
        guard let income = Double(monthlyIncome), income > 0 else {
            onboardingError = viewModel.loc("Please enter a valid monthly income")
            return
        }
        onboardingError = nil
        isSaving = true
        let data = BudgetData(
            monthlyIncome: income,
            monthlyEssentials: Double(monthlyEssentials),
            monthlySavingsGoal: Double(monthlySavings),
            payDay: payDay,
            currency: selectedCurrency,
            language: selectedLanguage,
            theme: selectedTheme.rawValue,
            colorMode: selectedColorMode.rawValue,
            font: selectedFont.rawValue,
        )
        Task {
            let localBudget = Budget(
                id: UUID().uuidString,
                monthlyIncome: income,
                monthlyEssentials: Double(monthlyEssentials),
                monthlySavingsGoal: Double(monthlySavings),
                payDay: payDay,
                currency: selectedCurrency,
                language: selectedLanguage,
                theme: selectedTheme.rawValue,
                colorMode: selectedColorMode.rawValue,
                font: selectedFont.rawValue
            )
            await MainActor.run {
                viewModel.budgets = [localBudget]
                viewModel.saveLocalData()
                viewModel.savePreferencesToDisk()
                isSaving = false
            }
        }
    }
}

extension AppViewModel {
    func applyBudgetPreferencesFromBudget(_ budget: Budget) {
        if let t = budget.theme, let appTheme = AppTheme(rawValue: t) { theme = appTheme }
        if let cm = budget.colorMode, let mode = AppColorMode(rawValue: cm) { colorMode = mode }
        if let f = budget.font, let appFont = AppFont(rawValue: f) { font = appFont }
        if let c = budget.currency { currency = c }
        if let l = budget.language { language = l }
    }
}
