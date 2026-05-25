import UIKit
import UserNotifications

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    var deviceToken: String?

    func registerForPushNotifications() async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self  // Keep self alive via static shared
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            return false
        }
    }

    func handleDeviceToken(_ token: Data) {
        deviceToken = token.map { String(format: "%02.2hhx", $0) }.joined()
    }

    func handleRegistrationError(_ error: Error) {
        deviceToken = nil
    }

    func scheduleBudgetAlert(summary: SpendSummary, currency: String, budgetName: String = "budget") {
        let center = UNUserNotificationCenter.current()
        // Remove old budget alerts
        center.removePendingNotificationRequests(withIdentifiers: ["budget_alert"])

        let pctUsed = summary.monthlyDisposable > 0 ? (summary.spent / summary.monthlyDisposable) * 100 : 0

        if pctUsed >= 100 {
            let content = UNMutableNotificationContent()
            content.title = "Budget Exceeded"
            content.body = "You've spent over your monthly budget. \(String(format: "%.0f", pctUsed))% used with \(summary.daysLeft) days remaining."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
            let request = UNNotificationRequest(identifier: "budget_alert", content: content, trigger: trigger)
            center.add(request)
        } else if pctUsed >= 80 {
            let content = UNMutableNotificationContent()
            content.title = "Budget Warning"
            content.body = "You've used \(String(format: "%.0f", pctUsed))% of your monthly budget. \(String(format: "%.2f", summary.safeDaily))/day left."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
            let request = UNNotificationRequest(identifier: "budget_alert", content: content, trigger: trigger)
            center.add(request)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        if id.hasPrefix("analysis_") {
            // Extract type: "analysis_daily", "analysis_weekly", "analysis_monthly"
            let type = id.replacingOccurrences(of: "analysis_", with: "")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .navigateToAITab, object: type)
            }
        }
        completionHandler()
    }
}
