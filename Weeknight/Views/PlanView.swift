import SwiftUI
import UIKit

struct PlanView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var swapDay: Weekday?
    @State private var autofillPresentation: AutofillPresentation?
    @State private var planActionError: String?
    @State private var showsShoppingList = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                weekSummary

                if showsBackendStatus {
                    BackendStatusView(onDark: false)
                        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                        .padding(.top, 16)
                }

                shoppingAction
                    .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                    .padding(.top, 20)

                if store.filledCount < store.totalCount {
                    openWeekActions
                        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                        .padding(.top, 20)
                }

                Text("Cooking days")
                    .font(.title2.weight(.black))
                    .foregroundStyle(WeeknightTheme.primaryText)
                    .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                    .padding(.top, 28)
                    .padding(.bottom, 6)

                VStack(spacing: 0) {
                    ForEach(store.plan.slots) { slot in
                        dayRow(slot)
                        if slot.id != store.plan.slots.last?.id {
                            Divider()
                                .overlay(WeeknightTheme.hairline)
                                .padding(.leading, WeeknightTheme.Spacing.gutter)
                        }
                    }
                }
                .animation(reduceMotion ? nil : .easeOut(duration: WeeknightTheme.Motion.settle), value: store.filledCount)

                if store.filledCount == store.totalCount, store.totalCount > 0 {
                    completedCelebration
                        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                        .padding(.top, 30)
                        .transition(.opacity)
                }

                estimateFootnote
            }
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

    private var weekSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PLANS · \(store.plan.weekLabel.uppercased())")
                .font(.caption.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(WeeknightTheme.forest)

            Text(planHeadline)
                .font(.largeTitle.weight(.black))
                .foregroundStyle(WeeknightTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("plan-headline")
                .accessibilityLabel(planHeadlineAccessibilityLabel)

            Label(store.plan.storeName, systemImage: "storefront")
                .font(.headline)
                .foregroundStyle(WeeknightTheme.primaryText)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    budgetAmount
                    Spacer(minLength: 12)
                    dinnerCount
                }
                VStack(alignment: .leading, spacing: 8) {
                    budgetAmount
                    dinnerCount
                }
            }

            BudgetProgressBar(spent: store.weeklySpend, budget: store.plan.budget)
                .accessibilityLabel("Budget progress")
                .accessibilityValue("\(store.weeklySpend.formatted()) of \(store.plan.budget.formatted())")

            Label(budgetStatusText, systemImage: store.remainingBudget.minorUnits < 0 ? "exclamationmark.triangle.fill" : "checkmark.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(store.remainingBudget.minorUnits < 0 ? WeeknightTheme.tomato : WeeknightTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("budget-remaining")
        }
        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
        .padding(.top, WeeknightTheme.Spacing.standard)
    }

    private var budgetAmount: some View {
        Text("\(store.weeklySpend.formatted()) of \(store.plan.budget.formatted())")
            .font(.title3.weight(.black))
            .foregroundStyle(WeeknightTheme.primaryText)
            .accessibilityIdentifier("budget-spent")
    }

    private var dinnerCount: some View {
        Text("\(store.filledCount) of \(store.totalCount) dinners planned")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(WeeknightTheme.secondaryText)
            .accessibilityIdentifier("plan-progress")
    }

    private var shoppingAction: some View {
        Button {
            store.confirmationMessage = nil
            showsShoppingList = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "cart")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(WeeknightTheme.background)
                    .frame(width: 48, height: 48)
                    .background(WeeknightTheme.forest)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Shopping List")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(WeeknightTheme.primaryText)
                    Text("\(store.shoppingProgress.display) items checked")
                        .font(.subheadline)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                        .accessibilityIdentifier("shopping-progress")
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(WeeknightTheme.forest)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(WeeknightTheme.surfaceElevated.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("open-shopping-list")
        .accessibilityLabel("Shopping list, \(store.shoppingProgress.display) items checked")
        .accessibilityHint("Opens the shopping list generated from this week")
    }

    private var openWeekActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.filledCount == 0 {
                Text("Start with a dinner you’ll look forward to, or let Weeknight fill your configured cooking days.")
                    .font(.body)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("\(openSlots.count) cooking day\(openSlots.count == 1 ? " is" : "s are") still open.")
                    .font(.body)
                    .foregroundStyle(WeeknightTheme.secondaryText)
            }

            Button("Find meals") { navigation.showMeals() }
                .buttonStyle(PrimaryActionButtonStyle())

            Button { runAutofill() } label: {
                if store.isAutofilling {
                    ProgressView()
                } else {
                    Label(store.filledCount == 0 ? "Draft my week" : "Fill open days", systemImage: "wand.and.stars")
                }
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(store.isAutofilling)
            .accessibilityIdentifier("autofill-plan")
        }
    }

    @ViewBuilder
    private func dayRow(_ slot: MealSlot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Text(slot.day.shortName.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(WeeknightTheme.forest)
                    .frame(width: 48, height: 44, alignment: .leading)

                if let recipe = store.recipe(for: slot) {
                    RecipeArtwork(style: recipe.artwork, compact: true)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.thumbnail, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(WeeknightTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("meal-\(slot.day.rawValue)")
                        Text("\(recipe.activeMinutes) min · serves \(slot.servings) · \(store.estimatedCost(for: recipe, servings: slot.servings).formatted())")
                            .font(.subheadline)
                            .foregroundStyle(WeeknightTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        if store.conflict(for: slot.day) == nil {
                            Label("Fits your current setup", systemImage: "checkmark.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(WeeknightTheme.forest)
                        }
                    }
                } else {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(WeeknightTheme.forest)
                        .frame(width: 72, height: 72)
                        .background(WeeknightTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.thumbnail, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No meal planned")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(WeeknightTheme.primaryText)
                        Text("Choose a recommendation for \(slot.day.rawValue).")
                            .font(.subheadline)
                            .foregroundStyle(WeeknightTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let recipe = store.recipe(for: slot) {
                filledDayActions(slot: slot, recipe: recipe)
                if let conflict = store.conflict(for: slot.day) {
                    planConflictWarning(conflict)
                }
            } else {
                Button("Add meal") { navigation.showMeals() }
                    .buttonStyle(.bordered)
                    .tint(WeeknightTheme.forest)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("add-meal-\(slot.day.rawValue)")
                    .accessibilityHint("Opens For You recommendations")
            }
        }
        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
        .padding(.vertical, 16)
        .accessibilityIdentifier("plan-day-\(slot.day.rawValue)")
    }

    private func filledDayActions(slot: MealSlot, recipe: Recipe) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                viewRecipeLink(slot: slot, recipe: recipe)
                replaceButton(day: slot.day)
                clearButton(day: slot.day)
            }
            VStack(alignment: .leading, spacing: 8) {
                viewRecipeLink(slot: slot, recipe: recipe)
                replaceButton(day: slot.day)
                clearButton(day: slot.day)
            }
        }
        .padding(.leading, 62)
        .accessibilityElement(children: .contain)
    }

    private func viewRecipeLink(slot: MealSlot, recipe: Recipe) -> some View {
        NavigationLink {
            RecipeDetailsView(recipeID: recipe.id, origin: .plan, initialServings: slot.servings)
        } label: {
            Label("View Recipe", systemImage: "book")
                .frame(minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(WeeknightTheme.forest)
        .accessibilityIdentifier("open-meal-\(slot.day.rawValue)")
        .accessibilityLabel("View \(recipe.title) recipe for \(slot.day.rawValue)")
    }

    private func replaceButton(day: Weekday) -> some View {
        Button { swapDay = day } label: {
            Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(WeeknightTheme.forest)
        .accessibilityIdentifier("replace-meal-\(day.rawValue)")
    }

    private func clearButton(day: Weekday) -> some View {
        Button(role: .destructive) {
            clearMeal(day)
        } label: {
            Label("Clear", systemImage: "xmark")
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("clear-meal-\(day.rawValue)")
    }

    private var completedCelebration: some View {
        let slots = store.plan.slots.filter { $0.recipeID != nil }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Your week, together")
                .font(.title2.weight(.black))
                .foregroundStyle(WeeknightTheme.primaryText)
            Text("A visual summary of the dinners listed above.")
                .font(.subheadline)
                .foregroundStyle(WeeknightTheme.secondaryText)
            if slots.count >= 3 {
                HStack(spacing: 5) {
                    celebrationImage(slots[0]).frame(maxWidth: .infinity)
                    VStack(spacing: 5) {
                        celebrationImage(slots[1])
                        celebrationImage(slots[2])
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 150 : 180)
            }
            if slots.count >= 5 {
                HStack(spacing: 5) {
                    celebrationImage(slots[3])
                    celebrationImage(slots[4])
                }
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 82 : 96)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.card, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Completed week photo summary")
    }

    private func celebrationImage(_ slot: MealSlot) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let recipe = store.recipe(for: slot) {
                RecipeArtwork(style: recipe.artwork)
            }
            NotchedDayTab(text: slot.day.shortName, compact: true)
                .padding(6)
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
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { conflictActions(conflict) }
                VStack(alignment: .leading, spacing: 8) { conflictActions(conflict) }
            }
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

    @ViewBuilder
    private func conflictActions(_ conflict: ScheduledPreferenceConflict) -> some View {
        Button("Replace") { swapDay = conflict.day }
            .buttonStyle(.borderedProminent)
            .tint(WeeknightTheme.tomato)
            .frame(minHeight: 44)
            .accessibilityIdentifier("replace-conflict-\(conflict.day.rawValue)")
        Button("Clear", role: .destructive) { clearMeal(conflict.day) }
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
            .accessibilityIdentifier("clear-conflict-\(conflict.day.rawValue)")
    }

    private var openSlots: [MealSlot] { store.plan.slots.filter { $0.recipeID == nil } }
    private var planHeadline: String {
        if store.filledCount == 0 { return "Nothing planned yet" }
        if store.filledCount == store.totalCount { return "Your week is ready" }
        return "Your week at a glance"
    }
    private var planHeadlineAccessibilityLabel: String {
        store.filledCount == store.totalCount ? "Your week is ready to shop" : planHeadline
    }
    private var budgetStatusText: String {
        if store.remainingBudget.minorUnits >= 0 {
            return "\(store.remainingBudget.formatted()) remaining in this week’s budget"
        }
        return "\(Money(minorUnits: abs(store.remainingBudget.minorUnits)).formatted()) over budget — replace or clear a meal to adjust"
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

    private func clearMeal(_ day: Weekday) {
        Task {
            do {
                try await store.clearMeal(on: day)
                UIAccessibility.post(notification: .announcement, argument: "\(day.rawValue)’s meal cleared")
            } catch {
                planActionError = error.localizedDescription
            }
        }
    }
}

struct AutofillPresentation: Identifiable {
    let id = UUID()
    let outcome: AutofillOutcome
}

private struct AutofillResultSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(AppNavigation.self) private var navigation
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
                            navigation.showPreferences()
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
