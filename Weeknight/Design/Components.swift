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
    var height: CGFloat = 3
    var onPhotography = false

    private var fraction: Double {
        guard budget.minorUnits > 0 else { return 0 }
        return min(1, Double(max(0, spent.minorUnits)) / Double(budget.minorUnits))
    }

    private var fill: Color {
        if spent.minorUnits > budget.minorUnits { return WeeknightTheme.tomato }
        if spent.minorUnits * 100 > budget.minorUnits * 85 { return WeeknightTheme.citrus }
        return onPhotography ? WeeknightTheme.leaf : WeeknightTheme.forest
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(onPhotography ? Color.white.opacity(0.28) : WeeknightTheme.hairline)
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
            .foregroundStyle(onDark ? WeeknightTheme.photoText : WeeknightTheme.secondaryText)
            .padding(.trailing, 8)
    }
}

struct RecipeArtwork: View {
    let style: ArtworkStyle
    var compact = false

    var body: some View {
        Image("recipe_\(style.rawValue)")
            .resizable()
            .scaledToFill()
        .clipped()
        .accessibilityHidden(true)
    }
}

struct NotchedDayTab: View {
    let text: String
    var compact = false

    var body: some View {
        Text(text.uppercased())
            .font((compact ? Font.caption2 : Font.caption).weight(.bold))
            .tracking(compact ? 1.1 : 1.8)
            .foregroundStyle(WeeknightTheme.primaryText)
            .padding(.horizontal, compact ? 9 : 14)
            .frame(minHeight: compact ? 30 : 38)
            .background(WeeknightTheme.background)
            .clipShape(NotchedDayTabShape())
    }
}

struct PhotoScrim: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color.black.opacity(0.12), location: 0),
                .init(color: Color.clear, location: 0.38),
                .init(color: Color.black.opacity(0.34), location: 0.63),
                .init(color: Color.black.opacity(0.9), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .accessibilityHidden(true)
    }
}

/// A compact, wrapping layout for the handful of editorial tags used across recipe surfaces.
struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let availableWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > availableWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: availableWidth.isFinite ? availableWidth : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
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
