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
    var name: String = ""
    var createdAt: Date = Date.now
    var completedDates: [Date] = []
    var frequency: HabitFrequency = HabitFrequency.daily
    /// Only meaningful when frequency is .weekly: how many days that week
    /// need a completion before the whole week counts as done.
    var timesPerWeek: Int = 1
    var startDate: Date = Date.now
    var endDate: Date?
    var reminderTime: Date?

    init(name: String, frequency: HabitFrequency = .daily, timesPerWeek: Int = 1,
         startDate: Date = .now, endDate: Date? = nil,
         reminderTime: Date? = nil) {
        self.name = name
        self.createdAt = .now
        self.completedDates = []
        self.frequency = frequency
        self.timesPerWeek = max(timesPerWeek, 1)
        self.startDate = startDate
        self.endDate = endDate
        self.reminderTime = reminderTime
    }
}

extension Habit {
    /// Stable identifier for this habit's notification. Must survive app
    /// relaunches so reschedule/cancel can find the pending request —
    /// which is why it's the encoded persistentModelID, not `hashValue`
    /// (hash seeds change every launch).
    var reminderID: String {
        "habit-reminder-\(persistentModelID.encodedString)"
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

    /// Did I log a completion for this specific day? Used to decide
    /// whether tapping a day should add or remove an entry.
    func hasLoggedCompletion(on day: Date) -> Bool {
        completedDates.contains { Calendar.current.isDate($0, inSameDayAs: day) }
    }

    /// Toggle this habit's completion for `day`. Weekly habits can need
    /// several distinct days logged (see timesPerWeek), so only the tapped
    /// day's own entry toggles; daily/monthly clear the whole period.
    func toggleCompletion(on day: Date, calendar: Calendar = .current) {
        if frequency == .weekly {
            if hasLoggedCompletion(on: day) {
                completedDates.removeAll { calendar.isDate($0, inSameDayAs: day) }
            } else {
                completedDates.append(day)
            }
        } else if isCompleted(on: day) {
            completedDates.removeAll {
                calendar.isDate($0, equalTo: day, toGranularity: granularity)
            }
        } else {
            completedDates.append(day)
        }
    }

    /// Is the period containing `day` considered done? For daily/monthly
    /// that's any completion in the period; for weekly it's reaching
    /// `timesPerWeek` distinct completions somewhere in that week.
    func isCompleted(on day: Date) -> Bool {
        switch frequency {
        case .weekly:
            let count = completedDates.filter {
                Calendar.current.isDate($0, equalTo: day, toGranularity: .weekOfYear)
            }.count
            return count >= max(timesPerWeek, 1)
        case .daily, .monthly:
            return completedDates.contains {
                Calendar.current.isDate($0, equalTo: day, toGranularity: granularity)
            }
        }
    }
}
