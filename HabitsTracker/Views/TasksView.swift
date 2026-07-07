import SwiftUI
import SwiftData

enum TaskFilter: String, CaseIterable {
    case days = "By days"
    case outstanding = "Outstanding tasks"
    case groups = "By groups"
    case completed = "Completed tasks"
}

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.dueDate) private var allTasks: [TaskItem]
    @Query private var groups: [TaskGroup]
    @State private var showingAddTask = false
    @State private var showingAddGroup = false
    @State private var taskToEdit: TaskItem?
    @State private var groupToEdit: TaskGroup?
    @State private var filter: TaskFilter = .days
    @State private var collapsedGroups: Set<PersistentIdentifier> = []

    private var calendar: Calendar { .current }

    // MARK: - Filtered collections

    private var urgentTasks: [TaskItem] {
        allTasks.filter { $0.priority == .urgent && !$0.isCompleted }
    }
    private var todayTasks: [TaskItem] {
        allTasks.filter { calendar.isDateInToday($0.dueDate) && !$0.isCompleted }
    }
    private var tomorrowTasks: [TaskItem] {
        allTasks.filter { calendar.isDateInTomorrow($0.dueDate) && !$0.isCompleted }
    }
    private var thisWeekTasks: [TaskItem] {
        allTasks.filter {
            !calendar.isDateInToday($0.dueDate)
            && !calendar.isDateInTomorrow($0.dueDate)
            && calendar.isDate($0.dueDate, equalTo: .now, toGranularity: .weekOfYear)
            && $0.dueDate > .now
            && !$0.isCompleted
        }
    }
    private var thisMonthTasks: [TaskItem] {
        allTasks.filter {
            calendar.isDate($0.dueDate, equalTo: .now, toGranularity: .month)
            && !calendar.isDate($0.dueDate, equalTo: .now, toGranularity: .weekOfYear)
            && $0.dueDate > .now
            && !$0.isCompleted
        }
    }
    private var outstandingTasks: [TaskItem] {
        allTasks.filter { !$0.isCompleted }
    }
    private var completedTasks: [TaskItem] {
        allTasks.filter(\.isCompleted)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // MARK: Filter menu
                Section {
                    Menu {
                        ForEach(TaskFilter.allCases, id: \.self) { option in
                            Button {
                                filter = option
                            } label: {
                                if filter == option {
                                    Label(option.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(option.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "line.3.horizontal")
                            Text(filter.rawValue)
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.primary)
                    }
                }

                // MARK: Content per filter
                switch filter {
                case .days:
                    taskSection("Urgent Tasks", tasks: urgentTasks)
                    taskSection("Today", tasks: todayTasks)
                    taskSection("Tomorrow", tasks: tomorrowTasks)
                    taskSection("This Week", tasks: thisWeekTasks)
                    taskSection("This Month", tasks: thisMonthTasks)

                case .outstanding:
                    taskSection("All outstanding", tasks: outstandingTasks)

                case .completed:
                    if completedTasks.isEmpty {
                        Section {
                            Text("No completed tasks yet")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        taskSection("Completed", tasks: completedTasks)
                    }

                case .groups:
                    ForEach(groups) { group in
                        let groupTasks = allTasks.filter { $0.group === group && !$0.isCompleted }
                        let stats = groupStats(group)
                        Section {
                            DisclosureGroup(isExpanded: expansionBinding(for: group)) {
                                if groupTasks.isEmpty {
                                    Text("No outstanding tasks in this group")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(groupTasks) { task in
                                        TaskRowView(task: task)
                                            .contentShape(Rectangle())
                                            .onTapGesture { taskToEdit = task }
                                    }
                                    .onDelete { indexSet in
                                        for index in indexSet {
                                            modelContext.delete(groupTasks[index])
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(Color(hex: group.colorHex))
                                        .frame(width: 10, height: 10)
                                    Text(group.name)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(stats.completed)/\(stats.total)")
                                        .font(.subheadline.monospacedDigit())
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(.primary)
                            }
                            .listRowBackground(groupProgressBackground(for: group, progress: stats.progress))
                        }
                    }
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Section("Edit Groups") {
                            if groups.isEmpty {
                                Button {
                                    showingAddGroup = true
                                } label: {
                                    Label("Add Group", systemImage: "plus.circle")
                                }
                            } else {
                                ForEach(groups) { group in
                                    Button {
                                        groupToEdit = group
                                    } label: {
                                        Label(group.name, systemImage: "circle.fill")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "pencil.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddTask = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView()
            }
            .sheet(isPresented: $showingAddGroup) {
                AddGroupView()
            }
            .sheet(item: $taskToEdit) { task in
                EditTaskView(task: task)
            }
            .sheet(item: $groupToEdit) { group in
                EditGroupView(group: group)
            }
            .overlay {
                if allTasks.isEmpty {
                    ContentUnavailableView("No tasks yet",
                        systemImage: "checklist",
                        description: Text("Tap + to add your first task"))
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func taskSection(_ title: String, tasks: [TaskItem]) -> some View {
        if !tasks.isEmpty {
            Section(title) {
                ForEach(tasks) { task in
                    TaskRowView(task: task)
                        .contentShape(Rectangle())
                        .onTapGesture { taskToEdit = task }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        modelContext.delete(tasks[index])
                    }
                }
            }
        }
    }

    private func expansionBinding(for group: TaskGroup) -> Binding<Bool> {
        Binding(
            get: { !collapsedGroups.contains(group.persistentModelID) },
            set: { isExpanded in
                if isExpanded {
                    collapsedGroups.remove(group.persistentModelID)
                } else {
                    collapsedGroups.insert(group.persistentModelID)
                }
            }
        )
    }

    private func groupStats(_ group: TaskGroup) -> (completed: Int, total: Int, progress: Double) {
        let items = allTasks.filter { $0.group === group }
        let completed = items.filter(\.isCompleted).count
        let progress = items.isEmpty ? 0 : Double(completed) / Double(items.count)
        return (completed, items.count, progress)
    }

    /// A row background that fills left-to-right with the group's colour as
    /// its tasks are completed, so the row itself reads as a progress bar.
    /// The text stays legible throughout since the tint stays translucent.
    @ViewBuilder
    private func groupProgressBackground(for group: TaskGroup, progress: Double) -> some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color(hex: group.colorHex).opacity(0.3))
                    .frame(width: geo.size.width * progress)
                Rectangle()
                    .fill(Color(.systemGray6))
            }
        }
    }
}
