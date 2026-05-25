import SwiftUI

struct GuestUpgradeModal: View {
    @Environment(AppViewModel.self) private var viewModel
    @Binding var showSignInSheet: Bool
    @Binding var signInRegisterMode: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "crown.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.yellow)
                Text(viewModel.loc("Account Required"))
                    .font(.title2.weight(.bold))
                Text(viewModel.loc("To upgrade to PennyLet Pro, you need an account. Your data will be saved and synced across devices."))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    Button {
                        signInRegisterMode = true
                        dismiss()
                        showSignInSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text(viewModel.loc("Create Account"))
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.yellow, in: RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        signInRegisterMode = false
                        dismiss()
                        showSignInSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "person.fill")
                            Text(viewModel.loc("Log In"))
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(viewModel.theme.primaryColor, in: RoundedRectangle(cornerRadius: 8))
                    }

                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text(viewModel.cancelLabel)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, 32)
                Spacer()
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
            .clearSpendScreenBackground(theme: viewModel.theme)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.cancelLabel) { dismiss() }
                }
            }
        }
    }
}
