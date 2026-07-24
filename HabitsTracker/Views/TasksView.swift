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
    @State private var searchText = ""
    @State private var quickAddText = ""
    @State private var showingScanList = false

    // MARK: - Filtered collections

    /// Every section of the list, built in a single pass over the query
    /// results instead of one full scan per section. Section membership
    /// itself lives on the model (`TaskItem.dueBucket`) so it stays
    /// testable and shared. Order within each section follows the query's
    /// dueDate sort.
    private struct Sections {
        var overdue: [TaskItem] = []
        var urgent: [TaskItem] = []
        var today: [TaskItem] = []
        var tomorrow: [TaskItem] = []
        var thisWeek: [TaskItem] = []
        var thisMonth: [TaskItem] = []
        var thisYear: [TaskItem] = []
        var outstanding: [TaskItem] = []
        var completed: [TaskItem] = []
    }

    private func buildSections() -> Sections {
        var sections = Sections()
        for task in allTasks {
            if task.isCompleted {
                sections.completed.append(task)
                continue
            }
            sections.outstanding.append(task)
            if task.isUrgent {
                sections.urgent.append(task)
            }
            switch task.dueBucket() {
            case .overdue: sections.overdue.append(task)
            case .today: sections.today.append(task)
            case .tomorrow: sections.tomorrow.append(task)
            case .thisWeek: sections.thisWeek.append(task)
            case .thisMonth: sections.thisMonth.append(task)
            case .thisYear: sections.thisYear.append(task)
            case nil: break   // beyond this year — Outstanding only
            }
        }
        return sections
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // MARK: Quick add
                Section {
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.secondary)
                        TextField("Quick add — try \"Dentist tomorrow 3pm\"",
                                  text: $quickAddText)
                            .onSubmit(quickAdd)
                            .submitLabel(.done)
                    }
                }

                // MARK: Content per filter
                switch filter {
                case .days:
                    let sections = buildSections()
                    taskSection("Overdue", tasks: sections.overdue, headerColor: .red)
                    taskSection("Urgent Tasks", tasks: sections.urgent)
                    taskSection("Today", tasks: sections.today)
                    taskSection("Tomorrow", tasks: sections.tomorrow)
                    taskSection("This Week", tasks: sections.thisWeek)
                    taskSection("This Month", tasks: sections.thisMonth)
                    taskSection("This Year", tasks: sections.thisYear)

                case .outstanding:
                    taskSection("All outstanding", tasks: buildSections().outstanding)

                case .completed:
                    let completed = buildSections().completed
                    if completed.isEmpty {
                        Section {
                            Text("No completed tasks yet")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        taskSection("Completed", tasks: completed)
                    }

                case .groups:
                    // One pass to bucket tasks per group, instead of
                    // rescanning the whole task list for every group row.
                    let tasksByGroup = Dictionary(
                        grouping: allTasks.filter { $0.group != nil },
                        by: { $0.group!.persistentModelID })
                    ForEach(groups) { group in
                        let groupItems = tasksByGroup[group.persistentModelID] ?? []
                        let groupTasks = groupItems
                            .filter { !$0.isCompleted }
                            .filter(matchesSearch)
                        let stats = GroupStats(tasks: groupItems)
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
                                            NotificationManager.cancelReminder(for: groupTasks[index])
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
            .monogramWatermark()
            .compartmentsTabBar()
            .navigationTitle("Tasks")
            .searchable(text: $searchText, prompt: "Search tasks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
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
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filter: \(filter.rawValue)")
                }
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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingScanList = true
                    } label: {
                        Image(systemName: "text.viewfinder")
                    }
                    .accessibilityLabel("Scan a list from a photo")
                    NavigationLink {
                        CalendarTasksView()
                    } label: {
                        Image(systemName: "calendar")
                    }
                    NavigationLink {
                        ShoppingListView()
                    } label: {
                        Image(systemName: "cart")
                    }
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
            .sheet(isPresented: $showingScanList) {
                ScanListView { proposals in
                    for proposal in proposals {
                        let task = TaskItem(
                            title: proposal.title.trimmingCharacters(in: .whitespaces),
                            dueDate: proposal.dueDate,
                            hasTime: proposal.hasTime)
                        modelContext.insert(task)
                    }
                    try? modelContext.save()
                    for task in allTasks where !task.isCompleted {
                        NotificationManager.scheduleReminder(for: task)
                    }
                }
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
        .tint(.accentTasks)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func taskSection(_ title: String, tasks: [TaskItem],
                             headerColor: Color? = nil) -> some View {
        let filtered = tasks.filter(matchesSearch)
        if !filtered.isEmpty {
            Section {
                ForEach(filtered) { task in
                    TaskRowView(task: task)
                        .contentShape(Rectangle())
                        .onTapGesture { taskToEdit = task }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        NotificationManager.cancelReminder(for: filtered[index])
                        modelContext.delete(filtered[index])
                    }
                }
            } header: {
                Text(title)
                    .foregroundStyle(headerColor ?? Color.secondary)
            }
        }
    }

    private func matchesSearch(_ task: TaskItem) -> Bool {
        searchText.isEmpty || task.title.localizedCaseInsensitiveContains(searchText)
    }

    /// One-line capture: parse date words out of the text and create the
    /// task straight away ("Dentist tomorrow 3pm" → task titled "Dentist").
    private func quickAdd() {
        let input = quickAddText.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty else { return }
        let parsed = QuickAddParser.parse(input)
        let task = TaskItem(title: parsed.title,
                            dueDate: parsed.dueDate,
                            hasTime: parsed.hasTime)
        modelContext.insert(task)
        try? modelContext.save()
        NotificationManager.scheduleReminder(for: task)
        quickAddText = ""
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

    private struct GroupStats {
        let completed: Int
        let total: Int

        init(tasks: [TaskItem]) {
            completed = tasks.filter(\.isCompleted).count
            total = tasks.count
        }

        var progress: Double {
            total == 0 ? 0 : Double(completed) / Double(total)
        }
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
