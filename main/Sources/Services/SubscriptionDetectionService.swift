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

    struct InferredSubscription: Identifiable, Sendable {
        let id: String
        let name: String
        let amount: Double
        let currencyCode: String
        let category: String?
        let interval: RecurringSubscription.BillingInterval
        let customIntervalDays: Int?
        let nextBillingDate: Date
        let latestTransactionDate: Date
        let matchedTransactions: Int
        let confidence: Double
    }

    private struct LocalCharge {
        let key: String
        let name: String
        let amount: Double
        let category: String?
        let date: Date
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
        "clearspend": "PennyLet Pro",
        "pennylet": "PennyLet Pro",
    ]

    func detectSubscriptions() async {
        isLoading = true
        defer { isLoading = false }

        #if targetEnvironment(simulator)
        detectedSubs = []
        monthlyTotal = 0
        yearlyTotal = 0
        #else
        let now = Date()
        var found: [DetectedSubscription] = []
        var productIDs = Set<String>()
        var latestTransactions: [String: StoreKit.Transaction] = [:]

        func consider(_ txn: StoreKit.Transaction) {
            guard txn.productType == .autoRenewable || txn.productType == .nonRenewable else { return }
            productIDs.insert(txn.productID)
            if let existing = latestTransactions[txn.productID] {
                if txn.purchaseDate > existing.purchaseDate {
                    latestTransactions[txn.productID] = txn
                }
            } else {
                latestTransactions[txn.productID] = txn
            }
        }

        // Pass 1: current entitlements catches the active subscriptions StoreKit exposes fastest.
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let txn) = result {
                consider(txn)
            }
        }

        // Pass 2: full purchase history catches expired, non-renewing, and restored subscriptions.
        for await result in StoreKit.Transaction.all {
            if case .verified(let txn) = result {
                consider(txn)
            }
        }

        // Pass 3: fetch StoreKit product details.
        var storeProducts: [String: StoreKit.Product] = [:]
        if !productIDs.isEmpty {
            if let fetched = try? await StoreKit.Product.products(for: productIDs) {
                for product in fetched {
                    storeProducts[product.id] = product
                }
            }
        }

        // Pass 4: build the list.
        for pid in productIDs {
            guard let txn = latestTransactions[pid] else { continue }
            let product = storeProducts[pid]
            let expiration = txn.expirationDate
            let active = txn.revocationDate == nil && (expiration.map { $0 > now } ?? true)
            let displayName = product?.displayName ?? friendlyName(for: pid)

            let period: String = {
                if let sub = product?.subscription {
                    switch sub.subscriptionPeriod.unit {
                    case .year: return sub.subscriptionPeriod.value == 1 ? "yearly" : "every \(sub.subscriptionPeriod.value) years"
                    case .month: return sub.subscriptionPeriod.value == 1 ? "monthly" : "every \(sub.subscriptionPeriod.value) months"
                    case .week: return sub.subscriptionPeriod.value == 1 ? "weekly" : (sub.subscriptionPeriod.value == 2 ? "biweekly" : "every \(sub.subscriptionPeriod.value) weeks")
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
                renewalDate: expiration,
                isActive: active
            ))
        }

        detectedSubs = found.sorted { a, b in
            if a.isActive != b.isActive { return a.isActive }
            return a.displayName < b.displayName
        }

        // Calculate totals
        monthlyTotal = found.filter(\.isActive).reduce(0) { total, sub in
            total + Self.monthlyValue(price: sub.price, period: sub.period)
        }
        yearlyTotal = monthlyTotal * 12
        #endif
    }

    static func inferLocalSubscriptions(
        from transactions: [Transaction],
        currencyCode: String
    ) -> [InferredSubscription] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let charges: [LocalCharge] = transactions.compactMap { tx in
            guard tx.type == .expense,
                  let date = tx.dateValue,
                  tx.amount > 0 else { return nil }

            let rawName = [tx.merchant, tx.note]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }
            guard let name = rawName else { return nil }

            let normalized = normalizedName(name)
            guard normalized.count >= 3 else { return nil }

            let amountBucket = Int((tx.amount * 100).rounded())
            return LocalCharge(
                key: "\(normalized)#\(amountBucket)",
                name: name,
                amount: tx.amount,
                category: tx.category,
                date: calendar.startOfDay(for: date)
            )
        }

        let grouped = Dictionary(grouping: charges, by: { $0.key })
        let inferred = grouped.compactMap { _, group -> InferredSubscription? in
            let ordered = group.sorted { $0.date < $1.date }
            guard ordered.count >= 2 else { return nil }

            let gaps = zip(ordered.dropFirst(), ordered).compactMap { later, earlier in
                calendar.dateComponents([.day], from: earlier.date, to: later.date).day
            }.filter { $0 > 0 }

            guard let medianGap = median(gaps.map(Double.init)),
                  let interval = interval(forMedianGap: medianGap) else { return nil }

            let expectedDays = expectedDays(for: interval, medianGap: medianGap)
            let intervalTolerance = max(3.0, expectedDays * 0.25)
            let intervalConsistency = gaps.isEmpty ? 0 : Double(gaps.filter {
                abs(Double($0) - expectedDays) <= intervalTolerance
            }.count) / Double(gaps.count)

            let amounts = ordered.map(\.amount)
            let medianAmount = median(amounts) ?? ordered.last?.amount ?? 0
            let amountTolerance = max(1.0, medianAmount * 0.12)
            let amountConsistency = Double(amounts.filter {
                abs($0 - medianAmount) <= amountTolerance
            }.count) / Double(amounts.count)

            let categoryBoost = ordered.contains { ($0.category ?? "").lowercased() == "subscriptions" } ? 0.12 : 0
            let countScore = min(Double(ordered.count) * 0.12, 0.36)
            let confidence = min(0.98, 0.22 + countScore + intervalConsistency * 0.22 + amountConsistency * 0.20 + categoryBoost)
            guard confidence >= (categoryBoost > 0 ? 0.52 : 0.62) else { return nil }

            guard let latest = ordered.last else { return nil }
            var nextDate = calendar.date(byAdding: .day, value: Int(expectedDays.rounded()), to: latest.date) ?? latest.date
            while nextDate <= today {
                nextDate = calendar.date(byAdding: .day, value: Int(expectedDays.rounded()), to: nextDate) ?? nextDate
            }

            let category = ordered.reversed().first { $0.category != nil }?.category
            let displayName = mostCommonName(in: ordered)
            let customDays = interval == .custom ? max(1, Int(medianGap.rounded())) : nil
            let cents = Int((medianAmount * 100).rounded())
            return InferredSubscription(
                id: "\(normalizedName(displayName))#\(cents)#\(interval.rawValue)",
                name: displayName,
                amount: medianAmount,
                currencyCode: currencyCode,
                category: category,
                interval: interval,
                customIntervalDays: customDays,
                nextBillingDate: nextDate,
                latestTransactionDate: latest.date,
                matchedTransactions: ordered.count,
                confidence: confidence
            )
        }

        return inferred.sorted {
            if $0.confidence != $1.confidence { return $0.confidence > $1.confidence }
            return $0.nextBillingDate < $1.nextBillingDate
        }
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

    private static func normalizedName(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func median(_ values: [Double]) -> Double? {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return nil }
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private static func interval(forMedianGap gap: Double) -> RecurringSubscription.BillingInterval? {
        switch gap {
        case 5...9: return .weekly
        case 10...18: return .biweekly
        case 24...38: return .monthly
        case 2...120: return .custom
        default: return nil
        }
    }

    private static func expectedDays(for interval: RecurringSubscription.BillingInterval, medianGap: Double) -> Double {
        switch interval {
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30
        case .custom: return max(1, medianGap.rounded())
        }
    }

    private static func mostCommonName(in charges: [LocalCharge]) -> String {
        let counts = Dictionary(grouping: charges, by: \.name)
            .mapValues(\.count)
        return counts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return lhs.key.count < rhs.key.count
        }?.key ?? charges.last?.name ?? "Subscription"
    }

    private static func monthlyValue(price: Decimal, period: String) -> Double {
        let value = NSDecimalNumber(decimal: price).doubleValue
        switch period {
        case "yearly": return value / 12
        case "monthly": return value
        case "weekly": return value * 4.33
        case "biweekly": return value * 2.165
        case "daily": return value * 30
        default:
            if let parsed = parseDynamicPeriod(period) {
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

    private static func parseDynamicPeriod(_ period: String) -> (count: Int, unit: String)? {
        let parts = period.split(separator: " ")
        guard parts.count == 3,
              parts[0].lowercased() == "every",
              let count = Int(parts[1]) else { return nil }
        return (count, String(parts[2]).lowercased())
    }
}
