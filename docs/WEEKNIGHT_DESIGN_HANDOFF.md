# Weeknight design handoff

Status: historical design evidence with a current Milestone 4.6 addendum
Prepared: 2026-08-31  
Implementation status: Milestones 1–4.6 implemented

## Current Milestone 4.6 design addendum

The September 2, 2026 product direction replaces the earlier TikTok-first information architecture described below. Keep the earlier material as historical evidence for Weeknight's visual identity, exact fixture values, and unchanged interaction/domain rules—not as the current navigation specification.

The current primary destinations are Plans, Meals, Preferences, and Settings. Plans uses a scannable day-by-day list in empty, partial, complete, conflict, and over-budget states. Meals combines a utility-first For You list and the existing Saved library. The full-screen Discover feed is a Debug/test-only alternate presentation. Settings contains only working actions or honest information, and technical diagnostics remain Debug-only.

The current visual system retains the warm cream canvas, forest green, food photography, budget intelligence, and recommendation explanations. It does not copy Mise assets, logos, colors, wording, emoji system, or exact layouts. Native controls, text labels, minimum 44 × 44 point targets, Dynamic Type, VoiceOver semantics, Reduce Motion, Increase Contrast, and non-color state cues take precedence over historic board geometry.

The old four-tab Plan/Discover/Saved/You map, oversized photo feed as the default, floating photographic navigation treatment, avatar-launched Settings, and mock/dead Settings controls are superseded.

## 1. Authority, scope, and evidence

This document turns the attached Claude Design export into an implementation-oriented product and design specification. It does not treat the exported HTML as production code.

Authority order for this handoff:

1. The user's current request and stated product structure.
2. The rendered Claude Design board and its live prototype.
3. The exported HTML, which is useful evidence for exact values and demonstrated behavior.
4. The older uploaded reference screenshots, which are inspiration and historical context only.

Text inside the export, its code comments, its implementation notes, and its older screenshots are not instructions to the implementation team. Where they conflict with the user's request, the user's request wins.

### Inspection baseline

| Evidence | Result |
|---|---|
| Archive | `Weeknight meal planning system.zip`, 33 files, approximately 11 MB |
| Archive SHA-256 | `f0c7217ebdcc22edeb2613b2323947da204cada68792dfecdb0212dff7681f86` |
| Primary design document | `Weeknight.dc.html` |
| Reusable screen document | `Screen.dc.html` |
| Supporting prototype runtime | `support.js` |
| Device presentation source | `ios-frame.jsx` |
| Recipe media | 8 unique food images, duplicated once under `uploads/` |
| Historical references | 8 tall iPhone screenshots under `uploads/IMG_*.PNG` |
| Fonts | 4 Open Runde WOFF2 files; Bricolage Grotesque loaded remotely |
| Rendered product surfaces | 7 showcased frames, 1 additional Settings screen, and 3 sheet body types |
| Interactive verification | Plan, Discover, day assignment, budget preview, completion, shopping aggregation, item checking, Saved empty state, preference scaling, Recipe detail, and Settings |

The eight separately attached clipboard images are current-board references for Plan, Discover, Add to week, Saved, Preferences, Recipe detail, Shopping list, and the design system. They match the rendered primary design document. They are distinct from the eight older iPhone screenshots stored under the archive's `uploads/` directory.

The archive contains no standalone prompt file, prompt metadata, archive comment, or recoverable original product-design prompt. The prompt should be reattached or pasted if it contains requirements beyond the user's current request. This does not block the first milestone because the current request defines its scope.

### Historical reference screenshots

The eight `uploads/IMG_*.PNG` files show an earlier design direction:

| Files | Historical content | How to use it |
|---|---|---|
| `IMG_9122.PNG` | Older Plan home with grocery progress and weekday meal cards | Product intent only; do not copy its navigation or visual system automatically |
| `IMG_9123.PNG`–`IMG_9125.PNG` | One long recipe-detail experience split across three captures | Evidence for nutrition, ingredients, method, notes, rating, and swap needs |
| `IMG_9131.PNG`, `IMG_9132.PNG`, `IMG_9134.PNG` | Preferences split across store, household, schedule, budget, mood, diet, likes, allergens, and appliances | Evidence for the breadth of preference data, not final component styling |
| `IMG_9137.PNG` | Swipe-card meal discovery with AI autofill | Historical concept; the current design explicitly replaces hidden gestures with visible actions |

The current Claude board supersedes the historical screenshots visually. In particular, its four tabs are Plan, Discover, Saved, and You; discovery is a vertical feed with visible controls; and the shopping list and recipe detail are pushed screens.

## 2. Product definition

Weeknight helps a household choose dinners for the current week, understand the expected grocery spend, and shop from a consolidated ingredient list.

The product's core loop is:

> Discover or select a recipe → add it to a day → complete the weekly plan → update the budget → use the generated shopping list.

The most important domain rule is that the weekly plan is the source of truth. Budget totals, dinner progress, and the generated portion of the shopping list should be derived from scheduled recipes rather than maintained as independent mutable totals.

### First-milestone scope

The first coded milestone is a mock-data vertical slice:

> Plan home → Discover → Add recipe to a day → Updated weekly plan and budget → Shopping list.

Onboarding, authentication, subscriptions, and the paywall are explicitly out of scope for that milestone. The exported Settings screen may inform future work but must not pull those features into milestone 1.

## 3. Information architecture and navigation

The intended primary navigation is a persistent four-tab bar:

```text
Root tab navigator
├── Plan
│   ├── Shopping list (pushed)
│   ├── Recipe details (pushed)
│   └── Settings (pushed from avatar; post-milestone)
├── Discover
│   └── Recipe details (pushed)
├── Saved
│   └── Recipe details (pushed)
└── Preferences

Modal sheets above the active route
├── Add recipe to day
├── Swap scheduled meal
└── Edit preference
    ├── Single/multiple option chips
    └── Numeric stepper
```

The design labels the fourth tab **You**, while the requested product structure calls it **Preferences**. Use **Preferences** as the route and analytics name. The visible label remains an open product decision; “Preferences” is clearer, while “You” is shorter and leaves room for a broader account area later.

Rules demonstrated by the prototype:

- The tab bar is visible on Plan, Discover, Saved, and Preferences.
- Recipe details, Shopping list, Settings, and modal sheets hide the tab bar.
- A pushed screen returns to its originating tab.
- Any tab change closes the active sheet and pushed view.
- The avatar at the top right of Plan opens Settings.
- The supermarket chip on Plan opens the supermarket preference sheet directly.
- An empty day and the “Build your week” action both enter Discover.

## 4. Screen inventory

### 4.1 Plan — home

Purpose: make the current week's status understandable at a glance and provide direct routes to complete or revise it.

Primary content:

- Time-based greeting and completion headline.
- Avatar/settings entry.
- Selected supermarket and current week range.
- Estimated shop total, weekly budget, amount remaining, and a budget status message.
- Shopping-list summary with checked/total items and circular progress.
- One section per configured cooking day.
- Filled-day recipe card with photo, tags, duration, servings, price, Swap, and Clear.
- Empty-day invitation with a suggested amount available per open day.
- “Build your week” and “Fill the rest for me” actions while the plan is incomplete.

Plan states:

| State | Headline and behavior |
|---|---|
| No dinners | “Let's fill the week”; all configured days are empty |
| Partial | “Your week is nearly set”; remaining count and build/autofill actions are visible |
| Complete | “Your week is ready to shop”; all configured days are filled and completion CTAs disappear |
| Comfortable budget | Positive mint/green treatment and remaining amount |
| Near limit | Caution treatment is specified but not fully applied on the live Plan card |
| Over budget | $0 left plus explicit overage and recovery-by-swap copy |
| Empty shopping list | 0 items and a route to add a dinner |
| Partially shopped | Checked/total count and circular percentage |

Transitions:

- Tap a filled card → Recipe details.
- Tap Swap → Swap sheet for that day.
- Tap Clear → the day becomes empty; totals and list derive again; success toast appears.
- Tap an empty day or Build your week → Discover.
- Tap Fill the rest for me → attempt to fill open days with eligible recipes, then return to Plan.
- Tap Shopping list → Shopping list pushed screen.
- Tap supermarket → supermarket preference sheet.
- Tap avatar → Settings.

### 4.2 Discover

Purpose: let the user browse one recipe at a time, understand its fit, and act without relying on hidden gestures.

Primary content:

- Full-bleed, vertically snapping recipe panels.
- Fixed progress pill showing dinners chosen and current spend/budget.
- Fixed “Fill the rest for me” action.
- Recipe photo with dark readability gradient.
- Fit status, title, time, household servings, estimated cost, tags, recommendation rationale, and source.
- Visible action rail: Save, Add to week, Recipe, Not for me, Share.
- Persistent four-tab bar.

Transitions and mutations:

- Vertical scroll → next/previous recipe panel.
- Save → toggles the saved collection and shows a toast.
- Add to week → Add-to-day sheet.
- Recipe → Recipe details.
- Not for me → removes the recipe from the current feed and records negative feedback.
- Share → intended native share/copy behavior; prototype only shows “Link copied.”
- Top back → Plan.
- Fill the rest for me → autofill attempt, then Plan.

Feed eligibility should eventually run in this order:

1. Hard exclusions: medical allergens and incompatible dietary restrictions.
2. Equipment eligibility: recipe must be cookable with available appliances.
3. Remove recipes already in this week and explicitly skipped recipes.
4. Soft ranking: dislikes, preferred proteins, meal vibes, cook time, price fit, history, and saved/cooked behavior.

The live prototype currently implements only step 3. It does not enforce the safety-critical allergen claims made by its preference copy.

### 4.3 Add recipe to day sheet

Purpose: make scheduling and its budget effect explicit before a single committing action.

Primary content:

- Drag handle, title, explanatory copy, close action.
- Recipe summary with thumbnail, time, servings, and cost.
- One row per configured cooking day.
- Each row states either “Free — nothing planned” or the meal that would be replaced.
- Selected row has a tinted background, green outline/chip, and check icon.
- Before/after budget bar, projected total, and remaining/over-budget message.
- Contextual CTA: Choose a day, Add to [day], or Replace [day]'s dinner.

State sequence:

```text
Closed
  → Open / no day selected
  → Day selected / preview recalculates
  → Committing
  → Success / Plan updated / sheet closed / toast
  ↘ Error / selection retained / retry or cancel
```

The exported “Choose a day” CTA is visually disabled and its handler refuses to commit, but it is still reported as enabled by the browser because it is a clickable `div`. Production must use a real disabled button.

### 4.4 Saved

Purpose: retrieve bookmarked or imported recipes and schedule them without returning to Discover.

Primary content:

- Saved count and helper text.
- Search by saved recipe.
- Filters: All, Recently saved, Cooked before, Imported.
- Horizontal collection cards: Fast nights, Batch cook, Feed friends, New collection.
- Saved recipe cards with image, source, tags, time, cost, Add to week, and unsave action.
- Empty-state illustration, explanation, and route to Discover.

Transitions and mutations:

- Search → filters the current saved set.
- Filter chip → selected/unselected state and result set update.
- Recipe card → Recipe details.
- Add to week → Add-to-day sheet.
- Heart → removes/adds saved state.
- New collection → intended collection creation flow; prototype only shows a toast.

The Imported filter intentionally demonstrates an empty state. There is no import input or parser in the prototype. The Saved header still says “3 recipes” while this filter shows zero results; product copy should distinguish the overall saved count from the filtered result count.

### 4.5 Preferences

Purpose: configure the inputs that affect price, portions, plan shape, ranking, eligibility, and list generation.

Top summary:

> [household] · [dinners per week] · [budget] at [supermarket] · [cook time]

Groups and effects:

| Group | Preference | Intended effect |
|---|---|---|
| The week | Supermarket | Prices and list |
| The week | Country & currency | Currency and units |
| The week | Household size | Portions, quantities, price |
| The week | Cooking days | Plan slots |
| The week | Weekly budget | Budget fit and ranking |
| The week | Cooking time | Ranking/eligibility policy to decide |
| Taste | Meal vibes | Soft ranking |
| Taste | Preferred proteins | Soft ranking |
| Taste | Dislikes | Soft down-ranking, not exclusion |
| Medical allergens | Allergens to exclude | Hard exclusion |
| Kitchen | Appliances | Hard equipment eligibility |

The user's requested structure also explicitly includes **dietary restrictions** and **schedule**. The export has cooking days and cooking time but no standalone dietary-restriction row. Add dietary restrictions as a hard eligibility preference, separate from medical allergens and dislikes.

Preference editing behavior:

- Tapping a row opens the common sheet.
- Single-select and multi-select values use option chips.
- Budget and household use numeric steppers.
- Changes remain draft state until Save.
- Save closes the sheet, updates the summary, derives affected plan/list data, and shows a toast.
- Cancel/backdrop discards the draft.
- Changes that invalidate or over-budget an existing plan need an explicit reconciliation policy; the prototype silently keeps scheduled recipes.

### 4.6 Recipe details

Purpose: support a scheduling decision and provide the complete cooking reference.

Primary content:

- Photo hero, back, and save action.
- Scheduled day badge when applicable.
- Recipe name and source.
- Total estimated price, price per serving, time, and serving count.
- Nutrition summary: calories, protein, carbs, and fat.
- Serving stepper and ingredient list.
- Numbered method.
- Personal notes.
- Sticky action: Add to week when unscheduled; Swap this meal when scheduled.

Transitions and mutations:

- Back → originating tab.
- Save → saved-state toggle.
- Serving stepper → ingredient quantity preview.
- Notes → should persist per user and recipe.
- Add → Add-to-day sheet.
- Swap → Swap sheet for the scheduled day.

The current stepper changes ingredient strings only. It does not update price, nutrition, or the scheduled plan's serving count, and notes are reset whenever the detail screen is reopened. Production must define whether this is a temporary cooking-scale preview or an edit to the scheduled meal, then keep all affected values consistent.

### 4.7 Shopping list

Purpose: provide one actionable, consolidated list for the active week and store.

Primary content:

- Back and share controls.
- Store and number of planned dinners.
- Estimated total and bought/total progress.
- Aisle groups: Produce, Meat & fish, Chilled & dairy, Pantry.
- Item rows with checked state, normalized quantity, estimated price, and source day/recipe.
- “Add your own item” action.
- Empty state when no meals are scheduled.

Behavior:

- The generated list updates whenever the plan, household, or relevant store/pricing inputs change.
- Exact ingredient names are merged in the prototype.
- Identical quantity strings display as `quantity × occurrence count`.
- Different quantity strings display with `+`.
- Multiple sources collapse to day abbreviations; a single source also names the recipe.
- Tapping a row toggles bought state and updates item, aisle, list, and Plan progress.
- Share should use the native share sheet or a clearly specified alternative.
- Custom items should remain separate from generated items but participate in progress.

The design says “generate the shopping list,” while the prototype generates it continuously. Recommended milestone behavior: generation is automatic and deterministic; “generated” describes the data origin, not an extra user step.

### 4.8 Settings — additional exported screen

Purpose: hold account and application settings outside meal preferences.

Exported rows:

- Profile identity.
- Notifications.
- Measurement units.
- Connected stores.
- Import a recipe.
- Subscription.
- Privacy & data.
- Help.
- Sign out.

Most rows are visual only and have no prototype transition. Settings is not one of the seven showcased board frames and is outside milestone 1. Authentication, subscription, paywall, and sign-out behavior must not be scaffolded as part of the first vertical slice.

### 4.9 Swap and preference sheets

The same sheet shell is reused for three body types:

- Day/recipe choice rows for add and swap.
- Option chips for single- and multi-select preferences.
- Numeric stepper for household and budget.

Swap rows show recipe name, cost, time, and price delta versus the current meal. The selected replacement updates the projected weekly spend. Committing returns to Plan with the replacement installed.

## 5. Verified happy path

The following exact path was verified in the live export. It is suitable as the canonical milestone-1 end-to-end fixture.

| Step | Screen/action | Expected derived state |
|---|---|---|
| 1 | Open Plan | 3 of 5 dinners; Honey Soy Chicken Monday, Chilli Tuesday, Stir-Fry Wednesday; `$35.40 / $80`; 25 unique list items; 3 checked |
| 2 | Enter Discover | Fixed progress pill remains `3 of 5` and `$35.40/$80` |
| 3 | Add Proper Carbonara and select Thursday | Preview is `$44.30 of $80`; `$35.70 still spare`; replacement warnings remain on occupied days |
| 4 | Commit Thursday | Plan becomes 4 of 5; budget becomes `$44.30`; list becomes 31 unique items; toast confirms the day and total |
| 5 | Return to Discover; add Weeknight Chicken Curry to Friday | Preview is `$56.70 of $80`; `$23.30 still spare` |
| 6 | Commit Friday | Plan headline becomes “Your week is ready to shop”; all 5 planned; budget is `$56.70`; list becomes 36 unique items |
| 7 | Open Shopping list | Store is Trader Joe's; 5 dinners; `$56.70`; 3 of 36 items checked |
| 8 | Check Broccoli | Overall progress becomes 4 of 36 and Produce becomes 2 of 11; returning to Plan must show the same progress |

The one-add milestone slice can stop after step 4 and still prove the state pipeline. The complete core loop requires supporting steps 5–8 as a repeat of the same flow.

## 6. Shared components

| Component | Responsibilities | Main variants/states |
|---|---|---|
| App screen shell | Safe areas, cream canvas, scrolling, fixed overlays | Tab screen, pushed screen, full-bleed photo screen |
| Bottom tab bar | Four primary destinations and active state | Active/inactive, hidden on pushed screens |
| Push header | Back, title/subtitle, optional share | Standard, hero overlay |
| Avatar button | Settings entry | Initials now; real profile later |
| Budget card | Spend, limit, remaining/overage, progress, guidance | Comfortable, near limit, over, stale price |
| Progress pill | Dinners chosen and spend in Discover | Partial, complete, over budget |
| Shopping summary card | List route and checked progress | Empty, partial, complete |
| Planned-meal card | Recipe summary and day actions | Filled, loading price, stale price |
| Empty-day card | Return to discovery | Available, no eligible recipes |
| Recipe feed panel | Full photo, fit, metadata, rationale, action rail | Saved/unsaved, fit/tight/over, skipped transition |
| Recipe list card | Saved recipe summary | Saved, unsaving, scheduling |
| Status/tag pill | Tag, fit, allergen, eligibility | Neutral, positive, caution, danger |
| Section header | Eyebrow plus rule and optional count | Neutral, medical/danger |
| Preference row | Label, current value, effect tag, chevron | Standard, safety-critical |
| Search field | Query entry and clear | Empty, typing, no results |
| Filter chip | Saved view or option | Selected, unselected, disabled |
| Collection card | Saved recipe grouping | Standard, new collection |
| Recipe hero | Image, readability overlay, save/back | Scheduled, unscheduled |
| Serving stepper | Minimum/maximum and quantity scale | Default, min disabled, max disabled |
| Ingredient row | Name, quantity, category cue | Scaled, unavailable price |
| Method step | Ordered cooking instruction | Standard |
| Notes field | Persisted user note | Empty, editing, saved/error |
| Shopping aisle group | Header, per-group progress, rows | Empty, partial, complete |
| Shopping item row | Required quantity, sources, price, bought state | Unchecked, checked, custom, unavailable |
| Bottom sheet shell | Modal presentation, title, close, focus management | Day choice, option chips, number stepper |
| Toast | Short confirmation and optional undo | Success, informational, recoverable error |
| Empty-state panel | Explain absence and offer one next action | Saved, filtered results, shopping list, feed exhausted |
| Skeleton card | Preserve layout during fetch | Recipe/list/price loading |
| Error banner | Explain failure, fallback, and recovery | Stale pricing, offline, retry |

## 7. Visual system

### 7.1 Typography

| Token | Family | Size / line height / weight | Intended use |
|---|---|---|---|
| `type.display` | Bricolage Grotesque | 30 / 31.8 / 800; tracking about `-0.032em` | Screen titles and large money |
| `type.section` | Bricolage Grotesque | 21 / 24.15 / 800; tracking about `-0.026em` | Section and sheet titles |
| `type.cardTitle` | Open Runde | 16.5 / 20.6 / 700; tracking about `-0.012em` | Recipe names in cards/rows |
| `type.body` | Open Runde | 14 / 21 / 500 | Ingredients, descriptions, method |
| `type.meta` | Open Runde | 12 / 12–16.2 / 600 | Time, servings, price, compact labels |
| `type.eyebrow` | Open Runde | 11 / 11–14.3 / 700; tracking `0.13em`; uppercase | Section dividers and category labels |

Observed one-off sizes include 38, 33, 31, 29, 27, 26, 20, 18, 15.5, 14.5, 13.5, 12.5, 11.5, 10.5, 10, and 9.5 px. Production should map these to a smaller semantic type scale and support dynamic text. The 9.5–11 px labels are too small to rely on for essential information.

Open Runde is bundled locally at weights 400, 500, 600, and 700. Bricolage Grotesque is requested from Google Fonts at weights 600, 700, and 800.

### 7.2 Core color tokens

| Token | Hex | Use |
|---|---|---|
| `color.forest` | `#0E2A1C` | Primary text, dark surfaces, secondary actions |
| `color.deepPine` | `#143824` | Dark-card and hero gradient top |
| `color.deepestPine` | `#0A1F15` | Dark gradient bottom and Discover canvas; used but absent from the board's named swatches |
| `color.leaf` | `#3FBE55` | Primary action and selected control |
| `color.bottle` | `#186B2C` | Green text, icons, links |
| `color.mint` | `#8FE7A8` | Positive information on dark surfaces |
| `color.wash` | `#DCF3E1` | Selected backgrounds and light green tints |
| `color.cream` | `#FBF5EA` | App canvas |
| `color.white` | `#FFFFFF` | Raised cards and input surfaces |
| `color.sand` | `#EDE5D5` | Tracks and primary dividers |
| `color.ink` | `#1D1B18` | Body copy |
| `color.stone` | `#8F8B82` | Metadata and labels |
| `color.citrus` | `#E9B23C` | Near-budget caution |
| `color.tomato` | `#E4553A` | Saved accent and over-budget accent |

### 7.3 Supporting and state colors

| Semantic group | Values observed |
|---|---|
| Secondary text | `#4A4741`, `#6E6A62`, `#A09B92`, `#A5A099`, `#BAB5AA` |
| Neutral controls/dividers | `#F2EBDC`, `#E4DCCA`, `#D2CBBB`, `#DCD5C6`, `#DCD3C0` |
| Alternate surfaces | `#F7F1E6`, `#FCFAF5`, `#F1EADB` |
| Success tints | `#E9F6ED`, `#C4E6CE` |
| Caution | `#B98307`, `#7A5604`, `#8A6104`, `#FDF0D2`, `#F5D07A` |
| Danger/error | `#C4472C`, `#B7351F`, `#8C2A17`, `#FCE3DC`, `#FCEAE4`, `#FFF7F5`, `#F3B7A9` |
| Ingredient category cues | `#5BAE4F`, `#C4472C`, `#4E8FD1`, `#B98307` |
| Image fallback | `#20372A`, `#DCD3C0` |

The external design-board canvas uses `#EDE4D2`; it is not an app token. Colors in the simulated iOS chrome are presentation-only and must not be included in the app theme.

### 7.4 Spacing, size, radius, shadow, and motion

Stated rules:

- Baseline grid: 4 px.
- Screen gutter: 20 px.
- Pill radius: 999 px.
- Card radius: 22 px.
- Row radius: 18 px.
- Sheet top radius: 28 px.
- Thumbnail radius: 14 px.
- Minimum touch target: 44 × 44 px.

Recommended spacing tokens:

| Token | Value |
|---|---|
| `space.1` | 4 px |
| `space.2` | 8 px |
| `space.3` | 12 px |
| `space.4` | 16 px |
| `space.5` | 20 px |
| `space.6` | 24 px |
| `space.7` | 28 px |
| `space.8` | 32 px |

The export frequently uses off-grid values such as 5, 7, 9, 11, 13, 14, 15, 17, 18, 19, 22, 26, and 30 px. Treat the 4 px statement as intent and normalize implementation spacing through tokens.

Additional radii observed: 26 for the budget card; 20 for compact panels and lists; 16 for search and some thumbnails; 14, 12, and 10 for nested controls. Use semantic radius tokens rather than copying each inline value.

Shadows are warm, diffuse, and low contrast. Cards use a 1 px near shadow plus a large negative-spread dark-green shadow. Primary actions use a leaf-green glow. Preserve the hierarchy, not the literal browser shadow strings.

Motion observed:

- Budget width: 450 ms, emphasized ease.
- Dinner/list progress: 400 ms, emphasized ease.
- Sheet: 340 ms, upward motion with a slight overshoot.
- Scrim fade: 200 ms.
- Toast: 2.6-second enter/hold/exit animation.
- Discover: mandatory vertical scroll snapping.

Production must disable or simplify nonessential motion when Reduce Motion is enabled.

## 8. Prototype data and variables

### 8.1 External demo properties

| Property | Export values |
|---|---|
| Weekly budget | Default 80; editor range 40–240; step 10 |
| Household size | Default 1; outer editor range 1–6; preference sheet range 1–8 |
| Market | Trader Joe's, Whole Foods, Safeway, Costco, Aldi |

The two household maxima conflict and require one production rule.

### 8.2 Initial shared state

| Field | Initial value / purpose |
|---|---|
| `tab` | `plan` |
| `view` | `null`; becomes `recipe`, `list`, or `settings` |
| `recipeId` | `curry` |
| `sheet` | `null`; holds add, swap, or preference draft |
| `plan` | Mon honey-soy, Tue chilli, Wed stir-fry, Thu empty, Fri empty |
| `saved` | curry, caesar, chopped |
| `checked` | Jasmine rice, Soy sauce, Garlic |
| `skipped` | Empty recipe-id list |
| `serves` | 1; temporary Recipe-detail stepper |
| `note` | Empty and nonpersistent |
| `query` | Empty Saved search |
| `savedFilter` | All |
| `toast` | Empty transient message |
| `prefs` | Country, market, household, cooking days, budget, time, vibes, proteins, dislikes, allergens, appliances |

### 8.3 Recipe fixture

| ID | Recipe | Time | Base cost | Tags | Ingredients |
|---|---|---:|---:|---|---:|
| `honeysoy` | Honey Soy Chicken & Broccoli | 25m | $11.60 | Fakeaway; Protein-packed | 8 |
| `chilli` | Smoky Chilli Con Carne | 45m | $13.60 | Healthy comfort; Batch friendly | 9 |
| `stirfry` | Ginger Rice Noodle Stir-Fry | 20m | $10.20 | Speedy; Meat-free | 10 |
| `curry` | Weeknight Chicken Curry | 40m | $12.40 | Healthy comfort; Freezes well | 10 |
| `carbonara` | Proper Carbonara | 20m | $8.90 | Speedy; Five ingredients | 6 |
| `caesar` | Charred Chicken Caesar | 25m | $9.80 | Low calorie; Protein-packed | 7 |
| `chopped` | Big Chopped Salad | 15m | $9.40 | Speedy; Meat-free | 9 |
| `steak` | Steak Frites, Chimichurri | 35m | $18.75 | Treat night; Protein-packed | 10 |

Recipe prices are sums of ingredient price estimates. The prototype multiplies that entire base price by household size.

### 8.4 Derived values

The export derives:

- Configured cooking days from Preferences.
- Filled days and remaining open days.
- Weekly spend from each scheduled recipe's price × household.
- Remaining budget and budget utilization.
- Feed recipes by removing scheduled and skipped recipes.
- Budget-fit status for each feed recipe.
- Shopping items from the active plan.
- Unique list total, checked total, per-aisle progress, and circular progress.
- Day-assignment and swap previews.
- Complete/partial Plan headline.
- Saved result sets from saved IDs, a filter, and a name query.

This is the right high-level dependency direction. Production should move these calculations into pure, tested domain functions and selectors.

## 9. States and transitions

### 9.1 Cross-product state matrix

| Surface | Empty | Loading | Error/stale | Selected/checked | Disabled |
|---|---|---|---|---|---|
| Plan | No dinners; empty day cards | Meal and price skeletons needed | Price-refresh banner; retain last known totals | Current tab; filled day | Autofill when no eligible recipe or no open day |
| Discover | No eligible recipes / feed exhausted needed | Full-panel skeleton or stable image placeholder | Recipe/price retry or stale estimate | Saved heart; active tab | Add when recipe is not schedulable; share while unavailable |
| Add sheet | No cooking days is an error state | “Adding…” CTA and locked choices | Commit error with selection retained | Chosen day | CTA before day selection; occupied/locked day if policy requires |
| Saved | Nothing saved; no imports; no search results | Recipe-card skeleton | Load/import error | Filter chip; saved heart | Add when no configured day or recipe ineligible |
| Preferences | “None yet” values | Save/validation progress if remote | Validation or save error | Option chips | Stepper at min/max; incompatible combinations |
| Recipe | Missing recipe/error rather than empty | Hero/content skeleton | Content or price unavailable | Saved heart; scheduled badge | Serving − at 1, + at max; Add when ineligible |
| Shopping | Nothing to buy yet | Group/list skeleton | Stale-price banner with last-known data | Bought checkbox | Item unavailable; actions while regenerating |

Only some of these are wired. The board provides static examples of a loading skeleton, stale-price error, disabled CTA, and status variants. Production should not claim those states complete until they are reachable and tested.

### 9.2 Budget state rules

The intended weekly rules are:

- Comfortable: spend is no more than 85% of the limit.
- Near limit: spend is above 85% and no more than the limit.
- Over: spend exceeds the limit.

The Discover fit pill uses a different rule: a candidate is “Tight, but it fits” when it consumes more than 55% of the current remaining budget. Keep weekly status and candidate-fit status as separate named calculations.

Over-budget states must show the exact overage and a recovery route such as Swap. Do not encode status by color alone.

### 9.3 Shopping list reconciliation

Recommended stable behavior when the plan changes:

1. Regenerate required items from the plan using canonical ingredient IDs and structured quantities.
2. Preserve checked state for an unchanged logical item.
3. Reopen an item if its required quantity increased after it was checked, or clearly mark the delta as newly required.
4. Remove generated items no longer required, but never remove custom user items.
5. Keep price staleness separate from bought state.

The prototype keys checked state only by display name, so removing and re-adding an ingredient can make it reappear already checked.

## 10. Asset inventory and production disposition

### 10.1 Included visual assets

- Eight recipe images in `photos/`: Caesar, Carbonara, Chilli, Chopped Salad, Curry, Honey Soy, Steak, and Stir-Fry.
- Eight byte-identical duplicates in `uploads/photos-*`.
- Eight historical iPhone screenshots in `uploads/IMG_*.PNG`.
- Four local Open Runde font files.
- Bricolage Grotesque loaded from Google Fonts.
- Inline SVG icons for navigation, back, add, heart, recipe/list, skip, share, star/rationale, search, shopping, swap, clear, chevron, alert, check, and progress.
- CSS-rendered status bar and iPhone frame in `ios-frame.jsx`.
- A board thumbnail in `.thumbnail`.

### 10.2 Assets that must be replaced or cleared before production

| Asset/content | Required action |
|---|---|
| All eight recipe photos | Replace with commissioned/owned media or record explicit commercial rights, creator credit, permitted crops, and expiry; current provenance is incomplete |
| Caesar photo | Metadata identifies a copyright holder (“Ren Fuller”); do not ship without a matching license |
| Historical screenshots | Never ship; they contain third-party imagery, branding, emoji/device chrome, and a superseded UI |
| Trader Joe's and other store branding | Use names/logos only under an approved trademark/partner policy; the current app uses initials rather than the historical logo |
| Recipe names, sources, ingredient lists, and instructions | Complete content/licensing and attribution review for Meera Sodha, Bon Appétit, Delish, Serious Eats, and other named sources |
| Open Runde | Add the font license and distribution permission to the repository; the archive contains no license file |
| Bricolage Grotesque | Pin and self-host an approved build if allowed, include its license, and avoid runtime dependence on Google Fonts |
| Inline SVG icons | Convert to a documented production icon set with consistent stroke and accessible labels; verify original authorship/license |
| Avatar identity and email | Replace the hardcoded name/email with neutral mock data until account work is in scope |
| iOS device chrome | Presentation-only; do not package it as application UI |

Every production image record should include an accessibility description and rights metadata. Decorative recipe-card crops may be hidden from screen readers if the recipe title provides the same identity; hero photos should have a meaningful description when relevant.

## 11. Accessibility review

The design has strong non-color cues in several status pills, but the exported prototype is not accessible application code.

### Critical semantic gaps

Browser inspection of the live Shopping list found 39 pointer-styled click targets, zero native buttons, zero links, zero keyboard-capable custom controls, and zero ARIA labels. Equivalent patterns appear throughout the other screens.

Production requirements:

- Use native buttons, links, text inputs, checkboxes, tabs, and dialog semantics.
- Provide accessible names for every icon-only control.
- Expose selected, saved, expanded, checked, disabled, busy, current-tab, and scheduled states.
- Give bottom sheets dialog semantics, focus trapping, Escape/back dismissal, focus restoration, and a non-drag close path.
- Announce plan, budget, list-progress, save, skip, and commit results through an appropriate live region without duplicate speech.
- Associate visible labels with Search and Notes; use a multiline text area for notes.
- Preserve logical focus order despite fixed action rails and sticky CTAs.

### Touch targets

The board claims a 44 px minimum, but the export includes smaller controls: 26 px Discover back, 29 px serving buttons, 31 px sheet close, 36 px Saved heart, 38 px pushed-screen header buttons, and 40 px Recipe hero buttons. Expand the hit area to at least 44 × 44 logical pixels without changing the visible icon size.

### Contrast

Measured examples:

| Pair | Contrast | Result |
|---|---:|---|
| Forest on Cream | 14.16:1 | Pass |
| Ink on Cream | 15.83:1 | Pass |
| Bottle on Cream | 6.09:1 | Pass for normal text |
| Mint on Deep pine | 8.74:1 | Pass |
| White on Deep pine | 12.96:1 | Pass |
| Stone on Cream | 3.13:1 | Fails for normal-size text |
| Stone on White | 3.40:1 | Fails for normal-size text |
| White on Leaf | 2.41:1 | Fails even the 3:1 large-text threshold |
| Tomato on Cream | 3.42:1 | Fails for normal-size text |

The primary leaf-green button must not use white text without changing one of the colors. Forest text on Leaf is 6.37:1 and is the closest existing compliant pairing, though it changes the visual character. Revisit muted metadata colors as well.

### Responsive text and motion

- Support Dynamic Type/font scaling without clipping fixed-height cards.
- Test long recipe/store names and translated strings.
- Keep status and price meaning outside truncated text.
- Provide a Reduce Motion mode for sheet overshoot, progress animation, toast motion, and scroll snapping.
- Do not make a mandatory snap feed trap keyboard or switch users.
- Respect safe areas on devices with and without a Dynamic Island/home indicator.

## 12. Proposed application data model

Use IDs, structured quantities, ISO dates/currencies, and integer minor monetary units. Avoid display strings as domain data.

### Core entities

```text
UserPreferences
  id
  countryCode
  currencyCode
  measurementSystem
  storeId
  householdSize
  cookingWeekdays[]
  weeklyBudgetMinor
  maxWeeknightMinutes
  dietaryRestrictionIds[]
  medicalAllergenIds[]
  dislikedIngredientIds[]
  preferredProteinIds[]
  mealVibeIds[]
  applianceIds[]

WeekPlan
  id
  weekStartDate
  timeZone
  storeId
  currencyCode
  slots[]
  revision
  updatedAt

MealSlot
  date
  weekday
  recipeId | null
  servings

Recipe
  id
  title
  sourceName
  sourceUrl | null
  imageAssetId
  baseServings
  activeMinutes
  totalMinutes
  estimatedCostMinor
  currencyCode
  nutritionPerServing
  tagIds[]
  dietaryRestrictionIds[]
  allergenIds[]
  requiredApplianceIds[]
  ingredients[]
  steps[]
  rights

RecipeIngredient
  ingredientId
  quantityValue
  quantityUnit
  preparation
  estimatedCostMinor

Ingredient
  id
  canonicalName
  aisleId
  allergenIds[]
  aliases[]

ShoppingList
  id
  weekPlanId
  generatedFromRevision
  storeId
  currencyCode
  items[]
  generatedAt

ShoppingListItem
  id
  ingredientId | null
  displayName
  requiredQuantities[]
  estimatedCostMinor | null
  sourceMealRefs[]
  isCustom
  isChecked
  checkedAt | null

SavedRecipe
  recipeId
  savedAt
  origin: curated | imported
  collectionIds[]

RecipeFeedback
  recipeId
  kind: skipped | liked | disliked | cooked
  createdAt

RecipeNote
  recipeId
  text
  updatedAt

PriceQuote
  ingredientId
  storeId
  packageQuantity
  priceMinor
  currencyCode
  observedAt
  source

MediaAsset
  id
  uri
  altText
  credit
  license
  expiresAt | null
```

### Derived domain services

- `evaluateRecipeEligibility(recipe, preferences)` — safety and equipment gates.
- `rankRecipes(recipes, plan, preferences, feedback)` — soft ranking only.
- `priceRecipe(recipe, servings, storeQuotes)` — returns value plus freshness/confidence.
- `summarizeBudget(plan, pricedRecipes, budget)` — comfortable, near, or over.
- `aggregateShoppingList(plan, recipes, customItems, priorProgress)` — canonical merge and checked-state reconciliation.
- `previewAssignment(plan, recipeId, slotDate)` — replacement, cost delta, and affected list.
- `assignRecipe(plan, recipeId, slotDate)` and `swapRecipe(...)` — immutable plan mutations.

Allergen and dietary eligibility must be testable, deterministic, and enforced before ranking, autofill, or substitution.

## 13. Recommended implementation architecture

Recommended client stack for a cross-platform mobile product:

- React Native with Expo and TypeScript.
- Expo Router for the four tabs, pushed screens, and modal routes.
- A small persisted client store for the active plan, preferences, Saved state, shopping progress, and fixture version. Zustand with an AsyncStorage adapter is a reasonable fit; a typed reducer is also sufficient for milestone 1.
- TanStack Query only when asynchronous recipe, price, import, or account data exists. Do not put purely derived plan totals in a server-state cache.
- Pure TypeScript domain functions for scheduling, eligibility, pricing, budget status, and list aggregation.
- Repository interfaces with a mock implementation first and remote/local implementations later.
- React Native Testing Library for components/integration, a standard TypeScript unit runner for domain functions, and Maestro or Detox for the vertical-slice device journey.

Suggested feature-first layout after scaffolding approval:

```text
app/
  (tabs)/
    plan
    discover
    saved
    preferences
  recipe/[recipeId]
  shopping-list
  settings

src/
  design-system/
    tokens
    components
  domain/
    planning
    recipes
    pricing
    shopping
    preferences
  features/
    plan
    discover
    scheduling
    shopping-list
    recipe-details
    saved
    preferences
  data/
    contracts
    mock
    persistence
  testing/
    fixtures
    accessibility
```

Architecture boundaries:

- Screens compose features; they do not calculate budget or list totals.
- Domain functions accept plain typed data and have no React dependency.
- The plan is stored; spend, completion, and generated items are selected/derived.
- UI components consume semantic tokens; no copied inline colors or spacing.
- Money is stored in minor units with an ISO currency, not floating-point dollars.
- Dates are stored as ISO local dates plus the plan time zone, not weekday labels.
- Quantities use value/unit structures and canonical ingredient IDs.
- Mock fixtures use the exact verified path values so tests and screenshots share one source.
- Async repositories return loading, stale, error, and retry metadata; the UI does not invent network state.

For milestone 1, keep all data local and deterministic. A backend, account model, paywall, subscription SDK, remote price refresh, recipe importer, and notification service are deliberately unnecessary.

## 14. Inconsistencies and missing product decisions

### Resolve before milestone 1

1. **Fourth-tab label:** Preferences or You. Recommendation: Preferences for the first release.
2. **Canonical price meaning:** cost of consumed ingredient quantities versus cost of store packages. The current totals assume linear ingredient estimates.
3. **Shopping-list generation:** automatic derivation is recommended; confirm there is no explicit Generate action.
4. **Servings:** decide whether household size sets every scheduled meal and whether Recipe-detail scaling is preview-only or plan-editing.
5. **Asset/content rights:** replace or clear all recipe media and attributed content before public distribution.
6. **Accessibility color correction:** choose a compliant primary-button text/background pairing.
7. **Dietary restrictions:** add the requested hard-eligibility field and define supported values.
8. **Milestone fixture:** approve the verified Carbonara-to-Thursday path and exact totals as the acceptance baseline.

### Resolve before safety/ranking work

9. Medical allergens, dietary restrictions, and appliances are described as hard filters but are not applied by the prototype.
10. Decide whether cook time is a hard filter, a weekday/weekend rule, or ranking only.
11. Define preference-change reconciliation when an existing meal becomes ineligible.
12. Define allergen data provenance, warnings, cross-contamination policy, and liability copy.
13. Define Not for me undo, duration, and management.
14. Define autofill priorities, behavior when the budget cannot fill the week, and whether it may repeat a recipe.

### Resolve before real pricing and internationalization

15. Changing supermarket currently changes only the label; all ingredient prices remain fixed.
16. Country/currency changes do not change the `$` formatter, stores, units, or quantities.
17. Household pricing scales linearly, which ignores package sizes and pantry carryover.
18. Pantry overlap is charged per recipe and summed; decide whether “estimated shop” represents required purchase or recipe allocation.
19. Ingredient merging is exact-name only; `Egg` and `Eggs`, aliases, unit conversion, and package rounding need canonical rules.
20. Price freshness and confidence need a timestamp and stale-state policy.

### Interaction and content gaps

21. Near/over budget styling on the live Plan progress bar stays green even though the design system specifies caution and striped overage states.
22. When already over budget, an empty day can say “Around $6 left” because the prototype clamps the hint to a minimum while the budget card says $0 left.
23. Resetting the demo plan preserves changed preferences; acceptable for a board tool, not a product behavior.
24. Serving changes do not update price or nutrition, and ingredient amounts are shown as string multiplication rather than normalized totals.
25. Recipe notes are not persisted.
26. Recently saved and Cooked before are hardcoded approximations rather than timestamp/history queries.
27. Collections, share, custom shopping items, and most Settings rows only display a toast or no action.
28. Search matches recipe title only; define source/tag/ingredient search and no-results copy.
29. Week range is hardcoded; define week navigation, rollover, past-week behavior, locale, and time zone.
30. Shopping checked state is keyed by display name and can remain checked across removal/re-addition.
31. Plan copy says “1 nights to fill”; pluralization needs correction.
32. The design claims a 4 px spacing grid and 44 px touch minimum, but the export violates both.
33. Static loading/error examples are not reachable in the live prototype.
34. The original product-design prompt is absent from the supplied archive.

## 15. Handoff decisions recommended for approval

| ID | Recommendation |
|---|---|
| D-01 | Route name and first visible label: Preferences |
| D-02 | Automatically derive the list after every committed plan mutation |
| D-03 | Store money in minor units and treat milestone estimates as mock consumed-quantity cost |
| D-04 | Treat household size as the scheduled serving default; make Recipe-detail scaling preview-only until a later edit-flow decision |
| D-05 | Use medical allergens and dietary restrictions as hard exclusions; dislikes as soft ranking |
| D-06 | Keep Plan as the only stored weekly source of truth; derive spend, completion, and generated list data |
| D-07 | Use the exact verified 3-meal fixture and Carbonara-to-Thursday path for milestone-1 tests |
| D-08 | Use placeholders or rights-cleared assets in code; do not import the attached recipe photos into a distributable build by default |
| D-09 | Exclude Settings, accounts, subscription, paywall, import, collections, sharing, and autofill implementation from milestone 1 |
| D-10 | Make real semantic controls and WCAG-compliant colors part of the milestone definition of done, not a cleanup phase |

## 16. Handoff completion checklist

- [x] Complete archive inventory.
- [x] All rendered screens and modal variants identified.
- [x] Primary and secondary navigation documented.
- [x] Happy path verified with exact values.
- [x] Shared data and derivation rules documented.
- [x] Empty, loading, error, selected, checked, and disabled states catalogued.
- [x] Visual tokens and observed inconsistencies documented.
- [x] Assets and production-replacement requirements documented.
- [x] Accessibility risks documented with measured examples.
- [x] Proposed data model and architecture documented.
- [x] Open decisions and implementation gates documented.
- [ ] Product/design review approves or amends D-01 through D-10.
- [ ] Original product-design prompt is supplied if it contains additional requirements.
