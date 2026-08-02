import SwiftUI
import SwiftData

/// Lets one subtask link to — or depend on — existing tasks, a whole
/// compartment box, or another subtask. One pop-out menu offers three
/// actions (link, depends on, blocks); linking keeps the whole-box-vs-
/// one-of-its-subtasks popup (a link can mean either), while a dependency
/// target is unambiguous on its own — a task, a whole box, or a specific
/// subtask (any box, not just this one's own) — so those are three plain
/// sections with no popup needed. Completed tasks, sealed boxes, and
/// completed subtasks never appear as candidates; a subtask's own parent
/// box is excluded from the neutral link list too (that's containment,
/// not a link).
struct LinkedTasksForSubtaskView: View {
    @Bindable var subtask: BoxSubtask
    @Query private var allTasks: [TaskItem]
    @Query private var allBoxes: [TaskBox]
    @State private var activeSheet: ActiveSheet?
    @State private var boxPendingChoice: TaskBox?

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
            case .dependsOn: "No other tasks, boxes, or subtasks to depend on"
            case .blocks: "No other tasks, boxes, or subtasks to block"
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

    private var everySubtask: [BoxSubtask] {
        allBoxes.flatMap(\.allSubtasks)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(subtask.allLinkedTasks) { linked in
                relatedRow(icon: "link", tint: .secondary, title: linked.title) {
                    subtask.unlink(linked)
                }
            }
            ForEach(subtask.allLinkedBoxes) { box in
                relatedRow(icon: "shippingbox", tint: .secondary, title: box.name) {
                    subtask.unlink(box)
                }
            }
            ForEach(subtask.allLinkedSubtasks) { peer in
                relatedRow(icon: "checklist", tint: .secondary, title: peer.title,
                          subtitle: peer.box?.name) {
                    subtask.unlink(peer)
                }
            }

            ForEach(subtask.allTaskBlockers) { blocker in
                relatedRow(icon: "arrow.triangle.branch", tint: .red, title: blocker.title) {
                    subtask.removeBlocker(blocker)
                }
            }
            ForEach(subtask.allBoxBlockers) { box in
                relatedRow(icon: "arrow.triangle.branch", tint: .red, title: box.name) {
                    subtask.removeBlocker(box)
                }
            }
            ForEach(subtask.allSubtaskBlockers) { blocker in
                relatedRow(icon: "arrow.triangle.branch", tint: .red, title: blocker.title,
                          subtitle: blocker.box?.name) {
                    subtask.removeBlockingSubtask(blocker)
                }
            }

            ForEach(subtask.allBlockedTasks) { blocked in
                relatedRow(icon: "arrow.triangle.branch", tint: .green, title: blocked.title) {
                    blocked.removeBlocker(subtask)
                }
            }
            ForEach(subtask.allBlockedBoxes) { box in
                relatedRow(icon: "arrow.triangle.branch", tint: .green, title: box.name) {
                    box.removeBlocker(subtask)
                }
            }
            ForEach(subtask.allSubtaskBlocked) { blocked in
                relatedRow(icon: "arrow.triangle.branch", tint: .green, title: blocked.title,
                          subtitle: blocked.box?.name) {
                    blocked.removeBlockingSubtask(subtask)
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
                    Label("This subtask depends on…", systemImage: "arrow.triangle.branch")
                }
                Button {
                    activeSheet = .picker(.blocks)
                } label: {
                    Label("This subtask blocks…", systemImage: "arrow.triangle.branch")
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
                            if action == .link {
                                Button {
                                    boxPendingChoice = box
                                } label: {
                                    Label(box.name, systemImage: "shippingbox")
                                        .foregroundStyle(.primary)
                                }
                            } else {
                                Button {
                                    choose(box, action: action)
                                } label: {
                                    Label(box.name, systemImage: "shippingbox")
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }
                // Dependency actions can reach any subtask directly — no
                // need to drill into a box first, since a specific subtask
                // (rather than the whole box) is exactly what's meant here.
                if action != .link {
                    let peers = availablePeerSubtasks(for: action)
                    if !peers.isEmpty {
                        Section("Subtasks") {
                            ForEach(peers) { candidate in
                                Button {
                                    choosePeer(candidate, action: action)
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
            }
            .navigationTitle(action.sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { activeSheet = nil }
                }
            }
            .overlay {
                if isEmptyPicker(action) {
                    ContentUnavailableView(action.emptyMessage, systemImage: "link")
                }
            }
            // The whole-box-vs-subtask choice — only for the neutral link
            // action, where a box tap is genuinely ambiguous.
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
                        activeSheet = nil
                    }
                    if !openSubtasks(in: box).isEmpty {
                        Button("Choose a subtask instead") {
                            boxPendingChoice = nil
                            activeSheet = .subtaskPicker(box, .link)
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
            List(openSubtasks(in: box)) { peer in
                Button {
                    subtask.link(peer)
                    activeSheet = nil
                } label: {
                    Text(peer.title)
                        .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Link to a subtask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { activeSheet = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func isEmptyPicker(_ action: LinkAction) -> Bool {
        let noTasks = availableTasks(for: action).isEmpty
        let noBoxes = availableBoxes(for: action).isEmpty
        let noPeers = action == .link || availablePeerSubtasks(for: action).isEmpty
        return noTasks && noBoxes && noPeers
    }

    // MARK: - Candidates

    private func availableTasks(for action: LinkAction) -> [TaskItem] {
        allTasks.filter { candidate in
            !candidate.isCompleted && !isRelated(candidate, action: action)
        }
    }

    private func availableBoxes(for action: LinkAction) -> [TaskBox] {
        allBoxes.filter { box in
            box !== subtask.box && !box.isSealed && !isRelated(box, action: action)
        }
    }

    /// Peer-subtask candidates for a dependency, spanning every box's
    /// subtasks — not just this one's own parent, since a dependency can
    /// cross boxes (unlike the neutral link's box-drill-down).
    private func availablePeerSubtasks(for action: LinkAction) -> [BoxSubtask] {
        everySubtask.filter { candidate in
            candidate !== subtask && !candidate.isCompleted && !isRelatedPeer(candidate, action: action)
        }
    }

    private func openSubtasks(in box: TaskBox) -> [BoxSubtask] {
        box.allSubtasks.filter { !$0.isCompleted && $0 !== subtask }
    }

    private func isRelated(_ candidate: TaskItem, action: LinkAction) -> Bool {
        switch action {
        case .link: subtask.allLinkedTasks.contains { $0 === candidate }
        case .dependsOn: subtask.allTaskBlockers.contains { $0 === candidate }
        case .blocks: subtask.allBlockedTasks.contains { $0 === candidate }
        }
    }

    private func isRelated(_ box: TaskBox, action: LinkAction) -> Bool {
        switch action {
        case .link: subtask.allLinkedBoxes.contains { $0 === box }
        case .dependsOn: subtask.allBoxBlockers.contains { $0 === box }
        case .blocks: subtask.allBlockedBoxes.contains { $0 === box }
        }
    }

    private func isRelatedPeer(_ candidate: BoxSubtask, action: LinkAction) -> Bool {
        switch action {
        case .link: subtask.allLinkedSubtasks.contains { $0 === candidate }
        case .dependsOn: subtask.allSubtaskBlockers.contains { $0 === candidate }
        case .blocks: subtask.allSubtaskBlocked.contains { $0 === candidate }
        }
    }

    // MARK: - Choosing a target

    private func choose(_ candidate: TaskItem, action: LinkAction) {
        switch action {
        case .link: subtask.link(candidate)
        case .dependsOn: subtask.addBlocker(candidate)
        case .blocks: candidate.addBlocker(subtask)
        }
        activeSheet = nil
    }

    private func choose(_ box: TaskBox, action: LinkAction) {
        switch action {
        case .link: break   // handled by the whole-box-vs-subtask popup
        case .dependsOn: subtask.addBlocker(box)
        case .blocks: box.addBlocker(subtask)
        }
        activeSheet = nil
    }

    private func choosePeer(_ candidate: BoxSubtask, action: LinkAction) {
        switch action {
        case .link: subtask.link(candidate)
        case .dependsOn: subtask.addBlockingSubtask(candidate)
        case .blocks: candidate.addBlockingSubtask(subtask)
        }
        activeSheet = nil
    }
}
