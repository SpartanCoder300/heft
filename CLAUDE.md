# Heft — Agent Context

> **North Star:** Every pixel exists to get you back to the barbell faster.

This file gives any AI agent working in this folder the context needed to make good decisions without re-reading everything from scratch.

---

## Platform Target — Non-Negotiable

**Minimum deployment target: iOS 26. No exceptions.**

Heft is a premium app built for the current platform and forward. Older iOS versions are not supported and never will be. Any agent working in this project must operate under the following constraints at all times:

- **Always reference iOS 26+ documentation.** If an API or pattern exists in an older form and was updated or replaced in iOS 26, use the iOS 26 version.
- **Liquid Glass is the only material.** Every surface — cards, sheets, modals, overlays, pickers — uses Apple's Liquid Glass. No fallback materials (`UIMaterial`, plain `Color`, opaque backgrounds) are ever used. No conditional `if #available` checks for Liquid Glass — it is always available.
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
2. **Satisfying by Default** — Liquid Glass throughout, haptic feedback, 60fps animations, makes effort feel physical
3. **Intelligence Removes Friction** — smart auto-fill, natural language input, suggests next weight, asked exactly once

---

## Files in This Folder

| File | What it is |
|------|-----------|
| `heft_wireframes.html` | iOS app wireframe — open in any browser, fully interactive |
| `heft_watchos.html` | watchOS companion wireframe — open in any browser |
| `Heft_Product_Spec.pages` | Full product spec (binary Apple Pages — read via `strings` extraction) |
| `Heft_Build_Order_Guide.pages` | Original build order (binary Apple Pages) |
| `Heft_Build_Order_Guide.docx` | **Updated build order** — use this one, it reflects current wireframe state |
| `Heft_SwiftData_Architecture.pages` | Data layer spec (binary Apple Pages — read via `strings` extraction) |

The `.pages` files are binary IWA format with Snappy compression. They cannot be opened directly on Linux. Extract readable content with:
```bash
strings "filename.pages" | grep -E "[A-Za-z][A-Za-z ]{8,}" | grep -v "JFIF\|Photoshop\|CDEFG\|cdefg"
```

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

**Sync:** SwiftData + CloudKit, iOS 26+, SQLite backend, zero-configuration.

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

```swift
// Theme accents — all dark, Apple system-color aligned
// Midnight Strength (default): #7C7FF5  — deep indigo
// Ember:                        #E8622A  — hot iron orange
// Graphite:                     #8E9AAB  — cool silver-slate, no hue cast
// Abyss:                        #0A84FF  — Apple system blue (dark mode)
// Dynamic Mesh (Pro):           #BF5AF2  — Apple system purple (dark mode)

// Shared tokens
background:  #050505   // near-black "Obsidian"
surface:     #0F1117   // card / glass surface
textPrimary: rgba(255,255,255,0.92)
textMuted:   rgba(255,255,255,0.48)
textFaint:   rgba(255,255,255,0.28)
red:         #FF453A   // Apple system red (dark)
green:       #34D399   // success / PR
amber:       #F59E0B   // warmup set chip

// Motion
standard transition: 300ms ease
fast transition:     150ms ease
```

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
- The `.pages` files are read-only from this environment — make documentation changes in `.docx` format
- Do not surface the internal `/sessions/...` path to the user; refer to "the folder you selected" instead
