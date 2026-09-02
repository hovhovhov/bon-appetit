import SwiftUI

struct DiscoverView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedRecipe: Recipe?
    @State private var detailRecipeID: Recipe.ID?
    @State private var visibleRecipeID: Recipe.ID?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                WeeknightTheme.deepestPine.ignoresSafeArea()
                content(size: proxy.size)
                if store.recipeMode == .ready || store.recipeMode == .stale,
                   !store.discoverRecipes.isEmpty {
                    VStack(spacing: 7) {
                        progressHeader
                        if showsBackendStatus { BackendStatusView(onDark: true) }
                    }
                    .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                    .padding(.top, 8)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $selectedRecipe) { recipe in
            AddToWeekSheet(recipe: recipe, servings: store.preferences.householdSize)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(WeeknightTheme.Radius.sheet)
        }
        .navigationDestination(item: $detailRecipeID) { recipeID in
            RecipeDetailsView(
                recipeID: recipeID,
                origin: .discover,
                initialServings: store.preferences.householdSize
            )
        }
        .task {
            await store.loadRecipesIfNeeded()
            if visibleRecipeID == nil { visibleRecipeID = store.rankedDiscoverRecipes.first?.id }
        }
        .accessibilityIdentifier("discover-screen")
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        switch store.recipeMode {
        case .loading:
            loadingState
        case .error:
            statePanel(
                icon: "wifi.exclamationmark",
                title: "Recipes didn’t load",
                message: "Your local week is safe. Try again to restore the feed.",
                action: "Try again"
            ) { Task { await store.retryRecipes() } }
        case .empty:
            statePanel(
                icon: "fork.knife",
                title: "No recipes yet",
                message: "There is nothing in this recipe source right now.",
                action: "Back to Plan"
            ) { store.selectedTab = .plan }
        case .ready, .stale:
            if store.discoverRecipes.isEmpty {
                noResultsState
            } else {
                recipePages(size: size)
            }
        }
    }

    @ViewBuilder
    private func recipePages(size: CGSize) -> some View {
        let pages = ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(Array(store.rankedDiscoverRecipes.enumerated()), id: \.element.id) { index, ranked in
                    RecipeFeedPage(
                        ranked: ranked,
                        position: index,
                        count: store.rankedDiscoverRecipes.count,
                        onDetails: { detailRecipeID = ranked.recipe.id },
                        onAdd: { selectedRecipe = ranked.recipe }
                    )
                    .frame(width: size.width, height: size.height)
                    .id(ranked.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollPosition(id: $visibleRecipeID)
        .accessibilityLabel("Recipe discovery feed")

        if reduceMotion {
            pages.scrollTargetBehavior(.viewAligned)
        } else {
            pages.scrollTargetBehavior(.paging)
        }
    }

    @ViewBuilder
    private var noResultsState: some View {
        let scheduled = Set(store.plan.slots.compactMap(\.recipeID))
        let unscheduled = store.recipes.filter { !scheduled.contains($0.id) }
        if unscheduled.isEmpty {
            statePanel(
                icon: "checkmark.circle.fill",
                title: "Every dinner is planned",
                message: "Your active week already contains every available recipe.",
                action: "See the plan"
            ) { store.selectedTab = .plan }
        } else {
            statePanel(
                icon: "slider.horizontal.3",
                title: "No recipes meet every hard rule",
                message: "The remaining recipes conflict with your current eligibility settings. Hard rules were not weakened.",
                action: "Review Preferences"
            ) { store.selectedTab = .preferences }
            .accessibilityIdentifier("discover-no-results")
        }
    }

    private var progressHeader: some View {
        HStack(spacing: 12) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.28))
                    Capsule()
                        .fill(WeeknightTheme.leaf)
                        .frame(width: proxy.size.width * Double(store.filledCount) / Double(max(1, store.totalCount)))
                }
            }
            .frame(height: 3)
            Text("\(store.weeklySpend.formatted()) / \(store.plan.budget.formatted())")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(WeeknightTheme.photoText)
                .lineLimit(1)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(store.filledCount) of \(store.totalCount) dinners chosen, \(store.weeklySpend.formatted()) of \(store.plan.budget.formatted())")
        .accessibilityIdentifier("discover-progress")
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().tint(WeeknightTheme.leaf)
            Text(store.backendState == .local ? "Loading local recipes…" : "Loading validated recipes…")
                .font(.headline)
                .foregroundStyle(WeeknightTheme.photoText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading recipes")
    }

    private func statePanel(
        icon: String,
        title: String,
        message: String,
        action: String,
        perform: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(WeeknightTheme.leaf)
            Text(title)
                .font(.largeTitle.weight(.black))
                .foregroundStyle(WeeknightTheme.photoText)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.body)
                .foregroundStyle(WeeknightTheme.photoText.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
            Button(action, action: perform)
                .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(WeeknightTheme.Spacing.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var showsBackendStatus: Bool {
        if case .local = store.backendState { return false }
        return true
    }
}

private struct RecipeFeedPage: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let ranked: RankedRecipe
    let position: Int
    let count: Int
    let onDetails: () -> Void
    let onAdd: () -> Void

    private var recipe: Recipe { ranked.recipe }
    private var servings: Int { store.preferences.householdSize }
    private var cost: Money { store.estimatedCost(for: recipe, servings: servings) }
    private var firstOpenDay: Weekday? { store.plan.slots.first(where: { $0.recipeID == nil })?.day }
    private var targetText: String { firstOpenDay.map { "FOR \($0.rawValue.uppercased())" } ?? "FOR YOUR WEEK" }
    private var addText: String { firstOpenDay.map { "Add to \($0.rawValue)" } ?? "Add to week" }

    private var fitText: String {
        if cost.minorUnits > store.remainingBudget.minorUnits {
            return "Adds \((cost - store.remainingBudget).formatted()) over budget"
        }
        let after = store.remainingBudget - cost
        if let next = store.plan.slots.drop(while: { $0.recipeID != nil }).dropFirst().first?.day {
            return "Leaves \(after.formatted()) for \(next.rawValue)"
        }
        return "Leaves \(after.formatted()) in your budget"
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RecipeArtwork(style: recipe.artwork)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            PhotoScrim()

            VStack(alignment: .leading, spacing: 0) {
                Text(targetText)
                    .font(.caption.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(WeeknightTheme.primaryText)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(WeeknightTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 76)

                Spacer(minLength: 80)

                HStack(alignment: .bottom, spacing: 14) {
                    positionTicks
                    VStack(alignment: .leading, spacing: 10) {
                        Text(recipe.title)
                            .font(dynamicTypeSize.isAccessibilitySize ? .title.weight(.black) : .system(size: 42, weight: .black))
                            .foregroundStyle(WeeknightTheme.photoText)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                            .accessibilityIdentifier("discover-title-\(recipe.id)")
                            .overlay {
                                Button(action: onDetails) {
                                    Color.clear
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Open \(recipe.title) details")
                                .accessibilityHint("Opens recipe details")
                                .accessibilityIdentifier("discover-details-\(recipe.id)")
                            }

                        Text("\(recipe.activeMinutes) min · serves \(servings) · \(cost.formatted())")
                            .font(.headline)
                            .foregroundStyle(WeeknightTheme.photoText.opacity(0.9))

                        Label(fitText, systemImage: cost.minorUnits > store.remainingBudget.minorUnits ? "exclamationmark.circle.fill" : "circle.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(cost.minorUnits > store.remainingBudget.minorUnits ? Color(hex: 0xFFB6A7) : WeeknightTheme.leaf)

                        Text(discoveryExplanation)
                            .font(.caption)
                            .foregroundStyle(WeeknightTheme.photoText.opacity(0.76))
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                            .accessibilityIdentifier("discover-explanation-\(recipe.id)")

                        if let caution = ranked.cautions.first {
                            Label(caution, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(Color(hex: 0xFFD7A0))
                                .lineLimit(2)
                        }
                    }
                }

                GeometryReader { proxy in
                    HStack(spacing: 12) {
                        Button {
                            store.toggleSaved(recipe.id)
                        } label: {
                            Text(store.isSaved(recipe.id) ? "SAVED" : "SAVE")
                                .font(.caption.weight(.bold))
                                .tracking(1)
                                .frame(width: 64, height: 54)
                        }
                        .foregroundStyle(WeeknightTheme.photoText)
                        .background(Color.black.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.62), lineWidth: 1)
                        }
                        .accessibilityLabel(store.isSaved(recipe.id) ? "Unsave \(recipe.title)" : "Save \(recipe.title)")
                        .accessibilityValue(store.isSaved(recipe.id) ? "Saved" : "Not saved")
                        .accessibilityIdentifier("discover-save-\(recipe.id)")

                        Button(addText, action: onAdd)
                            .buttonStyle(PrimaryActionButtonStyle())
                            .frame(width: max(0, proxy.size.width - 76))
                            .accessibilityIdentifier("add-recipe-\(recipe.id)")
                    }
                }
                .frame(height: 56)
                .padding(.top, 18)
                .padding(.bottom, 18)
            }
                .frame(
                    width: max(0, proxy.size.width - WeeknightTheme.Spacing.gutter * 2),
                    height: proxy.size.height,
                    alignment: .leading
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityElement(children: .contain)
    }

    private var discoveryExplanation: String {
        let dislikeContext = ranked.cautions.filter {
            $0.localizedCaseInsensitiveContains("marked as disliked")
        }
        let messages = ranked.explanations + dislikeContext
        return messages.isEmpty ? recipe.rationale : messages.joined(separator: " · ")
    }

    private var positionTicks: some View {
        VStack(spacing: 6) {
            ForEach(0..<min(count, 5), id: \.self) { index in
                Capsule()
                    .fill(index == position ? WeeknightTheme.photoText : WeeknightTheme.photoText.opacity(0.4))
                    .frame(width: 3, height: index == position ? 22 : 15)
            }
        }
        .padding(.bottom, 12)
        .accessibilityHidden(true)
    }
}
