import Foundation
import SwiftData
import WidgetKit

/// Widgets run in their own process and can't open the app's SwiftData
/// store, so the app drops a small JSON snapshot into the shared App Group
/// container whenever it goes to the background, then asks WidgetKit to
/// refresh. Keep the WidgetSnapshot shape in sync with the copy in the
/// CompartmentsWidgets target.
struct WidgetSnapshot: Codable {
    var updatedAt: Date
    var todayCompleted: Int
    var todayTotal: Int
    var habitsDone: Int
    var habitsTotal: Int
    // Optional so snapshots written before the shopping feature still decode
    var shoppingChecked: Int?
    var shoppingTotal: Int?
    var boxes: [BoxSnapshot]

    struct BoxSnapshot: Codable {
        var name: String
        var completed: Int
        var total: Int
        var colorHex: String
    }
}

@MainActor
enum WidgetBridge {
    static let appGroupID = "group.HabitsTrackerV1.HabitsTracker"
    static let snapshotFilename = "widget-snapshot.json"

    static func writeSnapshot(container: ModelContainer) {
        guard let directory = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        else { return }

        let context = container.mainContext
        let calendar = Calendar.current

        guard let tasks = try? context.fetch(FetchDescriptor<TaskItem>()),
              let habits = try? context.fetch(FetchDescriptor<Habit>()),
              let boxes = try? context.fetch(
                  FetchDescriptor<TaskBox>(sortBy: [SortDescriptor(\.createdAt)]))
        else { return }
        let shoppingItems = (try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? []

        let todayTasks = tasks.filter { calendar.isDateInToday($0.dueDate) }
        let index = HabitCompletionIndex(habits: habits)
        let activeHabits = habits.filter { $0.isActive(on: .now) }

        let snapshot = WidgetSnapshot(
            updatedAt: .now,
            todayCompleted: todayTasks.filter(\.isCompleted).count,
            todayTotal: todayTasks.count,
            habitsDone: activeHabits.filter { index.isCompleted($0, on: .now) }.count,
            habitsTotal: activeHabits.count,
            shoppingChecked: shoppingItems.filter(\.isChecked).count,
            shoppingTotal: shoppingItems.count,
            boxes: boxes.map {
                WidgetSnapshot.BoxSnapshot(name: $0.name,
                                           completed: $0.completedCount,
                                           total: $0.totalCount,
                                           colorHex: $0.displayColorHex)
            })

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: directory.appendingPathComponent(snapshotFilename),
                        options: .atomic)

        WidgetCenter.shared.reloadAllTimelines()
    }
}
