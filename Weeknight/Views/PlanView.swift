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
            VStack(alignment: .leading, spacing: 0) {
                weekSummary

                if showsBackendStatus {
                    BackendStatusView(onDark: false)
                        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                        .padding(.top, 16)
                }

                shoppingAction
                    .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                    .padding(.top, 12)

                dinnerSectionHeader
                    .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                    .padding(.top, 26)

                VStack(spacing: 22) {
                    ForEach(store.plan.slots) { slot in
                        dayRow(slot)
                    }
                }
                .padding(.top, 14)
                .animation(reduceMotion ? nil : .easeOut(duration: WeeknightTheme.Motion.settle), value: store.filledCount)

                if store.filledCount < store.totalCount {
                    openWeekActions
                        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                        .padding(.top, 26)
                }

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
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    storeContext
                    Text(store.plan.weekLabel)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                        .fixedSize(horizontal: true, vertical: true)
                }
                VStack(alignment: .leading, spacing: 8) {
                    storeContext
                    Text(store.plan.weekLabel)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.subheadline.weight(.semibold))

            budgetSummaryCard
        }
        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
        .padding(.top, 18)
    }

    private var storeContext: some View {
        Button { navigation.showPreferences() } label: {
            HStack(spacing: 9) {
                Text(storeInitials)
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.white)
                    .frame(width: 30, height: 30)
                    .background(WeeknightTheme.tomato)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                Text(store.plan.storeName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(WeeknightTheme.deepestPine)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 7)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.9))
            .clipShape(Capsule())
            .overlay { Capsule().stroke(WeeknightTheme.hairline, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Supermarket, \(store.plan.storeName)")
        .accessibilityHint("Opens supermarket preferences")
    }

    private var budgetSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) {
                    budgetSpendBlock
                    remainingBudgetBlock
                }
            } else {
                HStack(alignment: .bottom, spacing: 10) {
                    budgetSpendBlock
                        .frame(maxWidth: .infinity, alignment: .leading)
                    remainingBudgetBlock
                }
            }

            BudgetProgressBar(spent: store.weeklySpend, budget: store.plan.budget, height: 10, onPhotography: true)
                .accessibilityLabel("Budget progress")
                .accessibilityValue("\(store.weeklySpend.formatted()) of \(store.plan.budget.formatted())")

            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Image(systemName: store.remainingBudget.minorUnits < 0 ? "exclamationmark.triangle.fill" : "circle.fill")
                    .font(.caption)
                    .foregroundStyle(store.remainingBudget.minorUnits < 0 ? Color(hex: 0xFFD1C7) : WeeknightTheme.leaf)
                    .accessibilityHidden(true)
                Text(remainingDinnerBudgetText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(store.remainingBudget.minorUnits < 0 ? Color(hex: 0xFFD1C7) : Color.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("budget-remaining")
        }
        .padding(18)
        .background(WeeknightTheme.deepestPine)
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.budget, style: .continuous))
        .shadow(color: WeeknightTheme.deepestPine.opacity(0.16), radius: 14, y: 8)
    }

    private var budgetSpendBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("ESTIMATED SHOP")
                .font(.caption.weight(.bold))
                .tracking(1.7)
                .foregroundStyle(Color.white.opacity(0.62))
            (Text(store.weeklySpend.formatted())
                .font(.title.weight(.black))
             + Text("  of \(shortCurrency(store.plan.budget))")
                .font(.subheadline.weight(.bold))
                .foregroundColor(Color.white.opacity(0.55)))
            .foregroundStyle(WeeknightTheme.photoText)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("budget-spent")
            .accessibilityLabel("\(store.weeklySpend.formatted()) of \(store.plan.budget.formatted())")
        }
    }

    private var remainingBudgetBlock: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(remainingBudgetAmountText)
                .font(.headline.weight(.black))
                .foregroundStyle(store.remainingBudget.minorUnits < 0 ? Color(hex: 0xFFD1C7) : WeeknightTheme.leaf)
            Text(store.remainingBudget.minorUnits < 0 ? "over budget" : "still to spend")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.58))
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var shoppingAction: some View {
        Button {
            store.confirmationMessage = nil
            showsShoppingList = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(WeeknightTheme.forest)
                    .frame(width: 48, height: 48)
                    .background(WeeknightTheme.forest.opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Shopping list")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(WeeknightTheme.deepestPine)
                    Text("\(store.shoppingProgress.display) items · \(store.plan.storeName)")
                        .font(.footnote)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("shopping-progress")
                }
                Spacer(minLength: 8)
                shoppingProgressRing
            }
            .padding(16)
            .background(Color.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: WeeknightTheme.Radius.card, style: .continuous)
                    .stroke(WeeknightTheme.hairline, lineWidth: 1)
            }
            .shadow(color: WeeknightTheme.deepestPine.opacity(0.07), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("open-shopping-list")
        .accessibilityLabel("Shopping list, \(store.shoppingProgress.display) items checked")
        .accessibilityHint("Opens the shopping list generated from this week")
    }

    private var shoppingProgressRing: some View {
        ZStack {
            Circle()
                .stroke(WeeknightTheme.hairline, lineWidth: 6)
            Circle()
                .trim(from: 0, to: store.shoppingProgress.fraction)
                .stroke(WeeknightTheme.forest, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(WeeknightTheme.deepestPine)
                .frame(width: 40, height: 40)
            Text("\(shoppingProgressPercent)%")
                .font(.caption.weight(.black))
                .foregroundStyle(WeeknightTheme.photoText)
                .fixedSize(horizontal: true, vertical: true)
        }
        .frame(width: 54, height: 54)
        .accessibilityHidden(true)
    }

    private var dinnerSectionHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(store.filledCount == 0 ? "Nothing planned yet" : "Your dinners")
                .font(.title2.weight(.black))
                .foregroundStyle(WeeknightTheme.deepestPine)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("plan-headline")
                .accessibilityLabel(planHeadlineAccessibilityLabel)
            Spacer(minLength: 8)
            Text(openDinnerStatus)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(WeeknightTheme.secondaryText)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("plan-progress")
                .accessibilityLabel("\(store.filledCount) of \(store.totalCount) dinners planned")
        }
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

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    findMealsButton
                    autofillButton
                }
            } else {
                HStack(spacing: 10) {
                    findMealsButton
                    autofillButton
                }
            }
        }
    }

    private var findMealsButton: some View {
        Button("Find meals") { navigation.showMeals() }
            .buttonStyle(PrimaryActionButtonStyle())
    }

    private var autofillButton: some View {
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

    @ViewBuilder
    private func dayRow(_ slot: MealSlot) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            dayDivider(slot.day)
            if let recipe = store.recipe(for: slot) {
                filledDayCard(slot: slot, recipe: recipe)
                if let conflict = store.conflict(for: slot.day) {
                    planConflictWarning(conflict)
                }
            } else {
                emptyDayCard(slot)
            }
        }
        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
    }

    private func dayDivider(_ day: Weekday) -> some View {
        HStack(spacing: 12) {
            Text(day.rawValue.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(WeeknightTheme.secondaryText)
                .fixedSize(horizontal: true, vertical: true)
            Rectangle()
                .fill(WeeknightTheme.hairline)
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }

    private func filledDayCard(slot: MealSlot, recipe: Recipe) -> some View {
        VStack(spacing: 0) {
            NavigationLink {
                RecipeDetailsView(recipeID: recipe.id, origin: .plan, initialServings: slot.servings)
            } label: {
                mealCardContent(slot: slot, recipe: recipe)
                    .padding(14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("open-meal-\(slot.day.rawValue)")
            .accessibilityLabel("View \(recipe.title) recipe for \(slot.day.rawValue)")
            .accessibilityHint("Opens recipe details")

            Divider().overlay(WeeknightTheme.hairline)
            filledDayActions(slot: slot)
        }
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: WeeknightTheme.Radius.card, style: .continuous)
                .stroke(WeeknightTheme.hairline, lineWidth: 1)
        }
        .shadow(color: WeeknightTheme.deepestPine.opacity(0.07), radius: 10, y: 5)
    }

    @ViewBuilder
    private func mealCardContent(slot: MealSlot, recipe: Recipe) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                RecipeArtwork(style: recipe.artwork, imageDescription: "Photo of \(recipe.title)")
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.thumbnail, style: .continuous))
                mealCardDetails(slot: slot, recipe: recipe)
            }
        } else {
            HStack(alignment: .top, spacing: 14) {
                RecipeArtwork(style: recipe.artwork, compact: true, imageDescription: "Photo of \(recipe.title)")
                    .frame(width: 86, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.thumbnail, style: .continuous))
                mealCardDetails(slot: slot, recipe: recipe)
            }
        }
    }

    private func mealCardDetails(slot: MealSlot, recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(WeeknightTheme.deepestPine)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("meal-\(slot.day.rawValue)")
            recipeTags(recipe)
            recipeMetadata(recipe: recipe, servings: slot.servings)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func recipeTags(_ recipe: Recipe) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(recipe.tags.prefix(2)), id: \.self) { tag in
                Text(tag)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WeeknightTheme.forest)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(WeeknightTheme.forest.opacity(0.09))
                    .clipShape(Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func recipeMetadata(recipe: Recipe, servings: Int) -> some View {
        let cost = store.estimatedCost(for: recipe, servings: servings).formatted()
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                Text("\(recipe.activeMinutes)m")
                metadataDivider
                Text("serves \(servings)")
                metadataDivider
                Text(cost).foregroundStyle(WeeknightTheme.deepestPine)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(recipe.activeMinutes)m")
                Text("serves \(servings)")
                Text(cost)
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(WeeknightTheme.secondaryText)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recipe.activeMinutes) minutes, serves \(servings), estimated cost \(cost)")
    }

    private var metadataDivider: some View {
        Rectangle()
            .fill(WeeknightTheme.hairline)
            .frame(width: 1, height: 18)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func filledDayActions(slot: MealSlot) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 0) {
                replaceButton(day: slot.day)
                Divider().overlay(WeeknightTheme.hairline)
                clearButton(day: slot.day)
            }
            .accessibilityElement(children: .contain)
        } else {
            HStack(spacing: 0) {
                replaceButton(day: slot.day)
                Rectangle()
                    .fill(WeeknightTheme.hairline)
                    .frame(width: 1)
                    .accessibilityHidden(true)
                clearButton(day: slot.day)
            }
            .accessibilityElement(children: .contain)
        }
    }

    private func replaceButton(day: Weekday) -> some View {
        Button { swapDay = day } label: {
            Label("Swap meal", systemImage: "arrow.left.arrow.right")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(WeeknightTheme.deepestPine)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
        .accessibilityIdentifier("replace-meal-\(day.rawValue)")
    }

    private func clearButton(day: Weekday) -> some View {
        Button(role: .destructive) {
            clearMeal(day)
        } label: {
            Label("Clear day", systemImage: "trash")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(WeeknightTheme.deepestPine)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
        .accessibilityIdentifier("clear-meal-\(day.rawValue)")
    }

    private func emptyDayCard(_ slot: MealSlot) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "plus")
                .font(.title3.weight(.bold))
                .foregroundStyle(WeeknightTheme.forest)
                .frame(width: 64, height: 64)
                .background(WeeknightTheme.forest.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.thumbnail, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("No meal planned")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(WeeknightTheme.deepestPine)
                    .accessibilityIdentifier("empty-meal-\(slot.day.rawValue)")
                Text("Choose a dinner for \(slot.day.rawValue).")
                    .font(.subheadline)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Add meal") { navigation.showMeals() }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(WeeknightTheme.forest)
                    .frame(minHeight: 44, alignment: .leading)
                    .accessibilityIdentifier("add-meal-\(slot.day.rawValue)")
                    .accessibilityHint("Opens Explore meals")
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.white.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: WeeknightTheme.Radius.card, style: .continuous)
                .stroke(WeeknightTheme.hairline, lineWidth: 1)
        }
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
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { conflictActions(conflict) }
                VStack(alignment: .leading, spacing: 8) { conflictActions(conflict) }
            }
            Text("It stays planned until you replace or clear it. Verify labels and allergen information.")
                .font(.footnote.weight(.semibold))
                .accessibilityIdentifier("plan-conflict-\(conflict.day.rawValue)")
        }
        .foregroundStyle(WeeknightTheme.tomato)
        .padding(14)
        .background(WeeknightTheme.tomato.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
        .accessibilityElement(children: .contain)
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
    private var storeInitials: String {
        let initials = store.plan.storeName
            .split(whereSeparator: { !$0.isLetter })
            .prefix(2)
            .compactMap(\.first)
        return String(initials).uppercased()
    }
    private var shoppingProgressPercent: Int {
        Int((store.shoppingProgress.fraction * 100).rounded())
    }
    private var openDinnerStatus: String {
        let count = openSlots.count
        if count == 0 { return "Week complete" }
        return "\(count) dinner\(count == 1 ? "" : "s") left"
    }
    private var remainingBudgetAmountText: String {
        let amount = Money(
            minorUnits: abs(store.remainingBudget.minorUnits),
            currencyCode: store.remainingBudget.currencyCode
        ).formatted()
        return store.remainingBudget.minorUnits < 0 ? "\(amount) over" : "\(amount) left"
    }
    private var remainingDinnerBudgetText: String {
        guard store.remainingBudget.minorUnits >= 0 else { return budgetStatusText }
        guard !openSlots.isEmpty else { return "Week complete and within budget" }
        let perDinner = store.remainingBudget.minorUnits / openSlots.count
        let roundedMinorUnits = ((perDinner + 50) / 100) * 100
        let amount = shortCurrency(
            Money(minorUnits: roundedMinorUnits, currencyCode: store.remainingBudget.currencyCode)
        )
        return "About \(amount) per remaining dinner"
    }
    private var planHeadlineAccessibilityLabel: String {
        if store.filledCount == store.totalCount { return "Your week is ready to shop" }
        if store.filledCount == 0 { return "Nothing planned yet" }
        return "Your dinners"
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

    private func shortCurrency(_ money: Money) -> String {
        money.formatted().replacingOccurrences(of: ".00", with: "")
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
