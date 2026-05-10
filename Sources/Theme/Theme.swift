import SwiftUI

enum AppTheme: String, CaseIterable, Sendable {
    case sage, ocean, sunset, lavender, forest, midnight, coral, honey, plum, mint, sky, blush

    var primaryColor: Color {
        switch self {
        case .sage: Color(hex: "3f7a5e")
        case .ocean: Color(hex: "2563eb")
        case .sunset: Color(hex: "ea580c")
        case .lavender: Color(hex: "7c3aed")
        case .forest: Color(hex: "166534")
        case .midnight: Color(hex: "1e293b")
        case .coral: Color(hex: "e11d48")
        case .honey: Color(hex: "d97706")
        case .plum: Color(hex: "86198f")
        case .mint: Color(hex: "0d9488")
        case .sky: Color(hex: "0284c7")
        case .blush: Color(hex: "db2777")
        }
    }

    var accentColor: Color {
        switch self {
        case .sage: Color(hex: "d4a373")
        case .ocean: Color(hex: "7dd3fc")
        case .sunset: Color(hex: "fcd34d")
        case .lavender: Color(hex: "c4b5fd")
        case .forest: Color(hex: "86efac")
        case .midnight: Color(hex: "94a3b8")
        case .coral: Color(hex: "fda4af")
        case .honey: Color(hex: "fde68a")
        case .plum: Color(hex: "e9d5ff")
        case .mint: Color(hex: "5eead4")
        case .sky: Color(hex: "7dd3fc")
        case .blush: Color(hex: "f9a8d4")
        }
    }

    var label: String {
        switch self {
        case .sage: "Sage"
        case .ocean: "Ocean"
        case .sunset: "Sunset"
        case .lavender: "Lavender"
        case .forest: "Forest"
        case .midnight: "Midnight"
        case .coral: "Coral"
        case .honey: "Honey"
        case .plum: "Plum"
        case .mint: "Mint"
        case .sky: "Sky"
        case .blush: "Blush"
        }
    }

    var gradientColors: [Color] {
        [primaryColor, primaryColor.opacity(0.7)]
    }
}

enum AppColorMode: String, CaseIterable, Sendable {
    case light, dark, system

    var label: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .system: "System"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}

enum AppFont: String, CaseIterable, Sendable {
    case inter, serif, rounded, monospaced

    var label: String {
        switch self {
        case .inter: "Inter"
        case .serif: "Serif"
        case .rounded: "Rounded"
        case .monospaced: "Mono"
        }
    }

    var design: Font.Design? {
        switch self {
        case .inter: .default
        case .serif: .serif
        case .rounded: .rounded
        case .monospaced: .monospaced
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24 & 0xFF, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
