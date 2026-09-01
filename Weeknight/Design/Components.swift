import SwiftUI

struct BackendStatusView: View {
    @Environment(AppStore.self) private var store
    let onDark: Bool

    private var isRetryable: Bool {
        switch store.backendState {
        case .fallback, .cached, .unavailable: true
        case .local, .loading, .connected: false
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.backendState.displayTitle)
                    .font(.caption.weight(.bold))
                if let detail = store.backendState.detail {
                    Text(detail)
                        .font(.caption2)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 4)
            if isRetryable {
                Button {
                    Task { await store.connectBackend() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Retry local backend")
                .accessibilityIdentifier("backend-retry")
            }
        }
        .foregroundStyle(onDark ? Color.white : WeeknightTheme.primaryText)
        .padding(.leading, 12)
        .padding(.trailing, isRetryable ? 4 : 12)
        .frame(minHeight: 44)
        .background(onDark ? Color.black.opacity(0.54) : WeeknightTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(statusColor.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("backend-status-banner")
    }

    private var statusIcon: String {
        switch store.backendState {
        case .connected: "server.rack"
        case .loading: "arrow.triangle.2.circlepath"
        case .cached: "externaldrive.badge.checkmark"
        case .fallback: "checkmark.shield"
        case .unavailable: "wifi.slash"
        case .local: "iphone"
        }
    }

    private var statusColor: Color {
        switch store.backendState {
        case .connected: WeeknightTheme.mint
        case .loading, .cached: Color(hex: 0xD8A23D)
        case .fallback, .unavailable: Color(hex: 0xE38B73)
        case .local: WeeknightTheme.leaf
        }
    }
}

struct BudgetProgressBar: View {
    let spent: Money
    let budget: Money
    var height: CGFloat = 10

    private var fraction: Double {
        guard budget.minorUnits > 0 else { return 0 }
        return min(1, Double(max(0, spent.minorUnits)) / Double(budget.minorUnits))
    }

    private var fill: Color {
        if spent.minorUnits > budget.minorUnits { return WeeknightTheme.tomato }
        if spent.minorUnits * 100 > budget.minorUnits * 85 { return WeeknightTheme.citrus }
        return WeeknightTheme.mint
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(WeeknightTheme.background.opacity(0.18))
                Capsule()
                    .fill(fill)
                    .frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

struct TagChip: View {
    let text: String
    var onDark = false

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(onDark ? Color.white : WeeknightTheme.bottle)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(onDark ? Color.white.opacity(0.17) : WeeknightTheme.wash.opacity(0.75))
            .clipShape(Capsule())
    }
}

struct RecipeArtwork: View {
    let style: ArtworkStyle
    var compact = false

    private var palette: [Color] {
        switch style {
        case .honeySoy: return [Color(hex: 0xB66A32), Color(hex: 0x3F7C42), Color(hex: 0xF2D7A0)]
        case .chilli: return [Color(hex: 0x8C2A17), Color(hex: 0xD17B2E), Color(hex: 0xF2C96D)]
        case .stirFry: return [Color(hex: 0xD87543), Color(hex: 0x6DAF58), Color(hex: 0xE7C46A)]
        case .carbonara: return [Color(hex: 0xE5B843), Color(hex: 0xF4E2A7), Color(hex: 0x8C5438)]
        case .curry: return [Color(hex: 0xB95A1C), Color(hex: 0xE9A62E), Color(hex: 0x2F7541)]
        case .caesar: return [Color(hex: 0x4D8A46), Color(hex: 0xB7CB73), Color(hex: 0xE3C18A)]
        case .chopped: return [Color(hex: 0xE45B3F), Color(hex: 0xE9B23C), Color(hex: 0x4FA85A)]
        case .steak: return [Color(hex: 0x613729), Color(hex: 0xC98B3B), Color(hex: 0x2F6A42)]
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: compact ? 70 : 260)
                .offset(x: compact ? 18 : 74, y: compact ? -12 : -90)
            RoundedRectangle(cornerRadius: compact ? 12 : 44, style: .continuous)
                .fill(palette[2].opacity(0.48))
                .frame(width: compact ? 76 : 300, height: compact ? 36 : 150)
                .rotationEffect(.degrees(-12))
                .offset(x: compact ? -16 : -92, y: compact ? 20 : 120)
            Image(systemName: compact ? "fork.knife" : "fork.knife.circle.fill")
                .font(.system(size: compact ? 24 : 94, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    let background: Color
    var systemImage = "checkmark.circle.fill"

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(background)
            .clipShape(Capsule())
    }
}
