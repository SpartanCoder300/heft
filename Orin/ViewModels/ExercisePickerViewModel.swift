// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

enum PickerFilter: Hashable {
    case muscleGroup(String)
    case equipment(String)
    case custom

    var label: String {
        switch self {
        case .muscleGroup(let g): return g
        case .equipment(let e):   return e
        case .custom:             return "Custom"
        }
    }
}

@Observable
@MainActor
final class ExercisePickerViewModel {

    // MARK: - Input state (driven by the view)

    var searchText: String = ""
    /// Active filters. Empty = show all (equivalent to "All" chip selected).
    var selectedFilters: Set<PickerFilter> = []

    // MARK: - Loaded data

    private(set) var frecencyScores: [UUID: Double] = [:]
    /// Exercises added during this picker session — boosts them into recents immediately.
    var sessionAddedIDs: Set<UUID> = []

    func toggleFilter(_ filter: PickerFilter) {
        if selectedFilters.contains(filter) {
            selectedFilters.remove(filter)
        } else {
            selectedFilters.insert(filter)
        }
    }

    // MARK: - Filtering / search

    /// Top-5 exercises by frecency score the user has actually used (score > 0).
    /// Scoped to the active filter set.
    func recentExercises(from all: [ExerciseDefinition], filters: Set<PickerFilter> = []) -> [ExerciseDefinition] {
        var candidates = all.filter { !$0.isArchived && scoreFor($0) > 0 }
        candidates = applyFilters(filters, to: candidates)
        return candidates
            .sorted { scoreFor($0) > scoreFor($1) }
            .prefix(5)
            .map { $0 }
    }

    /// Exercises to show in the full library section.
    /// Filters are joined as OR within a row and AND across rows.
    /// Custom exercises float to the top within their group.
    func libraryExercises(from all: [ExerciseDefinition]) -> [ExerciseDefinition] {
        var filtered = applyFilters(selectedFilters, to: all.filter { !$0.isArchived })

        if searchText.count >= 2 {
            filtered = filtered.filter { fuzzyMatches(query: searchText, in: $0.name) }
        }

        return filtered.sorted {
            if $0.isCustom != $1.isCustom { return $0.isCustom }
            let fa = scoreFor($0), fb = scoreFor($1)
            if fa != fb { return fa > fb }
            let pa = popularityScore(for: $0.name), pb = popularityScore(for: $1.name)
            if pa != pb { return pa > pb }
            return $0.name < $1.name
        }
    }

    /// Returns exercises matching the active picker rows.
    /// Muscle filters union together, equipment/custom filters union together,
    /// and the two groups intersect. Empty set = no filtering.
    private func applyFilters(_ filters: Set<PickerFilter>, to exercises: [ExerciseDefinition]) -> [ExerciseDefinition] {
        guard !filters.isEmpty else { return exercises }

        let muscleGroups = Set(filters.compactMap { filter in
            if case .muscleGroup(let group) = filter { return group }
            return nil
        })
        let equipmentTypes = Set(filters.compactMap { filter in
            if case .equipment(let equipment) = filter { return equipment }
            return nil
        })
        let includesCustom = filters.contains(.custom)

        return exercises.filter { exercise in
            let matchesMuscleRow = muscleGroups.isEmpty || !muscleGroups.isDisjoint(with: exercise.muscleGroups)
            let matchesTypeRow = (equipmentTypes.isEmpty && !includesCustom)
                || equipmentTypes.contains(exercise.equipmentType)
                || (includesCustom && exercise.isCustom)

            return matchesMuscleRow && matchesTypeRow
        }
    }

    // MARK: - Character highlight ranges

    /// Returns the ranges of characters in `text` that match `query` via
    /// character-subsequence matching, for highlight rendering.
    func matchRanges(query: String, in text: String) -> [Range<String.Index>] {
        guard query.count >= 2 else { return [] }
        var ranges: [Range<String.Index>] = []
        let lower = text.lowercased()
        let qLower = query.lowercased()
        var textIdx = lower.startIndex
        for qChar in qLower {
            guard let found = lower[textIdx...].firstIndex(of: qChar) else { return [] }
            let original = text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: found))
            ranges.append(original..<text.index(after: original))
            textIdx = lower.index(after: found)
        }
        return ranges
    }

    // MARK: - Data loading

    func load(container: ModelContainer) {
        Task {
            let actor = ExerciseFrecencyActor(modelContainer: container)
            if let scores = try? await actor.scores() {
                self.frecencyScores = scores
            }
        }
    }

    // MARK: - Helpers

    private func scoreFor(_ def: ExerciseDefinition) -> Double {
        frecencyScores[def.id] ?? 0
    }

    private func popularityScore(for name: String) -> Int {
        Self.popularityScores[name] ?? 0
    }

    /// Static popularity tiers for seeded exercises.
    /// 3 = major compound lifts everyone knows
    /// 2 = common accessories / second-tier compounds
    /// 1 = less common but still frequently programmed
    /// 0 (default) = niche / specialized
    private static let popularityScores: [String: Int] = [
        // Tier 3 — the big lifts
        "Barbell Bench Press": 3,
        "Barbell Back Squat": 3,
        "Barbell Deadlift": 3,
        "Barbell Overhead Press": 3,
        "Bent-Over Barbell Row": 3,
        "Pull-Up": 3,
        "Chin-Up": 3,

        // Tier 2 — very common
        "Incline Barbell Bench Press": 2,
        "Dumbbell Bench Press": 2,
        "Incline Dumbbell Press": 2,
        "Lat Pulldown": 2,
        "Seated Cable Row": 2,
        "Single-Arm Dumbbell Row": 2,
        "Chest-Supported Dumbbell Row": 2,
        "Push Press": 2,
        "Leg Press": 2,
        "Romanian Deadlift": 2,
        "Hip Thrust": 2,
        "Glute Bridge": 2,
        "Cable Glute Kickback": 2,
        "Hip Abduction Machine": 2,
        "Hip Adduction Machine": 2,
        "Bulgarian Split Squat": 2,
        "Walking Lunge": 2,
        "Barbell Curl": 2,
        "Dumbbell Curl": 2,
        "Hammer Curl": 2,
        "Triceps Pushdown": 2,
        "Rope Pushdown": 2,
        "Close-Grip Bench Press": 2,
        "Skull Crusher": 2,
        "Lateral Raise": 2,
        "Face Pull": 2,
        "Seated Dumbbell Shoulder Press": 2,
        "Cable Fly": 2,
        "Leg Extension": 2,
        "Lying Leg Curl": 2,
        "Crunch": 2,
        "Sit-Up": 2,
        "Bicycle Crunch": 2,
        "Plank": 2,
        "Power Clean": 2,

        // Tier 1 — common enough
        "Sumo Deadlift": 1,
        "Trap Bar Deadlift": 1,
        "Front Squat": 1,
        "Goblet Squat": 1,
        "Hack Squat": 1,
        "Belt Squat": 1,
        "Barbell Lunge": 1,
        "Barbell Bulgarian Split Squat": 1,
        "Reverse Lunge": 1,
        "Lateral Lunge": 1,
        "Curtsy Lunge": 1,
        "Step-Up": 1,
        "Pistol Squat": 1,
        "Dumbbell Romanian Deadlift": 1,
        "Single-Leg Romanian Deadlift": 1,
        "Single-Leg Press": 1,
        "Single-Leg Calf Raise": 1,
        "Nordic Hamstring Curl": 1,
        "Seated Leg Curl": 1,
        "Standing Calf Raise": 1,
        "Seated Calf Raise": 1,
        "Barbell Glute Bridge": 1,
        "Dumbbell Hip Thrust": 1,
        "Single-Leg Glute Bridge": 1,
        "Single-Leg Hip Thrust": 1,
        "Smith Machine Hip Thrust": 1,
        "Cable Pull-Through": 1,
        "Kettlebell Swing": 1,
        "Arnold Press": 1,
        "Band Pull-Apart": 1,
        "EZ Bar Curl": 1,
        "Cable Curl": 1,
        "Bayesian Curl": 1,
        "Cross-Body Hammer Curl": 1,
        "Machine Preacher Curl": 1,
        "Overhead Dumbbell Extension": 1,
        "Overhead Cable Extension": 1,
        "Machine Triceps Extension": 1,
        "Weighted Dip": 1,
        "Machine Chest Press": 1,
        "Pec Deck": 1,
        "High Cable Fly": 1,
        "Dumbbell Pullover": 1,
        "Incline Dumbbell Curl": 1,
        "Cable Lateral Raise": 1,
        "Reverse Pec Deck": 1,
        "Inverted Row": 1,
        "T-Bar Row": 1,
        "Straight-Arm Pulldown": 1,
        "Meadows Row": 1,
        "Dumbbell Fly": 1,
        "Concentration Curl": 1,
        "Barbell Shrug": 1,
        "Dumbbell Shrug": 1,
        "Farmer Carry": 1,
        "Dead Hang": 1,
        "Ab Wheel Rollout": 1,
        "Cable Crunch": 1,
        "Pallof Press": 1,
        "Hanging Leg Raise": 1,
        "Hanging Knee Raise": 1,
        "Lying Leg Raise": 1,
        "Russian Twist": 1,
        "Good Morning": 1,
        "Hang Clean": 1,
        "Turkish Get-Up": 1,
    ]

    func fuzzyMatches(query: String, in text: String) -> Bool {
        guard !query.isEmpty else { return true }
        let lower = text.lowercased()
        let qLower = query.lowercased()
        var idx = lower.startIndex
        for ch in qLower {
            guard let found = lower[idx...].firstIndex(of: ch) else { return false }
            idx = lower.index(after: found)
        }
        return true
    }
}
