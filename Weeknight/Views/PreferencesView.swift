import SwiftUI
import UIKit

enum PreferenceEditorKind: String, CaseIterable, Identifiable, Hashable {
    case supermarket
    case market
    case household
    case cookingDays
    case budget
    case cookingTime
    case dietary
    case allergens
    case dislikes
    case proteins
    case mealStyles
    case appliances

    var id: String { rawValue }

    var title: String {
        switch self {
        case .supermarket: "Supermarket"
        case .market: "Country & currency"
        case .household: "Household size"
        case .cookingDays: "Cooking days"
        case .budget: "Weekly budget"
        case .cookingTime: "Cooking time"
        case .dietary: "Dietary restrictions"
        case .allergens: "Medical allergens"
        case .dislikes: "Disliked ingredients"
        case .proteins: "Preferred proteins"
        case .mealStyles: "Meal styles & vibes"
        case .appliances: "Kitchen appliances"
        }
    }

    var effect: String {
        switch self {
        case .supermarket, .market: "Prices"
        case .household: "Portions"
        case .cookingDays: "Plan"
        case .budget: "Budget"
        case .cookingTime, .dislikes, .proteins, .mealStyles: "Ranking"
        case .dietary, .allergens, .appliances: "Eligibility"
        }
    }

    var explanation: String {
        switch self {
        case .supermarket: "Changes the deterministic local quote set used for recipe and shopping estimates."
        case .market: "Weeknight currently supports United States pricing in USD. Unsupported markets stay unavailable rather than using made-up exchange rates."
        case .household: "Sets servings for planned dinners and scales the budget preview and shopping list."
        case .cookingDays: "Sets the nights that appear on your active week."
        case .budget: "Helps rank recipes and choose an autofill combination. It never changes medical eligibility."
        case .cookingTime: "Discover flags slower recipes; autofill uses this as a firm limit."
        case .dietary: "Recipes that do not meet every selected dietary restriction are excluded."
        case .allergens: "Recipes with a matching declared allergen are excluded before ranking."
        case .dislikes: "Recipes can still appear, but ingredients you dislike lower their ranking."
        case .proteins: "Selected proteins receive a transparent ranking boost."
        case .mealStyles: "Selected styles receive a transparent ranking boost."
        case .appliances: "Recipes that require equipment you have not selected are excluded."
        }
    }
}

struct PreferencesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var launchedEditor: PreferenceEditorKind?

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        if let flag = arguments.firstIndex(of: "--open-preference-editor"),
           arguments.indices.contains(flag + 1),
           let kind = PreferenceEditorKind(rawValue: arguments[flag + 1]) {
            _launchedEditor = State(initialValue: kind)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                planningSummary
                preferenceSection("THE WEEK", kinds: [.supermarket, .market, .household, .cookingDays, .budget, .cookingTime])
                preferenceSection("WHAT YOU EAT", kinds: [.dietary, .allergens, .dislikes, .proteins, .mealStyles])
                preferenceSection("KITCHEN", kinds: [.appliances])
                reduceMotionRow

                Button {
                    store.resetFixture()
                } label: {
                    Label("Reset demo week", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .accessibilityHint("Restores the canonical plan, preferences, shopping progress, Saved recipes, and notes")
                .accessibilityIdentifier("reset-fixture")

                Text("Recipe and shopping prices are deterministic local estimates, not live checkout quotes. Always verify ingredient labels and allergen information yourself.")
                    .font(.footnote)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .padding(.bottom, WeeknightTheme.Spacing.xLarge)
            }
            .padding(.horizontal, WeeknightTheme.Spacing.gutter)
            .padding(.top, WeeknightTheme.Spacing.standard)
        }
        .background(WeeknightTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(for: PreferenceEditorKind.self) { kind in
            PreferenceEditorSheet(kind: kind, initial: store.preferences)
        }
        .sheet(item: $launchedEditor) { kind in
            NavigationStack {
                PreferenceEditorSheet(kind: kind, initial: store.preferences)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .accessibilityIdentifier("preferences-screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("You")
                .font(.largeTitle.weight(.black))
                .foregroundStyle(WeeknightTheme.primaryText)
                .accessibilityIdentifier("preferences-title")
        }
    }

    private var planningSummary: some View {
        Text("\(store.preferences.householdSize) \(store.preferences.householdSize == 1 ? "person" : "people") · \(store.preferences.cookingDays.count) dinners a week · \(store.preferences.weeklyBudget.formatted()) at \(store.preferences.supermarket.rawValue) · under \(store.preferences.maximumCookingMinutes) min")
            .font(.title3)
            .foregroundStyle(WeeknightTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("preferences-summary")
    }

    private func preferenceSection(_ title: String, kinds: [PreferenceEditorKind]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1.8)
                .foregroundStyle(WeeknightTheme.secondaryText)
            VStack(spacing: 0) {
                ForEach(Array(kinds.enumerated()), id: \.element.id) { index, kind in
                    preferenceRow(kind)
                    if index < kinds.count - 1 {
                        Divider().overlay(WeeknightTheme.hairline)
                    }
                }
            }
        }
    }

    private func preferenceRow(_ kind: PreferenceEditorKind) -> some View {
        NavigationLink(value: kind) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(kind.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(kind == .allergens ? WeeknightTheme.tomato : WeeknightTheme.primaryText)
                    Text("\(summary(for: kind)) · \(kind.effect.lowercased())")
                        .font(.body)
                        .foregroundStyle(kind == .allergens ? WeeknightTheme.tomato : WeeknightTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 5)
                Image(systemName: "chevron.right")
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.title), \(summary(for: kind))")
        .accessibilityHint("Opens an editor. Changes are not applied until you save.")
        .accessibilityIdentifier("preference-row-\(kind.rawValue)")
    }

    private func summary(for kind: PreferenceEditorKind) -> String {
        let preferences = store.preferences
        switch kind {
        case .supermarket: return preferences.supermarket.rawValue
        case .market: return preferences.market.rawValue
        case .household: return "\(preferences.householdSize) \(preferences.householdSize == 1 ? "person" : "people")"
        case .cookingDays: return "\(preferences.cookingDays.count) dinners · \(preferences.cookingDays.map(\.shortName).joined(separator: ", "))"
        case .budget: return "\(preferences.weeklyBudget.formatted()) · about \(Money(minorUnits: preferences.weeklyBudget.minorUnits / max(1, preferences.cookingDays.count)).formatted()) a dinner"
        case .cookingTime: return "Under \(preferences.maximumCookingMinutes) min"
        case .dietary: return selectionSummary(preferences.dietaryRestrictions.map(\.rawValue))
        case .allergens: return selectionSummary(preferences.medicalAllergens.map(\.rawValue))
        case .dislikes:
            let names = WeeknightFixture.recipes.flatMap(\.ingredients).filter { preferences.dislikedIngredientIDs.contains($0.ingredient.id) }.map { $0.ingredient.displayName }
            return selectionSummary(Array(Set(names)))
        case .proteins: return selectionSummary(preferences.preferredProteins.map(\.rawValue))
        case .mealStyles: return selectionSummary(preferences.preferredMealStyles.map(\.rawValue))
        case .appliances: return selectionSummary(preferences.availableAppliances.map(\.rawValue))
        }
    }

    private func selectionSummary(_ values: [String]) -> String {
        values.isEmpty ? "None selected" : values.sorted().joined(separator: ", ")
    }

    private var reduceMotionRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Reduce motion")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(WeeknightTheme.primaryText)
                Text("Follows the iPhone system setting")
                    .font(.body)
                    .foregroundStyle(WeeknightTheme.secondaryText)
            }
            Spacer()
            Image(systemName: reduceMotion ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(reduceMotion ? WeeknightTheme.forest : WeeknightTheme.secondaryText.opacity(0.35))
        }
        .frame(minHeight: 56)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reduce motion")
        .accessibilityValue(reduceMotion ? "On, follows system setting" : "Off, follows system setting")
    }
}

private struct PreferenceEditorSheet: View {
    enum Phase: Equatable {
        case editing
        case reviewing(PreferenceUpdatePreview)
        case saving
        case failed(String)
    }

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let kind: PreferenceEditorKind
    @State private var draft: UserPreferences
    @State private var phase: Phase = .editing

    init(kind: PreferenceEditorKind, initial: UserPreferences) {
        self.kind = kind
        _draft = State(initialValue: initial)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if case .reviewing(let preview) = phase {
                    reconciliation(preview)
                } else {
                    Text(kind.explanation)
                        .font(.body)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("preference-editor-\(kind.rawValue)")
                    editorContent
                    if kind == .allergens { allergenSafetyNote }
                    if case .failed(let message) = phase { failureBanner(message) }
                }
            }
            .padding(WeeknightTheme.Spacing.gutter)
            .padding(.bottom, 90)
        }
        .background(WeeknightTheme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomAction
                .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
        }
        .navigationTitle(phaseTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .disabled(phase == .saving)
            }
        }
        .interactiveDismissDisabled(phase == .saving)
    }

    private var phaseTitle: String {
        if case .reviewing = phase { return "Review changes" }
        return kind.title
    }

    @ViewBuilder
    private var editorContent: some View {
        switch kind {
        case .supermarket:
            VStack(spacing: 10) {
                ForEach(Supermarket.allCases) { option in
                    selectionRow(
                        title: option.rawValue,
                        subtitle: quoteDescription(option),
                        selected: draft.supermarket == option
                    ) { draft.supermarket = option }
                }
            }
        case .market:
            VStack(spacing: 10) {
                ForEach(MarketOption.allCases) { option in
                    selectionRow(
                        title: option.rawValue,
                        subtitle: option.isSupported ? "Supported local price catalogue" : "Unavailable in this prototype",
                        selected: draft.market == option,
                        enabled: option.isSupported
                    ) { draft.market = option }
                }
            }
        case .household:
            numericEditor(
                value: draft.householdSize,
                unit: draft.householdSize == 1 ? "person" : "people",
                minimum: UserPreferences.minimumHouseholdSize,
                maximum: UserPreferences.maximumHouseholdSize,
                step: 1,
                identifier: "household"
            ) { draft.householdSize = $0 }
        case .cookingDays:
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose at least one night.")
                    .font(.subheadline)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Weekday.allCases) { day in
                        optionButton(day.rawValue, selected: draft.cookingDays.contains(day), identifier: "day-\(day.shortName)") {
                            toggle(day, in: &draft.cookingDays, minimumOne: true)
                        }
                    }
                }
            }
        case .budget:
            numericEditor(
                value: draft.weeklyBudget.minorUnits / 100,
                unit: "dollars a week",
                minimum: UserPreferences.minimumBudgetMinorUnits / 100,
                maximum: UserPreferences.maximumBudgetMinorUnits / 100,
                step: UserPreferences.budgetStepMinorUnits / 100,
                identifier: "budget",
                prefix: "$"
            ) { draft.weeklyBudget = Money(minorUnits: $0 * 100, currencyCode: draft.market.currencyCode) }
        case .cookingTime:
            numericEditor(
                value: draft.maximumCookingMinutes,
                unit: "minutes maximum",
                minimum: UserPreferences.minimumCookingMinutes,
                maximum: UserPreferences.maximumCookingMinutes,
                step: UserPreferences.cookingMinutesStep,
                identifier: "cooking-time"
            ) { draft.maximumCookingMinutes = $0 }
        case .dietary:
            multiSelect(DietaryRestriction.allCases, selected: draft.dietaryRestrictions, prefix: "dietary") { draft.dietaryRestrictions = $0 }
        case .allergens:
            multiSelect(MedicalAllergen.allCases, selected: draft.medicalAllergens, prefix: "allergen") { draft.medicalAllergens = $0 }
        case .dislikes:
            dislikedIngredientsEditor
        case .proteins:
            multiSelect(PreferredProtein.allCases, selected: draft.preferredProteins, prefix: "protein") { draft.preferredProteins = $0 }
        case .mealStyles:
            multiSelect(MealStyle.allCases, selected: draft.preferredMealStyles, prefix: "style") { draft.preferredMealStyles = $0 }
        case .appliances:
            VStack(alignment: .leading, spacing: 12) {
                Text("Select every appliance you can use. Leaving all unselected can make every recipe ineligible.")
                    .font(.subheadline)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                ForEach(KitchenAppliance.allCases) { appliance in
                    Button {
                        toggle(appliance, in: &draft.availableAppliances)
                    } label: {
                        HStack {
                            Image(systemName: appliance.systemImage).frame(width: 30)
                            Text(appliance.rawValue).font(.headline)
                            Spacer()
                            Image(systemName: draft.availableAppliances.contains(appliance) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(draft.availableAppliances.contains(appliance) ? WeeknightTheme.leaf : WeeknightTheme.secondaryText)
                        }
                        .foregroundStyle(WeeknightTheme.primaryText)
                        .padding(15)
                        .frame(minHeight: 54)
                        .background(WeeknightTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(draft.availableAppliances.contains(appliance) ? .isSelected : [])
                    .accessibilityValue(draft.availableAppliances.contains(appliance) ? "Selected" : "Not selected")
                    .accessibilityIdentifier("appliance-\(appliance.id)")
                }
            }
        }
    }

    private var dislikedIngredientsEditor: some View {
        let ingredients = Dictionary(
            WeeknightFixture.recipes.flatMap(\.ingredients).map { ($0.ingredient.id, $0.ingredient) },
            uniquingKeysWith: { first, _ in first }
        ).values.sorted { $0.displayName < $1.displayName }
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 9)], spacing: 9) {
            ForEach(ingredients) { ingredient in
                optionButton(
                    ingredient.displayName,
                    selected: draft.dislikedIngredientIDs.contains(ingredient.id),
                    identifier: "dislike-\(ingredient.id)"
                ) {
                    toggle(ingredient.id, in: &draft.dislikedIngredientIDs)
                }
            }
        }
    }

    private var allergenSafetyNote: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Medical safety", systemImage: "cross.case.fill")
                .font(.headline.weight(.bold))
            Text("This prototype filters the six allergens declared in its local recipe catalogue. It cannot guarantee safety. Verify product labels, cross-contact, and current medical advice yourself.")
                .font(.subheadline)
        }
        .foregroundStyle(Color(hex: 0x8C2A17))
        .padding(15)
        .background(Color(hex: 0xFCEAE4))
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("allergen-safety-note")
    }

    private func reconciliation(_ preview: PreferenceUpdatePreview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Check how your week changes", systemImage: "list.bullet.clipboard")
                .font(.title2.weight(.heavy))
                .foregroundStyle(WeeknightTheme.primaryText)
            Text("Nothing has changed yet. Saving applies the preference and plan update together.")
                .foregroundStyle(WeeknightTheme.secondaryText)

            if preview.servingChangeCount > 0 {
                reviewBlock(
                    title: "Portions",
                    icon: "person.2.fill",
                    lines: ["\(preview.servingChangeCount) planned \(preview.servingChangeCount == 1 ? "meal changes" : "meals change") to \(preview.draft.householdSize) servings."]
                )
            }
            if !preview.addedDays.isEmpty {
                reviewBlock(title: "Days added", icon: "calendar.badge.plus", lines: preview.addedDays.map { "\($0.rawValue) is added as an open slot." })
            }
            if !preview.removedDays.isEmpty {
                reviewBlock(title: "Days removed", icon: "calendar.badge.minus", lines: preview.removedDays.map { "\($0.rawValue) is removed from this week." })
            }
            if !preview.removedFilledSlots.isEmpty {
                reviewBlock(
                    title: "Planned meals removed",
                    icon: "calendar.badge.minus",
                    lines: preview.removedFilledSlots.map { "\($0.day.rawValue): \($0.recipeTitle)" },
                    warning: true
                )
            }
            if !preview.conflicts.isEmpty {
                reviewBlock(
                    title: "Meals with hard conflicts",
                    icon: "exclamationmark.triangle.fill",
                    lines: preview.conflicts.flatMap { conflict in
                        ["\(conflict.day.rawValue): \(conflict.recipe.title)"] + conflict.reasons.map { "• \($0.message)" }
                    },
                    warning: true
                )
                Text("These meals stay on the plan with a warning and Replace or Clear actions. Weeknight will never describe them as safe or eligible.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: 0x8C2A17))
            }

            reviewBlock(
                title: "Budget & shopping preview",
                icon: "cart.fill",
                lines: budgetAndShoppingLines(preview)
            )

            Text("Always verify ingredient labels and allergen information before cooking.")
                .font(.footnote)
                .foregroundStyle(WeeknightTheme.secondaryText)
        }
        .accessibilityIdentifier("preference-reconciliation")
    }

    private func budgetAndShoppingLines(_ preview: PreferenceUpdatePreview) -> [String] {
        [
            "Estimated week: \(preview.currentSpend.formatted()) → \(preview.projectedSpend.formatted())",
            "Shopping items: \(preview.currentShoppingItemCount) → \(preview.projectedShoppingItemCount)",
            "Quantity or estimate changes: \(preview.shoppingChangeCount) item\(preview.shoppingChangeCount == 1 ? "" : "s")",
        ]
    }

    private func reviewBlock(title: String, icon: String, lines: [String], warning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.headline.weight(.bold))
            ForEach(lines, id: \.self) { Text($0).font(.subheadline) }
        }
        .foregroundStyle(warning ? Color(hex: 0x8C2A17) : WeeknightTheme.primaryText)
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(warning ? Color(hex: 0xFCEAE4) : WeeknightTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var bottomAction: some View {
        VStack(spacing: 8) {
            if case .reviewing = phase {
                Button("Back to edit") { phase = .editing }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
            Button {
                saveTapped()
            } label: {
                if phase == .saving {
                    HStack { ProgressView(); Text("Saving…") }
                } else if case .reviewing = phase {
                    Text("Save preference and update week")
                } else {
                    Text("Review and save")
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(phase == .saving || draft == store.preferences)
            .opacity(draft == store.preferences ? 0.45 : 1)
            .accessibilityIdentifier("preference-save")
            .accessibilityValue(phase == .saving ? "Saving" : (draft == store.preferences ? "Disabled" : "Enabled"))
        }
    }

    private func saveTapped() {
        switch phase {
        case .reviewing:
            commit()
        case .editing, .failed:
            let preview = store.previewPreferenceUpdate(draft)
            if preview.requiresConfirmation {
                phase = .reviewing(preview)
                UIAccessibility.post(notification: .screenChanged, argument: "Review changes")
            } else {
                commit()
            }
        case .saving:
            break
        }
    }

    private func commit() {
        phase = .saving
        Task {
            do {
                try await store.commitPreferences(draft)
                UIAccessibility.post(notification: .announcement, argument: "Preferences saved")
                dismiss()
            } catch {
                phase = .failed(error.localizedDescription)
                UIAccessibility.post(notification: .announcement, argument: "Preferences could not be saved")
            }
        }
    }

    private func selectionRow(
        title: String,
        subtitle: String,
        selected: Bool,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(WeeknightTheme.secondaryText)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? WeeknightTheme.leaf : WeeknightTheme.secondaryText)
            }
            .foregroundStyle(enabled ? WeeknightTheme.primaryText : WeeknightTheme.secondaryText)
            .padding(15)
            .frame(minHeight: 60)
            .background(WeeknightTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(enabled ? (selected ? "Selected" : "Not selected") : "Unavailable")
    }

    private func optionButton(_ title: String, selected: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(title).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark").font(.caption.weight(.bold)) }
            }
            .foregroundStyle(selected ? WeeknightTheme.background : WeeknightTheme.primaryText)
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(selected ? WeeknightTheme.forest : WeeknightTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(selected ? WeeknightTheme.forest : WeeknightTheme.forest.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityIdentifier(identifier)
    }

    private func numericEditor(
        value: Int,
        unit: String,
        minimum: Int,
        maximum: Int,
        step: Int,
        identifier: String,
        prefix: String = "",
        update: @escaping (Int) -> Void
    ) -> some View {
        VStack(spacing: 20) {
            Text("\(prefix)\(value)")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(WeeknightTheme.primaryText)
            Text(unit).font(.headline).foregroundStyle(WeeknightTheme.secondaryText)
            HStack(spacing: 26) {
                Button { update(value - step) } label: {
                    Image(systemName: "minus").frame(width: 56, height: 56)
                }
                .buttonStyle(.bordered)
                .disabled(value <= minimum)
                .accessibilityLabel("Decrease \(kind.title)")
                .accessibilityIdentifier("\(identifier)-decrease")
                Button { update(value + step) } label: {
                    Image(systemName: "plus").frame(width: 56, height: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(WeeknightTheme.bottle)
                .disabled(value >= maximum)
                .accessibilityLabel("Increase \(kind.title)")
                .accessibilityIdentifier("\(identifier)-increase")
            }
            Text("Allowed range: \(prefix)\(minimum) to \(prefix)\(maximum)")
                .font(.footnote)
                .foregroundStyle(WeeknightTheme.secondaryText)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .weeknightCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(identifier)-value")
    }

    private func multiSelect<Option: CaseIterable & Hashable & Identifiable & RawRepresentable>(
        _ options: Option.AllCases,
        selected: Set<Option>,
        prefix: String,
        update: @escaping (Set<Option>) -> Void
    ) -> some View where Option.RawValue == String, Option.AllCases: RandomAccessCollection {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 9)], spacing: 9) {
            ForEach(options) { option in
                optionButton(option.rawValue, selected: selected.contains(option), identifier: "\(prefix)-\(option.rawValue)") {
                    var changed = selected
                    toggle(option, in: &changed)
                    update(changed)
                }
            }
        }
    }

    private func failureBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(hex: 0x8C2A17))
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0xFCEAE4))
            .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
    }

    private func quoteDescription(_ supermarket: Supermarket) -> String {
        switch supermarket {
        case .traderJoes: "Canonical local estimate set"
        case .aldi: "Local estimate set · about 8% lower"
        case .safeway: "Local estimate set · about 8% higher"
        }
    }

    private func toggle<Value: Hashable>(_ value: Value, in set: inout Set<Value>, minimumOne: Bool = false) {
        if set.contains(value) {
            if !minimumOne || set.count > 1 { set.remove(value) }
        } else {
            set.insert(value)
        }
    }

    private func toggle(_ day: Weekday, in days: inout [Weekday], minimumOne: Bool) {
        var set = Set(days)
        toggle(day, in: &set, minimumOne: minimumOne)
        days = Weekday.allCases.filter(set.contains)
    }
}
