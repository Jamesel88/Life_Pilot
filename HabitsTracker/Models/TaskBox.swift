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
    var subtasks: [BoxSubtask]?
    /// Existing tasks pulled into this box via the "Link a task" button
    @Relationship(inverse: \TaskItem.containingBoxes)
    var linkedTasks: [TaskItem]?
    /// Subtasks (belonging to OTHER boxes) linked to this box as a whole —
    /// distinct from `subtasks`, which are this box's own children.
    @Relationship(inverse: \BoxSubtask.linkedBoxes)
    var linkedSubtasks: [BoxSubtask]?

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

    var allSubtasks: [BoxSubtask] { subtasks ?? [] }
    var allLinkedTasks: [TaskItem] { linkedTasks ?? [] }
    var allLinkedSubtasks: [BoxSubtask] { linkedSubtasks ?? [] }

    var totalCount: Int { allSubtasks.count + allLinkedTasks.count }

    /// A box with nothing in it yet — drawn ajar with a dashed outline so
    /// it reads as "waiting to be filled", not "sealed and done".
    var isEmpty: Bool { totalCount == 0 }

    var completedCount: Int {
        allSubtasks.filter(\.isCompleted).count
            + allLinkedTasks.filter(\.isCompleted).count
    }

    /// How full the box is drawn: 0 when nothing done, 1 when everything is.
    var progress: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }

    /// The lid stays open while any item in the box is still outstanding.
    var isOpen: Bool { completedCount < totalCount }

    /// Sealed: everything in the box is done. Sealed boxes are excluded
    /// from "link into a box" pickers — nothing new belongs in a closed box.
    var isSealed: Bool { !isEmpty && !isOpen }

    /// Links an existing task into this box — same convention as
    /// TaskItem.link(to:); SwiftData maintains the containingBoxes
    /// inverse automatically once one side is set.
    func link(_ task: TaskItem) {
        guard !allLinkedTasks.contains(where: { $0 === task }) else { return }
        if linkedTasks == nil { linkedTasks = [] }
        linkedTasks?.append(task)
    }

    func unlink(_ task: TaskItem) {
        linkedTasks?.removeAll { $0 === task }
    }

    /// Links a subtask belonging to another box into this box as a whole.
    func link(_ subtask: BoxSubtask) {
        guard !allLinkedSubtasks.contains(where: { $0 === subtask }) else { return }
        if linkedSubtasks == nil { linkedSubtasks = [] }
        linkedSubtasks?.append(subtask)
    }

    func unlink(_ subtask: BoxSubtask) {
        linkedSubtasks?.removeAll { $0 === subtask }
    }
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
    var photos: [SubtaskPhoto]?
    /// Tasks linked to this specific subtask, rather than to the box as
    /// a whole — same convention as TaskBox.linkedTasks.
    @Relationship(inverse: \TaskItem.linkedSubtasks)
    var linkedTasks: [TaskItem]?
    /// Boxes (other than this subtask's own parent) this subtask is
    /// linked to as a whole — inverse of TaskBox.linkedSubtasks.
    var linkedBoxes: [TaskBox]?
    /// Other subtasks this one is linked to. Symmetric by convention,
    /// stored one-sided (like TaskItem.linkedTasks/linkedBy) — read
    /// through `allLinkedSubtasks`, never these two directly.
    @Relationship(inverse: \BoxSubtask.linkedBySubtasks)
    var linkedSubtasks: [BoxSubtask]?
    var linkedBySubtasks: [BoxSubtask]?

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

    var allLinkedTasks: [TaskItem] { linkedTasks ?? [] }
    var allLinkedBoxes: [TaskBox] { linkedBoxes ?? [] }

    /// Both directions of the peer-subtask link, merged and deduplicated
    /// — same convention as TaskItem.allLinkedTasks.
    var allLinkedSubtasks: [BoxSubtask] {
        var seen = Set<PersistentIdentifier>()
        return ((linkedSubtasks ?? []) + (linkedBySubtasks ?? [])).filter {
            seen.insert($0.persistentModelID).inserted
        }
    }

    func link(_ task: TaskItem) {
        guard !allLinkedTasks.contains(where: { $0 === task }) else { return }
        if linkedTasks == nil { linkedTasks = [] }
        linkedTasks?.append(task)
    }

    func unlink(_ task: TaskItem) {
        linkedTasks?.removeAll { $0 === task }
    }

    /// Links a whole other box to this subtask.
    func link(_ box: TaskBox) {
        guard !allLinkedBoxes.contains(where: { $0 === box }) else { return }
        if linkedBoxes == nil { linkedBoxes = [] }
        linkedBoxes?.append(box)
    }

    func unlink(_ box: TaskBox) {
        linkedBoxes?.removeAll { $0 === box }
    }

    /// Links to another subtask; the edge may live on either side, so
    /// unlink clears both.
    func link(_ other: BoxSubtask) {
        guard !allLinkedSubtasks.contains(where: { $0 === other }) else { return }
        if linkedSubtasks == nil { linkedSubtasks = [] }
        linkedSubtasks?.append(other)
    }

    func unlink(_ other: BoxSubtask) {
        linkedSubtasks?.removeAll { $0 === other }
        linkedBySubtasks?.removeAll { $0 === other }
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
