import SwiftUI
import SwiftData

/// Lets a whole box link to — or depend on — existing tasks and subtasks
/// belonging to other boxes. Same pop-out menu as a task's or subtask's
/// own linker (link / depends on / blocks), but flat: a box has no "self"
/// ambiguity the way a task or subtask does when a box shows up as a
/// candidate, so there's no whole-box-vs-something-inside-it popup here —
/// tasks and subtasks are just two plain sections. Completed tasks and
/// completed subtasks never appear as candidates.
struct LinkedTasksForBoxView: View {
    @Bindable var box: TaskBox
    @Query private var allTasks: [TaskItem]
    @Query private var allBoxes: [TaskBox]
    @State private var activeSheet: ActiveSheet?

    private enum LinkAction: String {
        case link, dependsOn, blocks

        var sheetTitle: String {
            switch self {
            case .link: "Link"
            case .dependsOn: "Depends On"
            case .blocks: "Blocks"
            }
        }

        var emptyMessage: String {
            switch self {
            case .link: "Nothing to link"
            case .dependsOn: "No other tasks or subtasks to depend on"
            case .blocks: "No other tasks or subtasks to block"
            }
        }
    }

    private enum ActiveSheet: Identifiable {
        case picker(LinkAction)
        var id: String {
            switch self { case .picker(let action): "picker-\(action.rawValue)" }
        }
    }

    private var otherBoxesSubtasks: [BoxSubtask] {
        allBoxes.filter { $0 !== box }.flatMap(\.allSubtasks)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(box.allLinkedTasks) { task in
                relatedRow(icon: "link", tint: .secondary, title: task.title) {
                    box.unlink(task)
                }
            }
            ForEach(box.allLinkedSubtasks) { subtask in
                relatedRow(icon: "checklist", tint: .secondary, title: subtask.title,
                          subtitle: subtask.box?.name) {
                    box.unlink(subtask)
                }
            }

            ForEach(box.allTaskBlockers) { task in
                relatedRow(icon: "arrow.triangle.branch", tint: .red, title: task.title) {
                    box.removeBlocker(task)
                }
            }
            ForEach(box.allSubtaskBlockers) { subtask in
                relatedRow(icon: "arrow.triangle.branch", tint: .red, title: subtask.title,
                          subtitle: subtask.box?.name) {
                    box.removeBlocker(subtask)
                }
            }

            ForEach(box.allBlockedTasks) { task in
                relatedRow(icon: "arrow.triangle.branch", tint: .green, title: task.title) {
                    task.removeBlocker(box)
                }
            }
            ForEach(box.allBlockedSubtasks) { subtask in
                relatedRow(icon: "arrow.triangle.branch", tint: .green, title: subtask.title,
                          subtitle: subtask.box?.name) {
                    subtask.removeBlocker(box)
                }
            }

            Menu {
                Button {
                    activeSheet = .picker(.link)
                } label: {
                    Label("Link a task or subtask", systemImage: "link")
                }
                Button {
                    activeSheet = .picker(.dependsOn)
                } label: {
                    Label("This box depends on…", systemImage: "arrow.triangle.branch")
                }
                Button {
                    activeSheet = .picker(.blocks)
                } label: {
                    Label("This box blocks…", systemImage: "arrow.triangle.branch")
                }
            } label: {
                Label("Link or add a dependency", systemImage: "link.badge.plus")
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .picker(let action):
                pickerSheet(action: action)
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

    // MARK: - Sheet

    @ViewBuilder
    private func pickerSheet(action: LinkAction) -> some View {
        NavigationStack {
            List {
                let tasks = availableTasks(for: action)
                let subtasks = availableSubtasks(for: action)
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
                if !subtasks.isEmpty {
                    Section("Subtasks") {
                        ForEach(subtasks) { candidate in
                            Button {
                                choose(candidate, action: action)
                            } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(candidate.title)
                                        .foregroundStyle(.primary)
                                    if let box = candidate.box {
                                        Text(box.name)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
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
                if availableTasks(for: action).isEmpty && availableSubtasks(for: action).isEmpty {
                    ContentUnavailableView(action.emptyMessage, systemImage: "link")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Candidates

    private func availableTasks(for action: LinkAction) -> [TaskItem] {
        allTasks.filter { candidate in
            !candidate.isCompleted && !isRelated(candidate, action: action)
        }
    }

    private func availableSubtasks(for action: LinkAction) -> [BoxSubtask] {
        otherBoxesSubtasks.filter { candidate in
            !candidate.isCompleted && !isRelated(candidate, action: action)
        }
    }

    private func isRelated(_ candidate: TaskItem, action: LinkAction) -> Bool {
        switch action {
        case .link: box.allLinkedTasks.contains { $0 === candidate }
        case .dependsOn: box.allTaskBlockers.contains { $0 === candidate }
        case .blocks: box.allBlockedTasks.contains { $0 === candidate }
        }
    }

    private func isRelated(_ candidate: BoxSubtask, action: LinkAction) -> Bool {
        switch action {
        case .link: box.allLinkedSubtasks.contains { $0 === candidate }
        case .dependsOn: box.allSubtaskBlockers.contains { $0 === candidate }
        case .blocks: box.allBlockedSubtasks.contains { $0 === candidate }
        }
    }

    // MARK: - Choosing a target

    private func choose(_ candidate: TaskItem, action: LinkAction) {
        switch action {
        case .link: box.link(candidate)
        case .dependsOn: box.addBlocker(candidate)
        case .blocks: candidate.addBlocker(box)
        }
        activeSheet = nil
    }

    private func choose(_ candidate: BoxSubtask, action: LinkAction) {
        switch action {
        case .link: box.link(candidate)
        case .dependsOn: box.addBlocker(candidate)
        case .blocks: candidate.addBlocker(box)
        }
        activeSheet = nil
    }
}
