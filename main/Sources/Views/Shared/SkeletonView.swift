import SwiftUI

struct SkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .overlay(shimmer(in: geo.size))
        }
        .onAppear { isAnimating = true }
        .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
    }

    private func shimmer(in size: CGSize) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.3), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .rotationEffect(.degrees(30))
            .offset(x: isAnimating ? size.width : -size.width)
    }
}

struct SkeletonCard: View {
    var body: some View {
        VStack(spacing: 12) {
            SkeletonView()
                .frame(height: 16)
            SkeletonView()
                .frame(height: 12)
                .padding(.trailing, 40)
            SkeletonView()
                .frame(height: 40)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
