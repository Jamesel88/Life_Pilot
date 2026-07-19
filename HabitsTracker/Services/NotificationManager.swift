import Foundation
import UserNotifications

enum NotificationManager {

    /// Ask the user for permission (safe to call repeatedly)
    static func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Schedule (or reschedule) the reminder for a habit
    static func scheduleReminder(for habit: Habit) {
        let center = UNUserNotificationCenter.current()

        // Remove any existing reminder for this habit first
        center.removePendingNotificationRequests(withIdentifiers: [habit.reminderID])

        guard let reminderTime = habit.reminderTime else { return }

        let content = UNMutableNotificationContent()
        content.title = "Habit reminder"
        content.body = habit.name
        content.sound = .default

        // Match the trigger's cadence to the habit's own frequency, so a
        // weekly or monthly habit doesn't nag every single day.
        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute], from: reminderTime)
        switch habit.frequency {
        case .daily:
            break
        case .weekly:
            components.weekday = calendar.component(.weekday, from: habit.startDate)
        case .monthly:
            components.day = calendar.component(.day, from: habit.startDate)
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: habit.reminderID,
                                            content: content,
                                            trigger: trigger)
        center.add(request)
    }

    /// Remove a habit's reminder (call when deleting a habit)
    static func cancelReminder(for habit: Habit) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [habit.reminderID])
    }

    // MARK: - Task reminders

    /// Schedule (or reschedule) the one-shot reminder for a task. Tasks
    /// with a specific time fire at that time; date-only tasks fire at
    /// 9am. Completed and past-due tasks get no reminder; calling this
    /// always clears any previous one first, so it doubles as "reschedule
    /// after editing".
    static func scheduleReminder(for task: TaskItem) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [task.reminderID])

        guard !task.isCompleted else { return }

        let calendar = Calendar.current
        let fireDate: Date
        if task.hasTime {
            fireDate = task.dueDate
        } else {
            fireDate = calendar.date(bySettingHour: 9, minute: 0, second: 0,
                                     of: task.dueDate) ?? task.dueDate
        }
        guard fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = task.dueWindow == .day
            ? "Task due"
            : "Due by end of \(task.dueWindow == .week ? "this week" : task.dueWindow == .month ? "this month" : "this year")"
        content.body = task.title
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute],
                                                 from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: task.reminderID,
                                         content: content, trigger: trigger))
    }

    /// Remove a task's reminder (call when completing or deleting it)
    static func cancelReminder(for task: TaskItem) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [task.reminderID])
    }

    /// Clear every pending reminder and reschedule from scratch — used
    /// after a backup restore, when all previous IDs are stale.
    static func rescheduleAll(habits: [Habit], tasks: [TaskItem]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for habit in habits {
            scheduleReminder(for: habit)
        }
        for task in tasks {
            scheduleReminder(for: task)
        }
    }
}
