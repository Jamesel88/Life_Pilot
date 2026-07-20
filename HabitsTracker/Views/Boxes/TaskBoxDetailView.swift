import SwiftUI
import SwiftData

/// Inside one box: the animated box up top, its own subtasks below, and
/// existing tasks linked in via the same "Link a task" flow used when
/// editing a task. Completing items here fills the box; linked tasks stay
/// in sync with the Tasks tab because they're the same TaskItem records.
struct TaskBoxDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var box: TaskBox
    @Query private var allTasks: [TaskItem]

    @State private var showingAddSubtask = false
    @State private var subtaskToEdit: BoxSubtask?
    @State private var showingLinkPicker = false
    @State private var showingEditBox = false

    private var sortedSubtasks: [BoxSubtask] {
        box.allSubtasks.sorted { $0.createdAt < $1.createdAt }
    }

    private var availableTasks: [TaskItem] {
        allTasks.filter { candidate in
            !box.allLinkedTasks.contains(where: { $0 === candidate })
        }
    }

    var body: some View {
        List {
            // MARK: The box itself
            Section {
                VStack(spacing: 12) {
                    CompartmentBoxView(color: Color(hex: box.displayColorHex),
                                       completed: box.completedCount,
                                       total: box.totalCount)
                        .frame(width: 130, height: 130)

                    if let group = box.group {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: group.colorHex))
                                .frame(width: 10, height: 10)
                            Text(group.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if box.totalCount == 0 {
                        Text("Every subtask or linked task becomes a compartment")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if box.isOpen {
                        Text("\(box.completedCount) of \(box.totalCount) compartments filled")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("All done — box sealed!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color(hex: box.displayColorHex))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            // MARK: Subtasks
            Section("Subtasks") {
                ForEach(sortedSubtasks) { subtask in
                    SubtaskRowView(subtask: subtask)
                        .contentShape(Rectangle())
                        .onTapGesture { subtaskToEdit = subtask }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        modelContext.delete(sortedSubtasks[index])
                    }
                }

                Button {
                    showingAddSubtask = true
                } label: {
                    Label("Add a subtask", systemImage: "plus.circle")
                }
            }

            // MARK: Linked tasks
            Section("Linked tasks") {
                ForEach(box.allLinkedTasks) { task in
                    HStack {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TaskRowView(task: task)
                        Button {
                            unlink(task)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    showingLinkPicker = true
                } label: {
                    Label("Link a task", systemImage: "link.badge.plus")
                }
            }
        }
        .monogramWatermark()
        .navigationTitle(box.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditBox = true
                } label: {
                    Image(systemName: "pencil.circle")
                }
            }
        }
        .sheet(isPresented: $showingLinkPicker) {
            NavigationStack {
                List(availableTasks) { candidate in
                    Button {
                        if box.linkedTasks == nil { box.linkedTasks = [] }
                        box.linkedTasks?.append(candidate)
                        showingLinkPicker = false
                    } label: {
                        TaskRowView(task: candidate)
                    }
                    .buttonStyle(.plain)
                }
                .navigationTitle("Link a Task")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingLinkPicker = false }
                    }
                }
                .overlay {
                    if availableTasks.isEmpty {
                        ContentUnavailableView("No other tasks to link",
                            systemImage: "link")
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingEditBox) {
            EditTaskBoxView(box: box)
        }
        .sheet(isPresented: $showingAddSubtask) {
            SubtaskEditorView(box: box)
        }
        .sheet(item: $subtaskToEdit) { subtask in
            SubtaskEditorView(box: box, subtask: subtask)
        }
    }

    private func unlink(_ task: TaskItem) {
        box.linkedTasks?.removeAll { $0 === task }
    }
}

/// One subtask row: completion toggle, title, and captions for the due
/// date (red once overdue) and any photo attachments.
struct SubtaskRowView: View {
    @Bindable var subtask: BoxSubtask

    var body: some View {
        HStack {
            CompletionToggleButton(isCompleted: subtask.isCompleted,
                                   itemTitle: subtask.title) {
                withAnimation {
                    subtask.isCompleted.toggle()
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(subtask.title)
                    .strikethrough(subtask.isCompleted)
                    .foregroundStyle(subtask.isCompleted ? .secondary : .primary)

                if !subtask.notes.isEmpty {
                    Text(subtask.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    if let dueDate = subtask.dueDate {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                            Text(dueDate, format: .dateTime.day().month())
                        }
                        .foregroundStyle(subtask.isOverdue ? .red : .secondary)
                    }
                    if !(subtask.photos ?? []).isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "photo")
                            Text("\((subtask.photos ?? []).count)")
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .font(.caption2)
            }

            Spacer()
        }
    }
}
