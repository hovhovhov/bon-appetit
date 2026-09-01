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
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pick the night you want to cook it. Occupied days show exactly what will be replaced.")
                        .font(.body)
                        .foregroundStyle(WeeknightTheme.secondaryText)

                    recipeSummary

                    VStack(spacing: 9) {
                        ForEach(store.plan.slots) { slot in
                            dayRow(slot)
                        }
                    }

                    Button("Cancel") { dismiss() }
                        .font(.headline)
                        .foregroundStyle(WeeknightTheme.primaryText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(isCommitting)
                }
                .padding(WeeknightTheme.Spacing.gutter)
            }
            .background(WeeknightTheme.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider()
                    compactProjection
                        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                        .padding(.top, 10)
                    if case .failure(let message) = commitState {
                        errorBanner(message)
                            .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                            .padding(.top, 8)
                    }
                    confirmationButton
                        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                }
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Add to your week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .disabled(isCommitting)
                        .accessibilityLabel("Close Add to week")
                }
            }
        }
        .interactiveDismissDisabled(isCommitting)
        .accessibilityIdentifier("add-to-week-sheet")
    }

    private var recipeSummary: some View {
        HStack(spacing: 13) {
            RecipeArtwork(style: recipe.artwork, compact: true)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(WeeknightTheme.primaryText)
                Text("\(recipe.activeMinutes)m · serves \(servings) · \(store.estimatedCost(for: recipe, servings: servings).formatted())")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WeeknightTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .weeknightCard()
        .accessibilityElement(children: .combine)
    }

    private func dayRow(_ slot: MealSlot) -> some View {
        let selected = selectedDay == slot.day
        let existing = store.recipe(for: slot)
        return Button {
            guard !isCommitting else { return }
            selectedDay = slot.day
            if case .failure = commitState { commitState = .idle }
        } label: {
            HStack(spacing: 12) {
                Text(slot.day.shortName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(selected ? WeeknightTheme.forest : WeeknightTheme.primaryText)
                    .frame(width: 48, height: 48)
                    .background(selected ? WeeknightTheme.leaf : WeeknightTheme.sand)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(slot.day.rawValue)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(WeeknightTheme.primaryText)
                    Text(existing.map { "Replaces \($0.title)" } ?? "Free — nothing planned")
                        .font(.subheadline)
                        .foregroundStyle(existing == nil ? WeeknightTheme.bottle : Color(hex: 0x8A6104))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(WeeknightTheme.leaf)
                        .accessibilityHidden(true)
                }
            }
            .padding(12)
            .background(selected ? WeeknightTheme.wash : WeeknightTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous)
                    .stroke(selected ? WeeknightTheme.leaf : WeeknightTheme.forest.opacity(0.08), lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isCommitting)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(existing == nil ? "Selects this open day" : "Selects this day and replaces the current meal")
        .accessibilityIdentifier("day-\(slot.day.rawValue)")
    }

    private var compactProjection: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Week after this change")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WeeknightTheme.secondaryText)
                Spacer(minLength: 4)
                Text(preview.map { "\($0.projectedSpend.formatted()) of \(store.plan.budget.formatted())" } ?? "Choose a day")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(WeeknightTheme.primaryText)
                    .accessibilityIdentifier("assignment-preview-spend")
            }
            if let preview {
                HStack(spacing: 9) {
                    BudgetProgressBar(spent: preview.projectedSpend, budget: store.plan.budget, height: 7)
                        .background(WeeknightTheme.sand)
                        .clipShape(Capsule())
                    if preview.isOverBudget {
                        Text("\(Money(minorUnits: abs(preview.projectedRemaining.minorUnits)).formatted()) over")
                            .foregroundStyle(WeeknightTheme.tomato)
                    } else {
                        Text("\(preview.projectedRemaining.formatted()) remaining")
                            .foregroundStyle(WeeknightTheme.bottle)
                            .accessibilityIdentifier("assignment-preview-remaining")
                    }
                }
                .font(.caption.weight(.bold))
            } else {
                Text("Select a day to preview spend and remaining budget.")
                    .font(.caption)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Couldn’t update the plan", systemImage: "exclamationmark.triangle.fill")
                .font(.headline.weight(.bold))
            Text(message)
                .font(.subheadline)
        }
        .foregroundStyle(Color(hex: 0x8C2A17))
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xFCEAE4))
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }

    private var confirmationButton: some View {
        Button {
            commit()
        } label: {
            switch commitState {
            case .committing:
                HStack { ProgressView(); Text("Adding…") }
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
        .opacity(selectedDay == nil ? 0.45 : 1)
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
                UIAccessibility.post(notification: .announcement, argument: "\(recipe.title) added to \(selectedDay.rawValue)")
                try? await Task.sleep(nanoseconds: 350_000_000)
                store.selectedTab = .plan
                dismiss()
            } catch {
                commitState = .failure(error.localizedDescription)
                UIAccessibility.post(notification: .announcement, argument: "Couldn’t update the plan. Try again.")
            }
        }
    }
}
