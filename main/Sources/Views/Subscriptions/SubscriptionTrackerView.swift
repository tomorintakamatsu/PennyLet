import SwiftUI

struct SubscriptionTrackerView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var detectedSubs: [SubscriptionDetectionService.DetectedSubscription] = []
    @State private var isLoading = false
    @State private var hasScanned = false
    @State private var showAddSubscription = false
    @State private var scanMessage = ""
    @State private var inferredSubs: [SubscriptionDetectionService.InferredSubscription] = []

    private var manualSubs: [RecurringSubscription] {
        viewModel.recurringSubscriptions.filter(\.isActive)
    }

    private var suggestedSubs: [SubscriptionDetectionService.InferredSubscription] {
        let existingNames = Set(
            manualSubs.map { normalizedName($0.name) } +
            detectedSubs.map { normalizedName($0.displayName) }
        )
        return inferredSubs.filter { !existingNames.contains(normalizedName($0.name)) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryCard

                actionBar

                if !manualSubs.isEmpty {
                    manualList
                }

                if !suggestedSubs.isEmpty {
                    suggestedList
                }

                if !detectedSubs.filter(\.isActive).isEmpty {
                    activeList
                }

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(scanMessage.isEmpty ? viewModel.loc("Scanning subscriptions...") : scanMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(viewModel.loc("This checks App Store purchase history that iOS allows this app to access."))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else if detectedSubs.isEmpty && manualSubs.isEmpty && hasScanned {
                    emptyState
                }

                if !detectedSubs.filter({ !$0.isActive }).isEmpty {
                    expiredList
                }

                if !hasScanned && detectedSubs.isEmpty {
                    scanPrompt
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .navigationTitle(viewModel.loc("Subscriptions"))
        .background(
            LinearGradient(
                colors: [
                    viewModel.theme.primaryColor.opacity(0.12),
                    viewModel.theme.accentColor.opacity(0.07),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .task {
            if !hasScanned {
                await scanSubs()
            }
        }
        .refreshable {
            await scanSubs()
        }
        .sheet(isPresented: $showAddSubscription) {
            AddSubscriptionSheet()
        }
    }

    // MARK: - Actions

    private func scanSubs() async {
        isLoading = true
        scanMessage = viewModel.loc("Checking active entitlements...")
        let service = SubscriptionDetectionService()
        try? await Task.sleep(nanoseconds: 250_000_000)
        scanMessage = viewModel.loc("Reviewing purchase history...")
        await service.detectSubscriptions()
        detectedSubs = service.detectedSubs
        scanMessage = viewModel.loc("Scanning transaction history...")
        inferredSubs = SubscriptionDetectionService.inferLocalSubscriptions(
            from: viewModel.transactions,
            currencyCode: viewModel.currency
        )
        scanMessage = ""
        isLoading = false
        hasScanned = true
    }

    // MARK: - Summary

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                showAddSubscription = true
            } label: {
                Label(viewModel.loc("Add Subscription"), systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [viewModel.theme.primaryColor, viewModel.theme.accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                    }
                    .shadow(color: viewModel.theme.primaryColor.opacity(0.24), radius: 14, y: 8)
            }
            .buttonStyle(.plain)

            Button {
                Task { await scanSubs() }
            } label: {
                Label(viewModel.loc("Scan Again"), systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(viewModel.theme.primaryColor.opacity(0.12), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
    }

    private var summaryCard: some View {
        let activeDetected = detectedSubs.filter(\.isActive)
        let totalCount = activeDetected.count + manualSubs.count

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(viewModel.loc("Active Subscriptions"))
                        .font(.title3.weight(.bold))
                    Text("\(totalCount) \(viewModel.loc("tracked"))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                Image(systemName: "creditcard.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
            }

            if currencyTotals.isEmpty {
                Text(viewModel.loc("Add manual subscriptions or scan App Store purchases to track renewals."))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(currencyTotals, id: \.currency) { item in
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.currency)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.68))
                        Spacer()
                        Text(item.formattedMonthly)
                            .font(.title2.weight(.bold))
                        Text("/\(viewModel.loc("mo"))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    viewModel.theme.primaryColor,
                    viewModel.theme.primaryColor.opacity(0.82),
                    viewModel.theme.accentColor.opacity(0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "repeat.circle.fill")
                .font(.system(size: 96))
                .foregroundStyle(.white.opacity(0.09))
                .offset(x: 20, y: 22)
        }
        .shadow(color: viewModel.theme.primaryColor.opacity(0.22), radius: 20, y: 10)
    }

    private var currencyTotals: [(currency: String, formattedMonthly: String, count: Int)] {
        let active = detectedSubs.filter(\.isActive)
        var values: [(currency: String, monthly: Double)] = active.map { sub in
            (sub.currencyCode, monthlyValue(for: sub))
        }
        values.append(contentsOf: manualSubs.map { ($0.currencyCode, monthlyValue(for: $0)) })

        let grouped = Dictionary(grouping: values, by: { $0.currency })
        return grouped.map { code, subs in
            let monthly = subs.reduce(0.0) { $0 + $1.monthly }
            let sym = currencySymbol(code)
            return (code, String(format: "\(sym)%.2f", monthly), subs.count)
        }.sorted { $0.currency < $1.currency }
    }

    private func currencySymbol(_ code: String) -> String {
        switch code.uppercased() {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY", "CNY": return "¥"
        case "KRW": return "₩"
        case "CAD": return "CA$"
        case "AUD": return "A$"
        default: return code.uppercased()
        }
    }

    // MARK: - Lists

    private var activeList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.loc("App Store subscriptions"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(detectedSubs.filter(\.isActive)) { sub in
                subscriptionRow(sub)
            }
        }
    }

    private var manualList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.loc("Manual subscriptions"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(manualSubs) { sub in
                manualSubscriptionRow(sub)
            }
        }
    }

    private var suggestedList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.loc("Suggested subscriptions"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(suggestedSubs) { sub in
                inferredSubscriptionRow(sub)
            }
        }
    }

    private var expiredList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.loc("Expired"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            ForEach(detectedSubs.filter { !$0.isActive }) { sub in
                subscriptionRow(sub)
            }
        }
    }

    private func subscriptionRow(_ sub: SubscriptionDetectionService.DetectedSubscription) -> some View {
        HStack(spacing: 14) {
            // Icon with period badge
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(sub.isActive ? viewModel.theme.primaryColor.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 46, height: 46)
                Image(systemName: sub.isActive ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(sub.isActive ? viewModel.theme.primaryColor : .gray)
                // Period badge
                Text(sub.period.prefix(1).uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(sub.isActive ? viewModel.theme.primaryColor : .gray, in: RoundedRectangle(cornerRadius: 4))
                    .offset(x: 4, y: 2)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(sub.displayName)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 4) {
                    Text(formatPrice(sub.price, sub.currencyCode))
                        .font(.caption.weight(.medium))
                    Text("· \(periodLabel(sub.period))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let renewal = sub.renewalDate, sub.isActive {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                        Text("\(viewModel.loc("Renews")) \(renewal.formatted(.relative(presentation: .named).locale(viewModel.appLocale)))")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(monthlyEquivalent(sub))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("/\(viewModel.loc("mo"))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .opacity(sub.isActive ? 1 : 0.5)
    }

    private func formatPrice(_ price: Decimal, _ code: String) -> String {
        let value = NSDecimalNumber(decimal: price).doubleValue
        let symbol = currencySymbol(code)
        // JPY and KRW don't use decimal places
        if code.uppercased() == "JPY" || code.uppercased() == "KRW" {
            return "\(symbol)\(Int(value))"
        }
        return String(format: "\(symbol)%.2f", value)
    }

    private func monthlyEquivalent(_ sub: SubscriptionDetectionService.DetectedSubscription) -> String {
        let monthly = monthlyValue(for: sub)
        let symbol = currencySymbol(sub.currencyCode)
        return String(format: "\(symbol)%.2f", monthly)
    }

    private func monthlyValue(for sub: SubscriptionDetectionService.DetectedSubscription) -> Double {
        let value = NSDecimalNumber(decimal: sub.price).doubleValue
        switch sub.period {
        case "yearly": return value / 12
        case "weekly": return value * 4.33
        case "biweekly": return value * 2.165
        case "daily": return value * 30
        default:
            if let parsed = parseDynamicPeriod(sub.period) {
                switch parsed.unit {
                case "day", "days": return value * (30 / Double(max(1, parsed.count)))
                case "week", "weeks": return value * (4.33 / Double(max(1, parsed.count)))
                case "month", "months": return value / Double(max(1, parsed.count))
                case "year", "years": return value / (12 * Double(max(1, parsed.count)))
                default: break
                }
            }
            return value
        }
    }

    private func manualSubscriptionRow(_ sub: RecurringSubscription) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(viewModel.theme.primaryColor.opacity(0.14))
                    .frame(width: 48, height: 48)
                Image(systemName: "repeat")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(viewModel.theme.primaryColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(sub.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(formatPrice(Decimal(sub.amount), sub.currencyCode)) · \(intervalLabel(sub))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(viewModel.loc("Next charge")) \(formattedDate(sub.nextBillingDate))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button(role: .destructive) {
                viewModel.deleteRecurringSubscription(sub)
            } label: {
                Image(systemName: "trash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func inferredSubscriptionRow(_ sub: SubscriptionDetectionService.InferredSubscription) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.orange.opacity(0.14))
                    .frame(width: 48, height: 48)
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(sub.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(formatPrice(Decimal(sub.amount), sub.currencyCode)) · \(intervalLabel(sub.interval, customIntervalDays: sub.customIntervalDays))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(sub.matchedTransactions) \(viewModel.loc("matches")) · \(viewModel.loc("Next charge")) \(sub.nextBillingDate.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(viewModel.appLocale)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                addInferredSubscription(sub)
            } label: {
                Text(viewModel.loc("Add"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(viewModel.theme.primaryColor, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .topTrailing) {
            Text(viewModel.loc("Suggested from transaction history"))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.orange.opacity(0.12), in: Capsule())
                .offset(x: -10, y: 10)
        }
    }

    private func monthlyValue(for sub: RecurringSubscription) -> Double {
        switch sub.interval {
        case .weekly: return sub.amount * 4.33
        case .biweekly: return sub.amount * 2.165
        case .monthly: return sub.amount
        case .custom:
            let days = max(1, sub.customIntervalDays ?? 30)
            return sub.amount * (30.0 / Double(days))
        }
    }

    private func intervalLabel(_ sub: RecurringSubscription) -> String {
        intervalLabel(sub.interval, customIntervalDays: sub.customIntervalDays)
    }

    private func intervalLabel(
        _ interval: RecurringSubscription.BillingInterval,
        customIntervalDays: Int?
    ) -> String {
        switch interval {
        case .weekly: return viewModel.loc("Weekly")
        case .biweekly: return viewModel.loc("Every 2 weeks")
        case .monthly: return viewModel.loc("Monthly")
        case .custom:
            return "\(viewModel.loc("Every")) \(customIntervalDays ?? 30) \(viewModel.loc("days"))"
        }
    }

    private func formattedDate(_ dateString: String) -> String {
        guard let date = Date.fromDateString(dateString) else { return dateString }
        return date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(viewModel.appLocale))
    }

    private func addInferredSubscription(_ sub: SubscriptionDetectionService.InferredSubscription) {
        Task {
            await viewModel.addRecurringSubscription(
                name: sub.name,
                amount: sub.amount,
                currencyCode: sub.currencyCode,
                category: sub.category ?? "subscriptions",
                note: nil,
                startDate: sub.latestTransactionDate,
                interval: sub.interval,
                customIntervalDays: sub.customIntervalDays
            )
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                inferredSubs.removeAll { $0.id == sub.id }
            }
        }
    }

    private func periodLabel(_ period: String) -> String {
        switch period {
        case "daily", "weekly", "biweekly", "monthly", "yearly", "subscription", "unknown":
            return viewModel.loc(period)
        default:
            if let parsed = parseDynamicPeriod(period) {
                return "\(viewModel.loc("Every")) \(parsed.count) \(viewModel.loc(parsed.unit))"
            }
            return period
        }
    }

    private func parseDynamicPeriod(_ period: String) -> (count: Int, unit: String)? {
        let parts = period.split(separator: " ")
        guard parts.count == 3,
              parts[0].lowercased() == "every",
              let count = Int(parts[1]) else { return nil }
        return (count, String(parts[2]).lowercased())
    }

    private func normalizedName(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Empty & Prompt

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(viewModel.loc("No App Store subscriptions found"))
                .font(.headline)
            Text(viewModel.loc("Active subscriptions purchased through Apple will appear here automatically."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(viewModel.loc("For subscriptions outside the App Store, add them manually so PennyLet can renew them for you."))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button {
                showAddSubscription = true
            } label: {
                Label(viewModel.loc("Add Subscription"), systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(viewModel.theme.primaryColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var scanPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(viewModel.theme.primaryColor)
            Text(viewModel.loc("Scan for Subscriptions"))
                .font(.title3.weight(.semibold))
            Text(viewModel.loc("PennyLet can detect your active App Store subscriptions and track them automatically."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Text(viewModel.loc("This scan only uses purchase information Apple makes available to this app."))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await scanSubs() }
            } label: {
                Label(viewModel.loc("Scan Now"), systemImage: "magnifyingglass")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(viewModel.theme.primaryColor, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

private struct AddSubscriptionSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amount = ""
    @State private var selectedCurrency = "native"
    @State private var startDate = Date()
    @State private var billingInterval: RecurringSubscription.BillingInterval = .monthly
    @State private var customIntervalDays = 30
    @State private var note = ""
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case amount
        case note
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedAmount: Double? {
        let cleaned = amount
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }

    private var currencyCode: String {
        selectedCurrency == "native" ? viewModel.currency : selectedCurrency
    }

    private var canSave: Bool {
        guard let value = parsedAmount else { return false }
        return !trimmedName.isEmpty && value > 0
    }

    private var monthlyPreview: Double {
        let value = parsedAmount ?? 0
        switch billingInterval {
        case .weekly: return value * 4.33
        case .biweekly: return value * 2.165
        case .monthly: return value
        case .custom: return value * (30.0 / Double(max(1, customIntervalDays)))
        }
    }

    private var nextChargeDate: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var candidate = calendar.startOfDay(for: startDate)
        while candidate <= today {
            candidate = nextBillingDate(after: candidate)
        }
        return candidate
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                    detailsCard
                    billingCard
                    noteCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 110)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(
                LinearGradient(
                    colors: [
                        viewModel.theme.primaryColor.opacity(0.12),
                        viewModel.theme.accentColor.opacity(0.07),
                        Color(.systemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle(viewModel.loc("New Subscription"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.loc("Cancel")) {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveFooter
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Image(systemName: "repeat.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(CurrencyFormat.format(monthlyPreview, currency: currencyCode))
                        .font(.title2.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text("/\(viewModel.loc("mo"))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(viewModel.loc("Subscription only"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
                Text(viewModel.loc("Add a recurring bill without creating a transaction."))
                    .font(.headline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    viewModel.theme.primaryColor,
                    viewModel.theme.primaryColor.opacity(0.82),
                    viewModel.theme.accentColor.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 88))
                .foregroundStyle(.white.opacity(0.09))
                .offset(x: 18, y: 22)
        }
        .shadow(color: viewModel.theme.primaryColor.opacity(0.22), radius: 20, y: 10)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(viewModel.loc("Details"), icon: "text.cursor")

            TextField(viewModel.loc("Name"), text: $name)
                .focused($focusedField, equals: .name)
                .textInputAutocapitalization(.words)
                .font(.headline)
                .padding(13)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 10) {
                Text(CurrencyFormat.currencySymbol(for: currencyCode))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(viewModel.theme.primaryColor)
                    .frame(width: 38, height: 44)
                    .background(viewModel.theme.primaryColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                TextField("0.00", text: $amount)
                    .focused($focusedField, equals: .amount)
                    .keyboardType(.decimalPad)
                    .font(.title3.weight(.semibold))

                Picker(viewModel.loc("Currency"), selection: $selectedCurrency) {
                    Text("\(viewModel.currency) · \(viewModel.loc("App currency"))").tag("native")
                    ForEach(CurrencyRateService.supportedCurrencies, id: \.code) { currency in
                        Text("\(currency.code) · \(currency.name)").tag(currency.code)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(viewModel.theme.primaryColor)
            }
            .padding(10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

            DatePicker(
                viewModel.loc("First charge"),
                selection: $startDate,
                displayedComponents: .date
            )
            .font(.subheadline.weight(.semibold))
            .padding(13)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.theme.primaryColor.opacity(0.10), lineWidth: 1)
        }
    }

    private var billingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(viewModel.loc("Billing"), icon: "calendar")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                intervalButton(.weekly, title: viewModel.loc("Weekly"), subtitle: viewModel.loc("Every 7 days"))
                intervalButton(.biweekly, title: viewModel.loc("2 weeks"), subtitle: viewModel.loc("Every 14 days"))
                intervalButton(.monthly, title: viewModel.loc("Monthly"), subtitle: viewModel.loc("Most common"))
                intervalButton(.custom, title: viewModel.loc("Custom"), subtitle: viewModel.loc("Pick days"))
            }

            if billingInterval == .custom {
                Stepper(value: $customIntervalDays, in: 1...365) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(viewModel.loc("Every")) \(customIntervalDays) \(viewModel.loc("days"))")
                            .font(.subheadline.weight(.semibold))
                        Text(viewModel.loc("Custom renewal interval"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(13)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 10) {
                Image(systemName: "bell.badge")
                    .foregroundStyle(viewModel.theme.primaryColor)
                Text("\(viewModel.loc("Next charge")) \(nextChargeDate.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(viewModel.appLocale)))")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(13)
            .background(viewModel.theme.primaryColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.theme.primaryColor.opacity(0.10), lineWidth: 1)
        }
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(viewModel.loc("Note"), icon: "note.text")

            TextField(viewModel.loc("Optional note"), text: $note, axis: .vertical)
                .focused($focusedField, equals: .note)
                .lineLimit(2...4)
                .padding(13)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.theme.primaryColor.opacity(0.10), lineWidth: 1)
        }
    }

    private var saveFooter: some View {
        VStack(spacing: 0) {
            Button {
                saveSubscription()
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(viewModel.loc("Save Subscription"))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: canSave
                            ? [viewModel.theme.primaryColor, viewModel.theme.accentColor]
                            : [Color.gray.opacity(0.55), Color.gray.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSave || isSaving)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .background(.ultraThinMaterial)
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(viewModel.theme.primaryColor)
            Text(title)
                .font(.subheadline.weight(.bold))
            Spacer()
        }
    }

    private func intervalButton(
        _ interval: RecurringSubscription.BillingInterval,
        title: String,
        subtitle: String
    ) -> some View {
        let isSelected = billingInterval == interval
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                billingInterval = interval
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    Spacer()
                }
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.72) : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                isSelected
                    ? viewModel.theme.primaryColor
                    : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }

    private func saveSubscription() {
        guard canSave, let value = parsedAmount else { return }
        isSaving = true
        let noteValue = trimmedNote.isEmpty ? nil : trimmedNote
        let intervalDays = billingInterval == .custom ? customIntervalDays : nil

        Task {
            await viewModel.addRecurringSubscription(
                name: trimmedName,
                amount: value,
                currencyCode: currencyCode,
                category: "subscriptions",
                note: noteValue,
                startDate: startDate,
                interval: billingInterval,
                customIntervalDays: intervalDays
            )
            isSaving = false
            dismiss()
        }
    }

    private func nextBillingDate(after date: Date) -> Date {
        let calendar = Calendar.current
        switch billingInterval {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .custom:
            return calendar.date(byAdding: .day, value: max(1, customIntervalDays), to: date) ?? date
        }
    }
}
