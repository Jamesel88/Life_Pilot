import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var allTasks: [TaskItem]
    @Query private var groups: [TaskGroup]
    @Query private var habits: [Habit]
    @Binding var tabSelection: Int
    @State private var dashboardMonth = Date()

    private var calendar: Calendar { .current }

    // MARK: - Task helpers

    private var todayTasks: [TaskItem] {
        allTasks.filter { calendar.isDateInToday($0.dueDate) }
    }

    /// Today's tasks with incomplete urgent items pinned to the top
    private var sortedTodayTasks: [TaskItem] {
        todayTasks.sorted { a, b in
            let aUrgent = a.priority == .urgent && !a.isCompleted
            let bUrgent = b.priority == .urgent && !b.isCompleted
            if aUrgent != bUrgent { return aUrgent }
            return a.dueDate < b.dueDate
        }
    }

    /// Groups that have at least one task due today
    private var activeGroups: [TaskGroup] {
        groups.filter { group in
            todayTasks.contains { $0.group === group }
        }
    }

    private func progress(for group: TaskGroup) -> Double {
        let tasks = todayTasks.filter { $0.group === group }
        guard !tasks.isEmpty else { return 0 }
        return Double(tasks.filter(\.isCompleted).count) / Double(tasks.count)
    }

    // MARK: - Habit helpers

    private var activeHabits: [Habit] {
        habits.filter { $0.isActive(on: .now) }
    }

    private var habitsDoneToday: Int {
        activeHabits.filter { $0.isCompleted(on: .now) }.count
    }

    private var habitsProgress: Double {
        guard !activeHabits.isEmpty else { return 0 }
        return Double(habitsDoneToday) / Double(activeHabits.count)
    }

    private func dayCompletion(_ day: Date) -> DayCompletion {
        let active = habits.filter { $0.isActive(on: day) }
        guard !active.isEmpty else { return .none }
        let doneCount = active.filter { $0.isCompleted(on: day) }.count
        if doneCount == 0 { return .none }
        if doneCount == active.count { return .full }
        return .partial
    }
    private var overallTaskProgress: Double {
        guard !todayTasks.isEmpty else { return 0 }
        return Double(todayTasks.filter(\.isCompleted).count) / Double(todayTasks.count)
    }

    private func todayTasks(for group: TaskGroup) -> [TaskItem] {
        todayTasks.filter { $0.group === group }
    }

    /// Every task, regardless of due date, that hasn't been completed yet
    private var allOutstandingTasks: [TaskItem] {
        allTasks.filter { !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var overallTasksProgress: Double {
        guard !allTasks.isEmpty else { return 0 }
        return Double(allTasks.filter(\.isCompleted).count) / Double(allTasks.count)
    }

    private var isDashboardAtCurrentMonth: Bool {
        calendar.isDate(dashboardMonth, equalTo: .now, toGranularity: .month)
    }

    private func changeDashboardMonth(_ delta: Int) {
        if delta > 0 && isDashboardAtCurrentMonth { return }
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: dashboardMonth) {
            dashboardMonth = newMonth
        }
    }
    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: Today's tasks
                    if !todayTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Today")
                                    .font(.headline)
                                Text(Date.now, format: .dateTime.weekday(.wide).day().month())
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            ForEach(sortedTodayTasks) { task in
                                if task.priority == .urgent && !task.isCompleted {
                                    TaskRowView(task: task)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 6)
                                        .background(.red.opacity(0.85),
                                                    in: RoundedRectangle(cornerRadius: 10))
                                } else {
                                    TaskRowView(task: task)
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    // MARK: Group rings
                    if !groups.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 18) {
                                ForEach(groups) { group in
                                    let groupTasks = todayTasks(for: group)
                                    VStack(spacing: 6) {
                                        ZStack {
                                            RingView(progress: progress(for: group),
                                                     color: Color(hex: group.colorHex),
                                                     lineWidth: 7)
                                                .frame(width: 54, height: 54)
                                            Text("\(groupTasks.filter(\.isCompleted).count)/\(groupTasks.count)")
                                                .font(.caption2.bold())
                                        }
                                        .frame(width: 64, height: 64)
                                        .background(Circle().fill(Color.primary.opacity(0.06)))

                                        Text(group.name)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    .onTapGesture { tabSelection = 1 }
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 6)
                        }
                        .scrollClipDisabled()
                    }
                    // MARK: Overview rings
                    ZStack {
                        RingView(progress: overallTaskProgress, color: .green)
                            .frame(width: 220, height: 220)

                        RingView(progress: habitsProgress, color: .orange)
                            .frame(width: 174, height: 174)

                        RingView(progress: overallTasksProgress, color: .blue)
                            .frame(width: 128, height: 128)

                        VStack(spacing: 2) {
                            Text("\(todayTasks.filter(\.isCompleted).count)/\(todayTasks.count)")
                                .font(.title3.bold())
                                .foregroundStyle(.green)
                            Text("tasks")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text("\(habitsDoneToday)/\(activeHabits.count)")
                                .font(.title3.bold())
                                .foregroundStyle(.orange)
                            Text("habits")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text("\(allTasks.filter(\.isCompleted).count)/\(allTasks.count)")
                                .font(.title3.bold())
                                .foregroundStyle(.blue)
                            Text("overall tasks")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 24)

                    // MARK: Legend
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Circle().fill(.green).frame(width: 10, height: 10)
                            Text("Tasks").font(.caption)
                        }
                        HStack(spacing: 6) {
                            Circle().fill(.orange).frame(width: 10, height: 10)
                            Text("Habits").font(.caption)
                        }
                        HStack(spacing: 6) {
                            Circle().fill(.blue).frame(width: 10, height: 10)
                            Text("Overall tasks").font(.caption)
                        }
                    }

                    // MARK: All outstanding tasks
                    VStack(alignment: .leading, spacing: 8) {
                        Text("All Outstanding Tasks")
                            .font(.headline)

                        if allOutstandingTasks.isEmpty {
                            Text("Nothing outstanding — nice work!")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView {
                                VStack(spacing: 12) {
                                    ForEach(allOutstandingTasks) { task in
                                        TaskRowView(task: task)
                                    }
                                }
                            }
                            .frame(height: 220)
                        }
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    // MARK: Habit calendar
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Habits Daily Progress Dashboard")
                            .font(.headline)
                        RadialCalendarView(month: dashboardMonth, dayCompletion: dayCompletion)
                            .frame(height: 240)
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .contentShape(Rectangle())
                    .onTapGesture { tabSelection = 2 }
                    .gesture(
                        DragGesture(minimumDistance: 24)
                            .onEnded { value in
                                if value.translation.width < -24 {
                                    changeDashboardMonth(1)
                                } else if value.translation.width > 24 {
                                    changeDashboardMonth(-1)
                                }
                            }
                    )
                }
                .padding()
            }
            .navigationTitle("Cockpit")
        }
    }
}
