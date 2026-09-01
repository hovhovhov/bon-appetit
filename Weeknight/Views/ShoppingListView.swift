import SwiftUI

struct ShoppingListView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            switch store.shoppingMode {
            case .loading:
                loadingState
            case .error:
                errorState
            case .empty:
                emptyState
            case .ready, .stale:
                if store.shoppingItems.isEmpty { emptyState } else { listContent }
            }
        }
        .background(WeeknightTheme.background.ignoresSafeArea())
        .navigationTitle("Shopping list")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .accessibilityIdentifier("shopping-list-screen")
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shopping list")
                        .font(.largeTitle.weight(.heavy))
                        .foregroundStyle(WeeknightTheme.primaryText)
                    Text("\(store.plan.storeName) · \(store.filledCount) dinners")
                        .font(.body)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                }

                summaryCard
                    .padding(.top, WeeknightTheme.Spacing.standard)

                if store.shoppingMode == .stale {
                    staleBanner
                        .padding(.top, WeeknightTheme.Spacing.medium)
                }

                ForEach(Aisle.allCases) { aisle in
                    let items = store.shoppingItems.filter { $0.ingredient.aisle == aisle }
                    if !items.isEmpty {
                        aisleGroup(aisle, items: items)
                            .padding(.top, WeeknightTheme.Spacing.large)
                    }
                }

                Text("Generated automatically from the active plan. Estimates use mock consumed quantities.")
                    .font(.footnote)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .padding(.vertical, WeeknightTheme.Spacing.large)
            }
            .padding(.horizontal, WeeknightTheme.Spacing.gutter)
            .padding(.top, WeeknightTheme.Spacing.standard)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ESTIMATED TOTAL")
                        .font(.caption.weight(.bold))
                        .tracking(1.3)
                        .foregroundStyle(WeeknightTheme.background.opacity(0.64))
                    Text(store.weeklySpend.formatted())
                        .font(.title.weight(.heavy))
                        .foregroundStyle(WeeknightTheme.background)
                    Text("\(store.shoppingProgress.display) items")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(WeeknightTheme.mint)
                        .accessibilityIdentifier("shopping-list-progress")
                    Text(store.shoppingProgress.checked == store.shoppingProgress.total ? "shopping complete" : "in the basket")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WeeknightTheme.background.opacity(0.58))
                }
            } else {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ESTIMATED TOTAL")
                            .font(.caption.weight(.bold))
                            .tracking(1.3)
                            .foregroundStyle(WeeknightTheme.background.opacity(0.64))
                        Text(store.weeklySpend.formatted())
                            .font(.largeTitle.weight(.heavy))
                            .foregroundStyle(WeeknightTheme.background)
                    }
                    Spacer(minLength: 10)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(store.shoppingProgress.display) items")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(WeeknightTheme.mint)
                            .accessibilityIdentifier("shopping-list-progress")
                        Text(store.shoppingProgress.checked == store.shoppingProgress.total ? "shopping complete" : "in the basket")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WeeknightTheme.background.opacity(0.58))
                    }
                }
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(WeeknightTheme.background.opacity(0.16))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(WeeknightTheme.mint)
                            .frame(width: proxy.size.width * store.shoppingProgress.fraction)
                    }
            }
            .frame(height: 9)
            .accessibilityHidden(true)
        }
        .padding(18)
        .background(
            LinearGradient(colors: [WeeknightTheme.deepPine, WeeknightTheme.deepestPine], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estimated total \(store.weeklySpend.formatted()), \(store.shoppingProgress.display) items checked")
    }

    private var staleBanner: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("Estimates didn’t refresh", systemImage: "exclamationmark.triangle.fill")
                .font(.headline.weight(.bold))
            Text("Showing the deterministic fixture values. Bought state is still current.")
                .font(.subheadline)
            Button("Try again") { Task { await store.retryShopping() } }
                .font(.subheadline.weight(.bold))
                .frame(minHeight: 44)
        }
        .foregroundStyle(Color(hex: 0x8C2A17))
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xFCEAE4))
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
    }

    private func aisleGroup(_ aisle: Aisle, items: [ShoppingListItem]) -> some View {
        let progress = Planning.aisleProgress(aisle, items: store.shoppingItems)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Text(aisle.rawValue.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                Rectangle()
                    .fill(WeeknightTheme.forest.opacity(0.1))
                    .frame(height: 1)
                Text("\(progress.checked)/\(progress.total)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .accessibilityIdentifier("aisle-progress-\(aisle.rawValue)")
            }
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    shoppingRow(item)
                    if index < items.count - 1 {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .weeknightCard()
        }
    }

    private func shoppingRow(_ item: ShoppingListItem) -> some View {
        Button {
            store.toggleShoppingItem(item)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isChecked ? WeeknightTheme.leaf : WeeknightTheme.secondaryText.opacity(0.4))
                    .frame(width: 32, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.ingredient.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(item.isChecked ? WeeknightTheme.secondaryText : WeeknightTheme.bodyText)
                        .strikethrough(item.isChecked)
                    Text(contributionText(item))
                        .font(.caption)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(item.quantityDisplay)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WeeknightTheme.bodyText)
                    Text(item.estimatedCost.formatted())
                        .font(.caption)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.ingredient.displayName), \(item.quantityDisplay), for \(contributionText(item)), \(item.estimatedCost.formatted())")
        .accessibilityValue(item.isChecked ? "Bought" : "Not bought")
        .accessibilityHint("Double tap to mark \(item.isChecked ? "not bought" : "bought")")
        .accessibilityIdentifier("shopping-item-\(item.id)")
    }

    private func contributionText(_ item: ShoppingListItem) -> String {
        if item.contributions.count == 1, let only = item.contributions.first {
            return "\(only.day.shortName) · \(only.recipeTitle)"
        }
        return item.contributions.map(\.day.shortName).joined(separator: " · ")
    }

    private var loadingState: some View {
        VStack(spacing: 15) {
            ProgressView()
            Text("Regenerating the shopping list…")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var errorState: some View {
        StateMessageView(
            icon: "exclamationmark.triangle.fill",
            title: "Shopping list unavailable",
            message: "Your plan is safe. Retry the local generator to rebuild the list.",
            actionTitle: "Retry"
        ) { Task { await store.retryShopping() } }
    }

    private var emptyState: some View {
        StateMessageView(
            icon: "basket",
            title: "Nothing to buy yet",
            message: "Add a dinner to any day and its ingredients will collect here by aisle.",
            actionTitle: nil,
            action: nil
        )
    }
}

private struct StateMessageView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(WeeknightTheme.bottle)
            Text(title)
                .font(.title2.weight(.heavy))
                .foregroundStyle(WeeknightTheme.primaryText)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(WeeknightTheme.secondaryText)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(ForestActionButtonStyle())
                    .padding(.top, 4)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
