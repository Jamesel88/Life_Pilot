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

        // Repeat daily at the chosen hour/minute
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
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
}
