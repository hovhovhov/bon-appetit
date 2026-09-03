# Milestone 4.6.2 validation — expressive Preferences redesign

Date: September 2, 2026  
Baseline: `ac22927`  
Scope: Preferences presentation, draft/save presentation, reconciliation presentation, focused tests, and documentation. Plans, Meals, Settings, persistence schema, backend contracts, eligibility rules, ranking, and plan/shopping calculations were not redesigned.

## Implemented design

- One continuous native SwiftUI Preferences surface with four chapters: Your week, Your taste, Rules we never break, and Your kitchen.
- Committed-only summary chips plus supported market/supermarket menus, a 1–8-person household control, seven explicit cooking-day controls, the domain's $40.00–$240.00 weekly-budget range in $10.00 steps, exact budget entry, and supported 15/30/45/60-minute choices.
- A forest budget module whose approximate per-dinner value comes from a pure integer-money domain helper and the draft's actual cooking-day count.
- Catalogue-counted meal-style cards, canonical preferred-protein chips, removable normalized disliked-ingredient tokens, and a real catalogue ingredient picker. The copy and accessibility hints identify all three as ranking preferences rather than exclusions.
- Text-backed dietary On/Off rows, an amber medical-allergen exclusion module, mutually exclusive No allergens behavior, and the existing deterministic reconciliation review for affected planned meals.
- Actual appliance cards with Have it/Don't have it text, check/circle state, and a catalogue eligibility summary derived from the same hard-filtering logic used elsewhere.
- A sticky changed-field count with Discard and Save/Review actions, atomic commit, error state, four-second success confirmation, and a quiet saved state. No fabricated timestamp or fake Undo is shown.

## Real-data adaptations

- The supported market is United States/USD; Canada/GBP-related options remain disabled as before and no location or nearby-store claim is made.
- The canonical seven meal styles are Speedy meals, Healthy comfort, Family favourites, Fakeaway, Meat-free, Protein packed, and Treat night. Counts reflect the current eligible catalogue, not the board's illustrative 64-recipe figure.
- Proteins are Chicken, Beef, Pork, Fish, and Vegetarian. Dietary rules are Vegetarian, Vegan, Pescatarian, and Gluten-free. Medical allergens are Milk, Egg, Fish, Wheat, Soy, and Sesame. Appliances are Stovetop, Oven, Microwave, Air fryer, and Blender.
- Halal, Peanuts, Shellfish, Tree nuts, Tofu, Lamb, Beans, Slow cooker, live availability, store logos, nearby-store counts, mock save times, and unsupported “Any” cooking time were not introduced.
- The app-wide native iOS 26 tab bar was preserved, so its system material and geometry differ from the static presentation frames.

## Automated validation

- Swift unit/store/domain suite: 59 passed, 0 failed.
- iPhone UI suite: 34 passed, 0 failed on iPhone 17 Simulator, iOS 26.5. This includes the canonical Milestone 1–3 journeys, Plans, Meals, Settings, backend states, persistence, accessibility audits, and three focused Milestone 4.6.2 journeys.
- Backend Vitest suite: 25 passed, 0 failed across 4 files.
- Backend TypeScript typecheck: passed.
- Backend production TypeScript build: passed.
- Native Release build for iPhone 17 Simulator: passed.
- Backend-dependent UI journeys used the deterministic local stub on port 8787 and the documented invalid-recommendation fixture on port 8790. No external service or live AI provider was used.

The build still reports the pre-existing Swift 6 captured-variable warnings in `Milestone4Tests.swift`; they are outside this presentation milestone and do not fail the current Swift language mode.

## Accessibility validation

- Selected, unselected, disabled, Have it/Don't have it, On/Off, allergen exclusion, changed-field, saving, and success states are exposed in text and accessibility values, not color alone.
- Increment/decrement controls meet the 44-point minimum and expose disabled states. Household and budget values support VoiceOver adjustment; actions have purpose-specific labels and hints.
- Accessibility Large reflows selectors and cards, expands rows vertically, stacks sticky actions, and preserves all essential text and controls.
- The implementation respects Reduce Motion for sticky-state transitions and uses native semantic colors and controls so Increase Contrast and Differentiate Without Color remain effective.
- Safety consequences are announced when review is required, and save confirmation receives accessibility focus and an announcement.

## Screenshot evidence

- `../artifacts/milestone-4-6-2/screenshots/preferences-your-week.png`
- `../artifacts/milestone-4-6-2/screenshots/preferences-budget-time-styles.png`
- `../artifacts/milestone-4-6-2/screenshots/preferences-proteins-dislikes.png`
- `../artifacts/milestone-4-6-2/screenshots/preferences-diet-allergens.png`
- `../artifacts/milestone-4-6-2/screenshots/preferences-kitchen.png`
- `../artifacts/milestone-4-6-2/screenshots/preferences-unsaved-changes.png`
- `../artifacts/milestone-4-6-2/screenshots/preferences-reconciliation.png`
- `../artifacts/milestone-4-6-2/screenshots/preferences-saved-confirmation.png`
- `../artifacts/milestone-4-6-2/screenshots/preferences-accessibility-large.png`

## Manual review

1. Open Preferences and confirm the committed summary chips match the current household, cooking days, weekly budget, and supermarket.
2. In Your week, change household size, one cooking day, budget, and cooking time. Confirm the sticky bar counts changed fields while the summary chips remain committed.
3. Use Type exact in the budget module and confirm its amount stays synchronized with the displayed budget. Discard the draft and confirm the committed values return.
4. In Your taste, select styles and proteins, remove a disliked ingredient, and add a real catalogue ingredient. Confirm the copy describes ranking rather than exclusion.
5. In Rules we never break, toggle a dietary rule and use No allergens, then add an allergen. If a planned dinner is affected, tap Save and review and confirm the warning names the real consequence without silently changing the plan.
6. In Your kitchen, toggle an appliance and confirm both its written state and the derived catalogue result count change.
7. Save a nonconflicting draft and confirm the temporary success bar appears, then collapses to All changes saved.
8. Increase the Simulator text size to an Accessibility setting and repeat a few controls. Selectors and grids should stack or grow, with no essential truncation and the sticky actions still reachable.

Stop after this review; onboarding and later milestones remain unstarted.
