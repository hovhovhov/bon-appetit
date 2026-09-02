# Milestone 4.6.1 validation — Meals exploration refinement

Date: September 2, 2026  
Baseline: `5becf3a`  
Scope: Meals Explore/Saved presentation, catalogue-backed cuisine browsing, tests, and documentation. Plans, calculations, persistence behavior, and later milestones were not redesigned.

## Implemented behavior

- The Meals selector is now visibly **Explore / Saved**.
- Explore contains eligible-only search, committed-preference-first styles, in-place collapsed/expanded style browsing, and a real cuisine grid.
- Style cards open real deterministic result sets.
- Cuisine cards derive their count and lowest price from hard-eligible recipes and use the existing money formatter.
- Cuisine and style results support local search and deterministic Cheapest first, Quickest first, and Name sorting.
- Compact result rows open Recipe Details, reuse Add/Replace, expose recipe-specific Add labels, and state an actual planned day in text.
- Saved keeps persisted timestamps, recent-first ordering, search, empty/no-results states, Recipe Details, notes, Save/Unsave, and Add/Replace while using the approved denser presentation.
- Fallback/offline status remains honest but is only shown when it explains the current system state.

## Catalogue contract

`Recipe.cuisine` is an optional, validated field. The backend accepts only Asian, Italian, Mexican, and Indian in the current development catalogue. Fixture record version 2 / catalogue version `dev-2026-08-31.2` supplies metadata only for recipes with known structured provenance. Missing cuisine remains valid for cached version-1 records; the client neither guesses from titles nor creates a screen-only mapping.

## Automated validation

- Backend: TypeScript typecheck passed; Vitest passed 25/25 tests across 4 files; production TypeScript build passed.
- iOS unit tests: 57/57 passed.
- iOS UI tests: 31/31 passed, including the original canonical planning journey and Milestones 2–4.6 regressions.
- Milestone 4.6.1 UI coverage includes Explore/Saved switching, style expansion and selection, cuisine navigation/search/sort, planned-day text, Add accessibility labeling, Saved ordering/unsave/no-results/empty state, and Accessibility Large layout.
- The existing primary-screen accessibility audit covers contrast, hit regions, descriptions, and visible text clipping. iOS reports its single-line editable search prompt as clipped even when the visible placeholder fits; that identified control is exempted from only the clipping finding, while its concise VoiceOver label/hint and the dedicated Accessibility Large journey remain asserted.
- Backend connected, backend unavailable, invalid-result deterministic fallback, and Debug-only legacy-feed boundaries passed their existing UI journeys.

## Simulator and visual validation

The final Debug build was exercised on the 390 × 844-point validation Simulator and the Release configuration was built for iOS Simulator. Captures were compared with the four supplied Meals references:

- `../artifacts/milestone-4-6-1/screenshots/meals-explore-collapsed.png`
- `../artifacts/milestone-4-6-1/screenshots/meals-explore-expanded.png`
- `../artifacts/milestone-4-6-1/screenshots/meals-cuisine-asian.png`
- `../artifacts/milestone-4-6-1/screenshots/meals-saved.png`
- `../artifacts/milestone-4-6-1/screenshots/meals-explore-accessibility-large.png`

VoiceOver names/states, text-backed Saved/planned/caution states, 44-point actions, Dynamic Type reflow, Reduce Motion-safe state changes, Increase Contrast, and Differentiate Without Color semantics reuse the existing native accessibility system and are covered by code review plus the automated journeys/audits.

## Intentional differences and assumptions

- The validated development catalogue contains four cuisines and only two eligible Asian meals in the canonical fixture. The reference board's 11 cuisines, 24 Asian meals, and lower prices were not copied because doing so would create fake state.
- Existing canonical meal-style names are used, so the full seven are Speedy meals, Family favourites, Protein packed, Healthy comfort, Meat-free, Fakeaway, and Treat night.
- Recipe art uses existing rights-safe Weeknight artwork; no Claude, Mise, device-frame, web, or unverified food assets ship in the target.
- Native iOS 26 `TabView` and navigation geometry differs from the static presentation board, including the system's current tab-bar material. Replacing the approved app-wide tab system would materially alter Plans and was outside this Meals-only checkpoint.
- At accessibility text sizes, cards become one column and rows grow instead of preserving the board's standard-size density.

## Manual review

1. Open **Meals** and confirm **Explore** is selected.
2. Check that the two visible style cards match your committed preferences; tap one and confirm the result list is genuinely filtered.
3. Return to Meals, tap **See all 7**, confirm all seven styles appear, then tap **Show less**.
4. Search for a title, ingredient, cuisine, or style and open a result's Recipe Details; return and confirm the previous Meals position is retained.
5. Open **Asian**, confirm the real result count and **Cheapest first** ordering, try its search, open a row, and use one recipe's **Add** action.
6. Confirm already planned recipes name their actual day.
7. Switch to **Saved**. Confirm recent-first ordering, source/time/servings/price, explicit **Saved** text, and Add or Replace behavior.
8. Unsave a recipe, confirm it disappears, then resave it through Recipe Details and confirm all Meals surfaces agree.
9. Try a Saved search with no match and clear it. If desired, remove all Saved recipes to inspect the empty state, then use Settings → Reset local data to restore the canonical fixture.
10. Increase iPhone text size to an Accessibility size and recheck Explore: cards should become one column and text/actions must remain usable.

Stop after this review; onboarding and later milestones remain unstarted.
