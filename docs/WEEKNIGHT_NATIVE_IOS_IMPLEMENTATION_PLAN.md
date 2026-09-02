# Weeknight — Native iPhone Implementation Plan

Status: Milestones 1–4.6.1 implemented; Milestone 4.6.1 is the current Meals direction
Platform: iPhone only  
Implementation: native Swift and SwiftUI  
Prepared: 2026-08-31

## Current Milestone 4.6.1 Meals amendment

The approved September 2, 2026 Meals exploration refinement supersedes the Milestone 4.6 **For You** presentation wherever they conflict. Plans is approved and unchanged.

- Meals remains one primary tab with **Explore** and **Saved** sections.
- Explore leads with eligible-catalogue search, committed meal styles, and cuisine browsing. The seven canonical styles expand and collapse in place, and every style opens a real filtered result set.
- Cuisine cards and result screens use only validated optional catalogue cuisine metadata. Counts and lowest prices derive from the hard-eligible recipes; no title inference or screen-only mapping is allowed.
- Search covers existing title, cuisine, ingredients, tags, and styles after deterministic eligibility filtering.
- Cuisine/style results use deterministic price, time, or title ordering and reuse Recipe Details plus the existing add/replace planning flow.
- Saved retains timestamps, recent-first ordering, search, empty/no-results states, notes, Recipe Details, and existing add/replace semantics while presenting explicit text-backed Saved and planned states.
- The optional cuisine field is backward compatible with older cached catalogue records. Missing metadata removes only the affected cuisine browse entry and never weakens eligibility.
- Medical, dietary, appliance, budget, persistence, backend-validation, and deterministic-fallback boundaries remain unchanged.

Milestone 4.6.1 validation and screenshot evidence is recorded in `MILESTONE_4_6_1_VALIDATION.md` and `../artifacts/milestone-4-6-1/screenshots/`.

## Current Milestone 4.6 amendment

The approved September 2, 2026 information-architecture and accessibility refinement supersedes the earlier TikTok-first navigation and presentation direction wherever they conflict. The remainder of this document is retained as historical milestone rationale and as the source for unchanged domain, persistence, repository, and backend rules.

- The persistent native `TabView` destinations are **Plans**, **Meals**, **Preferences**, and **Settings**.
- Plans always shows the current week summary, shopping progress, and every configured cooking day. Its completed collage is secondary to the day list.
- Meals contains **For You** and **Saved** in this historical amendment. Milestone 4.6.1 renames and replaces that presentation with Explore and Saved browsing.
- The previous full-screen Discover feed is excluded from Release navigation and retained behind a Debug/test launch boundary.
- Preferences remains the only planning-settings destination and preserves draft, cancel, reconciliation, atomic commit, and safety behavior.
- Settings contains honest personalization, accessibility, privacy/data, reset, and about information. Backend diagnostics are Debug-only.
- Recipe Details and Shopping List are pushed destinations. Add, replace, and preference editing remain sheets with origin-aware dismissal.
- Navigation and presentation state is not persisted. `WeekPlan` remains the source of truth for cost, completion, and shopping derivation.
- Onboarding, authentication, accounts, family sharing, cloud sync, notifications, subscriptions, paywalls, analytics, deployment, production hosting, and new API capabilities remain out of scope.

Milestone 4.6 validation and screenshot evidence is recorded in `MILESTONE_4_6_VALIDATION.md` and `../artifacts/milestone-4-6/screenshots/`.

## 1. Purpose

Weeknight helps a person build a realistic weekly dinner plan, stay aware of an estimated grocery budget, discover appealing recipes, save meals, and automatically produce a consolidated shopping list.

The product combines four ideas:

1. A weekly plan is the home screen and the source of truth.
2. A full-screen, swipeable recipe feed makes discovery enjoyable.
3. Every recipe can be saved or assigned directly to a day.
4. The budget and shopping list update automatically when the week changes.

The first release is not intended to solve live grocery pricing, accounts, subscriptions, or every personalization problem. It must first prove that the core planning loop feels useful and coherent.

## 2. Document authority

Use the product rules, visual system, content, and interaction references in `WEEKNIGHT_DESIGN_HANDOFF.md`.

This document is authoritative for platform, architecture, implementation order, scope, and validation. Any React Native, Expo, TypeScript, Android, or web-runtime recommendation in older documents is superseded by this plan.

The Claude Project HTML is a visual and interaction reference only. Do not copy its runtime or treat its generated code as production application code.

## 3. Decisions already made

These decisions are approved and should not block scaffolding:

- Build a native iPhone app with Swift and SwiftUI.
- Target iPhone portrait layouts first.
- Use four primary tabs: Plan, Discover, Saved, and Preferences.
- Plan is the stored source of truth for the active week.
- Budget totals, completion counts, and generated shopping items are derived from the plan.
- The shopping list is generated automatically from scheduled recipes.
- Money is stored in integer cents with an explicit currency code.
- Milestone 1 uses clearly labeled mock consumed-quantity estimates, not live checkout prices.
- The canonical fixture and totals in the design handoff are approved.
- Medical allergens and dietary restrictions will later be hard eligibility rules; dislikes will be soft ranking signals.
- Milestone 1 uses safe placeholders or rights-cleared local media.
- Milestone 1 state survives navigation during the running session, but does not need to survive an app restart.
- Saved and Preferences may be polished preview shells in Milestone 1, but must not pretend unfinished actions work.
- Onboarding is included in the roadmap but excluded from Milestone 1.
- Authentication, production backend work, subscriptions, and paywall logic are excluded from Milestone 1.

## 4. Product navigation

### Primary tabs

1. **Plan** — the current week, estimated spend, remaining budget, planned meals, and shopping progress.
2. **Discover** — a vertically paged recipe feed with explicit Save, Add to week, Recipe, Not for me, and Share actions only when those actions are functional.
3. **Saved** — bookmarked meals, search, and the ability to assign a saved meal to the current week.
4. **Preferences** — store, household, cooking days, budget, time, dietary needs, tastes, and equipment.

### Pushed or presented destinations

- Shopping list
- Recipe details
- Add to week day-picker sheet
- Swap meal flow
- Preference editing sheets
- Onboarding, presented only on first run after its milestone is implemented

## 5. Native technical baseline

### Application

- Xcode project using the SwiftUI app lifecycle.
- SwiftUI for all production interfaces.
- Minimum deployment target: iOS 17 unless the installed toolchain requires an explicit adjustment. Record any change in the README before implementation continues.
- `TabView` for primary navigation.
- `NavigationStack` for pushed destinations.
- Native SwiftUI sheets and confirmations for modal flows.
- The Observation framework or an equivalent small native observable store for application state.
- Foundation types for dates, currency, localization, and measurement.

### Data and persistence

- Pure Swift domain models and calculations.
- Repository protocols separating mock data from future production data.
- Deterministic local fixtures for the first milestones.
- In-memory state for Milestone 1.
- SwiftData or another approved native persistence layer beginning in Milestone 2.
- No network dependency in Milestone 1.

### Validation

- Swift Testing or XCTest for domain logic.
- XCTest and XCUITest for application and user-flow validation.
- `xcodebuild` for reproducible clean builds and tests.
- iOS Simulator for interaction review and screenshots.
- XcodeBuildMCP may be used when available to operate the Simulator and capture evidence.

## 6. Architecture and product rules

### Core models

- `Recipe`
- `Ingredient`
- `Money`
- `MealSlot`
- `WeekPlan`
- `ShoppingListItem`
- `ShoppingProgress`
- `UserPreferences`
- `SavedRecipeRecord`

### Source-of-truth rules

- `WeekPlan` stores configured cooking days and the recipe assigned to each day.
- Weekly spend is derived by summing scheduled recipe estimates.
- Remaining budget is derived from budget minus weekly spend.
- Plan completion is derived from filled versus configured meal slots.
- Shopping items are derived by aggregating canonical ingredients from scheduled recipes.
- Checked shopping state is stored separately and reconciled by stable canonical ingredient identity.
- Screens never write budget totals, item counts, or plan-completion counts directly.

### Money rules

- Store amounts in integer minor units, such as 890 cents.
- Associate every amount with an ISO currency code.
- Do not use floating-point arithmetic for totals.
- Milestone estimates must be described as estimates and must not imply a live supermarket quote.

### Ingredient rules

- Canonical ingredient identity is separate from display wording.
- Compatible quantities may merge; incompatible units remain explicit until a conversion rule exists.
- Every generated item records which planned days or meals contributed to it.
- Removing or replacing a meal deterministically regenerates its shopping contribution.

### Eligibility rules for later milestones

- Medical allergens and approved dietary restrictions are hard exclusions.
- Required but unavailable equipment is a hard exclusion.
- Dislikes influence ranking but do not automatically exclude a recipe.
- Autofill must run eligibility checks before ranking or budget optimization.

## 7. Design-system implementation

Create semantic native tokens rather than copying inline values from the HTML reference:

- Colors: background, surface, elevated surface, primary text, secondary text, forest action, leaf accent, success, warning, danger, divider, overlay.
- Typography: display, title, section heading, body, supporting copy, label, caption, price, numeric emphasis.
- Spacing, corner radius, shadows, control heights, icon sizes, and motion durations.
- Reusable components: primary button, secondary button, icon button, card, recipe card, chip, progress bar, tab item, empty-day row, modal row, sheet, toast, skeleton, and error banner.

Use native system typography by default. Any custom font must be bundled locally and have recorded distribution rights.

Use accessible color pairings from the start. In particular, do not place white text on a bright leaf green unless the measured contrast passes. Prefer forest text on leaf green or white text on a sufficiently dark green.

Every interactive control must have at least a 44 × 44 point target. Support VoiceOver, Dynamic Type, Reduce Motion, increased contrast, and light appearance. A dark appearance can be deferred unless it is explicitly designed and tested.

## 8. Canonical Milestone 1 fixture

### Starting week

| Day | Meal | Estimated cost |
|---|---|---:|
| Monday | Honey Soy Chicken & Broccoli | $11.60 |
| Tuesday | Smoky Chilli Con Carne | $13.60 |
| Wednesday | Ginger Rice Noodle Stir-Fry | $10.20 |
| Thursday | Empty | — |
| Friday | Empty | — |

Starting derived state:

- 3 of 5 dinners planned
- $35.40 of an $80.00 weekly budget
- $44.60 remaining
- 25 unique shopping items
- 3 items checked

After adding Proper Carbonara to Thursday:

- Carbonara cost: $8.90
- 4 of 5 dinners planned
- $44.30 spent
- $35.70 remaining
- 31 unique shopping items
- 3 items checked

After adding Weeknight Chicken Curry to Friday:

- Curry cost: $12.40
- 5 of 5 dinners planned
- $56.70 spent
- $23.30 remaining
- 36 unique shopping items
- 3 items checked

After checking Broccoli in the complete-week shopping list:

- Overall progress becomes 4 of 36
- Produce progress becomes 2 of 11
- Returning to Plan shows the same 4 of 36 state

The detailed fixture in the design handoff is authoritative if additional recipe or ingredient fields are required.

## 9. Milestone 1 — Core product vertical slice

### Goal

Prove one complete loop:

`Plan → Discover → Add recipe to a day → Plan updates → Shopping list regenerates → Checked progress returns to Plan`

### 9.1 Project foundation

Build:

- Native Xcode project and app target.
- Test targets.
- Four-tab shell.
- Shared navigation structure.
- Semantic design tokens and reusable components.
- Deterministic fixture reset.
- Mock recipe repository.
- Safe placeholder image strategy.
- Short README with build, test, run, and fixture-reset instructions.

Acceptance:

- The project builds from a clean checkout.
- Plan and Discover are functional destinations.
- Shopping list can be pushed and dismissed correctly.
- Add-to-week can be presented as a native sheet and dismissed safely.
- Saved and Preferences are either polished preview shells or hidden until useful.
- No React Native, Expo, JavaScript runtime, web view, or Claude-generated runtime is used.

### 9.2 Domain model and calculations

Build:

- Typed models listed in Section 6.
- Pure functions for filled/open slots, weekly spend, remaining budget, budget status, assignment preview, add/replace, ingredient aggregation, and shopping progress.
- Deterministic repository modes for success, loading, empty, and failure states.

Acceptance:

- The exact fixture values in Section 8 are produced by tests.
- Replacing a meal subtracts the old meal before adding the new one.
- Shared canonical ingredients merge correctly.
- Each aggregated item lists every contributing day.
- Calculations are deterministic and do not drift.

### 9.3 Plan home

Build:

- Greeting and weekly state headline.
- Selected store and week range.
- Estimated budget card with spend, remaining amount, progress, and budget status.
- Shopping-list summary and navigation.
- Filled and empty daily meal cards.
- Clear text action from an empty day to Discover.
- Immediate updates when the shared plan changes.

Acceptance:

- Initial state shows exactly 3 of 5, $35.40 of $80.00, $44.60 left, and 3 of 25 items.
- Adding Carbonara displays it on Thursday without a reload and updates all dependent values together.
- Adding Curry displays it on Friday and changes the headline to indicate the week is ready to shop.
- Over-budget fixture data shows the exact overage and useful recovery copy.
- Long recipe names and 200% Dynamic Type do not hide the day, price, or main action.

### 9.4 Discover feed

Build:

- Vertically paged or snap-aligned full-screen recipe cards.
- Fixed plan-progress header.
- Recipe fit, title, time, servings, estimate, tags, rationale, and source.
- A clearly visible Add to week control.
- Other controls only if implemented end to end; otherwise omit or visibly mark them as unavailable in the internal build.
- Loading, error/retry, and no-results modes.
- Reduced-motion behavior without forced snapping or unnecessary animation.

Acceptance:

- Recipes already assigned to the week are excluded from the feed.
- Proper Carbonara appears with 20 minutes and $8.90.
- Feed progress remains unchanged until the add operation commits.
- The action area never covers essential recipe information.
- Add to week is usable with touch, VoiceOver, and Switch Control.

### 9.5 Add-to-week sheet

Build:

- Selected recipe summary.
- One selectable row for every configured cooking day.
- “Free — nothing planned” copy for open days.
- Replacement copy naming the existing meal for occupied days.
- Disabled confirmation until a day is selected.
- Live projected weekly spend and remaining budget or overage.
- Committing, success, retryable failure, and cancel states.
- Atomic commit followed by dismissal and navigation to Plan.

Acceptance:

- Selecting Thursday for Carbonara previews $44.30 of $80.00 and $35.70 remaining.
- The selected row exposes its selected state to assistive technology.
- Double activation cannot add twice.
- Failure retains the selection and provides retry and cancel.
- Replacement calculations are correct.
- A successful commit causes exactly one mutation and one confirmation.

### 9.6 Shopping list

Build:

- Native pushed screen grouped by aisle.
- Aggregated item, quantity, source meals/days, estimated amount, and checked state.
- Overall and aisle-level progress.
- Empty, loading, partial, stale/error, and complete visual states where applicable to the local repository contract.
- Checked state that survives navigation during the running session.

Acceptance:

- Initial list has 25 unique items, 3 checked, and a $35.40 meal estimate.
- Carbonara produces 31 unique items and includes Thursday as a source.
- Curry produces 36 unique items and includes Friday as a source.
- Checking Broccoli changes overall progress to 4 of 36 and Produce to 2 of 11.
- Returning to Plan shows 4 of 36.
- Reopening the list retains that checked state for the session.
- An empty plan says there is nothing to buy and links back to planning.

### 9.7 Milestone 1 automated journey

The following journey must pass without test-only state mutation:

1. Launch with the canonical current week.
2. Confirm Plan shows 3 of 5, $35.40/$80.00, and 3/25.
3. Open Discover and choose Proper Carbonara.
4. Select Thursday and confirm the $44.30/$80.00 preview with $35.70 remaining.
5. Commit and confirm Plan shows Carbonara, 4 of 5, $44.30, and 3/31.
6. Add Weeknight Chicken Curry to Friday.
7. Confirm Plan shows a complete week, $56.70, and 3/36.
8. Open Shopping list and check Broccoli.
9. Confirm progress is 4/36.
10. Return to Plan and confirm the same 4/36 state.

### Milestone 1 exit gate

- Clean build and all tests pass.
- The canonical journey works in the iOS Simulator.
- Simulator screenshots are captured for Plan, Discover, Add to week, and Shopping list.
- No critical or high-severity accessibility issue remains in the included path.
- No unlicensed design reference is required by the build.
- No onboarding, account, backend, subscription, or paywall code has been introduced.
- A reviewer can reset the fixture and repeat the journey without developer tools.

Stop after this gate for product and visual review before beginning Milestone 2.

## 10. Milestone 2 — Recipe details, Saved, and local persistence

### Goal

Complete the meal-selection surfaces and make the local product feel coherent across app launches.

Build:

- Recipe details from Plan, Discover, and Saved.
- Ingredient and method sections.
- Serving adjustment with clearly defined preview or commit semantics.
- Save and unsave behavior shared across every screen.
- Saved search and approved filters.
- Add-to-week and Swap actions reused from the Milestone 1 domain flow.
- Local persistence for the plan, checked shopping state, saved recipes, and recipe notes.
- Fixture reset and a small migration/version strategy.
- Content-source and attribution fields.

Acceptance:

- Back navigation returns to the correct origin and restores feed/list position.
- Saved state remains consistent across Discover, Recipe details, and Saved.
- Notes and saved state survive app restart.
- Serving changes update every approved dependent value consistently.
- Scheduled recipes show their assigned day and a Swap action.
- Empty and no-results states have useful next actions.
- Missing or unlicensed media uses a safe fallback.

## 11. Milestone 3 — Preferences and eligibility engine

### Goal

Create one real `UserPreferences` system that influences portions, eligibility, ranking, and the configured week. This system will later be populated by onboarding.

Build:

- Country and currency.
- Preferred supermarket.
- Household size and default servings.
- Cooking days.
- Weekly budget.
- Maximum cooking time.
- Dietary restrictions.
- Medical allergens.
- Disliked ingredients.
- Preferred proteins and meal styles.
- Available appliances.
- Draft-versus-saved preference editing.
- Hard eligibility before soft ranking.
- Explicit reconciliation when a saved preference conflicts with scheduled meals.
- Explainable ranking signals.
- Autofill only after the safety and budget rules are reliable.

Acceptance:

- A recipe containing a selected medical allergen cannot be recommended, scheduled by autofill, or used as a substitute.
- Approved dietary restrictions are enforced as hard rules.
- Dislikes affect ranking without being misrepresented as medical safety.
- Missing required appliances exclude recipes.
- Household and cooking-day changes update the plan through an explicit, understandable reconciliation.
- Cancel discards preference drafts; Save performs one atomic update.
- Existing meals that become ineligible are visibly flagged and never described as safe.
- Autofill never violates a hard rule and explains when it cannot satisfy all constraints.

## 12. Milestone 4 — Onboarding and first-week creation

### Recommendation

Onboarding should be designed now, named in the plan, and implemented here—not in Milestone 1. It depends on the `UserPreferences` and eligibility behavior from Milestone 3. Building it earlier would either create a duplicate temporary preference model or collect answers that do not yet affect the product.

### Goal

Help a new user reach a useful first weekly plan quickly, without forcing account creation or a paywall before value is visible.

### First-run flow

Keep it short, approximately six steps:

1. **Welcome and promise** — explain that Weeknight creates a realistic dinner week, budget estimate, and shopping list.
2. **Household and cooking days** — number of people and which nights need dinner.
3. **Budget and supermarket** — weekly target and preferred store, with honest estimate language.
4. **Diet and medical allergens** — explicit selections, an explicit “None,” and clear safety wording.
5. **Taste and practicality** — maximum cooking time, dislikes, preferred proteins/styles, and key appliances. Nonessential answers may be skipped.
6. **Review and create my week** — summarize choices, generate the first plan, and land on Plan.

### Rules

- Onboarding writes directly into the same `UserPreferences` model used by the Preferences tab.
- Do not create a second onboarding-only preferences model.
- Store a local `hasCompletedOnboarding` state for first-run routing.
- Preserve progress if onboarding is interrupted.
- Allow Back without losing valid answers.
- Do not ask for notification permission until after the user experiences a relevant feature.
- Do not require an account in the initial onboarding.
- Do not place the subscription paywall inside the first-run flow at this stage.
- Generate the first plan using the same eligibility, ranking, budget, and plan APIs used everywhere else.

### Acceptance

- A first-time launch enters onboarding; a completed user enters Plan.
- Completing onboarding creates one valid `UserPreferences` record and one valid initial week.
- The resulting plan respects configured cooking days and all hard eligibility rules.
- Editing the same values later in Preferences updates the same underlying data.
- An interrupted flow resumes safely.
- VoiceOver and 200% Dynamic Type preserve all questions and controls.
- Analytics, if later approved, must not capture medical allergen details as raw event properties.

## 13. Milestone 5 — Production recipes, pricing, stores, import, and resilience

### Goal

Replace mock content with trustworthy production data without changing the screens’ domain contracts.

Build only after data providers and rights are approved:

- Production recipe repository.
- Licensed media, recipe content, attribution, and provenance.
- Store and pricing repository contracts.
- Package size, price source, freshness, confidence, currency, and measurement conversion.
- Clear decision between package-purchase estimate and consumed-quantity estimate, potentially showing both.
- Offline, stale, partial-price, missing-price, retry, and cache behavior.
- Internationalized dates, money, quantities, and pluralization.
- Recipe import with source attribution and eligibility validation.

Acceptance:

- Changing store changes the underlying quote or clearly says that estimates are unavailable.
- Missing quotes never silently contribute zero.
- Every estimate communicates source and freshness where appropriate.
- Unit conversion preserves recipe meaning and ingredient aggregation.
- Imported recipes preserve source attribution and pass eligibility checks before scheduling.

## 14. Milestone 6 — Accounts, sync, commercial features, and paywall

Potential scope:

- Authentication and account recovery.
- Cross-device synchronization.
- Notifications.
- Privacy and data controls.
- Sharing and collaboration.
- Subscription, entitlement, restore-purchase, and paywall flows.
- Connected stores.
- Consent-aware analytics and experimentation.

### Paywall recommendation

Do not implement the paywall before the core loop, onboarding, and value proposition have been validated. When monetization is designed, place the paywall after a genuine value moment—such as after the first personalized week has been generated and shown—not before the user understands the product. The exact trigger, free allowance, trial, price, and entitlement behavior require a separate product decision and purchase-sandbox plan.

Acceptance for this milestone must include privacy review, account lifecycle behavior, offline/sync-conflict tests, purchase restoration, and explicit handling of local data during sign-in and sign-out.

## 15. Cross-milestone quality gates

### Functionality

- Domain calculations are tested independently from views.
- Screens use the same state and repositories used by real app flows.
- Loading, empty, error, selected, disabled, committing, success, and checked states are intentionally reachable.
- Back, cancel, retry, interruption, and double-activation behavior are covered.

### Accessibility

- Meaningful text and controls meet appropriate WCAG contrast targets.
- Touch targets are at least 44 × 44 points.
- VoiceOver labels communicate purpose and state without repeating the entire surrounding card.
- Dynamic Type at 200% does not hide essential content or actions.
- Reduce Motion preserves usability.
- Status never depends on color alone.

### Visual quality

- Review at 390 × 844 points plus one narrow and one large iPhone simulator.
- Validate safe areas, tab-bar overlap, sheets, long titles, and localized formats.
- Test recipe overlays against both bright and dark imagery.
- Compare milestone screenshots with the approved PNG references while preserving native behavior.

### Data and architecture

- Money uses integer cents and an ISO currency.
- Dates have explicit calendar and time-zone behavior.
- Canonical ingredient identity is separate from display copy.
- Derived totals have a single tested implementation.
- Mock, local, and remote data are isolated behind repository contracts.
- Persistent data changes have explicit schema versions or migrations.

### Assets and content

- Every shipped image and font has recorded rights.
- Recipe content carries appropriate source and attribution metadata.
- Historical competitor screenshots, Claude device frames, and generated HTML assets are not bundled into the production app.
- Production builds do not fetch fonts from a third-party CDN at runtime.

## 16. Immediate next action

Begin a fresh Codex task in the final Weeknight project folder and implement Milestone 1 only.

The task should:

1. Read this plan and the design handoff completely.
2. Inspect all provided PNG and HTML references.
3. Record the installed Xcode version, available iOS Simulator runtime, chosen deployment target, and project structure.
4. Scaffold the native SwiftUI application.
5. Implement and test the complete Milestone 1 vertical slice.
6. Run clean builds and tests.
7. Launch the app in iOS Simulator and capture the four required screenshots.
8. Report what was implemented, any intentional visual deviations, tests run, and remaining issues.
9. Stop for review before Milestone 2.
