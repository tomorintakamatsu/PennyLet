import SwiftUI

struct SubscriptionTrackerView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var detectedSubs: [SubscriptionDetectionService.DetectedSubscription] = []
    @State private var isLoading = false
    @State private var hasScanned = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !detectedSubs.filter(\.isActive).isEmpty {
                    summaryCard
                    activeList
                }

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(viewModel.loc("Scanning subscriptions..."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else if detectedSubs.isEmpty && hasScanned {
                    emptyState
                }

                if !detectedSubs.filter({ !$0.isActive }).isEmpty {
                    expiredList
                }

                if !hasScanned {
                    scanPrompt
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .navigationTitle(viewModel.loc("Subscriptions"))
        .task {
            if !hasScanned {
                await scanSubs()
            }
        }
        .refreshable {
            await scanSubs()
        }
    }

    // MARK: - Actions

    private func scanSubs() async {
        isLoading = true
        let service = SubscriptionDetectionService()
        await service.detectSubscriptions()
        // Only clear previous results if new scan found something
        if !service.detectedSubs.isEmpty {
            detectedSubs = service.detectedSubs
        }
        isLoading = false
        hasScanned = true
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.theme.primaryColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.loc("Active Subscriptions"))
                        .font(.headline)
                    Text("\(detectedSubs.filter(\.isActive).count) \(viewModel.loc("found"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            ForEach(currencyTotals, id: \.currency) { item in
                HStack(alignment: .firstTextBaseline) {
                    Text(item.currency).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Text(item.formattedMonthly).font(.title3.weight(.bold))
                    Text("/\(viewModel.loc("mo"))").font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var currencyTotals: [(currency: String, formattedMonthly: String, count: Int)] {
        let active = detectedSubs.filter(\.isActive)
        let grouped = Dictionary(grouping: active, by: { $0.currencyCode })
        return grouped.map { code, subs in
            let monthly = subs.reduce(0.0) { total, sub in
                switch sub.period {
                case "yearly": return total + (NSDecimalNumber(decimal: sub.price).doubleValue / 12)
                case "monthly": return total + NSDecimalNumber(decimal: sub.price).doubleValue
                case "weekly": return total + (NSDecimalNumber(decimal: sub.price).doubleValue * 4.33)
                default: return total + NSDecimalNumber(decimal: sub.price).doubleValue
                }
            }
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
            Text(viewModel.loc("Detected on this device"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(detectedSubs.filter(\.isActive)) { sub in
                subscriptionRow(sub)
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
                    Text("· \(sub.period)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let renewal = sub.renewalDate, sub.isActive {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                        Text("Renews \(renewal.formatted(.relative(presentation: .named)))")
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
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
        let monthly: Double
        switch sub.period {
        case "yearly": monthly = NSDecimalNumber(decimal: sub.price).doubleValue / 12
        case "weekly": monthly = NSDecimalNumber(decimal: sub.price).doubleValue * 4.33
        default: monthly = NSDecimalNumber(decimal: sub.price).doubleValue
        }
        let symbol = currencySymbol(sub.currencyCode)
        return String(format: "\(symbol)%.2f", monthly)
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
            Button {
                Task { await scanSubs() }
            } label: {
                Label(viewModel.loc("Scan Again"), systemImage: "arrow.clockwise")
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
            Text(viewModel.loc("ClearSpend can detect your active App Store subscriptions and track them automatically."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
                    .background(viewModel.theme.primaryColor, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
