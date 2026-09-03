import SwiftUI
import UIKit

enum PreferenceEditorKind: String, CaseIterable, Identifiable, Hashable {
    case supermarket, market, household, cookingDays, budget, cookingTime
    case dietary, allergens, dislikes, proteins, mealStyles, appliances

    var id: String { rawValue }

    var chapter: PreferenceChapter {
        switch self {
        case .supermarket, .market, .household, .cookingDays, .budget, .cookingTime: .week
        case .dislikes, .proteins, .mealStyles: .taste
        case .dietary, .allergens: .rules
        case .appliances: .kitchen
        }
    }
}

enum PreferenceChapter: String, Hashable {
    case week, taste, rules, kitchen
}

enum PreferencePresentation {
    static func approximateBudgetPerDinner(_ preferences: UserPreferences) -> Money {
        Personalization.approximateBudgetPerDinner(preferences)
    }

    static func changedFieldCount(from committed: UserPreferences, to draft: UserPreferences) -> Int {
        [
            committed.market != draft.market,
            committed.supermarket != draft.supermarket,
            committed.householdSize != draft.householdSize,
            committed.cookingDays != draft.cookingDays,
            committed.weeklyBudget != draft.weeklyBudget,
            committed.maximumCookingMinutes != draft.maximumCookingMinutes,
            committed.dietaryRestrictions != draft.dietaryRestrictions,
            committed.medicalAllergens != draft.medicalAllergens,
            committed.dislikedIngredientIDs != draft.dislikedIngredientIDs,
            committed.preferredProteins != draft.preferredProteins,
            committed.preferredMealStyles != draft.preferredMealStyles,
            committed.availableAppliances != draft.availableAppliances,
        ].filter { $0 }.count
    }

    static func parsedBudgetMinorUnits(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
        guard !trimmed.isEmpty else { return nil }
        let pieces = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count <= 2, let whole = Int(pieces[0]), whole >= 0 else { return nil }
        let cents: Int
        if pieces.count == 1 || pieces[1].isEmpty {
            cents = 0
        } else {
            let fraction = String(pieces[1])
            guard fraction.count <= 2, fraction.allSatisfy(\.isNumber) else { return nil }
            cents = Int(fraction.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
        }
        return whole * 100 + cents
    }

    static func safetyChangeTitle(from committed: UserPreferences, to draft: UserPreferences) -> String? {
        if let allergen = MedicalAllergen.allCases.first(where: {
            draft.medicalAllergens.contains($0) && !committed.medicalAllergens.contains($0)
        }) {
            return "\(allergen.rawValue) added as a medical allergen"
        }
        if let restriction = DietaryRestriction.allCases.first(where: {
            draft.dietaryRestrictions.contains($0) && !committed.dietaryRestrictions.contains($0)
        }) {
            return "\(restriction.rawValue) dietary rule turned on"
        }
        if let appliance = KitchenAppliance.allCases.first(where: {
            committed.availableAppliances.contains($0) && !draft.availableAppliances.contains($0)
        }) {
            return "\(appliance.rawValue) marked unavailable"
        }
        return nil
    }
}

private enum PreferencesPalette {
    static let cream = WeeknightTheme.background
    static let paprika = Color(hex: 0xF7E5D2)
    static let paprikaText = Color(hex: 0x4B2D21)
    static let forest = Color(hex: 0x0D4A2E)
    static let forestDark = Color(hex: 0x10251A)
    static let forestPanel = Color(hex: 0x1C3026)
    static let citron = Color(hex: 0xCAE72E)
    static let amber = Color(hex: 0xF2B441)
    static let amberDark = Color(hex: 0x312F19)
    static let warmLine = Color(hex: 0xE4D6BD)
    static let safetyText = Color(hex: 0xF7F0DF)
    static let safetyMuted = Color(hex: 0xAAC0A7)
}

struct PreferencesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var committed = UserPreferences.canonical
    @State private var draft = UserPreferences.canonical
    @State private var didLoad = false
    @State private var reconciliationPreview: PreferenceUpdatePreview?
    @State private var isShowingBudgetEntry = false
    @State private var isShowingIngredientPicker = false
    @State private var isCommitting = false
    @State private var saveConfirmation: String?
    @State private var saveError: String?
    @State private var initialChapter: PreferenceChapter?
    @State private var initialEditor: PreferenceEditorKind?
    @AccessibilityFocusState private var confirmationFocused: Bool

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        if let flag = arguments.firstIndex(of: "--open-preference-editor"),
           arguments.indices.contains(flag + 1),
           let kind = PreferenceEditorKind(rawValue: arguments[flag + 1]) {
            _initialEditor = State(initialValue: kind)
        } else if let flag = arguments.firstIndex(of: "--preferences-section"),
                  arguments.indices.contains(flag + 1),
                  let chapter = PreferenceChapter(rawValue: arguments[flag + 1]) {
            _initialChapter = State(initialValue: chapter)
        }
    }

    private var isDirty: Bool { draft != committed }
    private var changeCount: Int { PreferencePresentation.changedFieldCount(from: committed, to: draft) }
    private var preview: PreferenceUpdatePreview { store.previewPreferenceUpdate(draft) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    weekChapter.id(PreferenceChapter.week)
                    tasteChapter.id(PreferenceChapter.taste)
                    rulesChapter.id(PreferenceChapter.rules)
                    kitchenChapter.id(PreferenceChapter.kitchen)
                }
            }
            .background(PreferencesPalette.cream.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) { stickyState }
            .task {
                guard !didLoad else { return }
                committed = store.preferences
                draft = store.preferences
                didLoad = true
                guard initialEditor != nil || initialChapter != nil else { return }
                await Task.yield()
                if let initialEditor {
                    // Lazy chapter contents are not registered with ScrollViewReader
                    // until their enclosing chapter has been materialized.
                    proxy.scrollTo(initialEditor.chapter, anchor: .top)
                    await Task.yield()
                    proxy.scrollTo(initialEditor, anchor: .center)
                } else if let initialChapter {
                    proxy.scrollTo(initialChapter, anchor: .top)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: Binding(
            get: { reconciliationPreview != nil },
            set: { if !$0 { reconciliationPreview = nil } }
        )) {
            if let reconciliationPreview {
                PreferenceReconciliationSheet(
                    preview: reconciliationPreview,
                    changeTitle: PreferencePresentation.safetyChangeTitle(from: committed, to: draft),
                    isSaving: isCommitting,
                    onCancel: { self.reconciliationPreview = nil },
                    onSave: {
                        self.reconciliationPreview = nil
                        commit(reconciliationPreview)
                    }
                )
            }
        }
        .sheet(isPresented: $isShowingBudgetEntry) {
            ExactBudgetSheet(
                money: draft.weeklyBudget,
                minimumMinorUnits: UserPreferences.minimumBudgetMinorUnits,
                maximumMinorUnits: UserPreferences.maximumBudgetMinorUnits
            ) { minorUnits in
                draft.weeklyBudget = Money(minorUnits: minorUnits, currencyCode: draft.market.currencyCode)
            }
        }
        .sheet(isPresented: $isShowingIngredientPicker) {
            IngredientPickerSheet(ingredients: availableIngredientsToDislike) { ingredient in
                draft.dislikedIngredientIDs.insert(ingredient.id)
            }
        }
        .onChange(of: store.preferences) { _, newValue in
            guard draft == committed else { return }
            committed = newValue
            draft = newValue
        }
        .task(id: saveConfirmation) {
            guard saveConfirmation != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            saveConfirmation = nil
        }
        .accessibilityIdentifier("preferences-screen")
    }

    private var weekChapter: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            chapterHeader(number: "01", title: "Your week", message: "The practical setup: where you shop, who’s eating, and what the week can cost.", foreground: WeeknightTheme.primaryText, muted: WeeknightTheme.secondaryText)
            marketSelectors
            householdControl
            cookingDaysControl
            budgetControl
            cookingTimeControl
        }
        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
        .padding(.top, WeeknightTheme.Spacing.standard)
        .padding(.bottom, 34)
        .background(PreferencesPalette.cream)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Preferences")
                .font(.largeTitle.weight(.black))
                .foregroundStyle(WeeknightTheme.primaryText)
                .accessibilityIdentifier("preferences-title")
            Text("How Weeknight plans for you. Everything here changes what lands in next week’s plan.")
                .font(.body)
                .foregroundStyle(WeeknightTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        summaryChip("\(store.preferences.householdSize) \(store.preferences.householdSize == 1 ? "person" : "people")")
                        summaryChip("\(store.preferences.cookingDays.count) dinners")
                        summaryChip("\(store.preferences.weeklyBudget.formatted()) a week")
                    }
                    summaryChip(store.preferences.supermarket.rawValue)
                }
                FlexiblePreferenceGrid(minimum: 116) {
                    summaryChip("\(store.preferences.householdSize) \(store.preferences.householdSize == 1 ? "person" : "people")")
                    summaryChip("\(store.preferences.cookingDays.count) dinners")
                    summaryChip("\(store.preferences.weeklyBudget.formatted()) a week")
                    summaryChip(store.preferences.supermarket.rawValue)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(committedSummary)
            .accessibilityIdentifier("preferences-summary")
        }
    }

    private var committedSummary: String {
        "\(store.preferences.householdSize) \(store.preferences.householdSize == 1 ? "person" : "people"), \(store.preferences.cookingDays.count) dinners, \(store.preferences.weeklyBudget.formatted()) a week, \(store.preferences.supermarket.rawValue)"
    }

    private func summaryChip(_ title: String) -> some View {
        Text(title).font(.subheadline.weight(.bold)).foregroundStyle(PreferencesPalette.forest)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 12).frame(minHeight: 36).background(WeeknightTheme.wash).clipShape(Capsule())
    }

    private func chapterHeader(number: String, title: String, message: String, foreground: Color, muted: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(number).font(.caption.weight(.black)).tracking(2)
                Rectangle().frame(height: 1).foregroundStyle(muted.opacity(0.35))
            }.foregroundStyle(muted)
            Text(title).font(.title.weight(.black)).foregroundStyle(foreground)
            Text(message).font(.callout).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var marketSelectors: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) { countrySelector; supermarketSelector }
        } else {
            HStack(alignment: .top, spacing: 12) { countrySelector; supermarketSelector }
        }
    }

    private var countrySelector: some View {
        Menu {
            ForEach(MarketOption.allCases) { option in
                Button {
                    guard option.isSupported else { return }
                    draft.market = option
                    draft.weeklyBudget = Money(minorUnits: draft.weeklyBudget.minorUnits, currencyCode: option.currencyCode)
                } label: { Label(option.rawValue, systemImage: draft.market == option ? "checkmark" : "circle") }
                    .disabled(!option.isSupported)
            }
        } label: {
            PreferenceSelectorCard(eyebrow: "Country", value: marketDisplayName, detail: "Prices in \(draft.market.currencyCode) $")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Country").accessibilityValue(draft.market.rawValue)
        .accessibilityHint("Choose a supported pricing country. Changes remain a draft until saved.")
        .accessibilityIdentifier("market-selector")
    }

    private var supermarketSelector: some View {
        Menu {
            ForEach(Supermarket.allCases) { supermarket in
                Button { draft.supermarket = supermarket } label: {
                    Label(supermarket.rawValue, systemImage: draft.supermarket == supermarket ? "checkmark" : "circle")
                }
            }
        } label: {
            PreferenceSelectorCard(eyebrow: "Supermarket", value: draft.supermarket.rawValue, detail: "Local estimate set")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Supermarket").accessibilityValue(draft.supermarket.rawValue)
        .accessibilityHint("Changes deterministic local price estimates after you save.")
        .accessibilityIdentifier("supermarket-selector")
    }

    private var marketDisplayName: String {
        draft.market.rawValue.components(separatedBy: " · ").first ?? draft.market.rawValue
    }

    private var householdControl: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Cooking for").font(.caption.weight(.bold)).tracking(1.8).foregroundStyle(WeeknightTheme.secondaryText)
                .accessibilityIdentifier("preference-editor-household")
            if dynamicTypeSize.isAccessibilitySize {
                householdValue
                HStack(spacing: 18) { householdMinus; Spacer(); householdPlus }
            } else {
                HStack(spacing: 18) { householdMinus; Spacer(); householdValue; Spacer(); householdPlus }
            }
            Text("Saving scales planned portions, prices, and the shopping list together.")
                .font(.subheadline).foregroundStyle(WeeknightTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).background(Color.white.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(PreferencesPalette.warmLine, lineWidth: 1) }
        .id(PreferenceEditorKind.household)
    }

    private var householdValue: some View {
        VStack(spacing: 0) {
            Text("\(draft.householdSize)").font(.system(size: dynamicTypeSize.isAccessibilitySize ? 54 : 66, weight: .black, design: .rounded)).minimumScaleFactor(0.75)
            Text(draft.householdSize == 1 ? "person" : "people").font(.headline).foregroundStyle(WeeknightTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore).accessibilityLabel("Household size")
        .accessibilityValue("\(draft.householdSize) \(draft.householdSize == 1 ? "person" : "people")")
        .accessibilityHint("Swipe up or down to adjust. Changes are saved only after review.")
        .accessibilityAdjustableAction { direction in
            switch direction { case .increment: adjustHousehold(by: 1); case .decrement: adjustHousehold(by: -1); @unknown default: break }
        }
        .accessibilityIdentifier("household-value")
    }

    private var householdMinus: some View {
        roundAdjustmentButton(symbol: "minus", label: "Decrease household size", disabled: draft.householdSize == UserPreferences.minimumHouseholdSize, identifier: "household-decrement") { adjustHousehold(by: -1) }
    }

    private var householdPlus: some View {
        roundAdjustmentButton(symbol: "plus", label: "Increase household size", disabled: draft.householdSize == UserPreferences.maximumHouseholdSize, identifier: "household-increment", filled: true) { adjustHousehold(by: 1) }
    }

    private func adjustHousehold(by delta: Int) {
        draft.householdSize = min(UserPreferences.maximumHouseholdSize, max(UserPreferences.minimumHouseholdSize, draft.householdSize + delta))
    }

    private var cookingDaysControl: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Cooking days").font(.title2.weight(.black))
                    .accessibilityIdentifier("preference-editor-cookingDays"); Spacer()
                Text("\(draft.cookingDays.count) dinners").font(.headline.weight(.bold)).foregroundStyle(PreferencesPalette.forest)
            }
            Text("Tap a day to plan a dinner for it. Choose at least one.").font(.body).foregroundStyle(WeeknightTheme.secondaryText)
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible()), GridItem(.flexible())] : Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                ForEach(Weekday.allCases) { day in cookingDayButton(day) }
            }
        }
        .id(PreferenceEditorKind.cookingDays)
    }

    private func cookingDayButton(_ day: Weekday) -> some View {
        let selected = draft.cookingDays.contains(day)
        return Button { toggleCookingDay(day) } label: {
            VStack(spacing: 6) {
                Text(dynamicTypeSize.isAccessibilitySize ? day.rawValue : day.shortName).font(.subheadline.weight(.black)).lineLimit(nil)
                Image(systemName: selected ? "checkmark" : "minus").font(.caption.weight(.black))
                    .foregroundStyle(selected ? PreferencesPalette.citron : WeeknightTheme.secondaryText)
            }
            .foregroundStyle(selected ? PreferencesPalette.safetyText : WeeknightTheme.secondaryText)
            .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 70 : 72)
            .background(selected ? PreferencesPalette.forest : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(selected ? PreferencesPalette.forest : PreferencesPalette.warmLine, style: StrokeStyle(lineWidth: 1, dash: selected ? [] : [4, 3])) }
        }
        .buttonStyle(.plain).disabled(selected && draft.cookingDays.count == 1)
        .accessibilityLabel(day.rawValue).accessibilityValue(selected ? "Selected, cooking day" : "Not selected")
        .accessibilityHint(selected && draft.cookingDays.count == 1 ? "At least one cooking day is required." : "Changes remain a draft until saved.")
        .accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier("day-\(day.shortName)")
    }

    private func toggleCookingDay(_ day: Weekday) {
        var selected = Set(draft.cookingDays)
        if selected.contains(day) { guard selected.count > 1 else { return }; selected.remove(day) } else { selected.insert(day) }
        draft.cookingDays = Weekday.allCases.filter(selected.contains)
    }

    private var budgetControl: some View {
        VStack(alignment: .leading, spacing: 20) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) { budgetTitle; budgetPerDinner }
            } else {
                HStack(alignment: .top) { budgetTitle; Spacer(); budgetPerDinner }
            }
            HStack(spacing: 14) {
                roundAdjustmentButton(symbol: "minus", label: "Decrease weekly budget by \(Money(minorUnits: UserPreferences.budgetStepMinorUnits).formatted())", disabled: draft.weeklyBudget.minorUnits <= UserPreferences.minimumBudgetMinorUnits, identifier: "budget-decrement", onDark: true) { adjustBudget(by: -UserPreferences.budgetStepMinorUnits) }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.22))
                        Capsule().fill(PreferencesPalette.citron).frame(width: geometry.size.width * budgetProgress)
                    }
                }.frame(height: 12).accessibilityHidden(true)
                roundAdjustmentButton(symbol: "plus", label: "Increase weekly budget by \(Money(minorUnits: UserPreferences.budgetStepMinorUnits).formatted())", disabled: draft.weeklyBudget.minorUnits >= UserPreferences.maximumBudgetMinorUnits, identifier: "budget-increment", onDark: true) { adjustBudget(by: UserPreferences.budgetStepMinorUnits) }
            }
            HStack(alignment: .firstTextBaseline) {
                Text(Money(minorUnits: UserPreferences.minimumBudgetMinorUnits).formatted()); Spacer()
                Text("Steps of \(Money(minorUnits: UserPreferences.budgetStepMinorUnits).formatted())"); Spacer()
                Text(Money(minorUnits: UserPreferences.maximumBudgetMinorUnits).formatted())
            }.font(.caption).foregroundStyle(Color.white.opacity(0.72))
        }
        .padding(18).foregroundStyle(PreferencesPalette.safetyText).background(PreferencesPalette.forest)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .id(PreferenceEditorKind.budget)
    }

    private var budgetTitle: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Weekly budget").font(.caption.weight(.black)).tracking(2).foregroundStyle(PreferencesPalette.citron)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .accessibilityIdentifier("preference-editor-budget")
                Spacer()
                Button("Type exact") { isShowingBudgetEntry = true }.font(.subheadline.weight(.bold)).foregroundStyle(PreferencesPalette.safetyText).frame(minHeight: 44).accessibilityIdentifier("budget-exact")
            }
            Text(draft.weeklyBudget.formatted()).font(.system(size: dynamicTypeSize.isAccessibilitySize ? 50 : 60, weight: .black, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.55)
                .accessibilityLabel("Weekly budget").accessibilityValue(draft.weeklyBudget.formatted()).accessibilityIdentifier("budget-value")
        }
    }

    private var budgetPerDinner: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
            Text(PreferencePresentation.approximateBudgetPerDinner(draft).formatted()).font(.title2.weight(.black)).foregroundStyle(PreferencesPalette.citron)
            Text("approximately a dinner, across \(draft.cookingDays.count) days").font(.subheadline).foregroundStyle(Color.white.opacity(0.74)).multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
        }.accessibilityElement(children: .combine)
    }

    private var budgetProgress: CGFloat {
        let range = UserPreferences.maximumBudgetMinorUnits - UserPreferences.minimumBudgetMinorUnits
        let current = min(range, max(0, draft.weeklyBudget.minorUnits - UserPreferences.minimumBudgetMinorUnits))
        return range > 0 ? CGFloat(current) / CGFloat(range) : 0
    }

    private func adjustBudget(by delta: Int) {
        let value = min(UserPreferences.maximumBudgetMinorUnits, max(UserPreferences.minimumBudgetMinorUnits, draft.weeklyBudget.minorUnits + delta))
        draft.weeklyBudget = Money(minorUnits: value, currencyCode: draft.market.currencyCode)
    }

    private var cookingTimeControl: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Most you’ll cook in a night").font(.title2.weight(.black))
                .accessibilityIdentifier("preference-editor-cookingTime")
            Text("Total active time, start to plate.").font(.body).foregroundStyle(WeeknightTheme.secondaryText)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: dynamicTypeSize.isAccessibilitySize ? 2 : 4), spacing: 8) {
                ForEach([15, 30, 45, 60], id: \.self) { minutes in cookingTimeButton(minutes) }
            }
            Text("Selected: \(draft.maximumCookingMinutes) minutes. Longer recipes are removed from autofill and flagged in Explore.")
                .font(.subheadline).foregroundStyle(WeeknightTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
        }.id(PreferenceEditorKind.cookingTime)
    }

    private func cookingTimeButton(_ minutes: Int) -> some View {
        let selected = draft.maximumCookingMinutes == minutes
        return Button { draft.maximumCookingMinutes = minutes } label: {
            VStack(spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle.dotted").font(.title2).foregroundStyle(selected ? PreferencesPalette.citron : WeeknightTheme.secondaryText)
                Text("\(minutes) min").font(.headline.weight(.black))
            }
            .frame(maxWidth: .infinity, minHeight: 96).foregroundStyle(selected ? PreferencesPalette.safetyText : WeeknightTheme.primaryText)
            .background(selected ? PreferencesPalette.forest : Color.white.opacity(0.34)).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(selected ? PreferencesPalette.forest : PreferencesPalette.warmLine, lineWidth: 1) }
        }
        .buttonStyle(.plain).accessibilityLabel("Maximum cooking time, \(minutes) minutes").accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier("cooking-time-\(minutes)")
    }

    private var tasteChapter: some View {
        VStack(alignment: .leading, spacing: 30) {
            chapterHeader(number: "02", title: "Your taste", message: "Soft preferences move recipes up and down the list. They never create a medical exclusion.", foreground: PreferencesPalette.paprikaText, muted: PreferencesPalette.paprikaText.opacity(0.72))
            mealStylesControl
            proteinsControl
            dislikesControl
        }
        .padding(.horizontal, WeeknightTheme.Spacing.gutter).padding(.vertical, 34).background(PreferencesPalette.paprika)
    }

    private var mealStylesControl: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Meal styles").font(.title2.weight(.black))
                .accessibilityIdentifier("preference-editor-mealStyles")
            Text("\(draft.preferredMealStyles.count) of \(MealStyle.allCases.count) picked").foregroundStyle(PreferencesPalette.paprikaText.opacity(0.72))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                ForEach(MealStyle.allCases) { style in mealStyleButton(style) }
            }
        }.foregroundStyle(PreferencesPalette.paprikaText).id(PreferenceEditorKind.mealStyles)
    }

    private func mealStyleButton(_ style: MealStyle) -> some View {
        let selected = draft.preferredMealStyles.contains(style)
        let count = eligibleRecipes(for: draft).filter { $0.mealStyles.contains(style) }.count
        return Button { toggle(style, in: &draft.preferredMealStyles) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: style.systemImage).font(.title2.weight(.bold)); Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title2)
                }
                Text(style.browseLabel).font(.headline.weight(.black)).fixedSize(horizontal: false, vertical: true)
                Text("\(count) eligible \(count == 1 ? "recipe" : "recipes")").font(.subheadline)
                    .foregroundStyle(selected ? Color.white.opacity(0.75) : PreferencesPalette.paprikaText.opacity(0.68))
            }
            .padding(15).frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .foregroundStyle(selected ? PreferencesPalette.safetyText : PreferencesPalette.paprikaText)
            .background(selected ? PreferencesPalette.forest : Color.white.opacity(0.72)).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(selected ? PreferencesPalette.forest : Color(hex: 0xE4CBB2), lineWidth: 1) }
        }
        .buttonStyle(.plain).accessibilityLabel(style.browseLabel)
        .accessibilityValue("\(selected ? "Selected" : "Not selected"), \(count) eligible \(count == 1 ? "recipe" : "recipes"), soft ranking preference")
        .accessibilityHint("Changes ranking only and never creates a medical exclusion.")
        .accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier("style-preference-\(style.rawValue)")
    }

    private var proteinsControl: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Proteins you enjoy").font(.title2.weight(.black))
                .accessibilityIdentifier("preference-editor-proteins")
            Text("We’ll lean recommendations toward these proteins. Nothing here is excluded.").foregroundStyle(PreferencesPalette.paprikaText.opacity(0.72)).fixedSize(horizontal: false, vertical: true)
            FlexiblePreferenceGrid(minimum: dynamicTypeSize.isAccessibilitySize ? 180 : 105) {
                ForEach(PreferredProtein.allCases) { protein in
                    preferenceChip(title: protein.rawValue, selected: draft.preferredProteins.contains(protein), identifier: "protein-\(protein.rawValue)") { toggle(protein, in: &draft.preferredProteins) }
                }
            }
        }.foregroundStyle(PreferencesPalette.paprikaText).id(PreferenceEditorKind.proteins)
    }

    private var dislikesControl: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ingredients you’d rather skip").font(.title2.weight(.black))
                .accessibilityIdentifier("preference-editor-dislikes")
            Text("Dislikes push a recipe down the list. They are not a safety exclusion—for that, use Medical allergens below.").foregroundStyle(PreferencesPalette.paprikaText.opacity(0.72)).fixedSize(horizontal: false, vertical: true)
            if dislikedIngredients.isEmpty { Text("No disliked ingredients").font(.subheadline.weight(.semibold)).foregroundStyle(PreferencesPalette.paprikaText.opacity(0.72)) }
            FlexiblePreferenceGrid(minimum: dynamicTypeSize.isAccessibilitySize ? 210 : 126) {
                ForEach(dislikedIngredients) { ingredient in
                    Button { draft.dislikedIngredientIDs.remove(ingredient.id) } label: {
                        HStack { Text(ingredient.displayName).font(.headline); Image(systemName: "xmark").font(.subheadline.weight(.bold)) }
                            .foregroundStyle(PreferencesPalette.paprikaText).padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.white.opacity(0.78)).clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay { RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color(hex: 0xE4CBB2), lineWidth: 1) }
                    }.buttonStyle(.plain).accessibilityLabel("Remove \(ingredient.displayName) from disliked ingredients")
                        .accessibilityHint("This changes ranking only.").accessibilityIdentifier("dislike-\(ingredient.id)")
                }
                if !availableIngredientsToDislike.isEmpty {
                    Button { isShowingIngredientPicker = true } label: {
                        Label("Add an ingredient", systemImage: "plus").font(.headline.weight(.bold)).foregroundStyle(PreferencesPalette.paprikaText.opacity(0.72))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .overlay { RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color(hex: 0xC9A98B), style: StrokeStyle(lineWidth: 1, dash: [5, 3])) }
                    }.buttonStyle(.plain).accessibilityHint("Choose a known catalogue ingredient. It will affect ranking after saving.").accessibilityIdentifier("add-disliked-ingredient")
                }
            }
        }.foregroundStyle(PreferencesPalette.paprikaText).id(PreferenceEditorKind.dislikes)
    }

    private var rulesChapter: some View {
        VStack(alignment: .leading, spacing: 30) {
            chapterHeader(number: "03", title: "Rules we never break", message: "Recipes that conflict with these selections are removed before recommendations are created.", foreground: PreferencesPalette.safetyText, muted: PreferencesPalette.safetyMuted)
            dietaryControl
            allergensControl
            Text("Saving a safety change re-checks every dinner already in this week’s plan. Weeknight never silently replaces a meal.").font(.subheadline).foregroundStyle(PreferencesPalette.safetyMuted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, WeeknightTheme.Spacing.gutter).padding(.vertical, 34).background(PreferencesPalette.forestDark)
    }

    private var dietaryControl: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Dietary restrictions").font(.title2.weight(.black)).foregroundStyle(PreferencesPalette.safetyText)
                .accessibilityIdentifier("preference-editor-dietary")
            Text("How you eat. Applies to everyone in the household.").foregroundStyle(PreferencesPalette.safetyMuted)
            VStack(spacing: 0) {
                ForEach(Array(DietaryRestriction.allCases.enumerated()), id: \.element.id) { index, restriction in
                    dietaryButton(restriction)
                    if index < DietaryRestriction.allCases.count - 1 { Divider().overlay(Color.white.opacity(0.12)) }
                }
            }.background(PreferencesPalette.forestPanel).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }.id(PreferenceEditorKind.dietary)
    }

    private func dietaryButton(_ restriction: DietaryRestriction) -> some View {
        let selected = draft.dietaryRestrictions.contains(restriction)
        return Button { toggle(restriction, in: &draft.dietaryRestrictions) } label: {
            HStack(alignment: .center, spacing: 13) {
                Image(systemName: selected ? "checkmark.square.fill" : "square").font(.title2).foregroundStyle(selected ? PreferencesPalette.citron : PreferencesPalette.safetyMuted)
                VStack(alignment: .leading, spacing: 4) {
                    Text(restriction.rawValue).font(.headline.weight(.bold))
                    Text(dietaryDescription(restriction)).font(.subheadline).foregroundStyle(PreferencesPalette.safetyMuted).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text(selected ? "ON" : "OFF").font(.caption.weight(.black)).tracking(1).foregroundStyle(selected ? PreferencesPalette.citron : PreferencesPalette.safetyMuted)
            }.foregroundStyle(PreferencesPalette.safetyText).padding(14).frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        }
        .buttonStyle(.plain).accessibilityLabel(restriction.rawValue).accessibilityValue(selected ? "On, selected dietary exclusion" : "Off")
        .accessibilityHint(dietaryDescription(restriction)).accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier("dietary-\(restriction.rawValue)")
    }

    private func dietaryDescription(_ restriction: DietaryRestriction) -> String {
        switch restriction {
        case .vegetarian: "No meat, poultry, or fish."
        case .vegan: "No animal products."
        case .pescatarian: "No meat or poultry; fish and seafood are allowed."
        case .glutenFree: "Only recipes declared gluten-free."
        }
    }

    private var allergensControl: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Medical allergens").font(.title2.weight(.black)); Text("SAFETY EXCLUSION").font(.caption.weight(.black)).tracking(1.6)
                }
            } icon: { Image(systemName: "exclamationmark.triangle.fill").font(.title2) }
            .foregroundStyle(PreferencesPalette.amber)
            .accessibilityIdentifier("allergen-safety-note")
            Text("Weeknight removes every recipe declaring one of these allergens. Always verify labels and cross-contact yourself.").foregroundStyle(PreferencesPalette.safetyText).fixedSize(horizontal: false, vertical: true)
            FlexiblePreferenceGrid(minimum: dynamicTypeSize.isAccessibilitySize ? 180 : 104) { ForEach(MedicalAllergen.allCases) { allergen in allergenButton(allergen) } }
            Divider().overlay(PreferencesPalette.amber.opacity(0.42))
            Button { draft.medicalAllergens.removeAll() } label: {
                HStack(spacing: 12) {
                    Image(systemName: draft.medicalAllergens.isEmpty ? "checkmark.square.fill" : "square").font(.title2)
                    Text("No allergens in this household").font(.headline.weight(.bold)).fixedSize(horizontal: false, vertical: true); Spacer()
                }.foregroundStyle(draft.medicalAllergens.isEmpty ? PreferencesPalette.amber : PreferencesPalette.safetyText).frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            }
            .buttonStyle(.plain).accessibilityLabel("No allergens in this household").accessibilityValue(draft.medicalAllergens.isEmpty ? "Selected" : "Not selected")
            .accessibilityHint("Selecting this clears every medical allergen.").accessibilityAddTraits(draft.medicalAllergens.isEmpty ? .isSelected : []).accessibilityIdentifier("allergen-none")
            Text(draft.medicalAllergens.isEmpty ? "No medical allergens are selected." : "Choosing no allergens clears the \(draft.medicalAllergens.count) selected \(draft.medicalAllergens.count == 1 ? "allergen" : "allergens").")
                .font(.footnote).foregroundStyle(PreferencesPalette.amber.opacity(0.84))
        }
        .padding(16).background(PreferencesPalette.amberDark).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(PreferencesPalette.amber, lineWidth: 1.5) }
        .id(PreferenceEditorKind.allergens)
    }

    private func allergenButton(_ allergen: MedicalAllergen) -> some View {
        let selected = draft.medicalAllergens.contains(allergen)
        return Button { toggle(allergen, in: &draft.medicalAllergens) } label: {
            HStack(spacing: 8) { Image(systemName: selected ? "nosign" : "circle"); Text(allergen.rawValue).font(.headline.weight(.bold)) }
                .foregroundStyle(selected ? PreferencesPalette.forestDark : PreferencesPalette.safetyText).frame(maxWidth: .infinity, minHeight: 52).padding(.horizontal, 8)
                .background(selected ? PreferencesPalette.amber : Color.clear).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(PreferencesPalette.amber.opacity(selected ? 1 : 0.52), lineWidth: 1) }
        }
        .buttonStyle(.plain).accessibilityLabel(allergen.rawValue).accessibilityValue(selected ? "Selected medical allergen, recipes are excluded" : "Not selected")
        .accessibilityHint("Changes remain a draft until reviewed and saved.").accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier("allergen-\(allergen.rawValue)")
    }

    private var kitchenChapter: some View {
        VStack(alignment: .leading, spacing: 26) {
            chapterHeader(number: "04", title: "Your kitchen", message: "Recipes that need equipment you don’t have are removed from recommendations and autofill.", foreground: WeeknightTheme.primaryText, muted: WeeknightTheme.secondaryText)
                .accessibilityIdentifier("preference-editor-appliances")
            kitchenApplianceGrid
            Text(kitchenEligibilitySummary).font(.body).foregroundStyle(WeeknightTheme.secondaryText).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("kitchen-eligibility-summary")
            if !isDirty {
                Label("All changes saved", systemImage: "checkmark.circle").font(.subheadline).foregroundStyle(WeeknightTheme.secondaryText).frame(minHeight: 44).accessibilityIdentifier("preferences-saved-state")
            }
            Text("Prices are deterministic local estimates, not live checkout quotes. Always verify ingredient labels and allergen information before cooking.")
                .font(.footnote).foregroundStyle(WeeknightTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, WeeknightTheme.Spacing.gutter).padding(.vertical, 34).padding(.bottom, 44).background(PreferencesPalette.cream)
        .id(PreferenceEditorKind.appliances)
    }

    @ViewBuilder private var kitchenApplianceGrid: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                ForEach(KitchenAppliance.allCases) { appliance in applianceButton(appliance) }
            }
        } else {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    applianceButton(.stovetop)
                    applianceButton(.oven)
                }
                HStack(spacing: 10) {
                    applianceButton(.microwave)
                    applianceButton(.airFryer)
                }
                applianceButton(.blender)
            }
        }
    }

    private func applianceButton(_ appliance: KitchenAppliance) -> some View {
        let selected = draft.availableAppliances.contains(appliance)
        return Button { toggle(appliance, in: &draft.availableAppliances) } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Image(systemName: preferenceApplianceIcon(appliance)).font(.title.weight(.bold))
                        .foregroundStyle(selected ? PreferencesPalette.citron : WeeknightTheme.secondaryText)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title2)
                        .foregroundStyle(selected ? PreferencesPalette.citron : WeeknightTheme.secondaryText)
                }
                Text(appliance.rawValue).font(.title3.weight(.black))
                Text(selected ? "Have it" : "Don’t have it").font(.subheadline.weight(.bold)).foregroundStyle(selected ? PreferencesPalette.citron : WeeknightTheme.secondaryText)
            }
            .foregroundStyle(selected ? PreferencesPalette.safetyText : WeeknightTheme.secondaryText).padding(15).frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
            .background(selected ? PreferencesPalette.forest : Color.white.opacity(0.36)).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(selected ? PreferencesPalette.forest : PreferencesPalette.warmLine, lineWidth: 1) }
        }
        .buttonStyle(.plain).accessibilityLabel(appliance.rawValue).accessibilityValue(selected ? "Have it, selected" : "Don’t have it, not selected")
        .accessibilityHint("Recipes requiring unavailable equipment are excluded after saving.").accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier("appliance-\(appliance.id)")
    }

    private func preferenceApplianceIcon(_ appliance: KitchenAppliance) -> String {
        switch appliance {
        case .stovetop: "flame"
        case .oven: "oven"
        case .microwave: "microwave"
        case .airFryer: "fan"
        case .blender: "drop.fill"
        }
    }

    private var kitchenEligibilitySummary: String {
        let count = eligibleRecipes(for: draft).count
        let total = store.recipesForCalculations.count
        return "\(count) of \(total) catalogue \(total == 1 ? "meal" : "meals") fit your draft dietary, allergen, and kitchen rules."
    }

    @ViewBuilder private var stickyState: some View {
        if isDirty {
            PreferenceUnsavedBar(changeCount: changeCount, preview: preview, changeTitle: PreferencePresentation.safetyChangeTitle(from: committed, to: draft), isSaving: isCommitting, errorMessage: saveError, useVerticalActions: dynamicTypeSize.isAccessibilitySize, onDiscard: discardDraft, onSave: saveTapped)
                .transition(reduceMotion ? .identity : .move(edge: .bottom).combined(with: .opacity))
        } else if let saveConfirmation {
            PreferenceSavedBar(message: saveConfirmation).accessibilityFocused($confirmationFocused)
                .transition(reduceMotion ? .identity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func saveTapped() {
        saveError = nil
        let update = preview
        if update.requiresConfirmation {
            reconciliationPreview = update
            UIAccessibility.post(notification: .screenChanged, argument: "Review preference changes")
        } else { commit(update) }
    }

    private func commit(_ update: PreferenceUpdatePreview) {
        guard !isCommitting else { return }
        isCommitting = true
        Task {
            do {
                let message = confirmationMessage(for: update)
                try await store.commitPreferences(update.draft)
                committed = store.preferences
                draft = store.preferences
                store.confirmationMessage = nil
                saveConfirmation = message
                confirmationFocused = true
                UIAccessibility.post(notification: .announcement, argument: "Preferences saved. \(message)")
            } catch {
                saveError = error.localizedDescription
                UIAccessibility.post(notification: .announcement, argument: "Preferences could not be saved")
            }
            isCommitting = false
        }
    }

    private func confirmationMessage(for preview: PreferenceUpdatePreview) -> String {
        if !preview.conflicts.isEmpty { return "\(preview.conflicts.count) planned \(preview.conflicts.count == 1 ? "dinner now needs" : "dinners now need") review. Nothing was silently replaced." }
        if preview.projectedPlan != store.plan || preview.shoppingChangeCount > 0 { return "This week’s plan and shopping list were updated together." }
        return "No planned dinners needed to change."
    }

    private func discardDraft() {
        draft = committed; saveError = nil
        UIAccessibility.post(notification: .announcement, argument: "Unsaved preference changes discarded")
    }

    private func eligibleRecipes(for preferences: UserPreferences) -> [Recipe] {
        MealsBrowsing.eligibleRecipes(from: store.recipesForCalculations, preferences: preferences)
    }

    private var allCatalogueIngredients: [Ingredient] {
        Dictionary(store.recipesForCalculations.flatMap(\.ingredients).map { ($0.ingredient.id, $0.ingredient) }, uniquingKeysWith: { first, _ in first })
            .values.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
    private var dislikedIngredients: [Ingredient] { allCatalogueIngredients.filter { draft.dislikedIngredientIDs.contains($0.id) } }
    private var availableIngredientsToDislike: [Ingredient] { allCatalogueIngredients.filter { !draft.dislikedIngredientIDs.contains($0.id) } }

    private func preferenceChip(title: String, selected: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) { Image(systemName: selected ? "checkmark" : "circle").font(.subheadline.weight(.black)); Text(title).font(.headline.weight(.bold)) }
                .foregroundStyle(selected ? PreferencesPalette.safetyText : PreferencesPalette.paprikaText).padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 50)
                .background(selected ? PreferencesPalette.forest : Color.white.opacity(0.78)).clipShape(Capsule())
                .overlay { Capsule().stroke(selected ? PreferencesPalette.forest : Color(hex: 0xE4CBB2), lineWidth: 1) }
        }
        .buttonStyle(.plain).accessibilityValue(selected ? "Selected soft preference" : "Not selected")
        .accessibilityHint("Influences ranking and does not exclude recipes.").accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier(identifier)
    }

    private func roundAdjustmentButton(symbol: String, label: String, disabled: Bool, identifier: String, filled: Bool = false, onDark: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.title2.weight(.bold)).frame(width: 52, height: 52)
                .foregroundStyle(onDark ? PreferencesPalette.safetyText : (filled ? PreferencesPalette.safetyText : PreferencesPalette.forest))
                .background(onDark ? Color.white.opacity(0.14) : (filled ? PreferencesPalette.forest : Color.clear)).clipShape(Circle())
                .overlay { Circle().stroke(onDark ? Color.white.opacity(0.1) : PreferencesPalette.forest, lineWidth: filled ? 0 : 1) }
        }
        .buttonStyle(.plain).disabled(disabled).opacity(disabled ? 0.42 : 1).accessibilityLabel(label)
        .accessibilityValue(disabled ? "Disabled" : "Enabled").accessibilityIdentifier(identifier)
    }

    private func toggle<Value: Hashable>(_ value: Value, in set: inout Set<Value>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}

private struct PreferenceSelectorCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let eyebrow: String
    let value: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow.uppercased()).font(.caption.weight(.bold)).tracking(1.6).foregroundStyle(WeeknightTheme.secondaryText)
            HStack(alignment: .firstTextBaseline) {
                Text(value)
                    .font(.headline.weight(.black))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.8)
                Spacer(minLength: 5)
                Image(systemName: "chevron.down").font(.subheadline.weight(.bold)).foregroundStyle(WeeknightTheme.secondaryText)
            }
            Text(detail).font(.footnote).foregroundStyle(WeeknightTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(WeeknightTheme.primaryText).padding(15).frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(Color.white.opacity(0.35)).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(PreferencesPalette.warmLine, lineWidth: 1) }
    }
}

private struct FlexiblePreferenceGrid<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let minimum: CGFloat
    @ViewBuilder let content: Content
    init(minimum: CGFloat, @ViewBuilder content: () -> Content) { self.minimum = minimum; self.content = content() }
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? max(minimum, 190) : minimum), spacing: 8)], alignment: .leading, spacing: 8) { content }
    }
}

private struct PreferenceUnsavedBar: View {
    let changeCount: Int
    let preview: PreferenceUpdatePreview
    let changeTitle: String?
    let isSaving: Bool
    let errorMessage: String?
    let useVerticalActions: Bool
    let onDiscard: () -> Void
    let onSave: () -> Void
    private var needsReview: Bool { preview.requiresConfirmation }
    private var warning: Bool { !preview.conflicts.isEmpty || !preview.removedFilledSlots.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: warning ? "exclamationmark.triangle.fill" : "circle.fill").font(warning ? .title3 : .caption)
                    .foregroundStyle(warning ? Color(hex: 0xB56C0B) : Color(hex: 0xC4770B)).padding(.top, 4)
                VStack(alignment: .leading, spacing: 5) {
                    Text(changeTitle ?? "\(changeCount) unsaved \(changeCount == 1 ? "change" : "changes")").font(.headline.weight(.black)).accessibilityIdentifier("preferences-unsaved-count")
                    Text(consequence).font(.subheadline).foregroundStyle(WeeknightTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
                    if let errorMessage { Text(errorMessage).font(.subheadline.weight(.semibold)).foregroundStyle(WeeknightTheme.tomato) }
                }
            }
            if useVerticalActions { VStack(spacing: 8) { discard; save } } else { HStack(spacing: 10) { discard; save } }
        }
        .padding(.horizontal, WeeknightTheme.Spacing.gutter).padding(.vertical, 14).background(PreferencesPalette.cream)
        .overlay(alignment: .top) { Rectangle().fill(warning ? Color(hex: 0xC77B0B) : PreferencesPalette.warmLine).frame(height: warning ? 3 : 1) }
        .accessibilityElement(children: .contain).accessibilityIdentifier("preferences-sticky-bar")
    }

    private var consequence: String {
        if !preview.conflicts.isEmpty { return "\(preview.conflicts.count) planned \(preview.conflicts.count == 1 ? "dinner conflicts" : "dinners conflict") with the draft. Saving keeps \(preview.conflicts.count == 1 ? "it" : "them") visible with warnings for review." }
        if !preview.removedFilledSlots.isEmpty { return "\(preview.removedFilledSlots.count) planned \(preview.removedFilledSlots.count == 1 ? "dinner is" : "dinners are") on a removed cooking day. Review before saving." }
        if preview.servingChangeCount > 0 { return "Saving updates \(preview.servingChangeCount) planned \(preview.servingChangeCount == 1 ? "dinner" : "dinners"), the budget, and shopping quantities together." }
        return "Saving re-checks this week’s plan and refreshes eligible meals."
    }

    private var discard: some View {
        Button("Discard", action: onDiscard).buttonStyle(SecondaryActionButtonStyle()).disabled(isSaving).accessibilityIdentifier("preference-discard")
    }
    private var save: some View {
        Button(action: onSave) { isSaving ? AnyView(HStack { ProgressView(); Text("Saving…") }) : AnyView(Text(needsReview ? "Review changes" : "Save Changes")) }
            .buttonStyle(PrimaryActionButtonStyle()).disabled(isSaving)
            .accessibilityLabel(needsReview ? "Review and save preference changes" : "Save preference changes").accessibilityIdentifier("preference-save")
    }
}

private struct PreferenceSavedBar: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(PreferencesPalette.citron)
            VStack(alignment: .leading, spacing: 4) {
                Text("Preferences saved").font(.headline.weight(.black))
                    .accessibilityIdentifier("preferences-saved-confirmation")
                Text(message).font(.subheadline).foregroundStyle(Color.white.opacity(0.78)).fixedSize(horizontal: false, vertical: true)
            }; Spacer()
        }
        .foregroundStyle(PreferencesPalette.safetyText).padding(.horizontal, WeeknightTheme.Spacing.gutter).padding(.vertical, 16).background(PreferencesPalette.forest)
        .accessibilityElement(children: .contain).accessibilityLabel("Preferences saved. \(message)").accessibilityIdentifier("preferences-saved-confirmation")
    }
}

private struct PreferenceReconciliationSheet: View {
    let preview: PreferenceUpdatePreview
    let changeTitle: String?
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: () -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label(changeTitle ?? "Check how your week changes", systemImage: "exclamationmark.triangle.fill").font(.title2.weight(.black))
                        .foregroundStyle(preview.conflicts.isEmpty ? PreferencesPalette.forest : Color(hex: 0x8C5200))
                        .accessibilityIdentifier("preference-reconciliation")
                    Text("Nothing has changed yet. Saving applies the preference and plan update atomically.").foregroundStyle(WeeknightTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
                    if !preview.conflicts.isEmpty {
                        reviewBlock(title: "\(preview.conflicts.count) affected \(preview.conflicts.count == 1 ? "dinner" : "dinners")", icon: "exclamationmark.shield.fill", lines: preview.conflicts.flatMap { conflict in ["\(conflict.day.rawValue): \(conflict.recipe.title)"] + conflict.reasons.map(\.message) }, warning: true)
                        Text("Saving keeps these dinners on the plan with visible warnings and Replace or Clear actions. Weeknight does not silently remove or replace them.").font(.subheadline.weight(.semibold)).foregroundStyle(Color(hex: 0x8C5200))
                    }
                    if !preview.removedFilledSlots.isEmpty {
                        reviewBlock(title: "Meals on removed days", icon: "calendar.badge.minus", lines: preview.removedFilledSlots.map { "\($0.day.rawValue): \($0.recipeTitle) will be removed with that day." }, warning: true)
                    }
                    if preview.servingChangeCount > 0 {
                        reviewBlock(title: "Portions", icon: "person.2.fill", lines: ["\(preview.servingChangeCount) planned \(preview.servingChangeCount == 1 ? "dinner changes" : "dinners change") to \(preview.draft.householdSize) servings."])
                    }
                    if !preview.addedDays.isEmpty || !preview.removedDays.isEmpty {
                        reviewBlock(title: "Cooking days", icon: "calendar", lines: preview.addedDays.map { "Add \($0.rawValue) as an open day." } + preview.removedDays.map { "Remove \($0.rawValue) from this week." })
                    }
                    reviewBlock(title: "Budget and shopping preview", icon: "cart.fill", lines: [
                        "Estimated week: \(preview.currentSpend.formatted()) → \(preview.projectedSpend.formatted())",
                        "Shopping items: \(preview.currentShoppingItemCount) → \(preview.projectedShoppingItemCount)",
                        "\(preview.shoppingChangeCount) shopping \(preview.shoppingChangeCount == 1 ? "item changes" : "items change") quantity or estimate."
                    ])
                    Text("Always verify ingredient labels and allergen information before cooking.").font(.footnote).foregroundStyle(WeeknightTheme.secondaryText)
                }.padding(WeeknightTheme.Spacing.gutter).padding(.bottom, 24)
            }
            .background(PreferencesPalette.cream)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    Button("Keep editing", action: onCancel).buttonStyle(SecondaryActionButtonStyle()).disabled(isSaving)
                    Button(action: onSave) { isSaving ? AnyView(HStack { ProgressView(); Text("Saving…") }) : AnyView(Text("Save preference changes")) }
                        .buttonStyle(PrimaryActionButtonStyle()).disabled(isSaving).accessibilityIdentifier("preference-reconciliation-save")
                }
                .padding(.horizontal, WeeknightTheme.Spacing.gutter).padding(.vertical, 10).background(PreferencesPalette.cream).overlay(alignment: .top) { Divider() }
            }
            .navigationTitle("Review changes").navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(isSaving).presentationDetents([.large]).accessibilityIdentifier("preference-reconciliation")
    }

    private func reviewBlock(title: String, icon: String, lines: [String], warning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.headline.weight(.black))
            ForEach(lines, id: \.self) { Text($0).font(.subheadline).fixedSize(horizontal: false, vertical: true) }
        }
        .foregroundStyle(warning ? Color(hex: 0x6E4200) : WeeknightTheme.primaryText).padding(15).frame(maxWidth: .infinity, alignment: .leading)
        .background(warning ? Color(hex: 0xFFF1D6) : WeeknightTheme.surfaceElevated.opacity(0.64)).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(warning ? Color(hex: 0xD68A18) : WeeknightTheme.hairline, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}

private struct IngredientPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let ingredients: [Ingredient]
    let onSelect: (Ingredient) -> Void
    @State private var query = ""

    private var results: [Ingredient] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return ingredients }
        return ingredients.filter { $0.displayName.localizedCaseInsensitiveContains(normalized) }
    }

    var body: some View {
        NavigationStack {
            List(results) { ingredient in
                Button(ingredient.displayName) {
                    onSelect(ingredient)
                    dismiss()
                }
                .foregroundStyle(WeeknightTheme.primaryText)
                .frame(minHeight: 44, alignment: .leading)
            }
            .scrollContentBackground(.hidden)
            .background(PreferencesPalette.cream)
            .searchable(text: $query, prompt: "Search catalogue ingredients")
            .accessibilityIdentifier("ingredient-picker-list")
            .navigationTitle("Add a disliked ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct ExactBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let money: Money
    let minimumMinorUnits: Int
    let maximumMinorUnits: Int
    let onApply: (Int) -> Void
    @State private var text: String
    init(money: Money, minimumMinorUnits: Int, maximumMinorUnits: Int, onApply: @escaping (Int) -> Void) {
        self.money = money; self.minimumMinorUnits = minimumMinorUnits; self.maximumMinorUnits = maximumMinorUnits; self.onApply = onApply
        let whole = money.minorUnits / 100
        let cents = abs(money.minorUnits % 100)
        _text = State(initialValue: String(format: "%d.%02d", whole, cents))
    }
    private var parsed: Int? { PreferencePresentation.parsedBudgetMinorUnits(text) }
    private var isValid: Bool { guard let parsed else { return false }; return (minimumMinorUnits...maximumMinorUnits).contains(parsed) }
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Enter one weekly amount. The main budget controls stay synchronized with it.").foregroundStyle(WeeknightTheme.secondaryText)
                TextField("Weekly budget", text: $text).keyboardType(.decimalPad).font(.largeTitle.weight(.black)).padding(16)
                    .background(WeeknightTheme.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityLabel("Exact weekly budget in dollars").accessibilityIdentifier("budget-exact-field")
                Text("Supported range: \(Money(minorUnits: minimumMinorUnits).formatted()) to \(Money(minorUnits: maximumMinorUnits).formatted()).")
                    .font(.subheadline).foregroundStyle(isValid ? WeeknightTheme.secondaryText : WeeknightTheme.tomato)
                Spacer()
                Button("Apply budget") { guard let parsed, isValid else { return }; onApply(parsed); dismiss() }
                    .buttonStyle(PrimaryActionButtonStyle()).disabled(!isValid).accessibilityIdentifier("budget-exact-apply")
            }
            .padding(WeeknightTheme.Spacing.gutter).background(PreferencesPalette.cream)
            .navigationTitle("Exact weekly budget").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }.presentationDetents([.medium])
    }
}
