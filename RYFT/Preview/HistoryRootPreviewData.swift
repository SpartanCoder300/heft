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

    // MARK: - Exercise History Preview

    static let exerciseHistoryContainer: ModelContainer = {
        let container = makeContainer()
        let ctx = container.mainContext

        // 9 sessions of "Bench Press" with progressive overload
        let progression: [(weight: Double, daysAgo: Int)] = [
            (135, 56), (145, 49), (155, 42), (155, 35),
            (165, 28), (175, 21), (185, 14), (205, 7), (215, 0)
        ]

        for (i, entry) in progression.enumerated() {
            let end = Calendar.current.date(byAdding: .day, value: -entry.daysAgo, to: .now)!
            let session = WorkoutSession(
                startedAt: end.addingTimeInterval(-3600),
                completedAt: end,
                routineTemplateId: nil
            )
            ctx.insert(session)

            let snapshot = ExerciseSnapshot(exerciseName: "Bench Press", order: 0, workoutSession: session)
            ctx.insert(snapshot)
            session.exercises.append(snapshot)

            // Warmup
            let warmup = SetRecord(weight: 95, reps: 5, setType: .warmup, isPersonalRecord: false, exerciseSnapshot: snapshot)
            ctx.insert(warmup)
            snapshot.sets.append(warmup)

            // 3 working sets ramping to the session's best
            for j in 0..<3 {
                let w = j == 2 ? entry.weight : entry.weight - 20
                let r = j == 2 ? 5 : 8
                let isPR = i == progression.count - 1 && j == 2
                let set = SetRecord(weight: w, reps: r, setType: .normal, isPersonalRecord: isPR, exerciseSnapshot: snapshot)
                ctx.insert(set)
                snapshot.sets.append(set)
            }
        }

        return container
    }()

    static var exerciseHistorySnapshots: [ExerciseSnapshot] {
        let all = (try? exerciseHistoryContainer.mainContext.fetch(
            FetchDescriptor<ExerciseSnapshot>()
        )) ?? []
        return all
            .filter { $0.workoutSession?.completedAt != nil }
            .sorted { $0.workoutSession!.completedAt! > $1.workoutSession!.completedAt! }
    }

    // MARK: - Existing

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
