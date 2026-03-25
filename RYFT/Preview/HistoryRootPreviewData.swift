// iOS 26+ only. No #available guards.

import Foundation
import SwiftData

@MainActor
enum HistoryRootPreviewData {
    static let emptyContainer: ModelContainer = makeContainer()

    static let populatedContainer: ModelContainer = {
        let container = makeContainer()
        let context = container.mainContext

        let strengthA = RoutineTemplate(name: "Strength A")
        let upper = RoutineTemplate(name: "Upper")
        context.insert(strengthA)
        context.insert(upper)

        addSession(to: context, daysAgo: 0, routineID: strengthA.id, exercisePrefix: "Bench", durationMinutes: 54, setCounts: [4, 4, 3], personalRecord: (exerciseIndex: 1, setIndex: 0))
        addSession(to: context, daysAgo: 2, routineID: upper.id, exercisePrefix: "Pull", durationMinutes: 49, setCounts: [4, 3, 3])
        addSession(to: context, daysAgo: 9, routineID: nil, exercisePrefix: "Open", durationMinutes: 43, setCounts: [3, 3])

        return container
    }()

    static var detailPreviewSession: WorkoutSession {
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        return try! populatedContainer.mainContext.fetch(descriptor).first!
    }

    private static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(
            "HistoryPreview",
            schema: PersistenceController.schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        return try! ModelContainer(for: PersistenceController.schema, configurations: [configuration])
    }

    private static func addSession(
        to context: ModelContext,
        daysAgo: Int,
        routineID: UUID?,
        exercisePrefix: String,
        durationMinutes: Int,
        setCounts: [Int],
        personalRecord: (exerciseIndex: Int, setIndex: Int)? = nil
    ) {
        let end = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        let session = WorkoutSession(
            startedAt: end.addingTimeInterval(TimeInterval(-durationMinutes * 60)),
            completedAt: end,
            routineTemplateId: routineID
        )
        context.insert(session)

        for (index, setCount) in setCounts.enumerated() {
            let snapshot = ExerciseSnapshot(
                exerciseName: "\(exercisePrefix) \(index + 1)",
                order: index,
                workoutSession: session
            )
            context.insert(snapshot)
            session.exercises.append(snapshot)

            for setIndex in 0..<setCount {
                let set = SetRecord(
                    weight: Double(95 + (index * 20) + (setIndex * 5)),
                    reps: 5 + (setIndex % 3),
                    setType: .normal,
                    isPersonalRecord: personalRecord?.exerciseIndex == index && personalRecord?.setIndex == setIndex,
                    exerciseSnapshot: snapshot
                )
                context.insert(set)
                snapshot.sets.append(set)
            }
        }
    }
}
