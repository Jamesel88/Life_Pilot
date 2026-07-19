import SwiftUI
import SwiftData

/// Lets a task be linked to other existing tasks (dependencies/related
/// work). Linking and unlinking always update both sides so opening either
/// task shows the connection.
struct LinkedTasksEditorView: View {
    @Bindable var task: TaskItem
    @Query private var allTasks: [TaskItem]
    @State private var showingPicker = false

    private var availableTasks: [TaskItem] {
        allTasks.filter { candidate in
            candidate !== task && !task.linkedTasks.contains(where: { $0 === candidate })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !task.linkedTasks.isEmpty {
                ForEach(task.linkedTasks) { linked in
                    HStack {
                        Image(systemName: "link")
                            .foregroundStyle(.secondary)
                        Text(linked.title)
                        Spacer()
                        Button {
                            task.unlink(from: linked)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                showingPicker = true
            } label: {
                Label("Link a task", systemImage: "link.badge.plus")
            }
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                List(availableTasks) { candidate in
                    Button {
                        task.link(to: candidate)
                        showingPicker = false
                    } label: {
                        Text(candidate.title)
                            .foregroundStyle(.primary)
                    }
                }
                .navigationTitle("Link a Task")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingPicker = false }
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
    }

}
