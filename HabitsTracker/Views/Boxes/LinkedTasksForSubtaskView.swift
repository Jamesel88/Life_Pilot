import SwiftUI
import SwiftData

/// Lets one subtask link to existing tasks, to a whole compartment box,
/// or to another subtask — the same three categories and the same
/// whole-box-vs-subtask popup as a task's own linker. Completed tasks,
/// sealed boxes, and completed subtasks never appear as candidates; a
/// subtask's own parent box is excluded too (that's containment, not a
/// link).
struct LinkedTasksForSubtaskView: View {
    @Bindable var subtask: BoxSubtask
    @Query private var allTasks: [TaskItem]
    @Query private var allBoxes: [TaskBox]
    @State private var showingPicker = false
    @State private var boxPendingChoice: TaskBox?
    @State private var boxForSubtaskPicking: TaskBox?

    private var availableTasks: [TaskItem] {
        allTasks.filter { candidate in
            !candidate.isCompleted
                && !subtask.allLinkedTasks.contains(where: { $0 === candidate })
        }
    }

    private var availableBoxes: [TaskBox] {
        allBoxes.filter { box in
            box !== subtask.box
                && !box.isSealed
                && !subtask.allLinkedBoxes.contains(where: { $0 === box })
        }
    }

    private func openSubtasks(in box: TaskBox) -> [BoxSubtask] {
        box.allSubtasks.filter { !$0.isCompleted && $0 !== subtask }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(subtask.allLinkedTasks) { linked in
                HStack {
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)
                    Text(linked.title)
                    Spacer()
                    Button {
                        subtask.unlink(linked)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(subtask.allLinkedBoxes) { box in
                HStack {
                    Image(systemName: "shippingbox")
                        .foregroundStyle(.secondary)
                    Text(box.name)
                    Spacer()
                    Button {
                        subtask.unlink(box)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(subtask.allLinkedSubtasks) { peer in
                HStack {
                    Image(systemName: "checklist")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(peer.title)
                        if let box = peer.box {
                            Text(box.name)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        subtask.unlink(peer)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                showingPicker = true
            } label: {
                Label("Link a task or box", systemImage: "link.badge.plus")
            }
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                List {
                    if !availableTasks.isEmpty {
                        Section("Tasks") {
                            ForEach(availableTasks) { candidate in
                                Button {
                                    subtask.link(candidate)
                                    showingPicker = false
                                } label: {
                                    Text(candidate.title)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                    if !availableBoxes.isEmpty {
                        Section("Compartment boxes") {
                            ForEach(availableBoxes) { box in
                                Button {
                                    boxPendingChoice = box
                                } label: {
                                    Label(box.name, systemImage: "shippingbox")
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Link")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingPicker = false }
                    }
                }
                .overlay {
                    if availableTasks.isEmpty && availableBoxes.isEmpty {
                        ContentUnavailableView("Nothing to link",
                            systemImage: "link")
                    }
                }
                // The same whole-box-vs-subtask popup as a task's linker
                .confirmationDialog(
                    boxPendingChoice.map { "Link to \($0.name)" } ?? "",
                    isPresented: Binding(
                        get: { boxPendingChoice != nil },
                        set: { if !$0 { boxPendingChoice = nil } }),
                    titleVisibility: .visible
                ) {
                    if let box = boxPendingChoice {
                        Button("Link the whole box") {
                            box.link(subtask)
                            boxPendingChoice = nil
                            showingPicker = false
                        }
                        if !openSubtasks(in: box).isEmpty {
                            Button("Choose a subtask instead") {
                                boxForSubtaskPicking = box
                                boxPendingChoice = nil
                                showingPicker = false
                            }
                        }
                        Button("Cancel", role: .cancel) { boxPendingChoice = nil }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $boxForSubtaskPicking) { box in
            NavigationStack {
                List(openSubtasks(in: box)) { peer in
                    Button {
                        subtask.link(peer)
                        boxForSubtaskPicking = nil
                    } label: {
                        Text(peer.title)
                            .foregroundStyle(.primary)
                    }
                }
                .navigationTitle("Link to a subtask")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { boxForSubtaskPicking = nil }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}
