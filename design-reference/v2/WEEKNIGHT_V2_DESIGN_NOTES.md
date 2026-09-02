# Weeknight v2 — implementation design notes

Status: implementation specification for Milestone 4.5
Primary visual authority: the PNGs in `design-reference/v2/`
Primary comparison viewport: 390 × 844 points

## 1. Evidence and authority

These notes translate the supplied Nectar v2 boards into native SwiftUI decisions. They do not turn presentation-board annotations into product features. The current request and the approved native implementation plan remain authoritative for product behavior; the PNGs are authoritative for visual character and composition.

Inspected references:

- `screen:/plan-partial+complete.png`
- `screen:/discover.png`
- `screen:/add-to-week.png`
- `screen:/recipe-details.png`
- `screen:/saved.png`
- `screen:/shopping-list.png`
- `screen:/you.png`
- `screen:/empty-state.png`
- `screen:/tiktik-preview.png`
- `design-system.png`
- `motion-storyboard.png`

The existing Milestone 4 app, README, implementation plan, handoff, Swift domain/data/state layers, native views, automated tests, and existing Simulator captures were also inspected before implementation.

## 2. Product hierarchy and navigation

### Visible facts

- The root has four persistent destinations: Plan, Discover, Saved, and You.
- Plan and Saved are cream editorial surfaces. Discover is a full-bleed media surface. Shopping List and Recipe Details are pushed destinations. Add to Week is a bottom sheet over the current recipe.
- The tab bar is quiet and flat: cream background, a small green dot plus green label for selection, muted labels for other tabs, and no visible icon rail in the reference.
- Plan has materially different partial, empty, and completed compositions rather than one card stack with small state changes.

### Native implementation decision

- Keep the existing `TabView` and `NavigationStack` behavior and VoiceOver-native tab semantics.
- Label the fourth tab **You** in the interface while retaining the internal `.preferences` route.
- Use an opaque cream tab-bar background with deep-green selection and subdued unselected items. Retain SF Symbol icons because completely removing them would weaken native discoverability and existing UI-test semantics; make them visually secondary.
- Keep existing functional preference editors, recipe notes, eligibility warnings, backend state, swaps, and autofill even where a board does not show them.

## 3. Semantic visual system

### Colour — visible facts

| Role | Reference value | Use |
|---|---:|---|
| Canvas cream | `#FBF8EC` | Primary screen background |
| Deep cream | `#F1E9D8` | Wells, empty-day surfaces, search field |
| Ink | `#14180F` | Type on cream |
| Action green | `#14512F` | Primary actions, selected controls, key progress |
| Light green | `#8FD37A` | Progress over photography only |
| Clay | `#A03B2A` | Allergens, over-budget, destructive/error states |
| Hairline | `#EBE3D2` | The only default separator |

One accent is used per surface. Deep green does not fill structural cards, and bright green is not used as a button fill.

### Colour — implementation assumptions

- System semantic adaptations are kept for increased contrast.
- Error wells use a very pale clay tint so error copy remains legible without introducing a second decorative accent.
- Photography uses a bottom black/ink scrim and, only when needed for top status text, a light top scrim. Cream screens do not use gradients.

### Typography — visible facts

- Recipe names are the dominant type, approximately 42–44 pt in the Discover reference.
- Screen titles are approximately 32–44 pt depending on composition.
- Feature/headline type is approximately 27–32 pt.
- Rows are approximately 17 pt semibold; body is approximately 15 pt regular; metadata is approximately 13 pt.
- Tracked, narrow uppercase is reserved for day tabs, section eyebrows, and tab/system roles.
- The board names Archivo and Archivo Narrow; those font files are not supplied with verified rights.

### Typography — implementation decision

- Use San Francisco through SwiftUI semantic styles. Heavy/black weights provide the editorial display voice; `.caption`/`.footnote` with tracking provide the narrow-label substitute.
- Dynamic Type remains semantic. At accessibility sizes, side-by-side clusters stack, photography becomes shorter where needed, and sticky controls keep labels visible rather than fixing exact board sizes.

### Space, radius, and geometry — visible facts

- Horizontal gutter: 22 pt.
- Vertical rhythm: 8 / 14 / 20 / 26 / 34 pt.
- Radius: 14 pt thumbnail; 18 pt icon button; 22 pt mosaic crop; 26–30 pt hero curtain/sheet; 28 pt primary action.
- Primary action height: 56 pt. Secondary control: 52 pt. Icon target: 52 pt. Rows: at least 44 pt.
- Sections are separated with whitespace, image crop boundaries, and hairlines rather than boxed cards.

### Native implementation decision

- Minimum hit target remains 44 × 44 pt; primary actions are 56 pt.
- Shadows are removed from normal content. A restrained shadow is allowed only on transient overlays when needed for separation.
- Pills are limited to primary actions, compact status/day labels, search, and controls whose native semantics benefit from the shape.

## 4. Signature components

### Notched day tab

Visible: a cream label overlaps the lower edge of photography. It has a soft top-right cut/notch and roughly 12 pt corners, with tracked uppercase day text.

Implementation: a reusable `NotchedDayTabShape` clips the label. Filled-plan hero uses “TONIGHT · MON 31” when appropriate; thumbnails use short day labels; the empty state uses “MON 31 · OPEN”. The label remains text, not baked into imagery.

### Photography crops

Visible:

- Curtain crop: full width, about 292 pt tall, lower corners near 30 pt; used by partial Plan and Recipe Details.
- Viewport crop: full bleed; used by Discover.
- Mosaic crop: 22 pt outer radius with adjacent edges reading as one crop rather than floating cards; used by completed Plan and Saved.
- Thumbnails: roughly 14 pt radius.
- Subjects sit in the upper two-thirds; lower areas are reserved for type on photographic screens.

Implementation:

- Every fixture recipe receives a rights-safe local generated photograph. Images use aspect-fill and reusable focal alignment.
- Discover overlays a linear black scrim strongest at the bottom. Essential text is always over the scrim and is never placed on a raw bright crop.
- Plan and Recipe Details place primary title copy on cream below the image, avoiding scrims there.

### Progress treatment

Visible: a 2–3 pt hairline with deep-green progress on cream; light green is reserved for progress over a photograph.

Implementation: one reusable budget/progress component supports cream and photographic variants, over-budget clay, and accessibility labels. Numeric values remain deterministic and are not animated as sources of truth.

### Buttons and selection controls

- Primary: deep green, cream text, 56 pt, fully rounded.
- Secondary: transparent/cream with a hairline outline and ink/green label.
- Selection rows: a pale deep-cream wash, green day label, and a filled green check circle. Unselected controls use a hairline circle plus explicit text.
- Disabled actions lower contrast but preserve readable labels and expose the disabled state to accessibility.

## 5. Screen specifications

### Plan — partial week

Visible structure:

1. “This week” with store/date eyebrow.
2. Spend and dinner/list progress in one compact line plus budget hairline.
3. One dominant featured meal photograph with overlapping notched day label.
4. Featured title and metadata below the photograph.
5. Remaining planned meals as compact thumbnail rows separated by hairlines.
6. Open nights consolidated into one inviting row with a square plus well and deep-green “Fill for me” action.

Implementation assumptions:

- The featured meal is today’s planned dinner when present; otherwise it is the first filled slot.
- Existing swap, recipe detail, conflict, and autofill actions remain available. Open nights stay individually addressable to VoiceOver even if visually summarized.
- Backend status is shown only when it conveys non-local state and uses an inline notice rather than a decorative card.

### Plan — completed week

Visible structure:

1. Green eyebrow with dinner count and spend.
2. Large “Your week is ready” headline.
3. Thin budget progress and under/over-budget sentence.
4. Five-photo asymmetric mosaic with day tabs.
5. Shopping item count/progress, review action, and deep-green primary button.

Implementation assumptions:

- The weekly plan remains the only data source. The reference’s `$63.95` does not replace the tested canonical completion total.
- For large Dynamic Type, the mosaic remains visual but the headline and shopping action receive priority; all meals remain available through accessible elements.

### Plan — empty

Visible: compact zero-state header, pale treatment over a dominant meal image, open-day tab, “Nothing planned yet”, explanatory copy, deep-green Find dinners, outlined Draft my week.

Implementation: use an eligible discovery recipe as an aspirational background with a cream veil. Both actions map to existing Discover and deterministic autofill behavior. Loading/unable autofill uses existing honest states.

### Discover

Visible:

- One full-bleed recipe per viewport.
- Thin progress hairline and spend at the top.
- A cream “FOR THURSDAY” label in the safe central-left region.
- Small vertical position ticks on the left.
- Large cream/white title, metadata, budget-fit sentence, Save secondary control, and Add primary action near the bottom.
- No right-hand social action rail.

Implementation:

- Use native vertical paging. When Reduce Motion is enabled, use view-aligned scrolling and cross-fade state changes without scale/translation.
- Preserve the feed’s current recipe when returning by keeping scroll selection in store/view state.
- The target day is the first open day; the button still presents Add to Week for explicit confirmation.
- Details remain available as a secondary text action, because that behavior is already implemented and useful.
- Loading/error/no-results states remain on a dark photographic-context surface with direct recovery actions.

### Add to Week

Visible: the underlying photograph stays visible behind a cream sheet with a 28–30 pt top radius; title remains on the image; the sheet has a drag indicator, “Which night?”, compact occupied rows, larger selectable open rows, an “After adding” total, progress hairline, and one primary confirmation.

Implementation:

- Use a large native sheet with a cream background and drag indicator. The exact full-screen photographic backdrop cannot be guaranteed for sheets opened from non-photographic origins, so the sheet includes a photo header when needed.
- Occupied days remain selectable for replacement and say what will be replaced. Errors retain selection. Commit remains atomic and double activation stays guarded.
- Selection haptic on day selection; success haptic on commit. With Reduce Motion, state changes use opacity only.

### Recipe Details

Visible: full-width curtain photograph with floating back/save controls; notched source label; large title and one metadata/rationale block; Ingredients with an inline serving stepper; unboxed hairline-separated ingredient rows; sticky deep-green action.

Implementation:

- Preserve method, notes, attribution, eligibility, scheduled serving update, swap, and clear behaviors below the reference’s first viewport.
- Replace metric cards and ingredient card with editorial text and hairlines.
- Use SF Symbols in circular 52 pt controls, maintaining VoiceOver labels.

### Saved

Visible: title/count, pill search well, a large asymmetric three-image mosaic with text on photography, then a small “Recently saved” row with outlined Add.

Implementation:

- Populate the mosaic from the first three filtered saved recipes and render additional results as editorial rows.
- Keep search and the existing All/Recently Saved filters; filters collapse horizontally and remain secondary to imagery.
- Empty and no-results states use the same cream editorial state language rather than a generic card.

### Shopping List

Visible: large title/store, strong “x of y in the basket” with total, thin progress hairline, uppercase aisle headings, unboxed rows with large circular checks, ingredient and quantity in one line, sources below, price trailing, and a sticky bottom estimate/action bar.

Implementation:

- Preserve deterministic aggregation and per-aisle progress in accessibility values even though the visible header shows aisle total rather than a fraction.
- Checking a row uses a short opacity/strikethrough transition and selection haptic; Reduce Motion removes translation/scale.
- Existing empty/loading/stale/error variants adopt the same typography, colour, and action system.

### You / Preferences

Visible: “You” headline, plain-language one-line summary, hairline-separated text rows grouped under tracked uppercase headings, no cards, no effect chips, and a Reduce Motion switch reflecting the system setting.

Implementation:

- Preserve every existing preference and draft/reconciliation sheet; group them into The week, What you eat, and Kitchen.
- Keep Medical allergens visually distinct with clay copy and explicit safety language.
- Display Reduce Motion as read-only system status; changing the system setting is not faked.
- Keep Reset demo week below the core preference rows as a secondary outlined action.

## 6. State and accessibility specification

- Loading: stable layout, neutral skeleton/wash or progress label; no misleading data.
- Empty: plain editorial composition with a direct recovery action; no dashed cards.
- Error/stale: clay label/well, concise explanation, explicit Retry, and preserved local data when available.
- Selected: colour plus checkmark/text and `.isSelected`; never colour alone.
- Disabled: readable label, lower emphasis, native disabled trait/value.
- Completed: headline and composition change on Plan, plus success haptic; no confetti or sound.
- Dynamic Type: semantic styles, wrapping to three lines where needed, stacking for accessibility sizes, scrollable content, and sticky controls that do not cover content.
- VoiceOver: image decoration is hidden when adjacent text names the recipe; mosaic images become recipe/day elements; row values expose checked, selected, planned, conflict, and budget state.
- Reduce Motion: no forced paging, arc, scale, or translated reveal; use immediate changes or a 120 ms opacity transition. Haptics remain confirmations.
- Contrast: cream/ink and cream/deep-green carry structural information. Text over photos always uses the darkest measured visual region created by a scrim.

## 7. Motion specification

Visible timings from the motion board:

- Recipe settle: 260 ms spring, light impact.
- Sheet detent: 320 ms spring.
- Fly-to-day: 420 ms cubic with budget counting over the last 200 ms.
- Completed-week reveal: 540 ms staggered cubic, success haptic.
- Shopping rows/merge: up to 800 ms total, ease-out.

Implementation assumptions:

- Native sheet and paging physics are preferred over manually timing platform transitions.
- Data commits happen immediately; animation observes the new state and never gates persistence or calculations.
- The fly-to-day image arc is intentionally approximated by a matched fade/scale because the native sheet dismisses across tab/navigation contexts and correctness takes priority over a brittle overlay.

## 8. Known reference conflicts and resolutions

- The v2 completed board shows five dinners for `$63.95`; the repository’s canonical completed fixture is `$56.70`. Preserve repository calculations and display live values.
- The v2 sheet’s Steak Frites projection is `$54.15`; projections remain computed from the selected recipe/day/servings.
- The v2 Saved board says “Bacon Carbonara”; the current model says “Proper Carbonara”. Preserve model content.
- The v2 Shopping board shows a visual subset of groups/items. The application must show the complete deterministic generated list.
- The v2 tab says “You”; current product structure says Preferences. Use “You” as the visible label and retain Preferences internally and in documentation.
- The board names commercial/reference fonts and uses supplied food images with unclear rights. Use system typography and newly generated project-local photography.
- The recording overlay is validation guidance, not application UI. No TikTok chrome or shaded overlay ships in the app.

## 9. Implementation plan

1. Replace legacy colour, geometry, typography, progress, button, image, notched-tab, and motion primitives with v2 semantic components.
2. Add rights-safe local fixture photography and bundle it through an asset catalogue.
3. Refactor shared root/tab treatment and preserve route/accessibility identifiers.
4. Recompose Plan partial, complete, and empty states from the same weekly-plan source of truth.
5. Recompose Discover and Add to Week with native paging/sheet behavior, safe-area-aware overlays, haptics, and reduced-motion alternatives.
6. Recompose Recipe Details, Saved, Shopping List, and Preferences while preserving all existing functional and safety states.
7. Build, run unit/store/integration/UI tests, and capture standard, small, large, Dynamic Type, and Reduce Motion Simulator evidence.
