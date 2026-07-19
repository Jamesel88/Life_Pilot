import SwiftUI

/// Tab identity in one place — views navigate with `.habits`, not a magic
/// number that silently breaks when tabs are added or reordered.
enum AppTab: Hashable {
    case dashboard, tasks, boxes, habits, settings
}

struct MainTabView: View {
    @State private var selection: AppTab = .dashboard

    var body: some View {
        TabView(selection: $selection) {
            DashboardView(tabSelection: $selection)
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(AppTab.dashboard)
            TasksView()
                .tabItem { Label("Tasks", systemImage: "checklist") }
                .tag(AppTab.tasks)
            TaskBoxesView()
                .tabItem { Label("Compartments", systemImage: "square.split.2x2") }
                .tag(AppTab.boxes)
            HabitsView()
                .tabItem { Label("Habits", systemImage: "repeat") }
                .tag(AppTab.habits)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
    }
}
