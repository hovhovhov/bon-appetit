import SwiftUI
import UIKit

struct PlanView: View {
    @Environment(AppStore.self) private var store
    @State private var swapDay: Weekday?
    @State private var autofillPresentation: AutofillPresentation?
    @State private var planActionError: String?

    private var headline: String {
        if store.filledCount == store.totalCount { return "Your week is ready to shop" }
        if store.filledCount == 0 { return "Let’s fill the week" }
        return "Your week is nearly set"
    }

    private var budgetGuidance: String {
        switch store.budgetStatus {
        case .comfortable:
            if store.filledCount == store.totalCount { return "Comfortably inside your budget" }
            let open = max(1, store.totalCount - store.filledCount)
            let perDinner = Money(
                minorUnits: max(0, store.remainingBudget.minorUnits) / open,
                currencyCode: store.plan.budget.currencyCode
            )
            return "About \(perDinner.formatted()) per remaining dinner"
        case .nearLimit:
            return "Close to the limit — keep the next dinner lean"
        case .exactlyAtBudget:
            return "Exactly on budget"
        case .overBudget:
            return "\(Money(minorUnits: abs(store.remainingBudget.minorUnits)).formatted()) over — replace a meal to recover"
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                BudgetCard(guidance: budgetGuidance)
                    .padding(.top, WeeknightTheme.Spacing.standard)
                shoppingSummary
                    .padding(.top, WeeknightTheme.Spacing.medium)
                dinnerSection
                    .padding(.top, 28)
                Text("Estimates use mock consumed quantities, not live checkout prices.")
                    .font(.footnote)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .padding(.top, WeeknightTheme.Spacing.large)
                    .padding(.bottom, WeeknightTheme.Spacing.xLarge)
            }
            .padding(.horizontal, WeeknightTheme.Spacing.gutter)
        }
        .background(WeeknightTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(item: $swapDay) { day in
            SwapMealSheet(day: day) {}
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $autofillPresentation) { presentation in
            AutofillResultSheet(presentation: presentation)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
        .accessibilityIdentifier("plan-screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GOOD EVENING")
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(WeeknightTheme.secondaryText)
            Text(headline)
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(WeeknightTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("plan-headline")
            HStack(spacing: 9) {
                Button {
                    store.selectedTab = .preferences
                } label: {
                    Label(store.plan.storeName, systemImage: "storefront.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WeeknightTheme.primaryText)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(WeeknightTheme.surface)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens Preferences")
                Text(store.plan.weekLabel)
                    .font(.subheadline)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, WeeknightTheme.Spacing.standard)
    }

    private var shoppingSummary: some View {
        NavigationLink {
            ShoppingListView()
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "bag.badge.plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(WeeknightTheme.bottle)
                    .frame(width: 48, height: 48)
                    .background(WeeknightTheme.wash)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Shopping list")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(WeeknightTheme.primaryText)
                    Text("\(store.shoppingProgress.display) items · \(store.plan.storeName)")
                        .font(.subheadline)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                        .accessibilityIdentifier("shopping-progress")
                }
                Spacer(minLength: 8)
                ZStack {
                    Circle().stroke(WeeknightTheme.sand, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: store.shoppingProgress.fraction)
                        .stroke(WeeknightTheme.leaf, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int((store.shoppingProgress.fraction * 100).rounded()))%")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(WeeknightTheme.primaryText)
                }
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
            }
            .padding(16)
            .weeknightCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("open-shopping-list")
        .accessibilityLabel("Shopping list, \(store.shoppingProgress.display) items checked")
    }

    private var dinnerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your dinners")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(WeeknightTheme.primaryText)
                Spacer()
                Text(store.filledCount == store.totalCount ? "All \(store.totalCount) planned" : "\(store.totalCount - store.filledCount) left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WeeknightTheme.secondaryText)
            }
            Text("\(store.filledCount) of \(store.totalCount) dinners planned")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WeeknightTheme.bottle)
                .accessibilityIdentifier("plan-progress")

            if store.filledCount < store.totalCount {
                Button {
                    runAutofill()
                } label: {
                    if store.isAutofilling {
                        HStack { ProgressView(); Text("Filling open days…") }
                    } else {
                        Label("Fill the rest for me", systemImage: "wand.and.stars")
                    }
                }
                .buttonStyle(ForestActionButtonStyle())
                .disabled(store.isAutofilling)
                .accessibilityIdentifier("autofill-plan")
                .accessibilityHint("Uses hard preferences, cooking time, variety, and budget to fill open cooking days")
            }

            ForEach(store.plan.slots) { slot in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 9) {
                        Text(slot.day.rawValue.uppercased())
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(WeeknightTheme.secondaryText)
                        Rectangle()
                            .fill(WeeknightTheme.forest.opacity(0.1))
                            .frame(height: 1)
                    }
                    if let recipe = store.recipe(for: slot) {
                        NavigationLink {
                            RecipeDetailsView(
                                recipeID: recipe.id,
                                origin: .plan,
                                initialServings: slot.servings
                            )
                        } label: {
                            PlannedMealCard(day: slot.day, recipe: recipe, servings: slot.servings)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("open-meal-\(slot.day.rawValue)")
                        if let conflict = store.conflict(for: slot.day) {
                            planConflictWarning(conflict)
                        }
                    } else {
                        EmptyMealCard(day: slot.day)
                    }
                }
            }
        }
    }

    private func planConflictWarning(_ conflict: ScheduledPreferenceConflict) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("This meal conflicts with your setup", systemImage: "exclamationmark.triangle.fill")
                .font(.headline.weight(.bold))
            Text(conflict.reasons.map(\.message).joined(separator: " "))
                .font(.subheadline)
            Text("It is still on your plan. Weeknight cannot describe it as safe or eligible; verify labels and allergen information.")
                .font(.footnote.weight(.semibold))
            HStack(spacing: 8) {
                Button("Replace") { swapDay = conflict.day }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: 0x8C2A17))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("replace-conflict-\(conflict.day.rawValue)")
                Button("Clear", role: .destructive) {
                    Task {
                        do {
                            try await store.clearMeal(on: conflict.day)
                            UIAccessibility.post(notification: .announcement, argument: "\(conflict.day.rawValue)’s meal cleared")
                        } catch {
                            planActionError = error.localizedDescription
                            UIAccessibility.post(notification: .announcement, argument: "The meal could not be cleared")
                        }
                    }
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .accessibilityIdentifier("clear-conflict-\(conflict.day.rawValue)")
            }
        }
        .foregroundStyle(Color(hex: 0x8C2A17))
        .padding(14)
        .background(Color(hex: 0xFCEAE4))
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan-conflict-\(conflict.day.rawValue)")
    }

    private func runAutofill() {
        Task {
            do {
                let outcome = try await store.fillOpenDays()
                autofillPresentation = AutofillPresentation(outcome: outcome)
                let announcement: String
                if case .success = outcome {
                    announcement = "Open cooking days filled"
                } else {
                    announcement = "Weeknight could not fill every open day"
                }
                UIAccessibility.post(notification: .announcement, argument: announcement)
            } catch {
                autofillPresentation = AutofillPresentation(
                    outcome: .unable(message: error.localizedDescription, suggestions: ["Try again", "Review Preferences"])
                )
                UIAccessibility.post(notification: .announcement, argument: "Autofill could not be completed")
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
    @Environment(\.dismiss) private var dismiss
    let presentation: AutofillPresentation

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch presentation.outcome {
                    case .success(_, let assignments, let projectedSpend):
                        Label("Your open days are filled", systemImage: "checkmark.circle.fill")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(WeeknightTheme.bottle)
                        Text("Weeknight applied one complete plan update and regenerated the shopping list.")
                            .foregroundStyle(WeeknightTheme.secondaryText)
                        ForEach(assignments) { assignment in
                            HStack(alignment: .top, spacing: 12) {
                                Text(assignment.day.shortName)
                                    .font(.subheadline.weight(.bold))
                                    .frame(width: 46, height: 46)
                                    .background(WeeknightTheme.wash)
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(assignment.recipeTitle).font(.headline.weight(.bold))
                                    Text("\(assignment.servings) serving\(assignment.servings == 1 ? "" : "s")")
                                        .font(.subheadline).foregroundStyle(WeeknightTheme.secondaryText)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .weeknightCard()
                        }
                        Label("Projected week: \(projectedSpend.formatted()) of \(store.plan.budget.formatted())", systemImage: "banknote")
                            .font(.headline.weight(.semibold))
                    case .unable(let message, let suggestions):
                        Label("Weeknight couldn’t fill every open day", systemImage: "exclamationmark.triangle.fill")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(Color(hex: 0x8C2A17))
                        Text(message)
                            .foregroundStyle(WeeknightTheme.primaryText)
                        if !suggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Things you can change").font(.headline.weight(.bold))
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Label(suggestion, systemImage: "arrow.right.circle")
                                }
                            }
                            .padding(15)
                            .weeknightCard()
                        }
                        Text("Hard allergen, dietary, and appliance rules were not weakened.")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(hex: 0x8C2A17))
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
}

private struct BudgetCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let guidance: String

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 5) {
                    Text("ESTIMATED SHOP")
                        .font(.caption.weight(.bold))
                        .tracking(1.3)
                        .foregroundStyle(WeeknightTheme.background.opacity(0.65))
                    Text("\(store.weeklySpend.formatted()) of \(store.plan.budget.formatted())")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(WeeknightTheme.background)
                        .accessibilityIdentifier("budget-spent")
                    if store.remainingBudget.minorUnits >= 0 {
                        Text("\(store.remainingBudget.formatted()) left")
                            .foregroundStyle(WeeknightTheme.mint)
                            .accessibilityIdentifier("budget-remaining")
                    } else {
                        Text("\(Money(minorUnits: abs(store.remainingBudget.minorUnits)).formatted()) over")
                            .foregroundStyle(Color(hex: 0xFFB4A5))
                            .accessibilityIdentifier("budget-remaining")
                    }
                    Text("still to spend")
                        .font(.caption)
                        .foregroundStyle(WeeknightTheme.background.opacity(0.58))
                }
                .font(.headline.weight(.bold))
            } else {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("ESTIMATED SHOP")
                            .font(.caption.weight(.bold))
                            .tracking(1.3)
                            .foregroundStyle(WeeknightTheme.background.opacity(0.65))
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(store.weeklySpend.formatted())
                                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                                .foregroundStyle(WeeknightTheme.background)
                            Text("of \(store.plan.budget.formatted())")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(WeeknightTheme.background.opacity(0.58))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("budget-spent")
                    }
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 3) {
                        if store.remainingBudget.minorUnits >= 0 {
                            Text("\(store.remainingBudget.formatted()) left")
                                .foregroundStyle(WeeknightTheme.mint)
                        } else {
                            Text("\(Money(minorUnits: abs(store.remainingBudget.minorUnits)).formatted()) over")
                                .foregroundStyle(Color(hex: 0xFFB4A5))
                        }
                        Text("still to spend")
                            .font(.caption)
                            .foregroundStyle(WeeknightTheme.background.opacity(0.58))
                    }
                    .font(.headline.weight(.bold))
                    .accessibilityIdentifier("budget-remaining")
                }
            }
            BudgetProgressBar(spent: store.weeklySpend, budget: store.plan.budget)
            Label(guidance, systemImage: store.budgetStatus == .overBudget ? "exclamationmark.triangle.fill" : "circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WeeknightTheme.background.opacity(0.84))
                .symbolRenderingMode(.monochrome)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [WeeknightTheme.deepPine, WeeknightTheme.deepestPine],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.budget, style: .continuous))
        .shadow(color: WeeknightTheme.deepestPine.opacity(0.3), radius: 18, y: 10)
    }
}

private struct PlannedMealCard: View {
    @Environment(AppStore.self) private var store
    let day: Weekday
    let recipe: Recipe
    let servings: Int

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            RecipeArtwork(style: recipe.artwork, compact: true)
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 7) {
                Text(recipe.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(WeeknightTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("meal-\(day.rawValue)")
                FlowLayout(spacing: 5) {
                    ForEach(recipe.tags, id: \.self) { TagChip(text: $0) }
                }
                HStack(spacing: 8) {
                    Text("\(recipe.activeMinutes)m")
                    Text("serves \(servings)")
                    Text(store.estimatedCost(for: recipe, servings: servings).formatted()).fontWeight(.bold)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(WeeknightTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .weeknightCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(day.rawValue), \(recipe.title), \(recipe.activeMinutes) minutes, serves \(servings), \(store.estimatedCost(for: recipe, servings: servings).formatted())")
    }
}

private struct EmptyMealCard: View {
    @Environment(AppStore.self) private var store
    let day: Weekday

    var body: some View {
        Button {
            store.selectedTab = .discover
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "plus")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(WeeknightTheme.bottle)
                    .frame(width: 48, height: 48)
                    .background(WeeknightTheme.wash)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Pick a dinner for \(day.shortName)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(WeeknightTheme.primaryText)
                    Text("Open Discover to find a budget-fit recipe")
                        .font(.subheadline)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(WeeknightTheme.secondaryText)
            }
            .padding(14)
            .background(WeeknightTheme.surface.opacity(0.62))
            .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: WeeknightTheme.Radius.card, style: .continuous)
                    .stroke(WeeknightTheme.forest.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: 64)
        .accessibilityIdentifier("empty-\(day.rawValue)")
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width.isFinite ? width : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
