import SwiftUI

struct MainTabView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            DashboardView(tabSelection: $selection)
                .tabItem { Image(systemName: "circle.circle") }
                .tag(0)
            TasksView()
                .tabItem { Label("Tasks", systemImage: "checklist") }
                .tag(1)
            HabitsView()
                .tabItem { Label("Habits", systemImage: "repeat") }
                .tag(2)
        }
    }
}
