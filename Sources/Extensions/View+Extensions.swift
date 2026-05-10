import SwiftUI

extension View {
    func cardStyle() -> some View {
        self
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    func gradientCard(colors: [Color]) -> some View {
        self
            .padding(24)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 24)
            )
    }
}
