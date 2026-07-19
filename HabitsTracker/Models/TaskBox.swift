import SwiftData
import Foundation

/// A bigger piece of work that holds its own subtasks and/or links to
/// existing tasks. Shown on the Boxes tab as a box whose lid stays open
/// while work remains and whose contents rise as items are completed.
@Model
class TaskBox {
    var name: String = ""
    var colorHex: String = "B08968"
    var createdAt: Date = Date.now
    var group: TaskGroup?      // same colour codes used by tasks
    @Relationship(deleteRule: .cascade, inverse: \BoxSubtask.box)
    var subtasks: [BoxSubtask] = []
    /// Existing tasks pulled into this box via the "Link a task" button.
    /// No declared inverse, so SwiftData nullifies dangling references
    /// automatically when a linked task is deleted (same convention as
    /// TaskItem.linkedTasks).
    var linkedTasks: [TaskItem] = []

    init(name: String, colorHex: String, group: TaskGroup? = nil) {
        self.name = name
        self.colorHex = colorHex
        self.group = group
    }
}

extension TaskBox {
    /// The colour the box is drawn in: its group's colour when one is
    /// assigned, otherwise its own picked colour.
    var displayColorHex: String { group?.colorHex ?? colorHex }

    var totalCount: Int { subtasks.count + linkedTasks.count }

    /// A box with nothing in it yet — drawn ajar with a dashed outline so
    /// it reads as "waiting to be filled", not "sealed and done".
    var isEmpty: Bool { totalCount == 0 }

    var completedCount: Int {
        subtasks.filter(\.isCompleted).count
            + linkedTasks.filter(\.isCompleted).count
    }

    /// How full the box is drawn: 0 when nothing done, 1 when everything is.
    var progress: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }

    /// The lid stays open while any item in the box is still outstanding.
    var isOpen: Bool { completedCount < totalCount }
}

/// A lightweight checklist item that lives inside one TaskBox only —
/// unlike TaskItem it never appears on the Tasks tab. Can carry an
/// optional due date and photo attachments.
@Model
class BoxSubtask {
    var title: String = ""
    var isCompleted: Bool = false
    var createdAt: Date = Date.now
    var dueDate: Date?         // nil = no particular day
    var notes: String = ""     // free-text extra info
    var box: TaskBox?
    @Relationship(deleteRule: .cascade, inverse: \SubtaskPhoto.subtask)
    var photos: [SubtaskPhoto] = []

    init(title: String, dueDate: Date? = nil) {
        self.title = title
        self.dueDate = dueDate
    }
}

extension BoxSubtask {
    var isOverdue: Bool {
        guard let dueDate, !isCompleted else { return false }
        return dueDate < Calendar.current.startOfDay(for: .now)
    }
}

/// A photo attached to one subtask. Image bytes are kept outside the
/// database file so large photos don't bloat the store.
@Model
class SubtaskPhoto {
    @Attribute(.externalStorage) var data: Data = Data()
    var createdAt: Date = Date.now
    var subtask: BoxSubtask?

    init(data: Data) {
        self.data = data
    }
}
