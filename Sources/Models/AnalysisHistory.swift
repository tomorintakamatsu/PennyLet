import Foundation

struct AnalysisHistory: Codable, Identifiable, Sendable {
    var id: String
    var type: String       // "daily", "weekly", "monthly"
    var content: String    // Rich text result
    var analysisDate: String?
    var createdDate: String?
    var categoryChartJSON: String?  // JSON for category chart data
    var dailyChartJSON: String?     // JSON for daily/trend chart data

    enum CodingKeys: String, CodingKey {
        case id, type, content
        case analysisDate = "analysis_date"
        case createdDate = "created_date"
        case categoryChartJSON = "category_chart_json"
        case dailyChartJSON = "daily_chart_json"
    }

    var categoryChartData: [(name: String, amount: Double)] {
        guard let json = categoryChartJSON,
              let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { item in
            guard let name = item["name"] as? String, let amount = item["amount"] as? Double else { return nil }
            return (name, amount)
        }
    }

    var dailyChartData: [(day: String, amount: Double)] {
        guard let json = dailyChartJSON,
              let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { item in
            guard let name = item["name"] as? String, let amount = item["amount"] as? Double else { return nil }
            return (name, amount)
        }
    }
}

struct AnalysisHistoryData: Codable {
    var type: String
    var content: String
    var analysisDate: String?
    var categoryChartJSON: String?
    var dailyChartJSON: String?

    enum CodingKeys: String, CodingKey {
        case type, content
        case analysisDate = "analysis_date"
        case categoryChartJSON = "category_chart_json"
        case dailyChartJSON = "daily_chart_json"
    }
}
