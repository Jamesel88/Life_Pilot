import Foundation
import SwiftData

/// Which "By days" section of the Tasks tab a task belongs to. Pure
/// date/window classification with no view code, so the rules live in one
/// place (TasksView and any future widget/intent read the same answer)
/// and can be unit-tested.
enum DueBucket {
    case overdue, today, tomorrow, thisWeek, thisMonth, thisYear
}

extension TaskItem {
    /// Classify this task into a "By days" section, or nil if it doesn't
    /// belong to any (dated beyond this year). Vague windows stay in
    /// their section for the whole period and go overdue once it passes;
    /// specific-day tasks flow Overdue → Today → Tomorrow → This Week →
    /// This Month → This Year.
    func dueBucket(now: Date = .now, calendar: Calendar = .current) -> DueBucket? {
        switch dueWindow {
        case .week:
            if calendar.isDate(dueDate, equalTo: now, toGranularity: .weekOfYear) {
                return .thisWeek
            }
            if dueDate < now { return .overdue }
            // A chosen future week flows down the ladder like a day task
            if calendar.isDate(dueDate, equalTo: now, toGranularity: .month) {
                return .thisMonth
            }
            return sameYearFallback(now: now, calendar: calendar)
        case .month:
            if calendar.isDate(dueDate, equalTo: now, toGranularity: .month) {
                return .thisMonth
            }
            if dueDate < now { return .overdue }
            return calendar.isDate(dueDate, equalTo: now, toGranularity: .year)
                ? .thisYear : nil
        case .year:
            if calendar.isDate(dueDate, equalTo: now, toGranularity: .year) {
                return .thisYear
            }
            return dueDate < now ? .overdue : nil
        case .day:
            if calendar.isDateInToday(dueDate) { return .today }
            if calendar.isDateInTomorrow(dueDate) { return .tomorrow }
            guard dueDate > now else { return .overdue }
            if calendar.isDate(dueDate, equalTo: now, toGranularity: .weekOfYear) {
                return .thisWeek
            }
            if calendar.isDate(dueDate, equalTo: now, toGranularity: .month) {
                return .thisMonth
            }
            if calendar.isDate(dueDate, equalTo: now, toGranularity: .year) {
                return .thisYear
            }
            return nil
        }
    }

    /// A week-window task dated later this year (its own week already
    /// mismatched) surfaces under This Year, same as a specific-day task.
    private func sameYearFallback(now: Date, calendar: Calendar) -> DueBucket? {
        guard dueDate > now,
              calendar.isDate(dueDate, equalTo: now, toGranularity: .year),
              !calendar.isDate(dueDate, equalTo: now, toGranularity: .month)
        else { return nil }
        return .thisYear
    }
}

// MARK: - Window descriptions

extension TaskItem {
    /// How a vague window reads on a row: "This week", "Week of 28 Jul",
    /// "August", "This year"… Nil for specific-day tasks.
    var dueWindowDescription: String? {
        let calendar = Calendar.current
        switch dueWindow {
        case .day:
            return nil
        case .week:
            if calendar.isDate(dueDate, equalTo: .now, toGranularity: .weekOfYear) {
                return "This week"
            }
            guard let start = calendar.dateInterval(of: .weekOfYear, for: dueDate)?.start
            else { return "Week" }
            return "Week of \(start.formatted(.dateTime.day().month()))"
        case .month:
            if calendar.isDate(dueDate, equalTo: .now, toGranularity: .month) {
                return "This month"
            }
            if calendar.isDate(dueDate, equalTo: .now, toGranularity: .year) {
                return dueDate.formatted(.dateTime.month(.wide))
            }
            return dueDate.formatted(.dateTime.month(.wide).year())
        case .year:
            return calendar.isDate(dueDate, equalTo: .now, toGranularity: .year)
                ? "This year" : dueDate.formatted(.dateTime.year())
        }
    }
}

// MARK: - Priority

extension TaskItem {
    /// Day-to-day tasks only ever get Normal or Urgent now — the old
    /// Low/High cases stay on `Priority` so any task saved with one
    /// before this change still decodes fine, but they're folded into
    /// "not urgent" everywhere (no stripe, no urgent-section listing).
    var isUrgent: Bool {
        get { priority == .urgent }
        set { priority = newValue ? .urgent : .normal }
    }
}

// MARK: - Reminders

extension TaskItem {
    /// Stable notification identifier. Keyed off `reminderUUID` — minted
    /// once at creation and stored on the model itself — rather than
    /// `persistentModelID`: a freshly-inserted object's persistent
    /// identifier isn't guaranteed to stay byte-identical once SwiftData
    /// promotes it from temporary to permanent at first save, so a
    /// reminder scheduled right after insert could end up impossible to
    /// cancel later under the *new* identifier. Falls back to the old
    /// scheme only for tasks saved before `reminderUUID` existed.
    var reminderID: String {
        if let reminderUUID {
            return "task-reminder-\(reminderUUID.uuidString)"
        }
        return "task-reminder-\(persistentModelID.encodedString)"
    }
}

// MARK: - Repeating tasks

extension TaskItem {
    /// The follow-up occurrence spawned when a repeating task is completed,
    /// or nil if this task doesn't repeat. The caller inserts it into the
    /// model context.
    func nextOccurrence() -> TaskItem? {
        guard let nextDate = nextDueDate else { return nil }
        return TaskItem(title: title, dueDate: nextDate, hasTime: hasTime,
                        dueWindow: dueWindow,
                        priority: priority, group: group,
                        repeatRule: repeatRule)
    }
}

// MARK: - Completion

extension TaskItem {
    /// Marks this task done: sets completion state, cancels its reminder,
    /// and spawns+schedules the next occurrence if it repeats. Pulled out
    /// of `TaskRowView` so every "mark complete" affordance in the app
    /// (the task row's checkbox, the Links tab's popover) shares the same
    /// notification bookkeeping instead of drifting apart.
    func complete(in modelContext: ModelContext) {
        guard !isCompleted else { return }
        isCompleted = true
        completedAt = .now
        NotificationManager.cancelReminder(for: self)
        if let next = nextOccurrence() {
            modelContext.insert(next)
            // Save first so the new task's permanent ID backs its
            // notification identifier
            try? modelContext.save()
            NotificationManager.scheduleReminder(for: next)
        }
    }
}

// MARK: - Linking

extension TaskItem {
    /// Both directions of the link relationship, merged and deduplicated —
    /// the only correct way to read a task's links (a link is stored on
    /// whichever side created it; SwiftData maintains the inverse).
    var allLinkedTasks: [TaskItem] {
        var seen = Set<PersistentIdentifier>()
        return ((linkedTasks ?? []) + (linkedBy ?? [])).filter {
            seen.insert($0.persistentModelID).inserted
        }
    }

    /// Links are symmetric to the user; storage-wise the edge lives on
    /// this task and SwiftData writes the inverse on `other`.
    func link(to other: TaskItem) {
        guard !allLinkedTasks.contains(where: { $0 === other }) else { return }
        if linkedTasks == nil { linkedTasks = [] }
        linkedTasks?.append(other)
    }

    /// The edge may live on either side — clear both.
    func unlink(from other: TaskItem) {
        linkedTasks?.removeAll { $0 === other }
        linkedBy?.removeAll { $0 === other }
    }

    /// Tasks that must finish before this one can start.
    var allBlockers: [TaskItem] { blockedBy ?? [] }

    /// Tasks waiting on this one to finish.
    var allBlocked: [TaskItem] { blocks ?? [] }

    /// Marks `other` as a prerequisite of this task. Stored as an edge on
    /// THIS task's `blockedBy`; SwiftData maintains `other.blocks` as the
    /// inverse automatically.
    func addBlocker(_ other: TaskItem) {
        guard other !== self, !allBlockers.contains(where: { $0 === other }) else { return }
        if blockedBy == nil { blockedBy = [] }
        blockedBy?.append(other)
    }

    /// Removes a prerequisite edge — cleared from both sides so a direct
    /// mutation from either task stays consistent.
    func removeBlocker(_ other: TaskItem) {
        blockedBy?.removeAll { $0 === other }
        blocks?.removeAll { $0 === other }
    }

    /// Subtasks that must finish before this task can start.
    var allSubtaskBlockers: [BoxSubtask] { blockedBySubtasks ?? [] }

    /// Subtasks waiting on this task to finish.
    var allBlockedSubtasks: [BoxSubtask] { blocksSubtasks ?? [] }

    /// Marks `subtask` as a prerequisite of this task. Stored on THIS
    /// task's `blockedBySubtasks`; SwiftData maintains
    /// `subtask.blocksTasks` as the inverse automatically.
    func addBlocker(_ subtask: BoxSubtask) {
        guard !allSubtaskBlockers.contains(where: { $0 === subtask }) else { return }
        if blockedBySubtasks == nil { blockedBySubtasks = [] }
        blockedBySubtasks?.append(subtask)
    }

    /// Removes a prerequisite edge — cleared from both sides.
    func removeBlocker(_ subtask: BoxSubtask) {
        blockedBySubtasks?.removeAll { $0 === subtask }
        blocksSubtasks?.removeAll { $0 === subtask }
    }

    /// Boxes that must finish before this task can start.
    var allBoxBlockers: [TaskBox] { blockedByBoxes ?? [] }

    /// Boxes waiting on this task to finish.
    var allBlockedBoxes: [TaskBox] { blocksBoxes ?? [] }

    /// Marks `box` as a prerequisite of this task. Stored on THIS task's
    /// `blockedByBoxes`; SwiftData maintains `box.blocksTasks` as the
    /// inverse automatically.
    func addBlocker(_ box: TaskBox) {
        guard !allBoxBlockers.contains(where: { $0 === box }) else { return }
        if blockedByBoxes == nil { blockedByBoxes = [] }
        blockedByBoxes?.append(box)
    }

    /// Removes a prerequisite edge — cleared from both sides.
    func removeBlocker(_ box: TaskBox) {
        blockedByBoxes?.removeAll { $0 === box }
        blocksBoxes?.removeAll { $0 === box }
    }
}
