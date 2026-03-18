// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

@Observable
@MainActor
final class ExercisePickerViewModel {

    // MARK: - Input state (driven by the view)

    var searchText: String = ""
    var selectedMuscleGroup: String? = nil

    // MARK: - Loaded data

    private(set) var frecencyScores: [String: Double] = [:]

    // MARK: - Filtering / search

    /// Top-8 exercises by frecency score the user has actually used (score > 0).
    /// Pass a muscleGroup to scope recents to that filter chip.
    func recentExercises(from all: [ExerciseDefinition], muscleGroup: String? = nil) -> [ExerciseDefinition] {
        var candidates = all.filter { scoreFor($0) > 0 }
        if let group = muscleGroup {
            candidates = candidates.filter { $0.muscleGroups.contains(group) }
        }
        return candidates
            .sorted { scoreFor($0) > scoreFor($1) }
            .prefix(8)
            .map { $0 }
    }

    /// Exercises to show in the full library section.
    /// Filtered by muscle group chip and/or fuzzy search query.
    /// Custom exercises float to the top within their group.
    func libraryExercises(from all: [ExerciseDefinition]) -> [ExerciseDefinition] {
        var filtered = all

        if let group = selectedMuscleGroup {
            filtered = filtered.filter { $0.muscleGroups.contains(group) }
        }

        if searchText.count >= 2 {
            filtered = filtered.filter { fuzzyMatches(query: searchText, in: $0.name) }
        }

        // Custom exercises first, then sort remaining by frecency
        return filtered.sorted {
            if $0.isCustom != $1.isCustom { return $0.isCustom }
            return scoreFor($0) > scoreFor($1)
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
        frecencyScores[def.name] ?? 0
    }

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
