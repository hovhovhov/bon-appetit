import SwiftUI
import UIKit

struct PlanView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var swapDay: Weekday?
    @State private var autofillPresentation: AutofillPresentation?
    @State private var planActionError: String?
    @State private var showsShoppingList = false

    var body: some View {
        ScrollView {
            Group {
                if store.filledCount == 0 {
                    emptyWeek
                } else if store.filledCount == store.totalCount {
                    completedWeek
                } else {
                    partialWeek
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: WeeknightTheme.Motion.completion), value: store.filledCount == store.totalCount)
        }
        .scrollIndicators(.hidden)
        .background(WeeknightTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showsShoppingList) {
            ShoppingListView()
        }
        .sheet(item: $swapDay) { day in
            SwapMealSheet(day: day) {}
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(WeeknightTheme.Radius.sheet)
        }
        .sheet(item: $autofillPresentation) { presentation in
            AutofillResultSheet(presentation: presentation)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(WeeknightTheme.Radius.sheet)
        }
        .alert(
            "Plan update failed",
            isPresented: Binding(
                get: { planActionError != nil },
                set: { if !$0 { planActionError = nil } }
            )
        ) {
            Button("OK") { planActionError = nil }
        } message: {
            Text(planActionError ?? "Try again.")
        }
        .onChange(of: store.filledCount) { previous, current in
            guard current == store.totalCount, previous != current else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .accessibilityIdentifier("plan-screen")
    }

    private var partialWeek: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            weekHeader(showShoppingProgress: true)
            if showsBackendStatus {
                BackendStatusView(onDark: false)
                    .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                    .padding(.top, WeeknightTheme.Spacing.medium)
            }
            if let feature = featuredSlot, let recipe = store.recipe(for: feature) {
                featuredMeal(slot: feature, recipe: recipe)
                    .padding(.top, WeeknightTheme.Spacing.medium)
            }
            plannedRowsExcludingFeature
                .padding(.horizontal, WeeknightTheme.Spacing.gutter)
            openNightsRow
                .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                .padding(.top, 8)
            estimateFootnote
        }
    }

    private var completedWeek: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(store.totalCount) DINNERS · \(store.weeklySpend.formatted())")
                    .font(.caption.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(WeeknightTheme.forest)
                Text("Your week\nis ready")
                    .font(.system(.largeTitle, design: .default, weight: .black))
                    .foregroundStyle(WeeknightTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("plan-headline")
                    .accessibilityLabel("Your week is ready to shop")
                BudgetProgressBar(spent: store.weeklySpend, budget: store.plan.budget)
                Text(completionBudgetLine)
                    .font(.subheadline)
                    .foregroundStyle(store.remainingBudget.minorUnits < 0 ? WeeknightTheme.tomato : WeeknightTheme.secondaryText)
                Text("\(store.filledCount) of \(store.totalCount) dinners planned")
                    .font(.caption)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .accessibilityIdentifier("plan-progress")
            }
            .padding(.horizontal, WeeknightTheme.Spacing.gutter)
            .padding(.top, WeeknightTheme.Spacing.standard)

            completedMosaic
                .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                .padding(.top, WeeknightTheme.Spacing.standard)

            shoppingCallToAction
                .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                .padding(.top, WeeknightTheme.Spacing.standard)

            estimateFootnote
        }
    }

    private var emptyWeek: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            weekHeader(showShoppingProgress: false, identifiesHeadline: false)
            if let recipe = store.rankedDiscoverRecipes.first?.recipe ?? store.recipesForCalculations.first {
                ZStack(alignment: .bottomLeading) {
                    RecipeArtwork(style: recipe.artwork)
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 220 : 292)
                    WeeknightTheme.background.opacity(0.68)
                    NotchedDayTab(text: firstOpenDay.map { "\($0.shortName) · OPEN" } ?? "OPEN")
                        .padding(.leading, WeeknightTheme.Spacing.gutter)
                        .offset(y: 1)
                }
                .clipShape(.rect(bottomLeadingRadius: 30, bottomTrailingRadius: 30))
                .padding(.top, WeeknightTheme.Spacing.medium)
            }

            VStack(alignment: .leading, spacing: 18) {
                Text("Nothing planned yet")
                    .font(.system(.largeTitle, design: .default, weight: .black))
                    .foregroundStyle(WeeknightTheme.primaryText)
                    .accessibilityIdentifier("plan-headline")
                Text("Swipe through dinners that fit \(store.plan.budget.formatted()) at \(store.plan.storeName), or let Weeknight draft the week for you.")
                    .font(.title3)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Find dinners") { store.selectedTab = .discover }
                    .buttonStyle(PrimaryActionButtonStyle())
                Button("Draft my week") { runAutofill() }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(store.isAutofilling)
                    .accessibilityIdentifier("autofill-plan")
            }
            .padding(WeeknightTheme.Spacing.gutter)
            estimateFootnote
        }
    }

    private func weekHeader(showShoppingProgress: Bool, identifiesHeadline: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text("This week")
                        .font(.largeTitle.weight(.black))
                        .accessibilityIdentifier(identifiesHeadline ? "plan-headline" : "plan-week-header")
                    Spacer(minLength: 12)
                    storeAndDate
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("This week")
                        .font(.largeTitle.weight(.black))
                        .accessibilityIdentifier(identifiesHeadline ? "plan-headline" : "plan-week-header")
                    storeAndDate
                }
            }
            .foregroundStyle(WeeknightTheme.primaryText)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(store.weeklySpend.formatted())
                        .font(.headline.weight(.black))
                        .accessibilityIdentifier("budget-spent")
                        .accessibilityLabel("\(store.weeklySpend.formatted()) of \(store.plan.budget.formatted())")
                    Text("of \(store.plan.budget.formatted())")
                        .foregroundStyle(WeeknightTheme.secondaryText)
                    Spacer(minLength: 8)
                    if showShoppingProgress {
                        shoppingHeaderLink
                    } else {
                        Text("0 of \(store.totalCount) dinners")
                            .foregroundStyle(WeeknightTheme.secondaryText)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text(store.weeklySpend.formatted())
                            .font(.headline.weight(.black))
                            .accessibilityIdentifier("budget-spent")
                            .accessibilityLabel("\(store.weeklySpend.formatted()) of \(store.plan.budget.formatted())")
                        Text("of \(store.plan.budget.formatted())")
                            .foregroundStyle(WeeknightTheme.secondaryText)
                    }
                    if showShoppingProgress { shoppingHeaderLink }
                }
            }
            .font(.subheadline)

            BudgetProgressBar(spent: store.weeklySpend, budget: store.plan.budget)

            Text("\(store.filledCount) of \(store.totalCount) dinners planned")
                .font(.caption)
                .foregroundStyle(WeeknightTheme.secondaryText)
                .accessibilityIdentifier("plan-progress")
            Text(store.remainingBudget.minorUnits >= 0 ? "\(store.remainingBudget.formatted()) left to spend" : "\(Money(minorUnits: abs(store.remainingBudget.minorUnits)).formatted()) over budget")
                .font(.caption)
                .foregroundStyle(store.remainingBudget.minorUnits >= 0 ? WeeknightTheme.secondaryText : WeeknightTheme.tomato)
                .accessibilityIdentifier("budget-remaining")
        }
        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
        .padding(.top, WeeknightTheme.Spacing.standard)
    }

    private var storeAndDate: some View {
        Text("\(store.plan.storeName) · \(store.plan.weekLabel)")
            .font(.caption.weight(.bold))
            .tracking(1)
            .foregroundStyle(WeeknightTheme.secondaryText)
            .lineLimit(2)
            .multilineTextAlignment(.trailing)
    }

    private var shoppingHeaderLink: some View {
        Button {
            store.confirmationMessage = nil
            showsShoppingList = true
        } label: {
            Text("\(store.filledCount) of \(store.totalCount) dinners · list \(store.shoppingProgress.display)")
                .foregroundStyle(WeeknightTheme.secondaryText)
                .lineLimit(2)
                .accessibilityIdentifier("shopping-progress")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("open-shopping-list")
        .accessibilityLabel("Shopping list, \(store.shoppingProgress.display) items checked")
    }

    @ViewBuilder
    private func featuredMeal(slot: MealSlot, recipe: Recipe) -> some View {
        NavigationLink {
            RecipeDetailsView(recipeID: recipe.id, origin: .plan, initialServings: slot.servings)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    RecipeArtwork(style: recipe.artwork)
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 220 : 292)
                    NotchedDayTab(text: "TONIGHT · \(slot.day.shortName)")
                        .padding(.leading, WeeknightTheme.Spacing.gutter)
                        .offset(y: 1)
                }
                .clipShape(.rect(bottomLeadingRadius: 30, bottomTrailingRadius: 30))

                VStack(alignment: .leading, spacing: 7) {
                    Text(recipe.title)
                        .font(.system(.title, design: .default, weight: .black))
                        .foregroundStyle(WeeknightTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("meal-\(slot.day.rawValue)")
                    Text("\(recipe.activeMinutes) min · serves \(slot.servings) · \(store.estimatedCost(for: recipe, servings: slot.servings).formatted())")
                        .font(.subheadline)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                }
                .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("open-meal-\(slot.day.rawValue)")

        if let conflict = store.conflict(for: slot.day) {
            planConflictWarning(conflict)
                .padding(.horizontal, WeeknightTheme.Spacing.gutter)
        }
    }

    private var plannedRowsExcludingFeature: some View {
        VStack(spacing: 0) {
            ForEach(nonFeaturedFilledSlots) { slot in
                if let recipe = store.recipe(for: slot) {
                    NavigationLink {
                        RecipeDetailsView(recipeID: recipe.id, origin: .plan, initialServings: slot.servings)
                    } label: {
                        PlannedMealRow(slot: slot, recipe: recipe)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("open-meal-\(slot.day.rawValue)")
                    if let conflict = store.conflict(for: slot.day) {
                        planConflictWarning(conflict)
                            .padding(.vertical, 8)
                    }
                    Divider().overlay(WeeknightTheme.hairline)
                }
            }
        }
    }

    private var openNightsRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                openNightsLabel
                Spacer(minLength: 6)
                autofillButton(compact: true)
            }
            VStack(alignment: .leading, spacing: 12) {
                openNightsLabel
                autofillButton(compact: false)
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .contain)
    }

    private var openNightsLabel: some View {
        Button {
            store.selectedTab = .discover
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(WeeknightTheme.forest)
                    .frame(width: 48, height: 48)
                    .background(WeeknightTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(openDayTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(WeeknightTheme.primaryText)
                    Text("\(store.remainingBudget.formatted()) left to spend")
                        .font(.subheadline)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(firstOpenDay.map { "empty-\($0.rawValue)" } ?? "empty-day")
    }

    private func autofillButton(compact: Bool) -> some View {
        Button { runAutofill() } label: {
            if store.isAutofilling {
                ProgressView().tint(WeeknightTheme.background)
            } else {
                Text(compact ? "Fill for me" : "Fill the rest for me")
            }
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(WeeknightTheme.background)
        .padding(.horizontal, 18)
        .frame(maxWidth: compact ? nil : .infinity, minHeight: 48)
        .background(WeeknightTheme.forest)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .disabled(store.isAutofilling)
        .accessibilityIdentifier("autofill-plan")
    }

    private var completedMosaic: some View {
        let slots = store.plan.slots.filter { $0.recipeID != nil }
        return VStack(spacing: 5) {
            if slots.count >= 3 {
                HStack(spacing: 5) {
                    mosaicLink(slots[0]).frame(maxWidth: .infinity)
                    VStack(spacing: 5) {
                        mosaicLink(slots[1])
                        mosaicLink(slots[2])
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 190 : 220)
            }
            if slots.count >= 5 {
                HStack(spacing: 5) {
                    mosaicLink(slots[3])
                    mosaicLink(slots[4])
                }
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 100 : 118)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func mosaicLink(_ slot: MealSlot) -> some View {
        Group {
            if let recipe = store.recipe(for: slot) {
                NavigationLink {
                    RecipeDetailsView(recipeID: recipe.id, origin: .plan, initialServings: slot.servings)
                } label: {
                    ZStack(alignment: .bottomLeading) {
                        RecipeArtwork(style: recipe.artwork)
                        LinearGradient(colors: [.clear, .black.opacity(0.2)], startPoint: .center, endPoint: .bottom)
                        NotchedDayTab(text: slot.day.shortName, compact: true)
                            .padding(6)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("open-meal-\(slot.day.rawValue)")
                .accessibilityLabel("\(slot.day.rawValue), \(recipe.title)")
            }
        }
    }

    private var shoppingCallToAction: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(store.shoppingProgress.total) items · \(store.shoppingProgress.checked) already in")
                    .font(.subheadline)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .accessibilityIdentifier("shopping-progress")
                Spacer()
                Text(store.plan.storeName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WeeknightTheme.forest)
            }
            Button {
                store.confirmationMessage = nil
                showsShoppingList = true
            } label: {
                Text("Get the shopping list")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .accessibilityIdentifier("open-shopping-list")
            .accessibilityLabel("Shopping list, \(store.shoppingProgress.display) items checked")
        }
    }

    private func planConflictWarning(_ conflict: ScheduledPreferenceConflict) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("This meal conflicts with your setup", systemImage: "exclamationmark.triangle.fill")
                .font(.headline.weight(.bold))
            Text(conflict.reasons.map(\.message).joined(separator: " "))
                .font(.subheadline)
            Text("It stays planned until you replace or clear it. Verify labels and allergen information.")
                .font(.footnote.weight(.semibold))
            HStack(spacing: 8) {
                Button("Replace") { swapDay = conflict.day }
                    .buttonStyle(.borderedProminent)
                    .tint(WeeknightTheme.tomato)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("replace-conflict-\(conflict.day.rawValue)")
                Button("Clear", role: .destructive) {
                    Task {
                        do {
                            try await store.clearMeal(on: conflict.day)
                            UIAccessibility.post(notification: .announcement, argument: "\(conflict.day.rawValue)’s meal cleared")
                        } catch {
                            planActionError = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .accessibilityIdentifier("clear-conflict-\(conflict.day.rawValue)")
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Resolve \(conflict.day.rawValue) conflict")
            .accessibilityIdentifier("plan-conflict-\(conflict.day.rawValue)")
        }
        .foregroundStyle(WeeknightTheme.tomato)
        .padding(14)
        .background(WeeknightTheme.tomato.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
    }

    private var estimateFootnote: some View {
        Text("Estimates use deterministic development quantities, not live checkout prices.")
            .font(.footnote)
            .foregroundStyle(WeeknightTheme.secondaryText)
            .padding(.horizontal, WeeknightTheme.Spacing.gutter)
            .padding(.vertical, WeeknightTheme.Spacing.large)
    }

    private var featuredSlot: MealSlot? { store.plan.slots.first(where: { $0.recipeID != nil }) }
    private var nonFeaturedFilledSlots: [MealSlot] {
        guard let featuredSlot else { return [] }
        return store.plan.slots.filter { $0.recipeID != nil && $0.id != featuredSlot.id }
    }
    private var openSlots: [MealSlot] { store.plan.slots.filter { $0.recipeID == nil } }
    private var firstOpenDay: Weekday? { openSlots.first?.day }
    private var openDayTitle: String {
        let names = openSlots.map { $0.day.rawValue }
        if names.count == 2 { return "\(names[0]) and \(names[1]) open" }
        if names.count == 1 { return "\(names[0]) open" }
        return "\(names.count) nights open"
    }
    private var completionBudgetLine: String {
        if store.remainingBudget.minorUnits >= 0 {
            return "\(store.remainingBudget.formatted()) under budget at \(store.plan.storeName)"
        }
        return "\(Money(minorUnits: abs(store.remainingBudget.minorUnits)).formatted()) over budget at \(store.plan.storeName)"
    }
    private var showsBackendStatus: Bool {
        if case .local = store.backendState { return false }
        return true
    }

    private func runAutofill() {
        Task {
            do {
                let outcome = try await store.fillOpenDays()
                autofillPresentation = AutofillPresentation(outcome: outcome)
                if case .success = outcome {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    UIAccessibility.post(notification: .announcement, argument: "Open cooking days filled")
                } else {
                    UIAccessibility.post(notification: .announcement, argument: "Weeknight could not fill every open day")
                }
            } catch {
                autofillPresentation = AutofillPresentation(
                    outcome: .unable(message: error.localizedDescription, suggestions: ["Try again", "Review Preferences"])
                )
            }
        }
    }
}

private struct PlannedMealRow: View {
    @Environment(AppStore.self) private var store
    let slot: MealSlot
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 10) {
            RecipeArtwork(style: recipe.artwork, compact: true)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.thumbnail, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(WeeknightTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("meal-\(slot.day.rawValue)")
                Text("\(slot.day.shortName) · \(recipe.activeMinutes) min")
                    .font(.subheadline)
                    .foregroundStyle(WeeknightTheme.secondaryText)
            }
            Spacer(minLength: 8)
            Text(store.estimatedCost(for: recipe, servings: slot.servings).formatted())
                .font(.subheadline.weight(.bold))
                .foregroundStyle(WeeknightTheme.primaryText)
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(slot.day.rawValue), \(recipe.title), \(recipe.activeMinutes) minutes, serves \(slot.servings), \(store.estimatedCost(for: recipe, servings: slot.servings).formatted())")
    }
}

struct AutofillPresentation: Identifiable {
    let id = UUID()
    let outcome: AutofillOutcome
}

private struct AutofillResultSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let presentation: AutofillPresentation

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if showsBackendStatus { BackendStatusView(onDark: false) }
                    switch presentation.outcome {
                    case .success(_, let assignments, let projectedSpend):
                        Text("Your week is ready")
                            .font(.largeTitle.weight(.black))
                            .foregroundStyle(WeeknightTheme.primaryText)
                        Text("Weeknight applied one complete plan update and regenerated the shopping list.")
                            .foregroundStyle(WeeknightTheme.secondaryText)
                        ForEach(assignments) { assignment in
                            HStack(alignment: .top, spacing: 12) {
                                Text(assignment.day.shortName)
                                    .font(.caption.weight(.bold))
                                    .tracking(1)
                                    .frame(width: 48, height: 48)
                                    .background(WeeknightTheme.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(assignment.recipeTitle).font(.headline.weight(.bold))
                                    Text("\(assignment.servings) serving\(assignment.servings == 1 ? "" : "s")")
                                        .font(.subheadline).foregroundStyle(WeeknightTheme.secondaryText)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            Divider().overlay(WeeknightTheme.hairline)
                        }
                        Text("Projected week: \(projectedSpend.formatted()) of \(store.plan.budget.formatted())")
                            .font(.headline.weight(.semibold))
                    case .unable(let message, let suggestions):
                        Text("Weeknight couldn’t fill every open day")
                            .font(.title.weight(.black))
                            .foregroundStyle(WeeknightTheme.tomato)
                        Text(message).foregroundStyle(WeeknightTheme.primaryText)
                        ForEach(suggestions, id: \.self) { suggestion in
                            Label(suggestion, systemImage: "arrow.right")
                        }
                        Text("Hard allergen, dietary, and appliance rules were not weakened.")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(WeeknightTheme.tomato)
                        Button("Review Preferences") {
                            dismiss()
                            store.selectedTab = .preferences
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .accessibilityIdentifier("autofill-review-preferences")
                    }
                }
                .padding(WeeknightTheme.Spacing.gutter)
            }
            .background(WeeknightTheme.background.ignoresSafeArea())
            .navigationTitle("Autofill result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .accessibilityIdentifier({
            if case .success = presentation.outcome { return "autofill-success" }
            return "autofill-unable"
        }())
    }

    private var showsBackendStatus: Bool {
        if case .local = store.backendState { return false }
        return true
    }
}
