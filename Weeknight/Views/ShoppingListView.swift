import SwiftUI
import UIKit

struct ShoppingListView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .accessibilityIdentifier("shopping-list-screen")
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Shopping")
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(WeeknightTheme.primaryText)
                    Spacer(minLength: 12)
                    Text(store.plan.storeName)
                        .font(.headline)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                        .multilineTextAlignment(.trailing)
                }

                summary
                    .padding(.top, 16)

                if store.shoppingMode == .stale {
                    staleBanner.padding(.top, 14)
                }

                ForEach(Aisle.allCases) { aisle in
                    let items = store.shoppingItems.filter { $0.ingredient.aisle == aisle }
                    if !items.isEmpty {
                        aisleGroup(aisle, items: items)
                            .padding(.top, 28)
                    }
                }

                Text("Generated automatically from the active week. Prices are deterministic development estimates.")
                    .font(.footnote)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .padding(.vertical, 28)
            }
            .padding(.horizontal, WeeknightTheme.Spacing.gutter)
            .padding(.top, WeeknightTheme.Spacing.standard)
            .padding(.bottom, 90)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Estimated total")
                        .font(.subheadline)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(store.weeklySpend.formatted())
                            .font(.title.weight(.black))
                        Text("of \(store.plan.budget.formatted())")
                            .font(.headline)
                            .foregroundStyle(WeeknightTheme.secondaryText)
                    }
                }
                Spacer()
                Text("Tap items as you shop")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WeeknightTheme.forest)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, WeeknightTheme.Spacing.gutter)
            .padding(.vertical, 12)
            .background(WeeknightTheme.background)
            .overlay(alignment: .top) { Divider().overlay(WeeknightTheme.hairline) }
        }
    }

    private var summary: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(store.shoppingProgress.checked) of \(store.shoppingProgress.total) in the basket")
                    .font(.title3.weight(.black))
                    .foregroundStyle(WeeknightTheme.primaryText)
                    .accessibilityIdentifier("shopping-list-progress")
                Spacer(minLength: 10)
                Text(store.weeklySpend.formatted())
                    .font(.title3.weight(.black))
                    .foregroundStyle(WeeknightTheme.primaryText)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(WeeknightTheme.hairline)
                    Capsule()
                        .fill(WeeknightTheme.forest)
                        .frame(width: proxy.size.width * store.shoppingProgress.fraction)
                }
            }
            .frame(height: 3)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estimated total \(store.weeklySpend.formatted()), \(store.shoppingProgress.display) items checked")
    }

    private var staleBanner: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("Estimates didn’t refresh", systemImage: "exclamationmark.triangle.fill")
                .font(.headline.weight(.bold))
            Text("Showing deterministic local values. Bought state is still current.")
                .font(.subheadline)
            Button("Try again") { Task { await store.retryShopping() } }
                .font(.subheadline.weight(.bold))
                .frame(minHeight: 44)
        }
        .foregroundStyle(WeeknightTheme.tomato)
        .padding(14)
        .background(WeeknightTheme.tomato.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
    }

    private func aisleGroup(_ aisle: Aisle, items: [ShoppingListItem]) -> some View {
        let progress = Planning.aisleProgress(aisle, items: store.shoppingItems)
        return VStack(alignment: .leading, spacing: 0) {
            Text("\(aisle.rawValue.uppercased()) · \(items.count)")
                .font(.caption.weight(.bold))
                .tracking(1.8)
                .foregroundStyle(WeeknightTheme.secondaryText)
                .padding(.bottom, 8)
                .accessibilityIdentifier("aisle-progress-\(aisle.rawValue)")
                .accessibilityLabel("\(progress.checked)/\(progress.total)")

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                shoppingRow(item)
                if index < items.count - 1 {
                    Divider().overlay(WeeknightTheme.hairline).padding(.leading, 54)
                }
            }
        }
    }

    private func shoppingRow(_ item: ShoppingListItem) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: WeeknightTheme.Motion.settle)) {
                store.toggleShoppingItem(item)
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isChecked ? WeeknightTheme.forest : WeeknightTheme.secondaryText)
                    .frame(width: 44, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(item.ingredient.displayName) · \(item.quantityDisplay)")
                        .font(.body.weight(.medium))
                        .foregroundStyle(item.isChecked ? WeeknightTheme.secondaryText : WeeknightTheme.primaryText)
                        .strikethrough(item.isChecked)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(contributionText(item))
                        .font(.caption)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text(item.estimatedCost.formatted())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WeeknightTheme.secondaryText)
            }
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
        return item.contributions.map(\.day.shortName).joined(separator: ", ")
    }

    private var loadingState: some View {
        StateMessageView(
            icon: "arrow.triangle.2.circlepath",
            title: "Regenerating the list",
            message: "Your active week is still the source of truth.",
            actionTitle: nil,
            action: nil
        )
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
            message: "Add a dinner and its ingredients will collect here by aisle.",
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
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(WeeknightTheme.forest)
            Text(title)
                .font(.largeTitle.weight(.black))
                .foregroundStyle(WeeknightTheme.primaryText)
            Text(message)
                .foregroundStyle(WeeknightTheme.secondaryText)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryActionButtonStyle())
            }
        }
        .padding(WeeknightTheme.Spacing.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
