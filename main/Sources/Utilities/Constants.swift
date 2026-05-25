import Foundation

enum APIConstants {
    private static let encodedAIProxyURL = "aHR0cHM6Ly9jbGVhcnNwZW5kLWFpLXByb3h5LmRlZXBzZWVrdjQud29ya2Vycy5kZXYvaW52b2tlLWxsbQ=="
    static let aiProxyURL = String(data: Data(base64Encoded: encodedAIProxyURL) ?? Data(), encoding: .utf8) ?? ""
    static let aiProxyClientID = "clearspend-ios"
    static let monthlyProductID = "clearspend_pro_monthly_3"
    static let yearlyProductID = "clearspend_pro_yearly_3"
    static let subscriptionGroupID = "D33B4606"
}
