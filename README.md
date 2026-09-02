# Weeknight

Weeknight is a native SwiftUI iPhone application. Milestone 4.6 reorganizes the existing planning product into four accessible primary tabs—Plans, Meals, Preferences, and Settings—without changing its deterministic planning, safety, persistence, or backend boundaries. Meals now contains For You and Saved; the earlier vertical Discover feed remains available only in Debug/test builds.

The app remains fully usable on device. AI never determines allergens, dietary safety, canonical prices, ingredient quantities, budget arithmetic, or shopping totals.

## Architecture

```text
iPhone SwiftUI UI
       |
       v
AppStore + deterministic domain + SwiftData
       |
       +---------------------> offline Milestone 3 engine
       |
       v
URLSession remote repository
       |
       v
loopback TypeScript/Fastify backend
       +--> Zod-validated development catalogue
       +--> deterministic stub/fallback
       \--> optional server-only Responses API adapter
```

See [backend/README.md](backend/README.md) for setup, contracts, privacy details, resilience, environment configuration, and the approval-gated live smoke procedure. The decision boundary is recorded in [ADR 0001](docs/adr/0001-local-backend-and-ai-boundary.md).

No public deployment, production database, production-cleared catalogue, external account creation, or paid service activation occurred in this milestone.

## Requirements

- Xcode 26.6 (build 17F113), or a compatible newer Xcode
- iOS 26.5 Simulator runtime for the recorded validation
- Minimum iOS deployment target: 17.0
- Primary validation device: 390 × 844 point iPhone 14
- Layout matrix: 375 × 667 point narrow iPhone, 390 × 844 point standard iPhone, and 440 × 956 point large iPhone
- Node.js 22 through 25 and npm for the local backend

## Run locally in stub mode

In Terminal, start the local backend:

```sh
cd /Users/hugo/Desktop/Weeknight/backend
npm install
npm start
```

Then:

1. Open `Weeknight.xcodeproj` in Xcode.
2. Select the **Weeknight** scheme.
3. Choose the **iPhone 17** Simulator.
4. Press **Run**.

Keep the backend Terminal window open. Stop it later with Control-C. No account, API key, internet connection, or AI charges are needed in stub mode. If the backend is stopped, Weeknight honestly switches to cached/local behavior and remains usable.

## Build and test

Backend:

```sh
cd /Users/hugo/Desktop/Weeknight/backend
npm run typecheck
npm test
npm run build
```

iPhone:

```sh
cd /Users/hugo/Desktop/Weeknight
xcodebuild \
  -project Weeknight.xcodeproj \
  -scheme Weeknight \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  clean test
```

All automated backend and iPhone tests use deterministic stubs or mock HTTP responses. They do not read a real key or spend AI tokens.

## Recorded Milestone 4 validation

Validation on September 1, 2026 passed the backend typecheck/build and 24 backend tests, a clean native build with 52 Swift tests and 18 UI journeys, and a Release Simulator build. The 15 existing Milestone 1–3 UI journeys passed unchanged. See [the validation record](docs/MILESTONE_4_VALIDATION.md) for scenarios, accessibility checks, and evidence.

## Recorded Milestone 4.6 validation

Validation on September 2, 2026 passed 78 iOS tests (52 unit and 26 UI), 24 backend tests, backend typecheck/build, the narrow/standard/large iPhone matrix, Accessibility Large text, Reduce Motion, Increase Contrast, the preserved Debug-only legacy feed, and a clean Release build. Seven final screen captures and the non-color semantics review are recorded in [the Milestone 4.6 validation record](docs/MILESTONE_4_6_VALIDATION.md).

## Safety and fallback boundary

The iPhone first computes the hard-eligible recipe-ID allow-list using medical-allergen, dietary, and appliance rules. The backend intersects those IDs with its validated catalogue before calling any provider. Provider results use strict schemas and undergo ID, uniqueness, required-day, and budget checks. The iPhone then repeats eligibility and plan validation before committing through the existing domain layer.

If the provider or backend is disabled, missing, slow, rate-limited, refused, malformed, unsafe, or over budget, Weeknight uses the deterministic Milestone 3 engine. Network responses cannot write derived totals directly.

## Existing preferences, ranking, and autofill

Preferences editors remain draft-and-commit. Medical allergens, dietary restrictions, and unavailable required appliances are hard exclusions. Cooking time remains a hard rule for autofill and an explained ranking caution in Meals. Dislikes, proteins, meal styles, budget fit, week variety, cooking-time fit, and Saved state remain deterministic ranking inputs.

The on-device **Fill the rest for me** engine still evaluates valid combinations for open cooking days, excludes scheduled or hard-ineligible recipes, enforces the time and budget limits, and commits the plan once. Trader Joe's, Aldi, and Safeway still use separate deterministic USD development estimates; unsupported CAD and GBP stores remain unavailable without fake conversion or live-pricing claims.

## Local persistence

Weeknight uses SwiftData for one versioned local application-state record. Its schema-version-2 payload contains the active week plan (including committed servings), checked shopping IDs, saved recipe timestamps, recipe notes, and committed preferences. Budget, completion, eligibility, Meals recommendation order, and shopping totals are recalculated from source state. The remote catalogue has a separate, schema-compatible cache in the app's Caches directory; it is never a replacement for SwiftData user state. Tab selection, Meals section selection, search, and legacy-presentation mode are presentation state and require no data migration.

## Reset the canonical fixture

In the app, open **Settings**, choose **Reset local data**, and confirm. This replaces the persisted record with the canonical preferences, plan, shopping checks, three initial Saved recipes, and empty notes. It can be used repeatedly; the reset upserts the same single record and does not duplicate data. Relaunching normally preserves state.

Automated runs can pass `--reset-fixture`; repeated use restores the same canonical record. Existing mock-state flags remain documented by their tests. Use `--backend-enabled` with a reset only for Milestone 4 backend validation; ordinary Milestone 1–3 reset journeys deliberately remain local and deterministic.

The canonical fixture starts with one-person servings; Monday through Friday cooking days; Trader Joe's USD estimates; an $80.00 budget; a 45-minute maximum; stovetop and oven available; Monday through Wednesday planned; Thursday and Friday open; $35.40 spent; and 3 of 25 shopping items checked.

## Project structure

- `Weeknight/` — native SwiftUI app, domain, SwiftData persistence, local and remote repositories, design system, and views
- `WeeknightTests/` — domain, store, persistence, and remote-repository tests
- `WeeknightUITests/` — Milestone 1–4.6 Simulator journeys and accessibility audits
- `backend/` — local TypeScript service, validated catalogue, provider adapters, and tests
- `docs/` — authoritative implementation/design documents and architecture decisions
- `design-reference/` — visual/exported references; never linked into the app target
- `artifacts/milestone-4/screenshots/` — final Milestone 4 Simulator evidence
- `artifacts/milestone-4-6/screenshots/` — final Milestone 4.6 primary-screen evidence

## Milestone 4 evidence

The final report records exact build/test counts and Simulator checks. Screenshots cover the backend catalogue, personalized explanations, generated week, safe invalid-output fallback, and backend-unavailable recovery in `artifacts/milestone-4/screenshots/`.
