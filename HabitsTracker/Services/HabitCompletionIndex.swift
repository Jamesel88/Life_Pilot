import Foundation
import SwiftData

/// Precomputed lookup tables for habit completion checks.
///
/// `Habit.isCompleted(on:)` scans the habit's whole `completedDates` array
/// per call, which is fine for a single row but quadratic when the
/// dashboard walks every day since the earliest habit start (streaks,
/// year dashes). Build one index per render pass — O(total completions) —
/// and every per-day check becomes a set/dictionary lookup.
///
/// Semantics mirror `Habit.isCompleted(on:)` exactly: daily needs an entry
/// that calendar day, monthly an entry that month, weekly at least
/// `timesPerWeek` entries somewhere in that week.
struct HabitCompletionIndex {
    private let calendar: Calendar
    private let habits: [Habit]
    private var days: [PersistentIdentifier: Set<Date>] = [:]
    private var weekCounts: [PersistentIdentifier: [Date: Int]] = [:]
    private var months: [PersistentIdentifier: Set<Date>] = [:]

    init(habits: [Habit], calendar: Calendar = .current) {
        self.habits = habits
        self.calendar = calendar
        for habit in habits {
            let id = habit.persistentModelID
            for date in habit.completedDates {
                days[id, default: []].insert(calendar.startOfDay(for: date))
                if let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start {
                    weekCounts[id, default: [:]][weekStart, default: 0] += 1
                }
                if let monthStart = calendar.dateInterval(of: .month, for: date)?.start {
                    months[id, default: []].insert(monthStart)
                }
            }
        }
    }

    func isCompleted(_ habit: Habit, on day: Date) -> Bool {
        let id = habit.persistentModelID
        switch habit.frequency {
        case .weekly:
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: day)?.start
            else { return false }
            return (weekCounts[id]?[weekStart] ?? 0) >= max(habit.timesPerWeek, 1)
        case .daily:
            return days[id]?.contains(calendar.startOfDay(for: day)) ?? false
        case .monthly:
            guard let monthStart = calendar.dateInterval(of: .month, for: day)?.start
            else { return false }
            return months[id]?.contains(monthStart) ?? false
        }
    }

    /// How the day went across every habit active that day — same rule the
    /// dashboard previously computed by rescanning each habit's dates.
    func dayCompletion(on day: Date) -> DayCompletion {
        let active = habits.filter { $0.isActive(on: day) }
        guard !active.isEmpty else { return .none }
        let doneCount = active.filter { isCompleted($0, on: day) }.count
        if doneCount == 0 { return .none }
        if doneCount == active.count { return .full }
        return .partial
    }
}
