# Heft — Agent Context

> **North Star:** Every pixel exists to get you back to the barbell faster.

This file gives any AI agent working in this folder the context needed to make good decisions without re-reading everything from scratch.

---

## Platform Target — Non-Negotiable

**Minimum deployment target: iOS 26. No exceptions.**

Heft is a premium app built for the current platform and forward. Older iOS versions are not supported and never will be. Any agent working in this project must operate under the following constraints at all times:

- **Always reference iOS 26+ documentation.** If an API or pattern exists in an older form and was updated or replaced in iOS 26, use the iOS 26 version.
- **Liquid Glass is the material for controls and chrome.** Tab bars, navigation bars, toolbars, and buttons get Liquid Glass automatically when you use standard SwiftUI components — do not fight it or disable it. For content surfaces (cards, sheets, modals, custom overlays), use the standard material hierarchy: `.ultraThinMaterial`, `.thinMaterial`, `.regularMaterial`, or `.thickMaterial`. Never use opaque backgrounds or plain `Color` fills for any surface. No conditional `if #available` checks — these materials are always available on iOS 26.
- **No backward-compatibility shims.** Do not write `if #available(iOS 26, *)` guards. Do not write `@available` fallback branches. The deployment target enforces iOS 26 — compatibility code is dead weight and must never be added.
- **SwiftUI-first, latest idioms only.** Use the most current SwiftUI APIs. If something was deprecated or superseded in iOS 26, use the replacement. Do not reference UIKit patterns unless no SwiftUI equivalent exists.
- **SwiftData only.** CoreData is not used anywhere in this project. All persistence goes through SwiftData with CloudKit sync.
- **Foundation Models on-device.** Apple Intelligence APIs are available as standard — not gated behind `#available` checks.
- **watchOS 26+ for the companion app.** Same philosophy applies to the Watch target.

When in doubt about any API, pattern, or design choice: ask "what does the iOS 26 documentation say?" and use that answer.

---

## What Heft Is

A premium iOS workout logger. Single conviction: the fastest workout logging app ever made. A set must be loggable in **under 2 seconds** from the active workout screen. This is a hard constraint, not an aspiration. Every feature decision is measured against it.

The market is crowded with apps that add social feeds, AI-generated programs, gamification badges, and subscriptions. Heft does none of that. It is fast, physical, and invisible.

**Three Pillars:**
1. **Speed Above All** — sub-2-second set logging, always
2. **Satisfying by Default** — Liquid Glass on controls, standard materials on content surfaces, haptic feedback, 60fps animations, makes effort feel physical
3. **Intelligence Removes Friction** — smart auto-fill, natural language input, suggests next weight, asked exactly once

---

## Files in This Folder

| File | What it is |
|------|-----------|
| `heft_wireframes.html` | iOS app wireframe — open in any browser, fully interactive |
| `heft_watchos.html` | watchOS companion wireframe — open in any browser |
| `Heft_Product_Spec.docx` | Full product specification |
| `Heft_Build_Order_Guide.docx` | Developer build order — 26 sections, hand one at a time to a developer |
| `Heft_SwiftData_Architecture.docx` | SwiftData model and data layer spec |

---

## Wireframe Architecture

Both HTML wireframes are **single self-contained files** with JS-driven screen navigation.

### Navigation pattern
```javascript
showScreen('screen-id', document.querySelectorAll('.nav-btn')[n])
```
Nav button indexes are **positional** — order matters. Current index map for `heft_wireframes.html`:

| Index | Screen |
|-------|--------|
| \[0\] | home-idle |
| \[1\] | home-active |
| \[2\] | home-rest |
| \[3\] | history |
| \[4\] | exercise-detail |
| \[5\] | routinebuilder |
| \[6\] | summary |
| \[7\] | settings |
| \[8\] | onboarding |
| \[9\] | healthkit |
| \[10\] | workout-empty |
| \[11\] | routinebuilder (New Routine entry) |
| \[12\] | home-active (duplicate path) |
| \[13\] | exerciseconfig |
| \[14\] | proupgrade |

When adding new screens: **always append a new nav button to the end** of `.screen-nav` to avoid breaking existing hardcoded index references.

### Key interactive elements
- **Exercise `···` button** → `openExerciseMenu(exerciseName)` → bottom sheet overlay `#exercise-menu-overlay`
- **Set type chips** — W (warmup, amber), N (normal, dim), D (dropset, blue) — on each set row, CSS grid `24px 34px 1fr 1fr 44px`
- **Pro Upgrade screen** (`screen-proupgrade`) — Annual $14.99/yr vs Lifetime $49.99 featured card
- **Exercise Config sheet** (`screen-exerciseconfig`) — set count stepper, rep range min/max, rest time chips, Remove from Routine

### Dynamic Mesh canvas
`transition(state)` calls are keyed to screen names. Both `proupgrade` and `exerciseconfig` are registered in `meshMap` inside `showScreen()`. When adding a new screen, register it there too.

---

## Data Architecture (SwiftData)

Core principle: **the UI never performs calculations.** Every number displayed is either a raw stored value or a pre-computed summary. Business logic lives exclusively in `@ModelActor`, never in Views or ViewModels.

**Three-layer separation:**

| Layer | Responsibility | Technology |
|-------|---------------|------------|
| Raw records | Immutable workout data | SwiftData `@Model` |
| Aggregation | Pre-computed analytics summaries | Background `@ModelActor` |
| Display | Reactive UI, no business logic | SwiftUI `@Observable` |

**Key models:**
- `ExerciseDefinition` — master catalogue, changes rarely, drives the exercise picker
- `RoutineTemplate` / `RoutineEntry` — named workout templates with ordered exercises and default sets/reps. Editing a template does **not** affect historical workout records (denormalized at log time)
- `WorkoutSession` — root of every logging record; `startedAt` is set when first set is logged, not when screen opens
- `SetRecord` — atomic unit; stores weight, reps, setType (normal/warmup/dropset), duration
- `ExerciseSnapshot` — denormalized exercise name at time of workout (survives catalogue edits)

**PR detection** — `currentPR`, `previousPR`, `prDate` are updated **synchronously on main actor** immediately when a set is logged, before any background processing. This guarantees the PR Moment screen renders with zero latency.

**Sync:** SwiftData for all users (local SQLite). CloudKit sync is a **Pro-only feature** — free tier stores data locally only. Pro users get zero-configuration CloudKit sync via SwiftData ModelConfiguration with cloudKitDatabase. Never enable CloudKit for a free entitlement.

---

## Business Model

| Tier | Price | Contents |
|------|-------|---------|
| Free | $0 | Unlimited logging, unlimited exercises, 90 days history |
| Pro Annual | $14.99/yr | Everything below |
| Pro Lifetime | $49.99 one-time | Advanced analytics, NL Input, Apple Watch, Live Activity, iCloud sync, Dynamic Mesh |

Revenue target: **$10M ARR** as bootstrap goal. 100K downloads × 5% paid conversion at scale.

---

## Build Order (summary)

Full detail in `Heft_Build_Order_Guide.docx`. Phase summary:

1. **App Shell** — SwiftUI tab nav, theme tokens, data models, persistence
2. **Usable Workout** — full logging loop, rest timer, finish+save, set type chips, exercise context menu, Exercise Config sheet
3. **Rewarding** — history, exercise detail, PR detection, volume trends, Apple Health sync
4. **Premium Polish** — settings, Pro Upgrade IAP screen (StoreKit 2), Dynamic Mesh, visual refinement
5. **Expansion** — NL Input, Apple Watch companion, iCloud sync, advanced analytics, widgets

---

## Design Tokens (approximate)

Colors are defined as named **Color Sets in Assets.xcassets** (not as Swift hex constants). A `Color+Tokens.swift` extension exposes them type-safely as `Color.heftBackground`, `Color.heftAccent`, etc. Non-color tokens live in `DesignTokens.swift`. See §2 of the Build Order Guide for the full spec.

### Background system — three layers

Each theme has its own subtly hue-shifted background base (not a single flat `#050505`). When the user switches theme, both `heftAccent` and `heftBackground` swap together from `@AppStorage`.

On top of the background base sits a **spotlight layer** — a single radial gradient tinted from `heftAccent.opacity(0.2)`, positioned slightly off-centre. This is derived in code, not a Color Set. For Pro users with Dynamic Mesh enabled, the spotlight is replaced by a `MeshGradient` whose control-point colors are defined in `MeshTheme.swift` (not in the asset catalog — they are runtime-animated `Color` values).

```
// Per-theme background bases — Color Set names in Assets.xcassets
BackgroundMidnight   #0C0C14   default — dark with indigo cast
BackgroundEmber      #0D0905   dark with warm brown cast
BackgroundGraphite   #0E0F10   dark neutral
BackgroundAbyss      #03060F   dark with navy cast
BackgroundMesh       #06040F   dark with purple cast

// Theme accents — Color Set names in Assets.xcassets
Accent               #7C7FF5   Midnight Strength (default)
AccentEmber          #E8622A   hot iron orange
AccentGraphite       #8E9AAB   cool silver-slate
AccentAbyss          #0A84FF   Apple system blue (dark)
AccentMesh           #BF5AF2   Apple system purple (dark)

// Shared surface Color Sets
Surface              #0F1117   card / sheet surface (same across all themes)
SurfaceElevated      #161B25   cards nested on top of other cards

// Semantic Color Sets
HeftRed              #FF453A   errors, destructive actions, rest timer final phase
HeftGreen            #34D399   PR badges, success, rest timer start phase
HeftAmber            #F59E0B   warmup set chips, rest timer mid phase
HeftGold             #FFD60A   Pro "Best Value" badge, workout complete glow, streak milestones

// UI structure Color Sets
Separator            #1E2530   1pt lines between list rows, section dividers
Border               #252E40   card outlines, input field edges

// Charts Color Set
ChartSecondary       #2DD4BF   second data series (teal reads cleanly on dark)

// NOT Color Sets — derived in code
textPrimary:      Color.white.opacity(0.92)
textMuted:        Color.white.opacity(0.48)
textFaint:        Color.white.opacity(0.28)
spotlight:        Color.heftAccent.opacity(0.2)  radial gradient, free-tier background layer
heatmap levels:   Color.heftAccent.opacity(0.2 / 0.4 / 0.7 / 1.0)
MeshGradient states: defined in MeshTheme.swift as SwiftUI Color constants

// Motion — ALL animations use .spring() physics, never .linear or .easeInOut
standard spring: Animation.spring(response: 0.3, dampingFraction: 0.75)
fast spring:     Animation.spring(response: 0.15, dampingFraction: 0.75)
```

---

## Icons & Illustrations

**Equipment type icons** — SF Symbols does not have sufficient coverage for all equipment categories. Use 6 custom SVG icons exported as single-scale PDF assets to Assets.xcassets (renders as vector at any size, zero runtime cost):

| Asset name | Equipment |
|---|---|
| `icon-barbell` | Barbell |
| `icon-dumbbell` | Dumbbell |
| `icon-cable` | Cable machine |
| `icon-machine` | Plate-loaded / selectorised machine |
| `icon-bodyweight` | Bodyweight |
| `icon-band` | Resistance band |

These are the only custom icon assets in the project. Design them as simple, consistent line-art at 28×28pt. Reference via `Image("icon-barbell")` etc.

**Muscle group chips** — text-only. No icon on the chip. "Chest", "Back", "Shoulders" etc. are faster to scan as labels than as small anatomical icons. Do not add icons to muscle group chips.

**Exercise illustrations** — never. Heft is a logger, not a tutorial. No animated GIFs, no form guides, no movement diagrams.

---

## Competitors (context for feature decisions)

| App | Weakness |
|-----|---------|
| Strong | Social bloat, noisy for serious lifters |
| Hevy | Dated UI (2015-era), slow development |
| Future | Expensive, AI programs not logging-focused |
| GymStreak | Focused on streaks/AI, not raw speed |
| Atom | Complex, Watch-first limits phone UX |

---

## Rules for Agents

- **iOS 26+ only. Always.** Reference iOS 26 documentation. Never write `#available` guards or CoreData fallbacks. See the Platform Target section above.
- Never add a feature that adds taps to the path from workout start → log set → next set
- Never reuse stable identifiers across records
- New nav buttons always go at the end of `.screen-nav`
- When modifying wireframe screens, register new screen IDs in `meshMap` inside `showScreen()`
- Documentation changes go in `.docx` format — the `.pages` files are the original binary sources and should not be edited
- Never add exercise illustrations, animated GIFs, or form guides — Heft is a logger, not a tutorial
- Muscle group chips are always text-only — never add icons to them
- Equipment type icons use the custom PDF asset set (`icon-barbell` etc.) — never substitute SF Symbols for these
