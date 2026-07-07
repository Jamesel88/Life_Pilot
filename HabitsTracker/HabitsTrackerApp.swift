import SwiftUI
import SwiftData

@main
struct HabitsTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
                .task {
                    NotificationManager.requestPermission()
                }
        }
        .modelContainer(for: [Habit.self, TaskGroup.self, TaskItem.self])
    }
}
