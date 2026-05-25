import Foundation

@MainActor
@Observable
final class ProStatusService {
    // Feature limits: free vs pro
    private let freeLimits: [String: Int] = ["daily": 5, "recap": 1, "insight": 0, "receipt": Int.max, "forecast": 0]
    private let proLimits: [String: Int] = ["daily": 30, "recap": 15, "insight": 10, "receipt": Int.max, "forecast": 3]

    func canUse(feature: String, isPro: Bool, usage: MonthlyUsage?) -> Bool {
        let limits = isPro ? proLimits : freeLimits
        guard let limit = limits[feature] else { return false }
        let used = currentUsage(feature: feature, usage: usage)
        return used < limit
    }

    func limitFor(feature: String, isPro: Bool) -> Int {
        let limits = isPro ? proLimits : freeLimits
        return limits[feature] ?? 0
    }

    func remainingUses(feature: String, isPro: Bool, usage: MonthlyUsage?) -> Int {
        let limits = isPro ? proLimits : freeLimits
        guard let limit = limits[feature] else { return 0 }
        let used = currentUsage(feature: feature, usage: usage)
        return max(0, limit - used)
    }

    func currentUsage(feature: String, usage: MonthlyUsage?) -> Int {
        guard let usage, usage.isCurrentMonth else { return 0 }
        switch feature {
        case "daily": return usage.daily
        case "recap": return usage.recap
        case "insight": return usage.insight
        case "receipt": return usage.receipt
        case "forecast": return usage.forecast
        default: return 0
        }
    }

    func makeIncremented(_ usage: MonthlyUsage?, feature: String) -> MonthlyUsage {
        var u = usage ?? MonthlyUsage.empty
        if !u.isCurrentMonth { u = MonthlyUsage.empty }
        switch feature {
        case "daily": u.daily += 1
        case "recap": u.recap += 1
        case "insight": u.insight += 1
        case "receipt": u.receipt += 1
        case "forecast": u.forecast += 1
        default: break
        }
        return u
    }
}
