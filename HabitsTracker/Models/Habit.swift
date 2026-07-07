import SwiftData
import Foundation

enum HabitFrequency: Int, Codable, CaseIterable {
    case daily = 0, weekly = 1, monthly = 2

    var label: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        }
    }
}

@Model
class Habit {
    var name: String
    var createdAt: Date
    var completedDates: [Date]
    var frequency: HabitFrequency
    var startDate: Date
    var endDate: Date?
    var reminderTime: Date?

    init(name: String, frequency: HabitFrequency = .daily,
         startDate: Date = .now, endDate: Date? = nil,
         reminderTime: Date? = nil) {
        self.name = name
        self.createdAt = .now
        self.completedDates = []
        self.frequency = frequency
        self.startDate = startDate
        self.endDate = endDate
        self.reminderTime = reminderTime
    }
}

extension Habit {
    /// Stable identifier for this habit's notification
    var reminderID: String {
        "habit-reminder-\(persistentModelID.hashValue)"
    }

    var granularity: Calendar.Component {
        switch frequency {
        case .daily: .day
        case .weekly: .weekOfYear
        case .monthly: .month
        }
    }

    /// Was this habit running on the given day?
    func isActive(on day: Date) -> Bool {
        startDate <= day && (endDate == nil || endDate! >= day)
    }

    /// Was this habit completed for the period containing the given day?
    func isCompleted(on day: Date) -> Bool {
        completedDates.contains {
            Calendar.current.isDate($0, equalTo: day, toGranularity: granularity)
        }
    }
}
