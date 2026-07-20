import SwiftData
import Foundation

enum Priority: Int, Codable, CaseIterable {
    case low = -1, normal = 0, high = 1, urgent = 2

    var label: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        case .urgent: "Urgent"
        }
    }
}

/// How precisely a task is scheduled: a specific day, or just "sometime
/// this week/month/year". Vague windows anchor their dueDate to the last
/// day of the current period so sorting and overdue logic keep working.
enum DueWindow: Int, Codable, CaseIterable {
    case day = 0, week = 1, month = 2, year = 3

    var label: String {
        switch self {
        case .day: "Specific day"
        case .week: "This week"
        case .month: "This month"
        case .year: "This year"
        }
    }

    var segmentLabel: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }

    var calendarComponent: Calendar.Component? {
        switch self {
        case .day: nil
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }

    /// The due date stored for a vague window: the start of the last day
    /// of the week/month/year containing `reference`. Returns nil for
    /// .day (the user picks that date themselves).
    func anchorDate(from reference: Date = .now) -> Date? {
        guard let component = calendarComponent,
              let interval = Calendar.current.dateInterval(of: component, for: reference)
        else { return nil }
        // interval.end is the first instant of the next period
        let lastDay = interval.end.addingTimeInterval(-1)
        return Calendar.current.startOfDay(for: lastDay)
    }
}

enum TaskRepeat: Int, Codable, CaseIterable {
    // Declaration order drives picker order; raw values are stable for
    // persisted data (4–6 were added after 0–3)
    case never = 0
    case daily = 1
    case weekdays = 4
    case weekly = 2
    case fortnightly = 5
    case monthly = 3
    case yearly = 6

    var label: String {
        switch self {
        case .never: "Never"
        case .daily: "Daily"
        case .weekdays: "Weekdays"
        case .weekly: "Weekly"
        case .fortnightly: "Every 2 weeks"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }
}

@Model
class TaskItem {
    var title: String = ""
    var dueDate: Date = Date.now          // calendar day + optional specific time
    var hasTime: Bool = false             // false = "any time that day"
    var dueWindow: DueWindow = DueWindow.day   // day = dueDate is exact; otherwise "by end of this week/month/year"
    var notes: String = ""                     // free-text extra info
    var completedAt: Date?                     // when it was ticked off — feeds Insights
    var priority: Priority = Priority.normal
    var isCompleted: Bool = false
    var group: TaskGroup?      // which ring this counts toward
    /// Task-to-task links (dependencies/related work). CloudKit requires
    /// every relationship to be optional and have an inverse, so a
    /// symmetric link is stored on ONE side only (`link(to:)` appends
    /// here; SwiftData maintains `linkedBy` on the other task). Read
    /// `allLinkedTasks` — never these two directly — to see both
    /// directions merged.
    @Relationship(inverse: \TaskItem.linkedBy)
    var linkedTasks: [TaskItem]?
    var linkedBy: [TaskItem]?
    /// Inverse of TaskBox.linkedTasks — the boxes this task is linked into
    var containingBoxes: [TaskBox]?
    var repeatRule: TaskRepeat = TaskRepeat.never

    init(title: String, dueDate: Date, hasTime: Bool = false,
         dueWindow: DueWindow = .day,
         priority: Priority = .normal, group: TaskGroup? = nil,
         repeatRule: TaskRepeat = .never) {
        self.title = title
        self.dueDate = dueDate
        self.hasTime = hasTime
        self.dueWindow = dueWindow
        self.priority = priority
        self.isCompleted = false
        self.group = group
        self.repeatRule = repeatRule
    }
}

extension TaskItem {
    /// The next occurrence's due date, or nil if this task doesn't repeat.
    var nextDueDate: Date? {
        let calendar = Calendar.current
        switch repeatRule {
        case .never:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: dueDate)
        case .weekdays:
            // Next Monday–Friday day
            var next = dueDate
            repeat {
                guard let advanced = calendar.date(byAdding: .day, value: 1, to: next)
                else { return nil }
                next = advanced
            } while calendar.isDateInWeekend(next)
            return next
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: dueDate)
        case .fortnightly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: dueDate)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: dueDate)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: dueDate)
        }
    }
}
