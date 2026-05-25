import Foundation

@MainActor
@Observable
final class RevenueCatService {
    var isLoading = false
    var error: String?

    var isPro: Bool { false }

    func configure() async {}
    func purchase() async throws -> Bool { false }
    func restorePurchases() async throws -> Bool { false }
}
