import SwiftUI

struct DiscoverView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedRecipe: Recipe?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                WeeknightTheme.deepestPine.ignoresSafeArea()
                content(size: proxy.size)
                if store.recipeMode == .ready, !store.discoverRecipes.isEmpty {
                    VStack(spacing: 7) {
                        progressHeader
                        if showsBackendStatus {
                            BackendStatusView(onDark: true)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $selectedRecipe) { recipe in
            AddToWeekSheet(recipe: recipe, servings: store.preferences.householdSize)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .task { await store.loadRecipesIfNeeded() }
        .accessibilityIdentifier("discover-screen")
    }

    private var showsBackendStatus: Bool {
        if case .local = store.backendState { return false }
        return true
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
                message: "The local fixture is unavailable. Try again to restore the feed.",
                action: "Try again"
            ) { Task { await store.retryRecipes() } }
        case .empty:
            statePanel(
                icon: "fork.knife.circle",
                title: "No recipes yet",
                message: "This mock repository is intentionally empty.",
                action: "Back to Plan"
            ) { store.selectedTab = .plan }
        case .ready, .stale:
            if store.discoverRecipes.isEmpty {
                let unscheduled = recipesNotAlreadyScheduled
                if unscheduled.isEmpty {
                    statePanel(
                        icon: "checkmark.circle.fill",
                        title: "Every dinner is planned",
                        message: "Your active week already contains every available fixture recipe.",
                        action: "See the plan"
                    ) { store.selectedTab = .plan }
                } else {
                    statePanel(
                        icon: "slider.horizontal.3",
                        title: "No recipes meet every hard rule",
                        message: hardRuleNoResultsMessage,
                        action: "Review Preferences"
                    ) { store.selectedTab = .preferences }
                    .accessibilityIdentifier("discover-no-results")
                }
            } else if reduceMotion {
                recipeScroll(size: size)
                    .scrollTargetBehavior(.viewAligned)
            } else {
                recipeScroll(size: size)
                    .scrollTargetBehavior(.paging)
            }
        }
    }

    private func recipeScroll(size: CGSize) -> some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(store.rankedDiscoverRecipes) { ranked in
                    RecipeFeedCard(ranked: ranked) {
                        selectedRecipe = ranked.recipe
                    }
                    .frame(width: size.width, height: size.height)
                    .id(ranked.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .id(store.discoverRecipes.map(\.id).joined(separator: "|"))
        .accessibilityLabel("Recipe discovery feed")
    }

    private var recipesNotAlreadyScheduled: [Recipe] {
        let scheduled = Set(store.plan.slots.compactMap(\.recipeID))
        return store.recipes.filter { !scheduled.contains($0.id) }
    }

    private var hardRuleNoResultsMessage: String {
        var parts: [String] = []
        if !store.preferences.medicalAllergens.isEmpty { parts.append("declared allergens") }
        if !store.preferences.dietaryRestrictions.isEmpty { parts.append("dietary restrictions") }
        if store.preferences.availableAppliances.count < KitchenAppliance.allCases.count { parts.append("available appliances") }
        let constraints = parts.isEmpty ? "current eligibility settings" : parts.joined(separator: ", ")
        return "The remaining local recipes conflict with \(constraints). Hard rules were not weakened."
    }

    private var progressHeader: some View {
        HStack(spacing: 11) {
            Button {
                store.selectedTab = .plan
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Back to Plan")
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(store.filledCount) of \(store.totalCount) dinners chosen")
                    Text("\(store.weeklySpend.formatted()) of \(store.plan.budget.formatted())")
                        .foregroundStyle(WeeknightTheme.mint)
                    discoverProgressBar
                }
                .font(.subheadline.weight(.bold))
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(store.filledCount) of \(store.totalCount) dinners chosen")
                        .font(.subheadline.weight(.bold))
                    discoverProgressBar
                }
                Spacer(minLength: 4)
                Text("\(store.weeklySpend.formatted())/\(store.plan.budget.formatted())")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(WeeknightTheme.mint)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(Color.white)
        .padding(9)
        .background(.ultraThinMaterial.opacity(0.75))
        .environment(\.colorScheme, .dark)
        .clipShape(Capsule())
        .overlay { Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(store.filledCount) of \(store.totalCount) dinners chosen, \(store.weeklySpend.formatted()) of \(store.plan.budget.formatted())")
        .accessibilityIdentifier("discover-progress")
    }

    private var discoverProgressBar: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Color.white.opacity(0.2))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(WeeknightTheme.mint)
                        .frame(width: proxy.size.width * Double(store.filledCount) / Double(max(1, store.totalCount)))
                }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }

    private var loadingState: some View {
        VStack(spacing: 18) {
            ProgressView()
                .tint(WeeknightTheme.mint)
                .scaleEffect(1.3)
            Text(store.backendState == .local ? "Loading local recipes…" : "Loading validated recipes…")
                .font(.headline)
                .foregroundStyle(Color.white)
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
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(WeeknightTheme.mint)
            Text(title)
                .font(.title2.weight(.heavy))
                .foregroundStyle(Color.white)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.75))
            Button(action, action: perform)
                .buttonStyle(PrimaryActionButtonStyle())
                .padding(.top, 6)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RecipeFeedCard: View {
    @Environment(AppStore.self) private var store
    let ranked: RankedRecipe
    let onAdd: () -> Void

    private var recipe: Recipe { ranked.recipe }
    private var servings: Int { store.preferences.householdSize }
    private var cost: Money { store.estimatedCost(for: recipe, servings: servings) }

    private var fit: (text: String, color: Color, background: Color, icon: String) {
        if cost.minorUnits > store.remainingBudget.minorUnits {
            let over = cost - store.remainingBudget
            return ("\(over.formatted()) over this week", Color(hex: 0x8C2A17), Color(hex: 0xFCE3DC), "exclamationmark.triangle.fill")
        }
        if cost.minorUnits * 100 > store.remainingBudget.minorUnits * 55 {
            return ("Tight, but it fits", Color(hex: 0x7A5604), Color(hex: 0xFDF0D2), "exclamationmark.circle.fill")
        }
        return ("Fits your budget", WeeknightTheme.forest, WeeknightTheme.wash, "checkmark.circle.fill")
    }

    var body: some View {
        ZStack {
            RecipeArtwork(style: recipe.artwork)
            LinearGradient(
                colors: [
                    WeeknightTheme.deepestPine.opacity(0.58),
                    Color.clear,
                    WeeknightTheme.deepestPine.opacity(0.22),
                    WeeknightTheme.deepestPine.opacity(0.97),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 128)
                StatusPill(text: fit.text, color: fit.color, background: fit.background, systemImage: fit.icon)
                Text(recipe.title)
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(Color.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                    .accessibilityIdentifier("discover-title-\(recipe.id)")
                HStack(spacing: 9) {
                    Label("\(recipe.activeMinutes)m", systemImage: "clock")
                    Text("serves \(servings)")
                    Text(cost.formatted()).fontWeight(.bold)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.92))
                .padding(.top, 10)
                FlowLayout(spacing: 6) {
                    ForEach(recipe.tags, id: \.self) { TagChip(text: $0, onDark: true) }
                }
                .padding(.top, 12)
                Divider()
                    .overlay(Color.white.opacity(0.22))
                    .padding(.vertical, 14)
                VStack(alignment: .leading, spacing: 7) {
                    Label {
                        Text("Why it’s here: \(ranked.explanations.first ?? recipe.rationale)")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .foregroundStyle(WeeknightTheme.mint)
                    }
                    if let caution = ranked.cautions.first {
                        Label(caution, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color(hex: 0xFFD58A))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(recipe.sourceName)
                        .foregroundStyle(Color.white.opacity(0.62))
                }
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.78))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("discover-explanation-\(recipe.id)")
                HStack(spacing: 10) {
                    NavigationLink {
                        RecipeDetailsView(
                            recipeID: recipe.id,
                            origin: .discover,
                            initialServings: servings
                        )
                    } label: {
                        Label("Recipe details", systemImage: "book.pages")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.white.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
                    }
                    .accessibilityIdentifier("discover-details-\(recipe.id)")

                    Button {
                        store.toggleSaved(recipe.id)
                    } label: {
                        Image(systemName: store.isSaved(recipe.id) ? "bookmark.fill" : "bookmark")
                            .font(.headline)
                            .foregroundStyle(store.isSaved(recipe.id) ? WeeknightTheme.mint : Color.white)
                            .frame(width: 48, height: 44)
                            .background(Color.white.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
                    }
                    .accessibilityLabel(store.isSaved(recipe.id) ? "Unsave \(recipe.title)" : "Save \(recipe.title)")
                    .accessibilityValue(store.isSaved(recipe.id) ? "Saved" : "Not saved")
                    .accessibilityIdentifier("discover-save-\(recipe.id)")
                }
                .padding(.top, 16)
                Button(action: onAdd) {
                    Label("Add to week", systemImage: "plus")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .padding(.top, 10)
                .accessibilityIdentifier("add-recipe-\(recipe.id)")
            }
            .padding(.horizontal, WeeknightTheme.Spacing.gutter)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .accessibilityElement(children: .contain)
    }
}
