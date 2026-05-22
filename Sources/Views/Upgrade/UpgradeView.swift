import SwiftUI
import StoreKit

struct UpgradeView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var products: [StoreKit.Product] = []
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var isYearly = true
    @State private var purchaseError: String?
    @State private var restoreMessage: String?

    private var monthly: StoreKit.Product? { products.first(where: { $0.id == APIConstants.monthlyProductID }) }
    private var yearly: StoreKit.Product?  { products.first(where: { $0.id == APIConstants.yearlyProductID  }) }
    private var selectedProduct: StoreKit.Product? { isYearly ? (yearly ?? monthly) : (monthly ?? yearly) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 40)).foregroundStyle(.yellow)
                        Text(viewModel.loc("ClearSpend Pro"))
                            .font(.title.weight(.bold))
                        Text(viewModel.loc("Get more AI analyses, visual charts, forecasts, and deeper spending insights."))
                            .multilineTextAlignment(.center).foregroundStyle(.secondary)
                            .padding(.horizontal, 28)
                    }.padding(.top, 16)

                    // Pricing
                    if isLoading {
                        ProgressView().padding(20)
                    } else {
                        pricingSection

                        // Plan picker
                        Picker(viewModel.loc("Plan"), selection: $isYearly) {
                            Text(viewModel.loc("Monthly")).tag(false)
                            Text(viewModel.loc("Yearly (save 40%)")).tag(true)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Features
                    featuresList

                    // Comparison
                    comparisonTable

                    // Subscribe button
                    if let product = selectedProduct {
                        Button {
                            Task { await purchase(product) }
                        } label: {
                            HStack {
                                if isPurchasing { ProgressView().tint(.white) }
                                Text(isPurchasing ? viewModel.loc("Processing...") : viewModel.loc("Subscribe"))
                            }
                            .font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(.yellow, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isPurchasing)
                    }

                    if let msg = purchaseError {
                        Text(msg).font(.caption).foregroundStyle(.red)
                    }

                    // Restore
                    Button(viewModel.loc("Restore Purchases")) {
                        Task { await restore() }
                    }
                    .font(.subheadline).foregroundStyle(viewModel.theme.primaryColor)

                    if let msg = restoreMessage {
                        Text(msg).font(.caption)
                            .foregroundStyle(msg.contains("✅") ? .green : .secondary)
                    }

                    // Policy links
                    VStack(spacing: 6) {
                        Link(viewModel.loc("Privacy Policy"),
                             destination: URL(string: "https://tomorintakamatsu.github.io/clearspend-privacy/privacy-policy.pdf")!)
                            .font(.caption2)
                        Link(viewModel.loc("Terms of Use (EULA)"),
                             destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .font(.caption2)
                    }.padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle(viewModel.loc("Upgrade"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.loc("Done")) { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .task { await loadProducts() }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        HStack(spacing: 12) {
            if let m = monthly {
                priceCard(product: m, period: viewModel.loc("Monthly"), price: m.displayPrice,
                          selected: !isYearly)
                    .onTapGesture { isYearly = false }
            }
            if let y = yearly {
                priceCard(product: y, period: viewModel.loc("Yearly"), price: y.displayPrice,
                          badge: viewModel.loc("Save 40%"), selected: isYearly)
                    .onTapGesture { isYearly = true }
            }
        }
    }

    private func priceCard(product: StoreKit.Product, period: String, price: String,
                           badge: String? = nil, selected: Bool = false) -> some View {
        VStack(spacing: 4) {
            // Reserve space for badge so both cards have equal height
            ZStack {
                if let badge {
                    Text(badge).font(.caption2.weight(.bold))
                        .foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 2)
                        .background(.yellow, in: Capsule())
                }
            }
            .frame(height: 18)

            Text(price).font(.title2.weight(.bold).monospacedDigit())
            Text(period).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(selected ? Color.yellow.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(selected ? Color.yellow : Color.gray.opacity(0.3), lineWidth: selected ? 2 : 1)
        )
    }

    // MARK: - Feature List

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(proFeatures, id: \.0) { icon, title, desc in
                HStack(spacing: 10) {
                    Image(systemName: icon).font(.callout).foregroundStyle(.yellow).frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(.subheadline.weight(.semibold))
                        Text(desc).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var proFeatures: [(String, String, String)] {
        [
            ("sparkles", viewModel.loc("More AI Analyses"), viewModel.loc("30 daily, 15 weekly, 10 monthly, and 3 forecasts every month")),
            ("tag.fill", viewModel.loc("Custom Categories"), viewModel.loc("Create your own spending and income categories")),
            ("chart.line.uptrend.xyaxis", viewModel.loc("Spending Forecasts"), viewModel.loc("AI predicts next month's spending based on your history")),
            ("clock.arrow.2.circlepath", viewModel.autoAnalysisLabel, viewModel.loc("Schedule automatic daily, weekly, and monthly AI analysis")),
            ("chart.pie.fill", viewModel.loc("Visual Pie Charts"), viewModel.loc("Beautiful spending breakdown charts in weekly and monthly reports")),
            ("bell.fill", viewModel.loc("Deeper Spending Insights"), viewModel.loc("Detailed patterns, trends, and personalized recommendations")),
        ]
    }

    // MARK: - Comparison Table

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("").frame(maxWidth: .infinity, alignment: .leading)
                Text(viewModel.loc("Free")).font(.caption.weight(.semibold)).frame(width: 52)
                Text(viewModel.loc("Pro")).font(.caption.weight(.semibold)).frame(width: 52).foregroundStyle(.yellow)
            }.padding(.horizontal, 12).padding(.vertical, 8)
            Divider()
            comparisonRow(icon: "sparkles", label: viewModel.dailyAnalysisTitle, free: "5\(viewModel.loc("/mo"))", pro: "30\(viewModel.loc("/mo"))")
            comparisonRow(icon: "chart.bar.fill", label: viewModel.weeklyRecapTitle, free: "1\(viewModel.loc("/mo"))", pro: "15\(viewModel.loc("/mo"))")
            comparisonRow(icon: "doc.text.magnifyingglass", label: viewModel.monthlyInsightTitle, free: "—", pro: "10\(viewModel.loc("/mo"))")
            comparisonRow(icon: "chart.line.uptrend.xyaxis", label: viewModel.loc("Spending Forecasts"), free: "—", pro: "3\(viewModel.loc("/mo"))")
            comparisonRow(icon: "camera.viewfinder", label: viewModel.scanReceiptLabel, free: "✓", pro: "✓")
            comparisonRow(icon: "creditcard.fill", label: viewModel.loc("Subscription Tracker"), free: "✓", pro: "✓")
            comparisonRow(icon: "clock.arrow.2.circlepath", label: viewModel.autoAnalysisLabel, free: "—", pro: "✓")
            comparisonRow(icon: "tag.fill", label: viewModel.loc("Custom Categories"), free: "—", pro: "✓")
            comparisonRow(icon: "chart.pie.fill", label: viewModel.loc("Visual Pie Charts"), free: "—", pro: "✓")
        }
        .font(.caption2).padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func comparisonRow(icon: String, label: String, free: String, pro: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.caption2).foregroundStyle(.secondary).frame(width: 16)
                Text(label).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                Text(free).frame(width: 52).foregroundStyle(.secondary)
                Text(pro).frame(width: 52).foregroundStyle(.yellow).fontWeight(.semibold)
            }.padding(.horizontal, 12).padding(.vertical, 6)
            Divider().padding(.leading, 36)
        }
    }

    // MARK: - StoreKit

    private func loadProducts() async {
        isLoading = true
        let ids = [APIConstants.monthlyProductID, APIConstants.yearlyProductID]
        do {
            let loaded = try await StoreKit.Product.products(for: ids)
            products = loaded.sorted { ($0.price ?? 0) < ($1.price ?? 0) }
        } catch {
            purchaseError = viewModel.loc("Unable to load pricing. Please try again.")
        }
        isLoading = false
    }

    private func purchase(_ product: StoreKit.Product) async {
        isPurchasing = true
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let txn) = verification {
                    await txn.finish()
                    viewModel.hasProSubscription = true
                    restoreMessage = "✅ \(viewModel.loc("Pro unlocked! Refreshing..."))"
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    dismiss()
                }
            case .userCancelled: break
            case .pending: purchaseError = viewModel.loc("Purchase pending approval.")
            @unknown default: break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
        isPurchasing = false
    }

    private func restore() async {
        restoreMessage = nil
        var found = false
        for await result in StoreKit.Transaction.all {
            guard case .verified(let txn) = result,
                  txn.productType == .autoRenewable || txn.productType == .nonRenewable,
                  txn.revocationDate == nil,
                  txn.expirationDate.map({ $0 > Date() }) ?? true else { continue }
            found = true; break
        }
        if found {
            viewModel.hasProSubscription = true
            restoreMessage = "✅ \(viewModel.loc("Purchase restored! Pro features are now unlocked."))"
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } else {
            restoreMessage = viewModel.loc("No active subscription found.")
        }
    }
}
