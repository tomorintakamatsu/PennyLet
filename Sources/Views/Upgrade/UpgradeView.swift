import SwiftUI
import StoreKit

struct UpgradeView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isYearly = true
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var restoreMessage: String?
    @State private var purchaseError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.yellow)

                    Text(viewModel.loc("ClearSpend Pro"))
                        .font(.title.weight(.bold))

                    Text(viewModel.loc("Get more AI analyses, visual charts, unlimited receipt scanning, and deeper spending insights."))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 32)

                    Picker(viewModel.loc("Plan"), selection: $isYearly) {
                        Text(viewModel.loc("Monthly")).tag(false)
                        Text(viewModel.loc("Yearly (save 40%)")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 32)

                    VStack(spacing: 16) {
                        priceCard
                        featuresList
                        comparisonTable
                    }
                    .padding(.horizontal, 20)

                    if !viewModel.isGuestMode {
                        Button {
                            Task { await purchase() }
                        } label: {
                            HStack {
                                if isPurchasing { ProgressView().tint(.white) }
                                Text(isPurchasing ? viewModel.loc("Processing...") : viewModel.loc("Subscribe"))
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.yellow, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(isPurchasing)
                        .padding(.horizontal, 20)
                    }

                    if let msg = purchaseError {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    if let msg = restoreMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(msg.contains("✅") ? .green : .secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    Button {
                        Task { await restore() }
                    } label: {
                        HStack {
                            if isRestoring {
                                ProgressView().tint(viewModel.theme.primaryColor)
                            }
                            Text(isRestoring ? viewModel.loc("Processing...") : viewModel.loc("Restore Purchases"))
                        }
                        .font(.subheadline)
                        .foregroundStyle(viewModel.theme.primaryColor)
                    }
                    .disabled(isRestoring)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle(viewModel.loc("Upgrade"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var priceCard: some View {
        let fallback = isYearly ? viewModel.loc("$39.99/yr") : viewModel.loc("$4.99/mo")
        return VStack(spacing: 4) {
            Text(fallback)
                .font(.system(size: 36, weight: .bold, design: .rounded))
            if isYearly {
                Text(viewModel.loc("Just $3.33/month"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(proFeatures, id: \.0) { icon, title, desc in
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(.yellow)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var proFeatures: [(String, String, String)] {
        [
            ("sparkles", viewModel.loc("More AI Analyses"), viewModel.loc("30 daily, 15 weekly, 10 monthly, and 3 forecasts every month")),
            ("tag.fill", viewModel.loc("Custom Categories"), viewModel.loc("Create your own spending and income categories")),
            ("chart.line.uptrend.xyaxis", viewModel.loc("Spending Forecasts"), viewModel.loc("AI predicts next month's spending based on your history")),
            ("clock.arrow.2.circlepath", viewModel.autoAnalysisLabel, viewModel.loc("Schedule automatic daily, weekly, and monthly AI analysis")),
            ("chart.pie.fill", viewModel.loc("Visual Pie Charts"), viewModel.loc("Beautiful spending breakdown charts in weekly and monthly reports")),
            ("camera.viewfinder", viewModel.loc("Unlimited Receipt Scanning"), viewModel.loc("Scan as many receipts as you want, no monthly cap")),
            ("bell.fill", viewModel.loc("Deeper Spending Insights"), viewModel.loc("Detailed patterns, trends, and personalized recommendations")),
        ]
    }

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("").frame(maxWidth: .infinity, alignment: .leading)
                Text(viewModel.loc("Free"))
                    .font(.caption.weight(.semibold))
                    .frame(width: 60)
                Text(viewModel.loc("Pro"))
                    .font(.caption.weight(.semibold))
                    .frame(width: 60)
                    .foregroundStyle(.yellow)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().background(.secondary.opacity(0.3))

            comparisonRow(icon: "sparkles", label: viewModel.dailyAnalysisTitle, free: "5\(viewModel.loc("/mo"))", pro: "30\(viewModel.loc("/mo"))")
            comparisonRow(icon: "chart.bar.fill", label: viewModel.weeklyRecapTitle, free: "1\(viewModel.loc("/mo"))", pro: "15\(viewModel.loc("/mo"))")
            comparisonRow(icon: "doc.text.magnifyingglass", label: viewModel.monthlyInsightTitle, free: "—", pro: "10\(viewModel.loc("/mo"))")
            comparisonRow(icon: "chart.line.uptrend.xyaxis", label: viewModel.loc("Spending Forecasts"), free: "—", pro: "3\(viewModel.loc("/mo"))")
            comparisonRow(icon: "camera.viewfinder", label: viewModel.scanReceiptLabel, free: "5\(viewModel.loc("/mo"))", pro: "∞")
            comparisonRow(icon: "creditcard.fill", label: viewModel.loc("Subscription Tracker"), free: "✓", pro: "✓")
            comparisonRow(icon: "clock.arrow.2.circlepath", label: viewModel.autoAnalysisLabel, free: "—", pro: "✓")
            comparisonRow(icon: "tag.fill", label: viewModel.loc("Custom Categories"), free: "—", pro: "✓")
            comparisonRow(icon: "chart.pie.fill", label: viewModel.loc("Visual Pie Charts"), free: "—", pro: "✓")
        }
        .font(.caption)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func comparisonRow(icon: String, label: String, free: String, pro: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(label)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(free)
                    .frame(width: 60)
                    .foregroundStyle(.secondary)
                Text(pro)
                    .frame(width: 60)
                    .foregroundStyle(.yellow)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            Divider().background(.secondary.opacity(0.15)).padding(.leading, 48)
        }
    }

    // MARK: - Purchase

    private func purchase() async {
        isPurchasing = true
        purchaseError = nil
        let productID = isYearly ? APIConstants.yearlyProductID : APIConstants.monthlyProductID

        // Load product off main actor
        let products = await Task.detached {
            try? await StoreKit.Product.products(for: [productID])
        }.value

        guard let product = products?.first else {
            purchaseError = viewModel.loc("Unable to load pricing. Please try again.")
            isPurchasing = false
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let txn) = verification {
                    await txn.finish()
                    viewModel.hasProSubscription = true
                    purchaseError = nil
                    isPurchasing = false
                    restoreMessage = "✅ \(viewModel.loc("Pro unlocked! Refreshing..."))"
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    dismiss()
                }
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase pending approval."
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
        isPurchasing = false
    }

    // MARK: - Restore

    private func restore() async {
        isRestoring = true
        restoreMessage = nil
        // Check Apple ID subscriptions via StoreKit
        var foundPro = false
        for await result in StoreKit.Transaction.all {
            guard case .verified(let txn) = result,
                  txn.productType == .autoRenewable || txn.productType == .nonRenewable,
                  txn.revocationDate == nil,
                  txn.expirationDate.map({ $0 > Date() }) ?? true else { continue }
            foundPro = true
            break
        }
        if foundPro {
            viewModel.hasProSubscription = true
            restoreMessage = "✅ \(viewModel.loc("Purchase restored! Pro features are now unlocked."))"
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } else {
            restoreMessage = viewModel.loc("No active subscription found.")
        }
        isRestoring = false
    }
}
