import SwiftUI
import SwiftData

/// Every task belonging to one group — pushed when a group's mini ring on
/// the dashboard is tapped. Same ring-and-count language as the dashboard,
/// with outstanding work first and completed history below.
struct GroupTasksView: View {
    @Environment(\.modelContext) private var modelContext
    let group: TaskGroup
    @Query(sort: \TaskItem.dueDate) private var allTasks: [TaskItem]
    @State private var taskToEdit: TaskItem?

    private var groupColor: Color { Color(hex: group.colorHex) }

    private var groupTasks: [TaskItem] {
        allTasks.filter { $0.group === group }
    }
    private var outstanding: [TaskItem] {
        groupTasks.filter { !$0.isCompleted }
    }
    private var completed: [TaskItem] {
        groupTasks.filter(\.isCompleted)
    }
    private var progress: Double {
        groupTasks.isEmpty ? 0 : Double(completed.count) / Double(groupTasks.count)
    }

    var body: some View {
        List {
            // MARK: Progress header
            Section {
                VStack(spacing: 10) {
                    ZStack {
                        RingView(progress: progress, color: groupColor, lineWidth: 10)
                            .frame(width: 90, height: 90)
                        VStack(spacing: 0) {
                            Text("\(completed.count)/\(groupTasks.count)")
                                .font(.headline.monospacedDigit())
                            Text("done")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !outstanding.isEmpty {
                        Text("\(outstanding.count) left to do")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !groupTasks.isEmpty {
                        Text("All done — nice work!")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(groupColor)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            if !outstanding.isEmpty {
                Section("Outstanding") {
                    taskRows(outstanding)
                }
            }

            if !completed.isEmpty {
                Section("Completed") {
                    taskRows(completed)
                }
            }
        }
        .monogramWatermark()
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $taskToEdit) { task in
            EditTaskView(task: task)
        }
        .overlay {
            if groupTasks.isEmpty {
                ContentUnavailableView("No tasks in this group",
                    systemImage: "circle.dashed",
                    description: Text("Assign tasks to \"\(group.name)\" and they'll show up here"))
            }
        }
        .tint(groupColor)
    }

    @ViewBuilder
    private func taskRows(_ tasks: [TaskItem]) -> some View {
        ForEach(tasks) { task in
            TaskRowView(task: task)
                .contentShape(Rectangle())
                .onTapGesture { taskToEdit = task }
        }
        .onDelete { indexSet in
            for index in indexSet {
                NotificationManager.cancelReminder(for: tasks[index])
                modelContext.delete(tasks[index])
            }
        }
    }
}
