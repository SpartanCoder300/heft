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

## Core Rule
Logging a set must take <2 seconds

## Product Constraints
- No social features
- No extra taps
- No exercise illustrations
