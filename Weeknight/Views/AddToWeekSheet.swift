import SwiftUI
import UIKit

struct AddToWeekSheet: View {
    enum CommitState: Equatable {
        case idle
        case committing
        case success
        case failure(String)
    }

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let recipe: Recipe
    let servings: Int
    @State private var selectedDay: Weekday?
    @State private var commitState: CommitState = .idle

    init(recipe: Recipe, servings: Int? = nil, initialDay: Weekday? = nil) {
        self.recipe = recipe
        self.servings = servings ?? recipe.servings
        _selectedDay = State(initialValue: initialDay)
    }

    private var preview: AssignmentPreview? {
        selectedDay.map { store.preview(recipe: recipe, servings: servings, day: $0) }
    }

    private var isCommitting: Bool { commitState == .committing }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    photoHeader
                    VStack(alignment: .leading, spacing: 0) {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Which night?")
                                    .font(.largeTitle.weight(.black))
                                Spacer()
                                recipePrice
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Which night?").font(.largeTitle.weight(.black))
                                recipePrice
                            }
                        }
                        .padding(.bottom, 14)

                        ForEach(Array(store.plan.slots.enumerated()), id: \.element.id) { index, slot in
                            dayRow(slot)
                            if index < store.plan.slots.count - 1 {
                                Divider().overlay(WeeknightTheme.hairline)
                            }
                        }
                    }
                    .foregroundStyle(WeeknightTheme.primaryText)
                    .padding(WeeknightTheme.Spacing.gutter)
                    .padding(.bottom, 134)
                }
            }
            .scrollIndicators(.hidden)
            .background(WeeknightTheme.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 10) {
                    compactProjection
                    if case .failure(let message) = commitState {
                        errorBanner(message)
                    }
                    confirmationButton
                }
                .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(WeeknightTheme.background)
                .overlay(alignment: .top) { Divider().overlay(WeeknightTheme.hairline) }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationBackground(WeeknightTheme.background)
        .interactiveDismissDisabled(isCommitting)
        .accessibilityIdentifier("add-to-week-sheet")
    }

    private var photoHeader: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                RecipeArtwork(style: recipe.artwork)
                    .frame(height: 210)
                LinearGradient(colors: [.black.opacity(0.28), .clear, .black.opacity(0.62)], startPoint: .top, endPoint: .bottom)
                Text(recipe.title)
                    .font(.title.weight(.black))
                    .foregroundStyle(WeeknightTheme.photoText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(WeeknightTheme.Spacing.gutter)
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(WeeknightTheme.photoText)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            .disabled(isCommitting)
            .accessibilityLabel("Close Add to week")
            .padding(14)
        }
        .clipShape(.rect(bottomLeadingRadius: WeeknightTheme.Radius.sheet, bottomTrailingRadius: WeeknightTheme.Radius.sheet))
        .accessibilityElement(children: .contain)
    }

    private var recipePrice: some View {
        Text("\(store.estimatedCost(for: recipe, servings: servings).formatted()) · \(servings) serving\(servings == 1 ? "" : "s")")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(WeeknightTheme.secondaryText)
    }

    private func dayRow(_ slot: MealSlot) -> some View {
        let selected = selectedDay == slot.day
        let existing = store.recipe(for: slot)
        return Button {
            guard !isCommitting else { return }
            selectedDay = slot.day
            if case .failure = commitState { commitState = .idle }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 12) {
                Text(slot.day.shortName.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(selected ? WeeknightTheme.forest : WeeknightTheme.secondaryText)
                    .frame(width: 48, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(existing?.title ?? "Free")
                        .font(.headline.weight(existing == nil ? .bold : .regular))
                        .foregroundStyle(existing == nil ? WeeknightTheme.primaryText : WeeknightTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(existing == nil ? freeDayCopy(excluding: slot.day) : "Replaces this meal")
                        .font(.subheadline)
                        .foregroundStyle(existing == nil ? WeeknightTheme.secondaryText : WeeknightTheme.tomato)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                if existing != nil, !selected {
                    Text("swap")
                        .font(.subheadline)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                }
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? WeeknightTheme.forest : WeeknightTheme.secondaryText.opacity(0.35))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(minHeight: existing == nil ? 68 : 56)
            .background {
                RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous)
                    .fill(selected ? WeeknightTheme.wash : Color.clear)
                    .animation(reduceMotion ? nil : .easeOut(duration: WeeknightTheme.Motion.settle), value: selected)
            }
            .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isCommitting)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityHint(existing == nil ? "Selects this open day" : "Selects this day and replaces the current meal")
        .accessibilityIdentifier("day-\(slot.day.rawValue)")
    }

    private func freeDayCopy(excluding day: Weekday) -> String {
        if let other = store.plan.slots.first(where: { $0.day != day && $0.recipeID == nil })?.day {
            return "Leaves \((store.remainingBudget - store.estimatedCost(for: recipe, servings: servings)).formatted()) for \(other.rawValue)"
        }
        return "Completes your week"
    }

    private var compactProjection: some View {
        VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("After adding")
                    .font(.subheadline)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                Spacer()
                Text(preview.map { "\($0.projectedSpend.formatted()) of \(store.plan.budget.formatted())" } ?? "Choose a day")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(WeeknightTheme.primaryText)
                    .accessibilityIdentifier("assignment-preview-spend")
            }
            if let preview {
                BudgetProgressBar(spent: preview.projectedSpend, budget: store.plan.budget)
                Text(preview.isOverBudget
                    ? "\(Money(minorUnits: abs(preview.projectedRemaining.minorUnits)).formatted()) over budget"
                    : "\(preview.projectedRemaining.formatted()) remaining")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(preview.isOverBudget ? WeeknightTheme.tomato : WeeknightTheme.forest)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("assignment-preview-remaining")
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(WeeknightTheme.tomato)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var confirmationButton: some View {
        Button { commit() } label: {
            switch commitState {
            case .committing:
                HStack { ProgressView().tint(WeeknightTheme.background); Text("Adding…") }
            case .success:
                Label("Added", systemImage: "checkmark")
            case .failure:
                Text(selectedDay.map { "Try adding to \($0.rawValue) again" } ?? "Try again")
            case .idle:
                Text(selectedDay.map { day in
                    let occupied = store.plan.slots.first(where: { $0.day == day })?.recipeID != nil
                    return occupied ? "Replace \(day.rawValue)’s dinner" : "Add to \(day.rawValue)"
                } ?? "Choose a day")
            }
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .disabled(selectedDay == nil || isCommitting || commitState == .success)
        .opacity(selectedDay == nil ? 0.42 : 1)
        .accessibilityIdentifier("add-confirm")
        .accessibilityValue(isCommitting ? "Busy" : (selectedDay == nil ? "Disabled" : "Enabled"))
    }

    private func commit() {
        guard let selectedDay, !isCommitting else { return }
        commitState = .committing
        Task {
            do {
                try await store.assign(recipe: recipe, servings: servings, to: selectedDay)
                commitState = .success
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                UIAccessibility.post(notification: .announcement, argument: "\(recipe.title) added to \(selectedDay.rawValue)")
                if !reduceMotion { try? await Task.sleep(nanoseconds: 320_000_000) }
                store.selectedTab = .plan
                dismiss()
            } catch {
                commitState = .failure(error.localizedDescription)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                UIAccessibility.post(notification: .announcement, argument: "Couldn’t update the plan. Try again.")
            }
        }
    }
}
