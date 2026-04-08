// iOS 26+ only. No #available guards.

import Foundation
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
        WeeklySnapshot.self,
        AITrainingContext.self,
    ])

    static let sharedModelContainer: ModelContainer = {
        let cloudConfig = ModelConfiguration(
            "Orin",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .automatic
        )

        if let container = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
            return container
        }

        // CloudKit unavailable (Previews, simulator without entitlements, or iCloud signed out) —
        // fall back to local-only storage so the app remains functional.
        let localConfig = ModelConfiguration(
            "Orin",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        if let container = try? ModelContainer(for: schema, configurations: [localConfig]) {
            return container
        }

        // Last resort: the store is corrupt or the schema migration failed.
        // Delete the local store so the app can restart cleanly.
        // All data synced via CloudKit will be re-delivered on the next launch.
        // Any unsynced local data (e.g. created while offline) is lost — but
        // a permanent crash loop is far worse.
        deleteStore(at: localConfig.url)

        do {
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            fatalError("Unable to create model container even after store reset: \(error)")
        }
    }()

    private static func deleteStore(at url: URL) {
        let fm = FileManager.default
        for ext in ["", "-shm", "-wal"] {
            let file = url.deletingPathExtension().appendingPathExtension("sqlite\(ext)")
            try? fm.removeItem(at: file)
        }
    }

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
            let container = try ModelContainer(for: schema, configurations: [configuration])
            ExerciseSeeder.seedIfNeeded(in: container.mainContext)
            return container
        } catch {
            fatalError("Unable to create preview model container: \(error)")
        }
    }()
}
