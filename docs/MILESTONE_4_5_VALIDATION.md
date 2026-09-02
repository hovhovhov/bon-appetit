# Milestone 4.5 — v2 Visual Refinement Validation

Validated on September 1, 2026.

## Scope completed

- Reworked Plan, Discover, Add to Week, Recipe Details, Shopping, Saved, and You/Preferences in native SwiftUI using the v2 editorial visual system.
- Added the approved cream, ink, green, light-green, clay, and hairline tokens; v2 spacing, radii, crop geometry, typography hierarchy, and motion timings.
- Preserved the weekly plan as the source of truth. Budget, open-night, completion, and shopping values remain derived from canonical state.
- Added deterministic UI coverage for partial, empty, and completed plan states.
- Added eight rights-safe generated food stills to the application asset catalog.

The implementation interpretation and board-to-code decisions are recorded in [WEEKNIGHT_V2_DESIGN_NOTES.md](../design-reference/v2/WEEKNIGHT_V2_DESIGN_NOTES.md).

## Verification

| Check | Result |
| --- | --- |
| Debug build and complete test suite, iPhone 14 simulator (390 × 844 pt) | Passed — 71 tests: 52 unit and 19 UI |
| Release build, iOS Simulator | Passed |
| Compact iPhone journey (375 × 667 pt) | Passed |
| Large iPhone journey (440 × 956 pt) | Passed |
| Reduce Motion journey | Passed; preference restored to off afterward |
| Large Dynamic Type, Recipe Details and Preferences | Passed |
| Backend typecheck | Passed |
| Backend Vitest suite | Passed — 24 tests in 4 files |
| Backend production build | Passed |
| `git diff --check` | Passed |

The final complete-suite result bundle was written to `/tmp/Weeknight-M45-FinalFull3.xcresult`. The final Release-derived data was written to `/tmp/Weeknight-M45-Release`.

## Visual evidence

- [Partial Plan](../design-reference/v2/implementation-screenshots/plan-partial-primary.png)
- [Empty Plan](../design-reference/v2/implementation-screenshots/plan-empty-primary.png)
- [Completed Plan](../design-reference/v2/implementation-screenshots/plan-complete-primary.png)
- [Discover](../design-reference/v2/implementation-screenshots/discover-primary.png)
- [Add to Week](../design-reference/v2/implementation-screenshots/add-to-week-primary.png)
- [Recipe Details](../design-reference/v2/implementation-screenshots/recipe-details-primary.png)
- [Shopping](../design-reference/v2/implementation-screenshots/shopping-primary.png)
- [Saved](../design-reference/v2/implementation-screenshots/saved-primary.png)
- [Saved Empty](../design-reference/v2/implementation-screenshots/saved-empty-primary.png)
- [Preferences](../design-reference/v2/implementation-screenshots/preferences-primary.png)
- [Compact iPhone](../design-reference/v2/implementation-screenshots/responsive-narrow.png)
- [Large iPhone](../design-reference/v2/implementation-screenshots/responsive-large.png)
- [Reduce Motion](../design-reference/v2/implementation-screenshots/accessibility-reduce-motion.png)
- [Large Dynamic Type](../design-reference/v2/implementation-screenshots/accessibility-large-type.png)

## Explicit substitutions and retained differences

- Archivo was not bundled or supplied. The app uses the native San Francisco family with matching weight, width, scale, and tracking intent.
- Exact licensed recipe photography and video were not supplied. Rights-safe generated stills replace them; no video autoplay or recording-only build mode was added.
- The motion-board examples `$63.95` and `31 items` are presentation examples, not state. The app continues to show the canonical seeded week values (`$56.70` and 36 shopping items).
- The native iOS tab bar and SF Symbols are retained for platform semantics and accessibility rather than reproducing custom reference chrome.
- The crop-to-day arc, final ribbon assembly, and budget count-up are implemented with native state transitions and reduced-motion fallbacks; the exact storyboard choreography is approximated rather than rendered as a bespoke animation engine.
- The optional share/export payoff remains deferred because sharing behavior and export requirements were not part of the approved product behavior. No later-roadmap functionality was started.
