import SwiftUI

enum WeeknightTheme {
    static let background = Color(hex: 0xFBF8EC)
    static let surface = Color(hex: 0xFBF8EC)
    static let surfaceElevated = Color(hex: 0xF1E9D8)
    static let primaryText = Color(hex: 0x14180F)
    static let bodyText = Color(hex: 0x14180F)
    static let secondaryText = Color(hex: 0x62665D)
    static let forest = Color(hex: 0x14512F)
    static let deepPine = Color(hex: 0x14512F)
    static let deepestPine = Color(hex: 0x0D2E1D)
    static let leaf = Color(hex: 0x8FD37A)
    static let bottle = Color(hex: 0x14512F)
    static let mint = Color(hex: 0x8FD37A)
    static let wash = Color(hex: 0xE8EDDF)
    static let sand = Color(hex: 0xF1E9D8)
    static let hairline = Color(hex: 0xEBE3D2)
    static let disabledText = Color(hex: 0x555A51)
    static let disabledSurface = Color(hex: 0xE5DDCC)
    static let citrus = Color(hex: 0xB67C20)
    static let tomato = Color(hex: 0xA03B2A)
    static let photoText = Color(hex: 0xFBF8EC)

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 14
        static let standard: CGFloat = 20
        static let gutter: CGFloat = 22
        static let large: CGFloat = 26
        static let xLarge: CGFloat = 34
    }

    enum Radius {
        static let chip: CGFloat = 28
        static let thumbnail: CGFloat = 14
        static let row: CGFloat = 18
        static let card: CGFloat = 22
        static let budget: CGFloat = 30
        static let sheet: CGFloat = 30
        static let button: CGFloat = 28
    }

    enum Motion {
        static let quick: Double = 0.12
        static let settle: Double = 0.26
        static let sheet: Double = 0.32
        static let assignment: Double = 0.42
        static let completion: Double = 0.54
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
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .background(WeeknightTheme.surfaceElevated.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: WeeknightTheme.Radius.card, style: .continuous)
                    .stroke(
                        contrast == .increased ? WeeknightTheme.forest.opacity(0.48) : WeeknightTheme.hairline,
                        lineWidth: contrast == .increased ? 2 : 1
                    )
            }
    }
}

extension View {
    func weeknightCard() -> some View { modifier(WeeknightCard()) }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(isEnabled ? WeeknightTheme.background : WeeknightTheme.disabledText)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, WeeknightTheme.Spacing.standard)
            .background(
                isEnabled
                    ? (configuration.isPressed ? WeeknightTheme.deepestPine : WeeknightTheme.forest)
                    : WeeknightTheme.disabledSurface
            )
            .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

struct ForestActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(isEnabled ? WeeknightTheme.background : WeeknightTheme.disabledText)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, WeeknightTheme.Spacing.standard)
            .background(
                isEnabled
                    ? (configuration.isPressed ? WeeknightTheme.deepPine : WeeknightTheme.forest)
                    : WeeknightTheme.disabledSurface
            )
            .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.button, style: .continuous))
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(isEnabled ? WeeknightTheme.primaryText : WeeknightTheme.disabledText)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, WeeknightTheme.Spacing.standard)
            .background(
                isEnabled
                    ? (configuration.isPressed ? WeeknightTheme.surfaceElevated : Color.clear)
                    : WeeknightTheme.disabledSurface
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(WeeknightTheme.secondaryText.opacity(0.42), lineWidth: 1)
            }
    }
}

struct NotchedDayTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = min(12, rect.height / 3)
        let notch: CGFloat = min(14, rect.width / 6)
        var path = Path()
        path.move(to: CGPoint(x: radius, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: notch),
            control: CGPoint(x: rect.maxX - 2, y: 1)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.maxY - radius),
            control: CGPoint(x: 0, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addQuadCurve(to: CGPoint(x: radius, y: 0), control: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        return path
    }
}
