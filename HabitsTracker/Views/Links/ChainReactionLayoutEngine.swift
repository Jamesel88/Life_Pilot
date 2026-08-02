import SwiftData
import Foundation

/// One task or subtask participating in an active dependency chain. Only
/// items with at least one directional (blocks/depends-on) edge ever show
/// up here — this is a map of live dependency chains, not a general
/// browser of every task or subtask in the app.
enum ChainItemKind {
    case task(TaskItem)
    case subtask(BoxSubtask)
}

struct ChainItem: Identifiable {
    let kind: ChainItemKind

    var id: PersistentIdentifier {
        switch kind {
        case .task(let task): task.persistentModelID
        case .subtask(let subtask): subtask.persistentModelID
        }
    }

    var title: String {
        switch kind {
        case .task(let task): task.title
        case .subtask(let subtask): subtask.title
        }
    }

    var isCompleted: Bool {
        switch kind {
        case .task(let task): task.isCompleted
        case .subtask(let subtask): subtask.isCompleted
        }
    }

    var isSubtask: Bool {
        if case .subtask = kind { return true }
        return false
    }
}

/// A directed dependency edge: `blockerID` must finish before `blockedID`
/// can start. Only ever built from `TaskItem.blockedBy`/`blocks` or
/// `BoxSubtask.subtaskBlockedBy`/`subtaskBlocks` — never from the neutral
/// `linkedTasks`/`linkedSubtasks` relationships, which stay inert (no
/// cascade, no badge) in this view.
struct DependencyEdge {
    let blockerID: PersistentIdentifier
    let blockedID: PersistentIdentifier
}

/// One row in the chain-reaction grid: a real compartment box, or the
/// synthetic "No box" row holding chain items that aren't linked into any
/// box, so nothing active is ever hidden just because rows are box-based.
struct ChainRow: Identifiable {
    enum RowKind {
        case box(TaskBox)
        case unboxed
    }
    let kind: RowKind
    let items: [ChainItem]

    var id: String {
        switch kind {
        case .box(let box): String(describing: box.persistentModelID)
        case .unboxed: "unboxed"
        }
    }

    var name: String {
        switch kind {
        case .box(let box): box.name
        case .unboxed: "No box"
        }
    }

    /// Neutral grey for the synthetic row — the same literal already used
    /// elsewhere in the app for boxless items (e.g. a subtask with no
    /// parent group), not a new palette entry.
    var displayColorHex: String {
        switch kind {
        case .box(let box): box.displayColorHex
        case .unboxed: "888888"
        }
    }
}

struct ChainLayout {
    var rows: [ChainRow]
    var edges: [DependencyEdge]

    var itemsByID: [PersistentIdentifier: ChainItem] {
        Dictionary(uniqueKeysWithValues: rows.flatMap(\.items).map { ($0.id, $0) })
    }
}

enum ChainReactionLayoutEngine {

    /// Builds the row/edge layout from scratch. Task↔task and
    /// subtask↔subtask (peer) dependencies are collected as two
    /// independent edge sets — the data model never lets a task block a
    /// subtask or vice versa, so they're never merged into one generic
    /// graph.
    static func buildLayout(tasks: [TaskItem], boxes: [TaskBox]) -> ChainLayout {
        var edges: [DependencyEdge] = []
        var seenEdgeKeys = Set<String>()
        var participatingTaskIDs = Set<PersistentIdentifier>()
        var participatingSubtaskIDs = Set<PersistentIdentifier>()

        func addEdge(blocker: PersistentIdentifier, blocked: PersistentIdentifier) {
            let key = "\(blocker)|\(blocked)"
            guard seenEdgeKeys.insert(key).inserted else { return }
            edges.append(DependencyEdge(blockerID: blocker, blockedID: blocked))
        }

        for task in tasks {
            for blocker in task.allBlockers {
                addEdge(blocker: blocker.persistentModelID, blocked: task.persistentModelID)
                participatingTaskIDs.insert(blocker.persistentModelID)
                participatingTaskIDs.insert(task.persistentModelID)
            }
        }

        let everySubtask = boxes.flatMap(\.allSubtasks)
        for subtask in everySubtask {
            for blocker in subtask.allSubtaskBlockers {
                addEdge(blocker: blocker.persistentModelID, blocked: subtask.persistentModelID)
                participatingSubtaskIDs.insert(blocker.persistentModelID)
                participatingSubtaskIDs.insert(subtask.persistentModelID)
            }
        }

        guard !participatingTaskIDs.isEmpty || !participatingSubtaskIDs.isEmpty else {
            return ChainLayout(rows: [], edges: [])
        }

        var tasksByID: [PersistentIdentifier: TaskItem] = [:]
        for task in tasks where participatingTaskIDs.contains(task.persistentModelID) {
            tasksByID[task.persistentModelID] = task
        }
        var subtasksByID: [PersistentIdentifier: BoxSubtask] = [:]
        for subtask in everySubtask where participatingSubtaskIDs.contains(subtask.persistentModelID) {
            subtasksByID[subtask.persistentModelID] = subtask
        }

        // A subtask's row is always its real parent box (a subtask is
        // never boxless in practice). A participating task's row is the
        // first box — by name, for determinism — that has it linked in;
        // any task left over after every box has claimed its own falls
        // into the synthetic "No box" row. Completed items still count as
        // "participating" (their edges stay in the graph — a just-freed
        // downstream item still needs to see them as satisfied) but never
        // get a tile of their own: once done, a task or subtask drops out
        // of the active-chain view entirely, same as the old graph view's
        // "only linked items show up" rule extended to "only *open*
        // linked items show a tile."
        var unclaimedTaskIDs = participatingTaskIDs
        var rows: [ChainRow] = []
        for box in boxes.sorted(by: { $0.name < $1.name }) {
            var items: [ChainItem] = []
            for subtask in box.allSubtasks
            where subtasksByID[subtask.persistentModelID] != nil && !subtask.isCompleted {
                items.append(ChainItem(kind: .subtask(subtask)))
            }
            for task in box.allLinkedTasks where unclaimedTaskIDs.contains(task.persistentModelID) {
                unclaimedTaskIDs.remove(task.persistentModelID)
                guard !task.isCompleted else { continue }
                items.append(ChainItem(kind: .task(task)))
            }
            guard !items.isEmpty else { continue }
            rows.append(ChainRow(kind: .box(box), items: items))
        }

        if !unclaimedTaskIDs.isEmpty {
            let leftover = unclaimedTaskIDs.compactMap { tasksByID[$0] }
                .filter { !$0.isCompleted }
                .sorted { $0.title < $1.title }
                .map { ChainItem(kind: .task($0)) }
            if !leftover.isEmpty {
                rows.append(ChainRow(kind: .unboxed, items: leftover))
            }
        }

        return ChainLayout(rows: rows, edges: edges)
    }

    /// Direct, still-outstanding blocker count (in-degree) — the badge
    /// shown on a selected tile, not the size of its full transitive
    /// chain. Blockers that are already done don't count: they have no
    /// tile of their own anymore, so the badge should match what's
    /// actually drawn as a red upstream tile.
    static func directBlockerCount(of item: ChainItem) -> Int {
        switch item.kind {
        case .task(let task): task.allBlockers.filter { !$0.isCompleted }.count
        case .subtask(let subtask): subtask.allSubtaskBlockers.filter { !$0.isCompleted }.count
        }
    }

    /// BFS in the "blocks" direction (this item → everything it
    /// transitively blocks), each entry tagged with its BFS depth for
    /// stagger timing. Never crosses into the upstream direction.
    static func downstreamChain(from id: PersistentIdentifier, edges: [DependencyEdge]) -> [(id: PersistentIdentifier, depth: Int)] {
        var forward: [PersistentIdentifier: [PersistentIdentifier]] = [:]
        for edge in edges { forward[edge.blockerID, default: []].append(edge.blockedID) }
        return bfs(from: id, adjacency: forward)
    }

    /// BFS in the "blocked by" direction (things transitively blocking
    /// this item) — lit instantly in the UI, so depth is tracked but
    /// unused for timing.
    static func upstreamChain(from id: PersistentIdentifier, edges: [DependencyEdge]) -> [(id: PersistentIdentifier, depth: Int)] {
        var backward: [PersistentIdentifier: [PersistentIdentifier]] = [:]
        for edge in edges { backward[edge.blockedID, default: []].append(edge.blockerID) }
        return bfs(from: id, adjacency: backward)
    }

    private static func bfs(from start: PersistentIdentifier, adjacency: [PersistentIdentifier: [PersistentIdentifier]]) -> [(id: PersistentIdentifier, depth: Int)] {
        var depth: [PersistentIdentifier: Int] = [start: 0]
        var queue = [start]
        var order: [(id: PersistentIdentifier, depth: Int)] = []
        var head = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            for next in adjacency[current] ?? [] where depth[next] == nil {
                let nextDepth = depth[current]! + 1
                depth[next] = nextDepth
                queue.append(next)
                order.append((id: next, depth: nextDepth))
            }
        }
        return order
    }

    /// Splits a downstream BFS result at `cap` visible + the rest
    /// overflowed, preserving BFS order (closest first) so the visible
    /// set is always the most immediately relevant.
    static func splitOverflow(_ chain: [(id: PersistentIdentifier, depth: Int)], cap: Int = 4)
        -> (visible: [(id: PersistentIdentifier, depth: Int)], overflow: [PersistentIdentifier]) {
        guard chain.count > cap else { return (chain, []) }
        return (Array(chain.prefix(cap)), chain.dropFirst(cap).map(\.id))
    }

    /// Items whose remaining-incomplete-blocker count just transitioned
    /// 1→0 as a result of `completedID` being marked done — drives the
    /// one-shot "freed" pulse. Only items directly blocked by
    /// `completedID` can possibly be affected, and since `completedID`
    /// was itself incomplete until this instant, any of those whose
    /// blockers are now *all* complete just lost their last one.
    static func newlyFreed(after completedID: PersistentIdentifier, edges: [DependencyEdge],
                           allItems: [PersistentIdentifier: ChainItem]) -> [PersistentIdentifier] {
        let directlyBlocked = edges.filter { $0.blockerID == completedID }.map(\.blockedID)
        return directlyBlocked.filter { blockedID in
            let blockers = edges.filter { $0.blockedID == blockedID }.map(\.blockerID)
            return blockers.allSatisfy { allItems[$0]?.isCompleted ?? true }
        }
    }
}
