import SwiftUI

extension View {
    func cardStyle() -> some View {
        self
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
    }

    func gradientCard(colors: [Color]) -> some View {
        self
            .padding(24)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 8)
            )
    }

    func clearSpendScreenBackground(theme: AppTheme) -> some View {
        background {
            PennyLetSurfaceBackground(theme: theme)
        }
        .scrollContentBackground(.hidden)
    }

    func premiumPanel(tint: Color? = nil) -> some View {
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.28),
                                (tint ?? Color.primary).opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.05), radius: 14, y: 8)
    }
}

private struct PennyLetSurfaceBackground: View {
    let theme: AppTheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.systemBackground)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    theme.primaryColor.opacity(0.13),
                    theme.accentColor.opacity(0.07),
                    Color(.systemBackground).opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .white.opacity(0.18),
                    .clear,
                    theme.primaryColor.opacity(0.05)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()
        }
    }
}
