import SwiftUI

enum WeeknightTheme {
    static let background = Color(hex: 0xFBF5EA)
    static let surface = Color.white
    static let surfaceElevated = Color(hex: 0xF7F1E6)
    static let primaryText = Color(hex: 0x0E2A1C)
    static let bodyText = Color(hex: 0x1D1B18)
    static let secondaryText = Color(hex: 0x625E57)
    static let forest = Color(hex: 0x0E2A1C)
    static let deepPine = Color(hex: 0x143824)
    static let deepestPine = Color(hex: 0x0A1F15)
    static let leaf = Color(hex: 0x3FBE55)
    static let bottle = Color(hex: 0x186B2C)
    static let mint = Color(hex: 0x8FE7A8)
    static let wash = Color(hex: 0xDCF3E1)
    static let sand = Color(hex: 0xEDE5D5)
    static let citrus = Color(hex: 0xE9B23C)
    static let tomato = Color(hex: 0xC4472C)

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let standard: CGFloat = 16
        static let gutter: CGFloat = 20
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
    }

    enum Radius {
        static let chip: CGFloat = 999
        static let thumbnail: CGFloat = 14
        static let row: CGFloat = 18
        static let card: CGFloat = 22
        static let budget: CGFloat = 26
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

struct WeeknightCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(WeeknightTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: WeeknightTheme.Radius.card, style: .continuous)
                    .stroke(WeeknightTheme.forest.opacity(0.07), lineWidth: 1)
            }
            .shadow(color: WeeknightTheme.forest.opacity(0.08), radius: 14, y: 8)
    }
}

extension View {
    func weeknightCard() -> some View { modifier(WeeknightCard()) }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(WeeknightTheme.forest)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, WeeknightTheme.Spacing.standard)
            .background(configuration.isPressed ? WeeknightTheme.leaf.opacity(0.75) : WeeknightTheme.leaf)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct ForestActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(WeeknightTheme.background)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, WeeknightTheme.Spacing.standard)
            .background(configuration.isPressed ? WeeknightTheme.deepPine : WeeknightTheme.forest)
            .clipShape(Capsule())
    }
}

