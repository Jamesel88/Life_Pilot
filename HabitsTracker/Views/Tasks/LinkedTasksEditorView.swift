import SwiftUI
import SwiftData

/// Lets a task be linked to — or made dependent on — other tasks, whole
/// compartment boxes, or individual subtasks. One pop-out menu offers the
/// three actions (link, depends on, blocks); each opens the same
/// task-or-box picker, with a box tap offering the choice between the
/// whole box or one of its subtasks, so every action reaches all three
/// target kinds through one consistent flow instead of tripling the UI.
/// Linking and dependency edges always update both sides so opening
/// either end shows the connection. Completed tasks, sealed boxes, and
/// completed subtasks never appear as candidates — nothing new belongs
/// on finished work.
struct LinkedTasksEditorView: View {
    @Bindable var task: TaskItem
    @Query private var allTasks: [TaskItem]
    @Query private var allBoxes: [TaskBox]
    @State private var activeSheet: ActiveSheet?
    @State private var boxPendingChoice: TaskBox?

    /// The three things this menu can do once a target is chosen.
    private enum LinkAction: String {
        case link, dependsOn, blocks

        var sheetTitle: String {
            switch self {
            case .link: "Link"
            case .dependsOn: "Depends On"
            case .blocks: "Blocks"
            }
        }

        var wholeBoxChoiceLabel: String {
            switch self {
            case .link: "Link the whole box"
            case .dependsOn: "Depend on the whole box"
            case .blocks: "Block the whole box"
            }
        }

        var emptyMessage: String {
            switch self {
            case .link: "Nothing to link"
            case .dependsOn: "No other tasks or boxes to depend on"
            case .blocks: "No other tasks or boxes to block"
            }
        }
    }

    private enum ActiveSheet: Identifiable {
        case picker(LinkAction)
        case subtaskPicker(TaskBox, LinkAction)

        var id: String {
            switch self {
            case .picker(let action): "picker-\(action.rawValue)"
            case .subtaskPicker(let box, let action): "subtask-\(box.persistentModelID)-\(action.rawValue)"
            }
        }
    }

    private var linkedBoxes: [TaskBox] { task.containingBoxes ?? [] }
    private var linkedSubtasks: [BoxSubtask] { task.linkedSubtasks ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(task.allLinkedTasks) { linked in
                relatedRow(icon: "link", tint: .secondary, title: linked.title) {
                    task.unlink(from: linked)
                }
            }
            ForEach(linkedBoxes) { box in
                relatedRow(icon: "shippingbox", tint: .secondary, title: box.name) {
                    box.unlink(task)
                }
            }
            ForEach(linkedSubtasks) { subtask in
                relatedRow(icon: "checklist", tint: .secondary, title: subtask.title,
                          subtitle: subtask.box?.name) {
                    subtask.unlink(task)
                }
            }

            ForEach(task.allBlockers) { blocker in
                relatedRow(icon: "arrow.triangle.branch", tint: .red, title: blocker.title) {
                    task.removeBlocker(blocker)
                }
            }
            ForEach(task.allBoxBlockers) { box in
                relatedRow(icon: "arrow.triangle.branch", tint: .red, title: box.name) {
                    task.removeBlocker(box)
                }
            }
            ForEach(task.allSubtaskBlockers) { subtask in
                relatedRow(icon: "arrow.triangle.branch", tint: .red, title: subtask.title,
                          subtitle: subtask.box?.name) {
                    task.removeBlocker(subtask)
                }
            }

            ForEach(task.allBlocked) { blocked in
                relatedRow(icon: "arrow.triangle.branch", tint: .green, title: blocked.title) {
                    blocked.removeBlocker(task)
                }
            }
            ForEach(task.allBlockedBoxes) { box in
                relatedRow(icon: "arrow.triangle.branch", tint: .green, title: box.name) {
                    box.removeBlocker(task)
                }
            }
            ForEach(task.allBlockedSubtasks) { subtask in
                relatedRow(icon: "arrow.triangle.branch", tint: .green, title: subtask.title,
                          subtitle: subtask.box?.name) {
                    subtask.removeBlocker(task)
                }
            }

            Menu {
                Button {
                    activeSheet = .picker(.link)
                } label: {
                    Label("Link a task, box, or subtask", systemImage: "link")
                }
                Button {
                    activeSheet = .picker(.dependsOn)
                } label: {
                    Label("This task depends on…", systemImage: "arrow.triangle.branch")
                }
                Button {
                    activeSheet = .picker(.blocks)
                } label: {
                    Label("This task blocks…", systemImage: "arrow.triangle.branch")
                }
            } label: {
                Label("Link or add a dependency", systemImage: "link.badge.plus")
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .picker(let action):
                pickerSheet(action: action)
            case .subtaskPicker(let box, let action):
                subtaskPickerSheet(box: box, action: action)
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func relatedRow(icon: String, tint: Color, title: String, subtitle: String? = nil,
                            onRemove: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private func pickerSheet(action: LinkAction) -> some View {
        NavigationStack {
            List {
                let tasks = availableTasks(for: action)
                let boxes = availableBoxes(for: action)
                if !tasks.isEmpty {
                    Section("Tasks") {
                        ForEach(tasks) { candidate in
                            Button {
                                choose(candidate, action: action)
                            } label: {
                                Text(candidate.title)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                if !boxes.isEmpty {
                    Section("Compartment boxes") {
                        ForEach(boxes) { box in
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
            .navigationTitle(action.sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { activeSheet = nil }
                }
            }
            .overlay {
                if availableTasks(for: action).isEmpty && availableBoxes(for: action).isEmpty {
                    ContentUnavailableView(action.emptyMessage, systemImage: "link")
                }
            }
            // The whole-box-vs-subtask choice, as a popup right when a
            // box is tapped — same pattern for all three actions.
            .confirmationDialog(
                boxPendingChoice.map { "\(action.sheetTitle): \($0.name)" } ?? "",
                isPresented: Binding(
                    get: { boxPendingChoice != nil },
                    set: { if !$0 { boxPendingChoice = nil } }),
                titleVisibility: .visible
            ) {
                if let box = boxPendingChoice {
                    Button(action.wholeBoxChoiceLabel) {
                        choose(box, action: action)
                        boxPendingChoice = nil
                        activeSheet = nil
                    }
                    if !openSubtasks(in: box, for: action).isEmpty {
                        Button("Choose a subtask instead") {
                            boxPendingChoice = nil
                            activeSheet = .subtaskPicker(box, action)
                        }
                    }
                    Button("Cancel", role: .cancel) { boxPendingChoice = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func subtaskPickerSheet(box: TaskBox, action: LinkAction) -> some View {
        NavigationStack {
            List(openSubtasks(in: box, for: action)) { subtask in
                Button {
                    choose(subtask, action: action)
                } label: {
                    Text(subtask.title)
                        .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Choose a subtask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { activeSheet = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Candidates

    private func availableTasks(for action: LinkAction) -> [TaskItem] {
        allTasks.filter { candidate in
            candidate !== task && !candidate.isCompleted && !isRelated(candidate, action: action)
        }
    }

    private func availableBoxes(for action: LinkAction) -> [TaskBox] {
        allBoxes.filter { box in
            !box.isSealed && !isRelated(box, action: action)
        }
    }

    private func openSubtasks(in box: TaskBox, for action: LinkAction) -> [BoxSubtask] {
        box.allSubtasks.filter { !$0.isCompleted && !isRelated($0, action: action) }
    }

    private func isRelated(_ candidate: TaskItem, action: LinkAction) -> Bool {
        switch action {
        case .link: task.allLinkedTasks.contains { $0 === candidate }
        case .dependsOn: task.allBlockers.contains { $0 === candidate }
        case .blocks: task.allBlocked.contains { $0 === candidate }
        }
    }

    private func isRelated(_ box: TaskBox, action: LinkAction) -> Bool {
        switch action {
        case .link: box.allLinkedTasks.contains { $0 === task }
        case .dependsOn: task.allBoxBlockers.contains { $0 === box }
        case .blocks: task.allBlockedBoxes.contains { $0 === box }
        }
    }

    private func isRelated(_ subtask: BoxSubtask, action: LinkAction) -> Bool {
        switch action {
        case .link: (task.linkedSubtasks ?? []).contains { $0 === subtask }
        case .dependsOn: task.allSubtaskBlockers.contains { $0 === subtask }
        case .blocks: task.allBlockedSubtasks.contains { $0 === subtask }
        }
    }

    // MARK: - Choosing a target

    private func choose(_ candidate: TaskItem, action: LinkAction) {
        switch action {
        case .link: task.link(to: candidate)
        case .dependsOn: task.addBlocker(candidate)
        case .blocks: candidate.addBlocker(task)
        }
        activeSheet = nil
    }

    private func choose(_ box: TaskBox, action: LinkAction) {
        switch action {
        case .link: box.link(task)
        case .dependsOn: task.addBlocker(box)
        case .blocks: box.addBlocker(task)
        }
    }

    private func choose(_ subtask: BoxSubtask, action: LinkAction) {
        switch action {
        case .link: subtask.link(task)
        case .dependsOn: task.addBlocker(subtask)
        case .blocks: subtask.addBlocker(task)
        }
        activeSheet = nil
    }
}
