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

    private(set) var frecencyScores: [String: Double] = [:]

    // MARK: - Filtering / search

    /// Top-5 exercises by frecency score the user has actually used (score > 0).
    /// Scoped to the active filter set.
    func recentExercises(from all: [ExerciseDefinition], filters: Set<PickerFilter> = []) -> [ExerciseDefinition] {
        var candidates = all.filter { scoreFor($0) > 0 }
        candidates = applyFilters(filters, to: candidates)
        return candidates
            .sorted { scoreFor($0) > scoreFor($1) }
            .prefix(5)
            .map { $0 }
    }

    /// Exercises to show in the full library section.
    /// Multiple active filters are joined as a union.
    /// Custom exercises float to the top within their group.
    func libraryExercises(from all: [ExerciseDefinition]) -> [ExerciseDefinition] {
        var filtered = applyFilters(selectedFilters, to: all)

        if searchText.count >= 2 {
            filtered = filtered.filter { fuzzyMatches(query: searchText, in: $0.name) }
        }

        return filtered.sorted {
            if $0.isCustom != $1.isCustom { return $0.isCustom }
            return scoreFor($0) > scoreFor($1)
        }
    }

    /// Returns exercises matching any of the active filters (union). Empty set = no filtering.
    private func applyFilters(_ filters: Set<PickerFilter>, to exercises: [ExerciseDefinition]) -> [ExerciseDefinition] {
        guard !filters.isEmpty else { return exercises }
        return exercises.filter { exercise in
            filters.contains { filter in
                switch filter {
                case .muscleGroup(let g): return exercise.muscleGroups.contains(g)
                case .equipment(let e):   return exercise.equipmentType == e
                case .custom:             return exercise.isCustom
                }
            }
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
