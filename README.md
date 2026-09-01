# Weeknight

Weeknight is a native SwiftUI iPhone application. Milestone 1 proves the complete local core loop: plan the week, discover a recipe, assign it to a day, derive the updated budget and shopping list, and check off shopping progress.

## Requirements

- Xcode 26.6 (build 17F113), or a compatible newer Xcode
- iOS 26.5 Simulator runtime for the recorded validation
- Minimum deployment target: iOS 17.0
- Primary validation device: iPhone 16 (390 × 844 points)

## Open and run in Xcode

1. Open `Weeknight.xcodeproj` in Xcode.
2. Select the **Weeknight** scheme.
3. Choose an iPhone Simulator, preferably **iPhone 16**.
4. Press **Run** (the triangular play button).

No account, network connection, third-party package, or backend is required.

## Command-line build

```sh
xcodebuild \
  -project Weeknight.xcodeproj \
  -scheme Weeknight \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  clean build
```

## Run tests

Run all unit and UI tests from Xcode with **Product → Test**, or use:

```sh
xcodebuild \
  -project Weeknight.xcodeproj \
  -scheme Weeknight \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

## Reset the canonical fixture

In the app, open **Preferences** and choose **Reset demo week**. Relaunching the app also resets Milestone 1 because its state is intentionally in memory only.

Automated runs can pass `--reset-fixture`. Mock states are reachable with `--recipe-mode loading|error|empty`, `--shopping-mode loading|error|stale`, and `--assignment-fails-once`.

The canonical fixture starts with Monday through Wednesday planned, Thursday and Friday open, $35.40 of an $80.00 budget, and 3 of 25 shopping items checked.

## Project structure

- `Weeknight/` — SwiftUI application, domain model, fixture repositories, store, design system, and feature views
- `WeeknightTests/` — domain and store tests
- `WeeknightUITests/` — canonical device journey
- `docs/` — authoritative product and implementation documents
- `design-reference/` — preserved visual and exported interaction references; never linked into the app target
- `artifacts/screenshots/` — Simulator evidence from the completed milestone

