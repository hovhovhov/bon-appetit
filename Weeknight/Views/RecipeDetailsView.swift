import SwiftUI
import UIKit

struct RecipeDetailsView: View {
    enum CommitState: Equatable {
        case idle
        case committing
        case success
        case failure(String)
    }

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let recipeID: Recipe.ID
    let origin: RecipeOrigin
    @State private var servingDraft: RecipeServingDraft
    @State private var noteDraft = ""
    @State private var committedNote = ""
    @State private var didLoadNote = false
    @State private var showsAddSheet = false
    @State private var showsSwapSheet = false
    @State private var commitState: CommitState = .idle

    init(recipeID: Recipe.ID, origin: RecipeOrigin, initialServings: Int) {
        self.recipeID = recipeID
        self.origin = origin
        _servingDraft = State(initialValue: RecipeServingDraft(committed: initialServings))
    }

    private var recipe: Recipe? { store.recipeLookup[recipeID] }
    private var scheduledSlot: MealSlot? { store.scheduledSlot(for: recipeID) }
    private var noteIsEdited: Bool { noteDraft != committedNote }
    private var isCommitting: Bool { commitState == .committing }

    var body: some View {
        Group {
            if let recipe {
                details(recipe)
            } else {
                ContentUnavailableView(
                    "Recipe unavailable",
                    systemImage: "fork.knife.circle",
                    description: Text("This recipe is no longer in the local catalogue.")
                )
            }
        }
        .background(WeeknightTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(WeeknightTheme.photoText)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.28))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Back to \(origin.rawValue)")
                .accessibilityIdentifier("recipe-details-back")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.toggleSaved(recipeID)
                } label: {
                    Image(systemName: store.isSaved(recipeID) ? "bookmark.fill" : "bookmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(WeeknightTheme.photoText)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.28))
                        .clipShape(Circle())
                }
                .accessibilityLabel(store.isSaved(recipeID) ? "Unsave recipe" : "Save recipe")
                .accessibilityValue(store.isSaved(recipeID) ? "Saved" : "Not saved")
                .accessibilityIdentifier("details-save-\(recipeID)")
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            guard !didLoadNote else { return }
            let stored = store.note(for: recipeID)
            noteDraft = stored
            committedNote = stored
            didLoadNote = true
        }
    }

    private func details(_ recipe: Recipe) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                hero(recipe)
                if !store.eligibility(for: recipe).isEligible {
                    eligibilityWarning(recipe)
                        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                }
                ingredients(recipe)
                method(recipe)
                notes
                attribution(recipe)
            }
            .padding(.bottom, scheduledSlot == nil ? 108 : 176)
        }
        .ignoresSafeArea(edges: .top)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar(recipe)
        }
        .sheet(isPresented: $showsAddSheet) {
            AddToWeekSheet(recipe: recipe, servings: servingDraft.value)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsSwapSheet) {
            if let scheduledSlot {
                SwapMealSheet(day: scheduledSlot.day) {
                    dismiss()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func eligibilityWarning(_ recipe: Recipe) -> some View {
        let result = store.eligibility(for: recipe)
        return VStack(alignment: .leading, spacing: 8) {
            Label(
                scheduledSlot == nil ? "Not eligible for your current setup" : "This planned meal conflicts with your setup",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.headline.weight(.bold))
            ForEach(result.hardReasons) { reason in
                Text(reason.message).font(.subheadline)
            }
            Text("Weeknight cannot describe this recipe as safe. Verify ingredient labels and allergen information yourself.")
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(Color(hex: 0x8C2A17))
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xFCEAE4))
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("details-eligibility-warning")
    }

    private func hero(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                RecipeArtwork(style: recipe.artwork)
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 220 : 292)
                NotchedDayTab(text: scheduledSlot.map { "PLANNED · \($0.day.shortName)" } ?? recipe.sourceName)
                    .padding(.leading, WeeknightTheme.Spacing.gutter)
                    .offset(y: 1)
            }
            .clipShape(.rect(bottomLeadingRadius: 30, bottomTrailingRadius: 30))

            VStack(alignment: .leading, spacing: 12) {
                Text(recipe.title)
                    .font(dynamicTypeSize.isAccessibilitySize ? .title.weight(.black) : .largeTitle.weight(.black))
                    .foregroundStyle(WeeknightTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(recipe.activeMinutes) min active · serves \(servingDraft.value) · \(store.estimatedCost(for: recipe, servings: servingDraft.value).formatted()) estimated")
                    .font(.headline)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                Text(recipe.rationale)
                    .font(.title3)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, WeeknightTheme.Spacing.gutter)
            .padding(.top, 16)
        }
        .accessibilityElement(children: .combine)
    }

    private func overview(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    metric("Time", value: "\(recipe.activeMinutes) min", icon: "clock")
                    metric("Servings", value: "\(servingDraft.value)", icon: "person.2")
                    metric("Estimated cost", value: store.estimatedCost(for: recipe, servings: servingDraft.value).formatted(), icon: "basket")
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    metric("Time", value: "\(recipe.activeMinutes) min", icon: "clock")
                    metric("Servings", value: "\(servingDraft.value)", icon: "person.2")
                    metric("Est. cost", value: store.estimatedCost(for: recipe, servings: servingDraft.value).formatted(), icon: "basket")
                }
            }
            FlowLayout(spacing: 7) {
                ForEach(recipe.tags, id: \.self) { TagChip(text: $0) }
            }
            Label(recipe.rationale, systemImage: "sparkles")
                .font(.body)
                .foregroundStyle(WeeknightTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
    }

    private func metric(_ label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label.uppercased(), systemImage: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(WeeknightTheme.secondaryText)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(WeeknightTheme.primaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WeeknightTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func servingEditor(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("Servings", detail: scheduledSlot == nil ? "Preview before adding" : "Draft until you update")
            HStack(spacing: 14) {
                Button {
                    servingDraft.decrement()
                    commitState = .idle
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(!servingDraft.canDecrement || isCommitting)
                .accessibilityLabel("Decrease servings")
                .accessibilityIdentifier("servings-decrease")

                Text("\(servingDraft.value)")
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(WeeknightTheme.primaryText)
                    .frame(minWidth: 52)
                    .accessibilityLabel("\(servingDraft.value) servings")
                    .accessibilityIdentifier("servings-value")

                Button {
                    servingDraft.increment()
                    commitState = .idle
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(!servingDraft.canIncrement || isCommitting)
                .accessibilityLabel("Increase servings")
                .accessibilityIdentifier("servings-increase")

                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(store.estimatedCost(for: recipe, servings: servingDraft.value).formatted())
                        .font(.title3.weight(.bold))
                        .foregroundStyle(WeeknightTheme.bottle)
                        .accessibilityIdentifier("servings-cost-preview")
                    Text("estimated")
                        .font(.caption)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                }
            }
            if servingDraft.isEdited {
                Label("Preview edited — not applied yet", systemImage: "pencil.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: 0x7A5604))
                    .accessibilityIdentifier("servings-edited-state")
            }
        }
        .padding(16)
        .weeknightCard()
        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
    }

    private func ingredients(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center) {
                    Text("Ingredients")
                        .font(.title2.weight(.black))
                    Spacer()
                    servingControls(recipe)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ingredients").font(.title2.weight(.black))
                    servingControls(recipe)
                }
            }
            ForEach(Array(recipe.ingredients.enumerated()), id: \.element.ingredient.id) { index, entry in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(entry.quantity(for: servingDraft.value, baseServings: recipe.servings))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(WeeknightTheme.bottle)
                        .frame(minWidth: 68, alignment: .leading)
                        .accessibilityIdentifier("ingredient-quantity-\(entry.ingredient.id)")
                    Text(entry.ingredient.displayName)
                        .font(.body)
                        .foregroundStyle(WeeknightTheme.primaryText)
                    Spacer(minLength: 8)
                    Text(entry.cost(for: servingDraft.value, baseServings: recipe.servings).formatted())
                        .font(.caption)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                }
                .accessibilityElement(children: .combine)
                if index < recipe.ingredients.count - 1 { Divider().overlay(WeeknightTheme.hairline) }
            }
            if servingDraft.isEdited {
                Label("Preview edited — not applied yet", systemImage: "pencil.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WeeknightTheme.citrus)
                    .accessibilityIdentifier("servings-edited-state")
            }
        }
        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
    }

    private func servingControls(_ recipe: Recipe) -> some View {
        HStack(spacing: 10) {
            Button {
                servingDraft.decrement()
                commitState = .idle
            } label: {
                Image(systemName: "minus").frame(width: 44, height: 44)
            }
            .foregroundStyle(WeeknightTheme.secondaryText)
            .background(WeeknightTheme.background)
            .clipShape(Circle())
            .overlay { Circle().stroke(WeeknightTheme.hairline, lineWidth: 1) }
            .disabled(!servingDraft.canDecrement || isCommitting)
            .accessibilityLabel("Decrease servings")
            .accessibilityIdentifier("servings-decrease")

            Text("\(servingDraft.value)")
                .font(.title3.weight(.black))
                .frame(minWidth: 34)
                .accessibilityLabel("\(servingDraft.value) servings")
                .accessibilityIdentifier("servings-value")

            Button {
                servingDraft.increment()
                commitState = .idle
            } label: {
                Image(systemName: "plus").frame(width: 44, height: 44)
            }
            .foregroundStyle(WeeknightTheme.background)
            .background(WeeknightTheme.forest)
            .clipShape(Circle())
            .disabled(!servingDraft.canIncrement || isCommitting)
            .accessibilityLabel("Increase servings")
            .accessibilityIdentifier("servings-increase")

            Text(store.estimatedCost(for: recipe, servings: servingDraft.value).formatted())
                .font(.caption)
                .foregroundStyle(WeeknightTheme.secondaryText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityIdentifier("servings-cost-preview")
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func method(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Cooking method", detail: "\(recipe.activeMinutes) minutes active")
            ForEach(Array(recipe.methodSteps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(WeeknightTheme.forest)
                        .frame(width: 32, height: 32)
                        .background(WeeknightTheme.mint)
                        .clipShape(Circle())
                    Text(step)
                        .font(.body)
                        .foregroundStyle(WeeknightTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Step \(index + 1). \(step)")
            }
        }
        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Your notes", detail: noteIsEdited ? "Edited, not saved" : "Saved locally")
            Button {
                store.saveNote(noteDraft, for: recipeID)
                committedNote = store.note(for: recipeID)
                noteDraft = committedNote
            } label: {
                Label(noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Clear note" : "Save note", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(ForestActionButtonStyle())
            .disabled(!noteIsEdited)
            .opacity(noteIsEdited ? 1 : 0.5)
            .accessibilityIdentifier("save-recipe-note")
            TextEditor(text: $noteDraft)
                .font(.body)
                .frame(minHeight: 110)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(WeeknightTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(noteIsEdited ? WeeknightTheme.leaf : WeeknightTheme.forest.opacity(0.16), lineWidth: 1.5)
                }
                .accessibilityLabel("Recipe note")
                .accessibilityHint(noteIsEdited ? "Edited, not saved" : "Saved locally")
                .accessibilityIdentifier("recipe-note-editor")
        }
        .padding(16)
        .weeknightCard()
        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
    }

    private func attribution(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Source & attribution", systemImage: "doc.text")
                .font(.headline.weight(.bold))
                .foregroundStyle(WeeknightTheme.primaryText)
            Text(recipe.sourceAttribution)
                .font(.footnote)
                .foregroundStyle(WeeknightTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(WeeknightTheme.primaryText)
                    Text(detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WeeknightTheme.secondaryText)
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(WeeknightTheme.primaryText)
                    Spacer(minLength: 8)
                    Text(detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WeeknightTheme.secondaryText)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private func actionBar(_ recipe: Recipe) -> some View {
        VStack(spacing: 9) {
            if case .failure(let message) = commitState {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: 0x8C2A17))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let scheduledSlot {
                if servingDraft.isEdited {
                    Button {
                        updateScheduledServings(day: scheduledSlot.day)
                    } label: {
                        if isCommitting {
                            HStack { ProgressView(); Text("Updating servings…") }
                        } else {
                            Label("Update servings to \(servingDraft.value)", systemImage: "checkmark")
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(isCommitting)
                    .accessibilityIdentifier("update-servings")
                }
                Button {
                    showsSwapSheet = true
                } label: {
                    Label("Swap \(scheduledSlot.day.rawValue)’s meal", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(ForestActionButtonStyle())
                .disabled(isCommitting)
                .accessibilityIdentifier("swap-meal")
                if !store.eligibility(for: recipe).isEligible {
                    Button(role: .destructive) {
                        clearScheduledMeal(day: scheduledSlot.day)
                    } label: {
                        Label("Clear \(scheduledSlot.day.rawValue)’s meal", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .disabled(isCommitting)
                    .accessibilityIdentifier("clear-conflicting-meal")
                }
            } else {
                Button {
                    showsAddSheet = true
                } label: {
                    Label("Add \(servingDraft.value) serving\(servingDraft.value == 1 ? "" : "s") to week", systemImage: "plus")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(isCommitting || !store.eligibility(for: recipe).isEligible)
                .opacity(store.eligibility(for: recipe).isEligible ? 1 : 0.45)
                .accessibilityIdentifier("details-add-to-week")
            }
        }
        .padding(.horizontal, WeeknightTheme.Spacing.gutter)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(WeeknightTheme.background)
        .overlay(alignment: .top) { Divider().overlay(WeeknightTheme.hairline) }
    }

    private func clearScheduledMeal(day: Weekday) {
        guard !isCommitting else { return }
        commitState = .committing
        Task {
            do {
                try await store.clearMeal(on: day)
                dismiss()
            } catch {
                commitState = .failure(error.localizedDescription)
            }
        }
    }

    private func updateScheduledServings(day: Weekday) {
        guard servingDraft.isEdited, !isCommitting else { return }
        commitState = .committing
        Task {
            do {
                try await store.updateServings(for: day, to: servingDraft.value)
                servingDraft = RecipeServingDraft(committed: servingDraft.value)
                commitState = .success
                UIAccessibility.post(notification: .announcement, argument: "Servings updated")
            } catch {
                commitState = .failure(error.localizedDescription)
                UIAccessibility.post(notification: .announcement, argument: "Servings could not be updated")
            }
        }
    }
}

struct SwapMealSheet: View {
    enum CommitState: Equatable {
        case idle
        case committing
        case failure(String)
    }

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let day: Weekday
    let onComplete: () -> Void
    @State private var selectedRecipeID: Recipe.ID?
    @State private var commitState: CommitState = .idle

    private var currentSlot: MealSlot? { store.plan.slots.first(where: { $0.day == day }) }
    private var currentRecipe: Recipe? { currentSlot.flatMap(store.recipe(for:)) }
    private var candidates: [Recipe] {
        store.eligibleRecipesForReplacement(on: day)
    }
    private var selectedRecipe: Recipe? { selectedRecipeID.flatMap { store.recipeLookup[$0] } }
    private var isCommitting: Bool { commitState == .committing }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose a replacement for \(day.rawValue). The same planning calculation will update budget and shopping together.")
                        .font(.body)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                    if let currentRecipe {
                        Label("Replacing \(currentRecipe.title)", systemImage: "calendar")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(WeeknightTheme.primaryText)
                    }
                    ForEach(candidates) { recipe in
                        candidateRow(recipe)
                    }
                    if case .failure(let message) = commitState {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color(hex: 0x8C2A17))
                    }
                }
                .padding(WeeknightTheme.Spacing.gutter)
            }
            .background(WeeknightTheme.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button {
                    commit()
                } label: {
                    if isCommitting {
                        HStack { ProgressView(); Text("Swapping…") }
                    } else {
                        Text(selectedRecipe.map { "Swap to \($0.title)" } ?? "Choose a replacement")
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(selectedRecipe == nil || isCommitting)
                .opacity(selectedRecipe == nil ? 0.5 : 1)
                .padding(WeeknightTheme.Spacing.gutter)
                .background(.ultraThinMaterial)
                .accessibilityIdentifier("swap-confirm")
            }
            .navigationTitle("Swap \(day.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .disabled(isCommitting)
                }
            }
        }
        .interactiveDismissDisabled(isCommitting)
        .accessibilityIdentifier("swap-meal-sheet")
    }

    private func candidateRow(_ recipe: Recipe) -> some View {
        let selected = selectedRecipeID == recipe.id
        let servings = currentSlot?.servings ?? recipe.servings
        return Button {
            selectedRecipeID = recipe.id
            commitState = .idle
        } label: {
            HStack(spacing: 12) {
                RecipeArtwork(style: recipe.artwork, compact: true)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(WeeknightTheme.primaryText)
                    Text("\(recipe.activeMinutes)m · serves \(servings) · \(store.estimatedCost(for: recipe, servings: servings).formatted())")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WeeknightTheme.secondaryText)
                }
                Spacer(minLength: 4)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? WeeknightTheme.leaf : WeeknightTheme.secondaryText)
            }
            .padding(12)
            .background(selected ? WeeknightTheme.wash : WeeknightTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isCommitting)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("swap-candidate-\(recipe.id)")
    }

    private func commit() {
        guard let selectedRecipe, !isCommitting else { return }
        commitState = .committing
        let servings = currentSlot?.servings ?? selectedRecipe.servings
        Task {
            do {
                try await store.assign(recipe: selectedRecipe, servings: servings, to: day)
                store.selectedTab = .plan
                dismiss()
                onComplete()
            } catch {
                commitState = .failure(error.localizedDescription)
            }
        }
    }
}
