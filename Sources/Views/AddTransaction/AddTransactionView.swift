import SwiftUI

struct AddTransactionView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var type: Transaction.TransactionType = .expense
    @State private var amount = ""
    @State private var category = "food"
    @State private var note = ""
    @State private var date = Date()
    @State private var isSaving = false
    @FocusState private var isAmountFocused: Bool
    @State private var showReceiptScanner = false
    @State private var newCategoryName = ""
    @State private var showCustomCategoryField = false
    @State private var selectedCurrency = "native"
    @State private var convertedAmount: Double?
    @State private var conversionRate: Double?
    @State private var isConverting = false
    @State private var conversionError: String?

    private var datePickerLocale: Locale {
        switch viewModel.language {
        case "ja": return Locale(identifier: "ja_JP")
        case "zh": return Locale(identifier: "zh_Hans")
        default: return Locale(identifier: "en_US")
        }
    }

    private var categoryList: [AppCategory] {
        var list = type == .income ? AppCategory.incomeCategories : AppCategory.expenseCategories
        if viewModel.isPro, let customs = viewModel.currentBudget?.customCategories {
            for (i, name) in customs.enumerated() {
                list.append(AppCategory(id: "custom_\(i)", label: name, icon: "tag.fill", color: .teal))
            }
        }
        return list
    }

    private var isValid: Bool {
        (Double(amount) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    typeToggle
                    amountField
                    currencySelector
                    conversionPreview
                    quickActions
                    categoryGrid
                    noteAndDate
                    Spacer(minLength: 20)
                    saveButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .navigationTitle(viewModel.addTransactionTitle)
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton(viewModel.loc("Done"))
            .environment(\.locale, datePickerLocale)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.cancelLabel) { dismiss() }
                }
            }
            .onAppear { isAmountFocused = true }
        }
        .sheet(isPresented: $showReceiptScanner) {
            ReceiptScannerView { resultAmount, resultCategory, resultMerchant in
                if let amt = resultAmount { amount = String(format: "%.2f", amt) }
                if let cat = resultCategory { category = cat }
                if let merch = resultMerchant { note = merch }
                showReceiptScanner = false
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        Button {
            showReceiptScanner = true
        } label: {
            Label(viewModel.scanReceiptLabel, systemImage: "doc.text.viewfinder")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Existing Views

    private var typeToggle: some View {
        HStack(spacing: 0) {
            ForEach([Transaction.TransactionType.expense, .income], id: \.self) { t in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        type = t
                        category = t == .income ? "salary" : "food"
                    }
                } label: {
                    Label(
                        t == .income ? viewModel.incomeLabel : viewModel.expenseLabel,
                        systemImage: t == .income ? "arrow.down.forward" : "arrow.up.forward"
                    )
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        type == t
                            ? (t == .income ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .foregroundStyle(type == t ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var amountField: some View {
        VStack(spacing: 8) {
            Text(viewModel.amountLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(CurrencyFormat.currencySymbol(for: selectedCurrency == "native" ? viewModel.currency : selectedCurrency))
                    .font(.system(size: 36, design: .rounded))
                    .foregroundStyle(.secondary)
                TextField("0", text: $amount)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 200)
            }
        }
        .padding(.vertical, 12)
    }

    private var currencySelector: some View {
        VStack(spacing: 8) {
            Picker(viewModel.loc("Currency"), selection: $selectedCurrency) {
                Text(viewModel.currency).tag("native")
                ForEach(CurrencyRateService.supportedCurrencies, id: \.code) { cur in
                    if cur.code != viewModel.currency {
                        Text("\(cur.code) (\(cur.symbol))").tag(cur.code)
                    }
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedCurrency) { _, _ in
                Task { await performConversion() }
            }
            .onChange(of: amount) { _, _ in
                if selectedCurrency != "native" {
                    Task { await performConversion() }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var conversionPreview: some View {
        if let converted = convertedAmount, let rate = conversionRate, selectedCurrency != "native", let value = Double(amount) {
            VStack(spacing: 4) {
                if isConverting {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(viewModel.loc("Converting..."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(CurrencyFormat.formatForeign(value, currency: selectedCurrency)) = \(CurrencyFormat.format(converted, currency: viewModel.currency))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(viewModel.loc("Rate")): 1 \(selectedCurrency) = \(String(format: "%.4f", rate)) \(viewModel.currency)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        } else if let error = conversionError {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.categoryLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(categoryList) { cat in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            category = cat.id
                            showCustomCategoryField = false
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(category == cat.id ? .white : cat.color)
                                .frame(width: 40, height: 40)
                                .background(
                                    category == cat.id ? cat.color : cat.color.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                            Text(viewModel.loc(cat.label))
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(category == cat.id ? .primary : .secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.isPro {
                    Button {
                        showCustomCategoryField.toggle()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: showCustomCategoryField ? "xmark" : "plus")
                                .font(.system(size: 16))
                                .foregroundStyle(.teal)
                                .frame(width: 40, height: 40)
                                .background(.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                            Text(viewModel.loc(showCustomCategoryField ? "Cancel" : "New"))
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }

            if showCustomCategoryField {
                HStack(spacing: 8) {
                    TextField(viewModel.loc("New Category"), text: $newCategoryName)
                        .padding(10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    Button(viewModel.loc("Add")) {
                        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        category = name
                        viewModel.addCustomCategory(name)
                        newCategoryName = ""
                        showCustomCategoryField = false
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.teal, in: RoundedRectangle(cornerRadius: 10))
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var noteAndDate: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "pencil.line")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                TextField(viewModel.noteLabel, text: $note)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

            DatePicker(viewModel.dateLabel, selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            HStack {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                }
                Text(isSaving ? viewModel.savingDots : viewModel.saveLabel)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isValid
                    ? LinearGradient(
                        colors: type == .income ? [Color.green, Color.green.opacity(0.7)] : [viewModel.theme.primaryColor, viewModel.theme.primaryColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
        .disabled(!isValid || isSaving)
    }

    private func save() {
        guard let value = Double(amount), value > 0 else { return }
        isSaving = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let useForeign = selectedCurrency != "native" && convertedAmount != nil
        let finalAmount = useForeign ? (convertedAmount ?? value) : value

        let data = TransactionData(
            amount: finalAmount,
            type: type,
            category: category,
            note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note.trimmingCharacters(in: .whitespaces),
            date: formatter.string(from: date),
            merchant: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note.trimmingCharacters(in: .whitespaces),
            originalCurrency: useForeign ? selectedCurrency : nil,
            originalAmount: useForeign ? value : nil,
            exchangeRate: useForeign ? conversionRate : nil,
            baseCurrency: useForeign ? viewModel.currency : nil
        )
        Task {
            await viewModel.addTransaction(data)
            isSaving = false
            dismiss()
        }
    }

    private func performConversion() async {
        guard let value = Double(amount), value > 0,
              selectedCurrency != "native" else {
            convertedAmount = nil
            conversionRate = nil
            return
        }
        isConverting = true
        conversionError = nil
        do {
            let result = try await CurrencyRateService.shared.convert(
                amount: value,
                from: selectedCurrency,
                to: viewModel.currency
            )
            convertedAmount = result.converted
            conversionRate = result.rate
        } catch let rateError as CurrencyRateError {
            conversionError = viewModel.loc(rateError.localizationKey)
            convertedAmount = nil
            conversionRate = nil
        } catch {
            conversionError = viewModel.loc("Could not fetch exchange rate.")
            convertedAmount = nil
            conversionRate = nil
        }
        isConverting = false
    }
}
