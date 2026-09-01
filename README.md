# Weeknight

Weeknight is a native SwiftUI iPhone application. Milestone 3 adds committed household preferences, deterministic recipe eligibility and explainable ranking, explicit plan reconciliation, and local autofill while preserving the approved Plan, Discover, Recipe details, Saved, and Shopping journeys.

## Requirements

- Xcode 26.6 (build 17F113), or a compatible newer Xcode
- iOS 26.5 Simulator runtime for the recorded validation
- Minimum deployment target: iOS 17.0
- Primary validation device: iPhone 17
- Additional layout validation devices: iPhone SE (3rd generation), iPhone 14, and iPhone 17 Pro Max

## Open and run in Xcode

1. Open `Weeknight.xcodeproj` in Xcode.
2. Select the **Weeknight** scheme.
3. Choose the **iPhone 17** Simulator.
4. Press **Run** (the triangular play button).

No account, network connection, third-party package, or backend is required.

## Command-line build

```sh
xcodebuild \
  -project Weeknight.xcodeproj \
  -scheme Weeknight \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  clean build
```

## Run tests

Run all unit and UI tests from Xcode with **Product → Test**, or use:

```sh
xcodebuild \
  -project Weeknight.xcodeproj \
  -scheme Weeknight \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

## Recorded validation

The completed milestone was validated on September 1, 2026 with Xcode 26.6 and the iOS 26.5 Simulator runtime:

- Clean build: passed on iPhone 17
- Automated tests: 41 unit/store tests plus 15 Milestone 1–3 UI journeys
- Device range: iPhone SE (3rd generation), iPhone 14, iPhone 17, and iPhone 17 Pro Max
- Accessibility: native controls and focus behavior, 44-point touch targets, semantic selected/disabled/editing/committing states, VoiceOver announcements, Reduce Motion-aware discovery paging, and a recorded Accessibility Large Dynamic Type Preferences view
- Evidence: named Simulator screenshots in `artifacts/milestone-3/screenshots/`

## Local persistence

Weeknight uses SwiftData for one versioned local application-state record. Its schema-version-2 JSON payload contains the active week plan (including committed servings), checked shopping ingredient IDs, saved recipe timestamps, recipe notes, and committed `UserPreferences`. Budget, completion, recipe eligibility, Discover order, and shopping totals are never persisted directly; they are recalculated from the restored plan, preferences, and recipe catalogue.

On first launch, the canonical fixture is seeded once. Normal app relaunches preserve approved user state. Schema version 1 migrates to version 2 using the prior plan’s store, budget, cooking days, and servings; an unsupported schema version falls back deterministically to the canonical fixture. `AppSnapshot.currentSchemaVersion` remains the migration boundary for future milestones.

## Preferences, ranking, and autofill

Each Preferences editor works on a draft. **Cancel** or dismissing the sheet discards it; **Save** commits once. Changes that affect planned servings, cooking days, or hard eligibility show a named impact summary first, then update preferences, Plan, budget, and Shopping together.

Medical allergens, dietary restrictions, and unavailable required appliances are hard exclusions. Cooking time is a hard rule only for autofill; Discover may show slower eligible recipes with an explicit caution and lower rank. Dislikes, proteins, meal styles, budget fit, week variety, cooking-time fit, and Saved state affect deterministic ranking. The app never calls AI, a backend, or the network.

**Fill the rest for me** considers every valid combination for open configured days, excludes scheduled and hard-ineligible recipes, enforces the cooking-time limit, stays within the remaining weekly budget when it succeeds, and commits the whole plan once. If no combination works, it leaves the week unchanged and explains which settings to review.

Trader Joe’s, Aldi, and Safeway use separate deterministic USD mock quote multipliers. Canada/CAD and United Kingdom/GBP are shown as unavailable; the prototype does not perform fake currency conversion or claim live supermarket pricing.

## Reset the canonical fixture

In the app, open **Preferences** and choose **Reset demo week**. This replaces the one persisted record with the canonical preferences, plan, shopping checks, three initial Saved recipes, and empty notes. Relaunching the app does not reset state.

Automated runs can pass `--reset-fixture`; repeated use resets the same record without duplication. Mock states are reachable with `--recipe-mode loading|error|empty`, `--shopping-mode loading|error|stale`, `--saved-mode loading|error|empty`, `--saved-no-results`, and `--assignment-fails-once`. Milestone 3 UI validation also uses deterministic local launch states for personalized Discover, hard-rule no results, autofill failure, and opening a named Preferences editor.

The canonical fixture starts with one-person servings; Monday through Friday cooking days; Trader Joe’s USD estimates; an $80.00 budget; a 45-minute maximum; stovetop and oven available; Monday through Wednesday planned; Thursday and Friday open; $35.40 spent; and 3 of 25 shopping items checked. No dietary, allergen, dislike, protein, or meal-style preference is selected.

## Project structure

- `Weeknight/` — SwiftUI application, domain model, fixture repositories, store, design system, and feature views
- `WeeknightTests/` — domain and store tests
- `WeeknightUITests/` — canonical device journey
- `docs/` — authoritative product and implementation documents
- `design-reference/` — preserved visual and exported interaction references; never linked into the app target
- `artifacts/milestone-3/screenshots/` — Simulator evidence from Milestone 3
