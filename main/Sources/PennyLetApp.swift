import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Token will be picked up by NotificationService
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Push registration failed: \(error.localizedDescription)")
    }
}

@main
struct PennyLetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if viewModel.isLoading {
                    Color.clear
                } else if viewModel.needsOnboarding {
                    WelcomeView()
                        .environment(viewModel)
                } else {
                    ContentView()
                        .environment(viewModel)
                }
            }
            .task {
                viewModel.loadPreferencesFromDisk()
                viewModel.loadLocalData()
                await NotificationService.shared.registerForPushNotifications()
                viewModel.isLoading = false
            }
            .tint(viewModel.theme.primaryColor)
            .preferredColorScheme(viewModel.colorMode.colorScheme)
            .fontDesign(viewModel.font.design)
            .environment(\.locale, viewModel.appLocale)
        }
    }
}
