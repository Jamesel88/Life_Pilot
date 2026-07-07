import SwiftData
import Foundation

enum Priority: Int, Codable, CaseIterable {
    case normal = 0, high = 1, urgent = 2

    var label: String {
        switch self {
        case .normal: "Normal"
        case .high: "High"
        case .urgent: "Urgent"
        }
    }
}

@Model
class TaskItem {
    var title: String
    var dueDate: Date          // calendar day + optional specific time
    var hasTime: Bool          // false = "any time that day"
    var priority: Priority
    var isCompleted: Bool
    var group: TaskGroup?      // which ring this counts toward

    init(title: String, dueDate: Date, hasTime: Bool = false,
         priority: Priority = .normal, group: TaskGroup? = nil) {
        self.title = title
        self.dueDate = dueDate
        self.hasTime = hasTime
        self.priority = priority
        self.isCompleted = false
        self.group = group
    }
}
