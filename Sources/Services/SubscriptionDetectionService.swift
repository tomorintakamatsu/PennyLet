import StoreKit
import SwiftUI

@MainActor
final class SubscriptionDetectionService {
    var detectedSubs: [DetectedSubscription] = []
    var isLoading = false
    var yearlyTotal: Double = 0
    var monthlyTotal: Double = 0

    struct DetectedSubscription: Identifiable, Sendable {
        let id: String
        let productID: String
        let displayName: String
        let price: Decimal
        let currencyCode: String
        let period: String  // "monthly", "yearly", etc
        let renewalDate: Date?
        let isActive: Bool
    }

    // Map common App Store product ID patterns to friendly names
    private let nameMap: [String: String] = [
        "youtube": "YouTube Premium",
        "spotify": "Spotify",
        "netflix": "Netflix",
        "disney": "Disney+",
        "hulu": "Hulu",
        "hbo": "Max (HBO)",
        "apple.music": "Apple Music",
        "apple.arcade": "Apple Arcade",
        "apple.news": "Apple News+",
        "apple.fitness": "Apple Fitness+",
        "apple.tv": "Apple TV+",
        "icloud": "iCloud+",
        "amazon": "Amazon Prime",
        "tinder": "Tinder",
        "bumble": "Bumble",
        "hinge": "Hinge",
        "strava": "Strava",
        "peloton": "Peloton",
        "fitness": "Fitness App",
        "calm": "Calm",
        "headspace": "Headspace",
        "duolingo": "Duolingo",
        "babbel": "Babbel",
        "adobe": "Adobe Creative Cloud",
        "microsoft": "Microsoft 365",
        "dropbox": "Dropbox",
        "google": "Google One",
        "notion": "Notion",
        "todoist": "Todoist",
        "evernote": "Evernote",
        "fantastical": "Fantastical",
        "carrot": "CARROT Weather",
        "dark.sky": "Dark Sky",
        "clearspend": "ClearSpend Pro",
    ]

    func detectSubscriptions() async {
        isLoading = true
        defer { isLoading = false }

        #if targetEnvironment(simulator)
        detectedSubs = []
        monthlyTotal = 0
        yearlyTotal = 0
        #else
        var found: [DetectedSubscription] = []
        var productIDs = Set<String>()
        var renewalDates: [String: Date] = [:]
        var expireDates: [String: Date] = [:]

        // Pass 1: collect active subscription transactions
        for await result in StoreKit.Transaction.all {
            guard case .verified(let txn) = result,
                  txn.productType == .autoRenewable || txn.productType == .nonRenewable,
                  txn.revocationDate == nil else { continue }
            let expired = txn.expirationDate.map { $0 <= Date() } ?? false
            if !expired {
                productIDs.insert(txn.productID)
                renewalDates[txn.productID] = txn.expirationDate
            }
            expireDates[txn.productID] = txn.expirationDate
        }

        // Pass 2: fetch StoreKit product details
        var storeProducts: [String: StoreKit.Product] = [:]
        if !productIDs.isEmpty {
            if let fetched = try? await StoreKit.Product.products(for: productIDs) {
                for product in fetched {
                    storeProducts[product.id] = product
                }
            }
        }

        // Pass 3: build the list
        for pid in productIDs {
            let product = storeProducts[pid]
            let renewal = renewalDates[pid]
            let displayName = friendlyName(for: pid)

            let period: String = {
                if let sub = product?.subscription {
                    switch sub.subscriptionPeriod.unit {
                    case .year: return sub.subscriptionPeriod.value == 1 ? "yearly" : "every \(sub.subscriptionPeriod.value) years"
                    case .month: return sub.subscriptionPeriod.value == 1 ? "monthly" : "every \(sub.subscriptionPeriod.value) months"
                    case .week: return sub.subscriptionPeriod.value == 1 ? "weekly" : "every \(sub.subscriptionPeriod.value) weeks"
                    case .day: return sub.subscriptionPeriod.value == 1 ? "daily" : "every \(sub.subscriptionPeriod.value) days"
                    @unknown default: return "unknown"
                    }
                }
                return "subscription"
            }()

            found.append(DetectedSubscription(
                id: pid,
                productID: pid,
                displayName: displayName,
                price: product?.price ?? 0,
                currencyCode: product?.priceFormatStyle.locale.currencyCode ?? product?.priceFormatStyle.locale.currency?.identifier ?? "USD",
                period: period,
                renewalDate: renewal,
                isActive: true
            ))
        }

        detectedSubs = found.sorted { a, b in
            if a.isActive != b.isActive { return a.isActive }
            return a.displayName < b.displayName
        }

        // Calculate totals
        monthlyTotal = found.filter(\.isActive).reduce(0) { total, sub in
            let monthlyPrice: Decimal
            switch sub.period {
            case "yearly": monthlyPrice = sub.price / 12
            case "monthly": monthlyPrice = sub.price
            case "weekly": monthlyPrice = sub.price * 4.33
            default: monthlyPrice = sub.price
            }
            return total + (NSDecimalNumber(decimal: monthlyPrice).doubleValue)
        }
        yearlyTotal = monthlyTotal * 12
        #endif
    }

    func friendlyName(for productID: String) -> String {
        let lower = productID.lowercased()
        for (key, name) in nameMap {
            if lower.contains(key) { return name }
        }
        // Fallback: clean up the product ID
        return productID
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
