# Weeknight

Weeknight is a native SwiftUI iPhone application. Milestone 2 completes the local recipe-selection loop: open Recipe details from Plan, Discover, or Saved; preview and commit serving changes; save recipes and notes; add or swap meals; and derive the updated budget and shopping list from the persisted weekly plan.

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
- Automated tests: 19 unit/store tests plus the Milestone 1 and Milestone 2 UI journeys
- Device range: iPhone SE (3rd generation), iPhone 14, iPhone 17, and iPhone 17 Pro Max
- Accessibility: native controls and focus behavior, semantic saved/selected/disabled/editing/committing states, Reduce Motion-aware discovery paging, and a recorded Accessibility Large Dynamic Type view
- Evidence: named Simulator screenshots in `artifacts/milestone-2/screenshots/`

## Local persistence

Milestone 2 uses SwiftData for one versioned local application-state record. Its JSON payload contains the active week plan (including committed servings), checked shopping ingredient IDs, saved recipe timestamps, and recipe notes. Budget, completion, and shopping totals are never persisted directly; they are recalculated from the restored plan and recipe catalogue.

On first launch, the canonical fixture is seeded once. Normal app relaunches preserve approved user state. An unsupported schema version falls back deterministically to the canonical fixture; `AppSnapshot.currentSchemaVersion` is the migration boundary for future milestones.

## Reset the canonical fixture

In the app, open **Preferences** and choose **Reset demo week**. This replaces the one persisted record with the canonical plan, shopping checks, three initial Saved recipes, and empty notes. Relaunching the app does not reset state.

Automated runs can pass `--reset-fixture`; repeated use resets the same record without duplication. Mock states are reachable with `--recipe-mode loading|error|empty`, `--shopping-mode loading|error|stale`, `--saved-mode loading|error|empty`, `--saved-no-results`, and `--assignment-fails-once`.

The canonical fixture starts with Monday through Wednesday planned, Thursday and Friday open, $35.40 of an $80.00 budget, and 3 of 25 shopping items checked.

## Project structure

- `Weeknight/` — SwiftUI application, domain model, fixture repositories, store, design system, and feature views
- `WeeknightTests/` — domain and store tests
- `WeeknightUITests/` — canonical device journey
- `docs/` — authoritative product and implementation documents
- `design-reference/` — preserved visual and exported interaction references; never linked into the app target
- `artifacts/milestone-2/screenshots/` — Simulator evidence from Milestone 2
