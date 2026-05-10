import SwiftUI
import AuthenticationServices
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
struct ClearSpendApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if viewModel.isLoading {
                    LaunchScreen()
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
        }
    }
}

struct LaunchScreen: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            Text("ClearSpend")
                .font(.largeTitle.weight(.bold))
            ProgressView()
                .padding(.top, 8)
        }
    }
}

struct SignInView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var email = ""
    @State private var password = ""
    @State private var otpCode = ""
    @State private var isRegistering: Bool

    init(startInRegisterMode: Bool = false) {
        _isRegistering = State(initialValue: startInRegisterMode)
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(.green)
            Text(viewModel.loc("ClearSpend"))
                .font(.largeTitle.weight(.bold))

            if viewModel.showOTPEntry {
                otpView
            } else {
                signInForm
            }

            Spacer()
        }
    }

    private var otpView: some View {
        VStack(spacing: 16) {
            Text(viewModel.loc("Verify Email"))
                .font(.title3.weight(.semibold))
            Text(viewModel.loc("Enter the verification code sent to your email"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let error = viewModel.authError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            TextField(viewModel.loc("Verification Code"), text: $otpCode)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            Button {
                viewModel.verifyOTPAndSignIn(code: otpCode)
            } label: {
                HStack {
                    if viewModel.isAuthenticating {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(viewModel.loc("Verify & Sign In"))
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(!otpCode.isEmpty && !viewModel.isAuthenticating ? Color.accentColor : Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(otpCode.isEmpty || viewModel.isAuthenticating)

            Button {
                viewModel.showOTPEntry = false
                viewModel.authError = nil
            } label: {
                Text(viewModel.loc("Back"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 36)
    }

    private var signInForm: some View {
        VStack(spacing: 16) {
            Text(viewModel.loc("Track spending, reach goals"))
                .foregroundStyle(.secondary)

            if let error = viewModel.authError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 14) {
                TextField(viewModel.loc("Email"), text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                SecureField(viewModel.loc("Password"), text: $password)
                    .textContentType(isRegistering ? .newPassword : .password)
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                Button {
                    if isRegistering {
                        viewModel.registerWithEmail(email: email, password: password)
                    } else {
                        viewModel.loginWithEmail(email: email, password: password)
                    }
                } label: {
                    HStack {
                        if viewModel.isAuthenticating {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isRegistering ? viewModel.loc("Create Account") : viewModel.loc("Sign In"))
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isValid && !viewModel.isAuthenticating ? Color.accentColor : Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!isValid || viewModel.isAuthenticating)

                Button {
                    withAnimation { isRegistering.toggle() }
                    viewModel.authError = nil
                } label: {
                    Text(isRegistering
                        ? viewModel.loc("Already have an account? Sign In")
                        : viewModel.loc("Don't have an account? Create one"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 12) {
                HStack {
                    Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.3))
                    Text(viewModel.loc("or"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.3))
                }

                Button {
                    viewModel.startAppleSignIn()
                } label: {
                    HStack {
                        if viewModel.isAuthenticating {
                            ProgressView()
                                .tint(.white)
                        }
                        Image(systemName: "apple.logo")
                            .font(.title3)
                        Text(viewModel.loc("Sign In with Apple"))
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(viewModel.isAuthenticating)

                Button {
                    viewModel.continueAsGuest()
                } label: {
                    Text(viewModel.loc("Continue as Guest"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .disabled(viewModel.isAuthenticating)
            }
        }
        .padding(.horizontal, 36)
    }

    private var isValid: Bool {
        email.contains("@") && email.contains(".") && password.count >= 6
    }
}
