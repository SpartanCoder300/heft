# AGENTS.md

> **North Star:** Every pixel exists to get you back to the barbell faster.

## Platform
- iOS 26+
- SwiftUI-first
- SwiftData only

## Foundation Models
- Check device + user availability
- Fail gracefully

## UI Rules
- Use system components first
- Let Liquid Glass apply automatically
- Prefer materials for elevated UI
- Avoid unnecessary opaque backgrounds
- Use solid colors when appropriate

## Architecture
- UI is lightweight
- Logic in data layer (@ModelActor)

## Previews

Follow Apple-style preview structure. Keep previews simple, local, and predictable.

### Rules

- Keep `#Preview` declarations **next to the view they preview**
- Do not move previews into separate files

### Data placement

- If preview setup is **1–2 lines**, keep it inline in the view file
- If preview requires **non-trivial setup** (multiple objects, builders, or reused state), move that into `Preview/` helpers
- If multiple screens share the same fake data, centralize it in a shared preview data file

### File structure

- Lightweight previews → stay in the view file
- Shared preview data → `RYFT/Preview/` (or `RYFTWidgets/Preview/` for widgets)

### Anti-patterns (do not do)

- Do not build large preview scaffolding inside view files
- Do not duplicate fake data across multiple previews
- Do not move `#Preview` blocks away from their views
- Do not introduce app-level containers unless absolutely required

### Goal

Previews should be:
- Fast to read
- Fast to modify
- Minimal
- Co-located with the UI they represent

## Core Rule
Logging a set must take <2 seconds

## Product Constraints
- No social features
- No extra taps
- No exercise illustrations
