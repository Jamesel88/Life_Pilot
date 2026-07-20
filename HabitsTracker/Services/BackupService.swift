import Foundation
import SwiftData

/// Everything the app stores, flattened into a Codable file the user can
/// save to Files/iCloud Drive and restore after a reinstall. Object
/// relationships are carried as UUIDs assigned at export time; photo bytes
/// ride along base64-encoded by JSONEncoder.
struct BackupFile: Codable {
    var version: Int = 1
    var exportedAt: Date = .now
    var habits: [HabitBackup] = []
    var groups: [GroupBackup] = []
    var tasks: [TaskBackup] = []
    var boxes: [BoxBackup] = []
    var shopping: [ShoppingItemBackup]?   // optional so older files decode
}

struct ShoppingItemBackup: Codable {
    var name: String
    var isChecked: Bool
    var createdAt: Date
}

struct HabitBackup: Codable {
    var name: String
    var createdAt: Date
    var completedDates: [Date]
    var frequency: HabitFrequency
    var timesPerWeek: Int
    var startDate: Date
    var endDate: Date?
    var reminderTime: Date?
}

struct GroupBackup: Codable {
    var id: UUID
    var name: String
    var colorHex: String
}

struct TaskBackup: Codable {
    var id: UUID
    var title: String
    var dueDate: Date
    var hasTime: Bool
    var dueWindow: DueWindow
    var priority: Priority
    var isCompleted: Bool
    var repeatRule: TaskRepeat
    var groupID: UUID?
    var linkedTaskIDs: [UUID]
    var notes: String?        // optional so pre-notes backup files still decode
    var completedAt: Date?
}

struct BoxBackup: Codable {
    var name: String
    var colorHex: String
    var createdAt: Date
    var groupID: UUID?
    var linkedTaskIDs: [UUID]
    var subtasks: [SubtaskBackup]
}

struct SubtaskBackup: Codable {
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var dueDate: Date?
    var notes: String
    var photos: [Data]
}

enum BackupError: LocalizedError {
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            "This file isn't a Compartments backup (or was made by a newer version of the app)."
        }
    }
}

@MainActor
enum BackupService {

    /// Counts shown to the user after a restore
    struct Summary {
        var habits = 0, groups = 0, tasks = 0, boxes = 0
    }

    // MARK: - Export

    static func makeBackupData(context: ModelContext) throws -> Data {
        var backup = BackupFile()

        let habits = try context.fetch(FetchDescriptor<Habit>())
        backup.habits = habits.map {
            HabitBackup(name: $0.name, createdAt: $0.createdAt,
                        completedDates: $0.completedDates,
                        frequency: $0.frequency, timesPerWeek: $0.timesPerWeek,
                        startDate: $0.startDate, endDate: $0.endDate,
                        reminderTime: $0.reminderTime)
        }

        let groups = try context.fetch(FetchDescriptor<TaskGroup>())
        var groupIDs: [PersistentIdentifier: UUID] = [:]
        backup.groups = groups.map { group in
            let id = UUID()
            groupIDs[group.persistentModelID] = id
            return GroupBackup(id: id, name: group.name, colorHex: group.colorHex)
        }

        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        var taskIDs: [PersistentIdentifier: UUID] = [:]
        for task in tasks {
            taskIDs[task.persistentModelID] = UUID()
        }
        backup.tasks = tasks.map { task in
            TaskBackup(id: taskIDs[task.persistentModelID]!,
                       title: task.title, dueDate: task.dueDate,
                       hasTime: task.hasTime, dueWindow: task.dueWindow,
                       priority: task.priority, isCompleted: task.isCompleted,
                       repeatRule: task.repeatRule,
                       groupID: task.group.flatMap { groupIDs[$0.persistentModelID] },
                       linkedTaskIDs: task.allLinkedTasks.compactMap { taskIDs[$0.persistentModelID] },
                       notes: task.notes,
                       completedAt: task.completedAt)
        }

        let shoppingItems = try context.fetch(FetchDescriptor<ShoppingItem>())
        backup.shopping = shoppingItems.map {
            ShoppingItemBackup(name: $0.name, isChecked: $0.isChecked,
                               createdAt: $0.createdAt)
        }

        let boxes = try context.fetch(FetchDescriptor<TaskBox>())
        backup.boxes = boxes.map { box in
            BoxBackup(name: box.name, colorHex: box.colorHex,
                      createdAt: box.createdAt,
                      groupID: box.group.flatMap { groupIDs[$0.persistentModelID] },
                      linkedTaskIDs: box.allLinkedTasks.compactMap { taskIDs[$0.persistentModelID] },
                      subtasks: box.allSubtasks
                          .sorted { $0.createdAt < $1.createdAt }
                          .map { subtask in
                              SubtaskBackup(title: subtask.title,
                                            isCompleted: subtask.isCompleted,
                                            createdAt: subtask.createdAt,
                                            dueDate: subtask.dueDate,
                                            notes: subtask.notes,
                                            photos: (subtask.photos ?? [])
                                                .sorted { $0.createdAt < $1.createdAt }
                                                .map(\.data))
                          })
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    // MARK: - Import

    static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(BackupFile.self, from: data) else {
            throw BackupError.unreadableFile
        }
        return backup
    }

    /// Replaces everything in the store with the backup's contents.
    /// Destructive — the caller must confirm with the user first.
    @discardableResult
    static func restore(_ backup: BackupFile, context: ModelContext) throws -> Summary {
        // Wipe current data (box/group deletes cascade to their children)
        try context.delete(model: TaskBox.self)
        try context.delete(model: TaskItem.self)
        try context.delete(model: TaskGroup.self)
        try context.delete(model: Habit.self)
        try context.delete(model: ShoppingItem.self)

        // Groups first — tasks and boxes point at them
        var groupsByID: [UUID: TaskGroup] = [:]
        for entry in backup.groups {
            let group = TaskGroup(name: entry.name, colorHex: entry.colorHex)
            context.insert(group)
            groupsByID[entry.id] = group
        }

        // Tasks in two passes: create them all, then wire the links
        var tasksByID: [UUID: TaskItem] = [:]
        for entry in backup.tasks {
            let task = TaskItem(title: entry.title, dueDate: entry.dueDate,
                                hasTime: entry.hasTime, dueWindow: entry.dueWindow,
                                priority: entry.priority,
                                group: entry.groupID.flatMap { groupsByID[$0] },
                                repeatRule: entry.repeatRule)
            task.isCompleted = entry.isCompleted
            task.notes = entry.notes ?? ""
            task.completedAt = entry.completedAt
            context.insert(task)
            tasksByID[entry.id] = task
        }
        for entry in backup.tasks {
            tasksByID[entry.id]?.linkedTasks =
                entry.linkedTaskIDs.compactMap { tasksByID[$0] }
        }

        for entry in backup.boxes {
            let box = TaskBox(name: entry.name, colorHex: entry.colorHex,
                              group: entry.groupID.flatMap { groupsByID[$0] })
            box.createdAt = entry.createdAt
            box.linkedTasks = entry.linkedTaskIDs.compactMap { tasksByID[$0] }
            context.insert(box)
            for subtaskEntry in entry.subtasks {
                let subtask = BoxSubtask(title: subtaskEntry.title,
                                         dueDate: subtaskEntry.dueDate)
                subtask.isCompleted = subtaskEntry.isCompleted
                subtask.createdAt = subtaskEntry.createdAt
                subtask.notes = subtaskEntry.notes
                subtask.box = box
                context.insert(subtask)
                for photoData in subtaskEntry.photos {
                    let photo = SubtaskPhoto(data: photoData)
                    photo.subtask = subtask
                    context.insert(photo)
                }
            }
        }

        for entry in backup.shopping ?? [] {
            let item = ShoppingItem(name: entry.name)
            item.isChecked = entry.isChecked
            item.createdAt = entry.createdAt
            context.insert(item)
        }

        var restoredHabits: [Habit] = []
        for entry in backup.habits {
            let habit = Habit(name: entry.name, frequency: entry.frequency,
                              timesPerWeek: entry.timesPerWeek,
                              startDate: entry.startDate, endDate: entry.endDate,
                              reminderTime: entry.reminderTime)
            habit.createdAt = entry.createdAt
            habit.completedDates = entry.completedDates
            context.insert(habit)
            restoredHabits.append(habit)
        }

        try context.save()

        // Everything old is gone, so all pending notifications are stale —
        // start over from the restored set
        NotificationManager.rescheduleAll(habits: restoredHabits,
                                          tasks: Array(tasksByID.values))

        return Summary(habits: backup.habits.count,
                       groups: backup.groups.count,
                       tasks: backup.tasks.count,
                       boxes: backup.boxes.count)
    }
}
