# Milestone 4.6 — Information Architecture and Accessibility Validation

Validated on September 2, 2026.

## Delivered scope

- Replaced the prior Plan / Discover / Saved / You shell with four native, labelled primary tabs: Plans, Meals, Preferences, and Settings.
- Made Plans a consistent day-first source-of-truth view for empty, partial, complete, preference-conflict, and over-budget weeks. The completed collage remains only a secondary summary below the daily plan.
- Combined discovery and saved recipes under Meals, with For You and Saved sections that share planning, save, eligibility, repository, and recipe-detail state.
- Preserved the previous full-screen Discover feed as `LegacyDiscoverFeedView`, reachable only through the `--legacy-discover-feed` launch boundary compiled under `#if DEBUG`.
- Moved planning-affecting controls into an accessible Preferences hierarchy without changing draft, cancel, reconciliation, atomic save, allergen, dietary, appliance, or deterministic eligibility behavior.
- Added an honest Settings hierarchy for personalization status, accessibility behavior, privacy and data, reset, and about information. Backend diagnostics remain Debug-only; no account, sign-in, family, subscription, language, units, notification, cloud, or dead support controls were added.
- Refined Recipe Details, Shopping List, Add to Plan, and Replace as pushed or presented destinations with origin-aware navigation.

## Preserved engineering boundaries

Milestone 4.6 is a presentation and navigation migration. `AppNavigation` owns the selected tab, selected Meals section, search query, and Debug-only legacy presentation mode. The persistent models, repositories, backend contracts, catalogue schema, budget arithmetic, shopping aggregation, assignment and replacement rules, eligibility filtering, AI response validation, and deterministic fallback were not changed.

The canonical 3 → 4 → 5 meal journey remains an end-to-end UI test and continues to assert the existing plan, budget, and shopping derivations rather than duplicating those calculations in views.

## Automated verification

| Check | Result |
| --- | --- |
| Complete Debug iOS suite, iPhone 14 (390 × 844 pt), iOS 26.5 | Passed — 78 tests: 52 unit and 26 UI; zero failures or skips |
| Canonical 3 → 4 → 5 meal journey | Passed as part of the complete suite |
| Narrow iPhone navigation, iPhone SE (3rd generation), iOS 26.5 | Passed |
| Large iPhone + Accessibility Large text, iPhone 17 Pro Max, iOS 26.5 | Passed |
| Primary-screen accessibility audit | Passed for contrast, hit regions, descriptions, and text clipping |
| Increase Contrast runtime + primary-screen audit | Passed for contrast, hit regions, and descriptions |
| Reduce Motion runtime inspection | Passed; Settings reported On and motion-dependent branches use `accessibilityReduceMotion`; restored to Off afterward |
| Legacy feed boundary regression | Passed; Debug launch renders the feed and reuses Recipe Details / planning actions |
| Backend typecheck | Passed |
| Backend Vitest suite | Passed — 24 tests in 4 files |
| Backend production build | Passed |
| Clean Release iOS Simulator build | Passed |
| Release legacy-feed boundary inspection | Passed; Debug-only feed launch marker is absent from the Release executable |
| `git diff --check` and repository hygiene review | Passed |

The final complete-suite result is `/tmp/Weeknight-M46-Final5.xcresult`. Matrix evidence is in `/tmp/Weeknight-M46-Narrow.xcresult`, `/tmp/Weeknight-M46-Large.xcresult`, and `/tmp/Weeknight-M46-HighContrast3.xcresult`. Release-derived data is in `/tmp/Weeknight-M46-FinalRelease`.

The XCTest accessibility audit intentionally ignores only elements outside the rendered ScrollView viewport or beneath the tab-bar boundary. Visible content is still audited, and a separate Accessibility Large navigation test exercises reflow on all four destinations.

## Accessibility review

- All primary tabs carry text and SF Symbols; the selected state is native tab-bar state, not color alone.
- Recipe rows expose separate Recipe Details, Add/Replace, Save/Unsave, and Clear controls with labels, values, hints, and minimum hit regions.
- Preference selections use text, checkmarks, and selected traits. Plan fit, caution, completion, conflict, and budget states use symbols and explicit language in addition to color.
- Meaningful recipe images have recipe-specific alternatives where needed; decorative symbols and duplicate artwork are hidden from VoiceOver.
- Lists, forms, pickers, steppers, confirmation dialogs, segmented controls, and navigation destinations retain native semantics and logical reading order.
- Accessibility Large text navigated all four primary destinations without losing their titles or controls. The segmented Meals picker adapts to a labelled Menu at accessibility sizes.
- Reduce Motion suppresses or simplifies view transitions; confirmation haptics and textual state remain.
- The iOS 26 tab bar uses an opaque Weeknight appearance and a real safe-area clearance, preventing essential content from being covered while retaining native tab semantics.

The Simulator accepted defaults writes for Differentiate Without Color and Button Shapes, but its Settings UI continued to report Differentiate Without Color as Off. That toggle is therefore recorded as a code-path and semantic inspection rather than a successful runtime toggle: every selection and status uses text, a symbol/checkmark, and accessibility traits or values. The exact manual step remains below for confirmation on a physical device or Simulator where the setting persists.

## Final screen evidence

- [Plans](../artifacts/milestone-4-6/screenshots/plans.png)
- [Meals — For You](../artifacts/milestone-4-6/screenshots/meals-for-you.png)
- [Meals — Saved](../artifacts/milestone-4-6/screenshots/meals-saved.png)
- [Preferences](../artifacts/milestone-4-6/screenshots/preferences.png)
- [Settings](../artifacts/milestone-4-6/screenshots/settings.png)
- [Recipe Details](../artifacts/milestone-4-6/screenshots/recipe-details.png)
- [Shopping List](../artifacts/milestone-4-6/screenshots/shopping-list.png)

## Manual review steps

1. Launch Weeknight on the `Weeknight Primary 390x844` iPhone 14 Simulator. Confirm the app opens on Plans and the native tab bar consistently labels Plans, Meals, Preferences, and Settings.
2. On Plans, inspect the partial week, scroll through all configured days, open Shopping List, open a recipe, replace a meal, and clear/add an open day. Confirm spend, remaining budget, planned count, and shopping progress update from the weekly plan.
3. Complete the week. Confirm the five daily rows remain the functional representation and the collage appears only afterward as a secondary celebration.
4. In Meals, switch between For You and Saved; search, save/unsave, open details, and add or replace a day. Disconnect the backend and confirm the existing cached/local fallback language remains honest and usable.
5. In Preferences, edit household size and cooking days, cancel once, then save once. Exercise a medical-allergen conflict and confirm reconciliation warns without silently deleting the planned meal.
6. In Settings, confirm there are no account, Sign in with Apple, family, subscription, cloud, language, units, notification, or fake support controls. Trigger Reset Local Data and confirm the destructive dialog describes the removal before accepting it.
7. In Settings > Accessibility, enable Larger Text to an accessibility size, Reduce Motion, Increase Contrast, and Differentiate Without Color one at a time. Revisit all four tabs and pushed destinations; confirm content reflows, motion simplifies, contrast stays clear, and selected/status states remain identifiable without color. Restore the settings afterward.
8. Turn on VoiceOver. Swipe through each primary screen in reading order; verify screen titles, tab labels and selected state, recipe image alternatives, row metadata, preference values, button hints, and separate Add / View Recipe / Replace / Clear actions. Confirm no task requires an unlabeled image or gesture-only interaction.
9. For internal regression only, run a Debug build with `--legacy-discover-feed`; confirm the preserved feed opens Recipe Details and planning actions. Repeat with a Release build and confirm the internal feed is unavailable.

## Remaining differences and risks

- iOS 26 renders the system tab bar with its current platform geometry. Weeknight supplies an opaque cream appearance and safe-area backing rather than replacing native semantics with custom chrome.
- The automated VoiceOver evidence validates descriptions, traits, hit regions, and hierarchy exposure; spoken cadence and rotor behavior still merit the manual device pass above.
- Differentiate Without Color could not be made to persist through this Simulator runtime's defaults interface, so its final runtime review is manual even though all status and selection designs have non-color indicators.
- Existing Swift 6 concurrency warnings in `WeeknightTests/Milestone4Tests.swift` predate this presentation migration. They do not fail the current Swift language mode, but should be removed before enabling Swift 6 strict mode.

## Explicitly out of scope

Onboarding, authentication, accounts, Sign in with Apple, family sharing, cloud synchronization, notifications, subscriptions, paywalls, analytics, deployment, production hosting, and new API capabilities were not implemented.
