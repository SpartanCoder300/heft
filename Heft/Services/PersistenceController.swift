// iOS 26+ only. No #available guards.

import SwiftData

enum PersistenceController {
    static let schema = Schema([
        ExerciseDefinition.self,
        RoutineTemplate.self,
        RoutineEntry.self,
        WorkoutSession.self,
        ExerciseSnapshot.self,
        SetRecord.self,
        BodyWeightEntry.self,
    ])

    static let sharedModelContainer: ModelContainer = {
        let cloudConfig = ModelConfiguration(
            "Heft",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .automatic,
            cloudKitDatabase: .automatic
        )

        if let container = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
            return container
        }

        // CloudKit unavailable (Previews, simulator without entitlements, or iCloud signed out) —
        // fall back to local-only storage so the app remains functional.
        let localConfig = ModelConfiguration(
            "Heft",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            fatalError("Unable to create model container: \(error)")
        }
    }()

    @MainActor
    static let previewContainer: ModelContainer = {
        let configuration = ModelConfiguration(
            "Preview",
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create preview model container: \(error)")
        }
    }()
}
