import SwiftUI
import SwiftData

/// One node in the linked-items graph: a task, a compartment box, or one
/// specific subtask inside a box. Only tasks and boxes participate —
/// habits were never part of the linking system, so they never appear
/// here. Only items actually linked to something show up at all; this
/// view visualizes connections, not every task/box in the app.
struct GraphNode {
    enum Kind {
        case task(TaskItem)
        case box(TaskBox)
        case subtask(BoxSubtask)
    }

    let kind: Kind

    var id: PersistentIdentifier {
        switch kind {
        case .task(let task): task.persistentModelID
        case .box(let box): box.persistentModelID
        case .subtask(let subtask): subtask.persistentModelID
        }
    }

    var title: String {
        switch kind {
        case .task(let task): task.title
        case .box(let box): box.name
        case .subtask(let subtask): subtask.title
        }
    }

    var isCompleted: Bool {
        switch kind {
        case .task(let task): task.isCompleted
        case .box(let box): !box.isEmpty && !box.isOpen
        case .subtask(let subtask): subtask.isCompleted
        }
    }

    /// The colour used for this node and the edges touching it
    var color: Color {
        switch kind {
        case .task(let task):
            if let group = task.group { return Color(hex: group.colorHex) }
            return .accentTasks
        case .box(let box):
            return Color(hex: box.displayColorHex)
        case .subtask(let subtask):
            // Ties the subtask visually to its parent box's colour
            return Color(hex: subtask.box?.displayColorHex ?? "888888")
        }
    }

    var isBox: Bool {
        if case .box = kind { return true }
        return false
    }

    var isSubtask: Bool {
        if case .subtask = kind { return true }
        return false
    }
}

struct GraphEdge: Identifiable {
    let id = UUID()
    let fromID: PersistentIdentifier
    let toID: PersistentIdentifier
}

/// A node with its computed canvas position and size (bigger = more
/// connections, echoing Obsidian's graph view).
struct PlacedNode: Identifiable {
    let node: GraphNode
    var position: CGPoint
    var size: CGFloat
    var id: PersistentIdentifier { node.id }
}

/// A small deterministic random source, seeded per-cluster so the layout
/// doesn't visibly jitter every time the view re-renders for an unrelated
/// data change elsewhere in the app.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed)) &+ 0x9E3779B97F4A7C15
        if state == 0 { state = 0x9E3779B97F4A7C15 }
    }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

enum GraphLayoutEngine {
    struct Layout {
        var nodes: [PlacedNode]
        var edges: [GraphEdge]
        var canvasSize: CGSize
    }

    /// Builds the whole graph from scratch: tasks linked to each other,
    /// tasks linked into a whole compartment box, and tasks linked to one
    /// specific subtask inside a box. Grouped into connected clusters,
    /// each laid out as a hub (a box if one exists in the cluster,
    /// otherwise the most-connected item) with its linked items scattered
    /// in a loose ring around it. Clusters are then placed on a golden-
    /// angle spiral ordered by how connected each hub is: a freshly
    /// linked box with few connections stays near the canvas centre, and
    /// the more directly linked it becomes, the further out it spirals —
    /// so the map visibly grows outward as a project accumulates links.
    static func buildLayout(tasks: [TaskItem], boxes: [TaskBox]) -> Layout {
        var nodesByID: [PersistentIdentifier: GraphNode] = [:]
        var adjacency: [PersistentIdentifier: Set<PersistentIdentifier>] = [:]

        func addNode(_ node: GraphNode) {
            if nodesByID[node.id] == nil { nodesByID[node.id] = node }
        }
        func addEdge(_ a: PersistentIdentifier, _ b: PersistentIdentifier) {
            guard a != b else { return }
            adjacency[a, default: []].insert(b)
            adjacency[b, default: []].insert(a)
        }

        for task in tasks {
            for linked in task.allLinkedTasks {
                addNode(GraphNode(kind: .task(task)))
                addNode(GraphNode(kind: .task(linked)))
                addEdge(task.persistentModelID, linked.persistentModelID)
            }
        }
        for box in boxes {
            for subtask in box.allSubtasks {
                for linked in subtask.allLinkedTasks {
                    addNode(GraphNode(kind: .subtask(subtask)))
                    addNode(GraphNode(kind: .task(linked)))
                    addEdge(subtask.persistentModelID, linked.persistentModelID)
                }
            }
        }
        for box in boxes {
            for linked in box.allLinkedTasks {
                addNode(GraphNode(kind: .box(box)))
                addNode(GraphNode(kind: .task(linked)))
                addEdge(box.persistentModelID, linked.persistentModelID)
            }
        }
        for box in boxes {
            for linkedSubtask in box.allLinkedSubtasks {
                addNode(GraphNode(kind: .box(box)))
                addNode(GraphNode(kind: .subtask(linkedSubtask)))
                addEdge(box.persistentModelID, linkedSubtask.persistentModelID)
            }
        }
        // Peer subtask-to-subtask links — collect every subtask once
        // across all boxes so links between subtasks in different boxes
        // are found too
        let everySubtask = boxes.flatMap(\.allSubtasks)
        for subtask in everySubtask {
            for peer in subtask.allLinkedSubtasks {
                addNode(GraphNode(kind: .subtask(subtask)))
                addNode(GraphNode(kind: .subtask(peer)))
                addEdge(subtask.persistentModelID, peer.persistentModelID)
            }
        }

        guard !nodesByID.isEmpty else {
            return Layout(nodes: [], edges: [], canvasSize: CGSize(width: 400, height: 400))
        }

        // Deduplicated edge list from the adjacency sets
        var edges: [GraphEdge] = []
        var seenPairs = Set<String>()
        for (a, neighbors) in adjacency {
            for b in neighbors {
                let key = [a, b].map(String.init(describing:)).sorted().joined(separator: "|")
                guard !seenPairs.contains(key) else { continue }
                seenPairs.insert(key)
                edges.append(GraphEdge(fromID: a, toID: b))
            }
        }

        // Connected components via BFS
        var visited = Set<PersistentIdentifier>()
        var components: [[PersistentIdentifier]] = []
        for id in nodesByID.keys {
            guard !visited.contains(id) else { continue }
            var queue = [id]
            var component: [PersistentIdentifier] = []
            visited.insert(id)
            while !queue.isEmpty {
                let current = queue.removeFirst()
                component.append(current)
                for neighbor in adjacency[current] ?? [] where !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    queue.append(neighbor)
                }
            }
            components.append(component)
        }

        // Each cluster's hub (a box if one exists in it, otherwise the
        // most-connected item) and how many direct connections that hub
        // has — this drives how far from the canvas centre it lands.
        struct ClusterInfo {
            let component: [PersistentIdentifier]
            let hubID: PersistentIdentifier
            let hubConnections: Int
            let footprint: CGFloat   // this cluster's own satellite-ring radius
        }

        let clusters: [ClusterInfo] = components.map { component in
            let hubID = component
                .first(where: { nodesByID[$0]?.isBox == true })
                ?? component.max(by: { (adjacency[$0]?.count ?? 0) < (adjacency[$1]?.count ?? 0) })
                ?? component[0]
            let footprint: CGFloat = 66 + CGFloat(component.count - 1) * 5
            return ClusterInfo(component: component, hubID: hubID,
                              hubConnections: adjacency[hubID]?.count ?? 0,
                              footprint: footprint)
        }

        // Ascending by hub prominence — freshly linked, sparsely
        // connected hubs stay near the middle; the more directly linked
        // a hub becomes, the further it spirals outward. Deterministic
        // tie-break (dictionary/BFS order isn't stable) so placement
        // doesn't shuffle between renders for equally-prominent hubs.
        let orderedClusters = clusters.sorted { a, b in
            if a.hubConnections != b.hubConnections { return a.hubConnections < b.hubConnections }
            let titleA = nodesByID[a.hubID]?.title ?? ""
            let titleB = nodesByID[b.hubID]?.title ?? ""
            return titleA == titleB
                ? String(describing: a.hubID) < String(describing: b.hubID)
                : titleA < titleB
        }

        // Golden angle keeps successive clusters from ever lining up
        // radially — the same spacing trick sunflower seed heads use, and
        // why consecutive indices are always ~137° apart regardless of
        // how many clusters there are. That angular separation is what
        // makes it safe to step the running radius out by only the
        // *average* of two neighbouring footprints (plus a small gap)
        // rather than reserving each cluster's full width twice — this
        // packs clusters much closer while a real collision would need
        // both a small angular gap AND a small radial one at once, which
        // this sequence avoids by construction.
        let goldenAngle = 137.50776405
        let gap: CGFloat = 20
        var placed: [PlacedNode] = []
        var minX: CGFloat = 0, maxX: CGFloat = 0
        var minY: CGFloat = 0, maxY: CGFloat = 0
        var runningRadius: CGFloat = 0
        var previousFootprint: CGFloat = 0

        for (index, cluster) in orderedClusters.enumerated() {
            var rng = SeededGenerator(seed: String(describing: cluster.hubID).hashValue)

            if index > 0 {
                runningRadius += previousFootprint / 2 + cluster.footprint / 2 + gap
            }
            let angle = Double(index) * goldenAngle
            let radiusJitter = CGFloat.random(in: -8...8, using: &rng)
            let placementRadius = runningRadius + radiusJitter
            let centre = CGPoint(x: placementRadius * cos(angle * .pi / 180),
                                 y: placementRadius * sin(angle * .pi / 180))
            previousFootprint = cluster.footprint

            let others = cluster.component.filter { $0 != cluster.hubID }
                .sorted { String(describing: $0) < String(describing: $1) }
            if let hubNode = nodesByID[cluster.hubID] {
                placed.append(PlacedNode(node: hubNode, position: centre,
                                         size: nodeSize(for: hubNode, connections: cluster.hubConnections)))
            }

            for (i, otherID) in others.enumerated() {
                guard let otherNode = nodesByID[otherID] else { continue }
                let angleJitter = Double.random(in: -12...12, using: &rng)
                let satelliteAngle = (360.0 / Double(max(others.count, 1))) * Double(i) + angleJitter
                let radians = satelliteAngle * .pi / 180
                let radiusJitter2 = CGFloat.random(in: -14...14, using: &rng)
                let position = CGPoint(
                    x: centre.x + (cluster.footprint + radiusJitter2) * cos(radians),
                    y: centre.y + (cluster.footprint + radiusJitter2) * sin(radians))
                let connections = adjacency[otherID]?.count ?? 0
                placed.append(PlacedNode(node: otherNode, position: position,
                                         size: nodeSize(for: otherNode, connections: connections)))
            }

            minX = min(minX, centre.x - cluster.footprint)
            maxX = max(maxX, centre.x + cluster.footprint)
            minY = min(minY, centre.y - cluster.footprint)
            maxY = max(maxY, centre.y + cluster.footprint)
        }

        // Shift everything so the least-prominent (most central) cluster
        // sits at the canvas's true centre, and every coordinate is
        // non-negative
        let margin: CGFloat = 90
        let shiftX = margin - minX
        let shiftY = margin - minY
        for index in placed.indices {
            placed[index].position.x += shiftX
            placed[index].position.y += shiftY
        }

        let canvasSize = CGSize(width: max(maxX - minX + margin * 2, 400),
                                height: max(maxY - minY + margin * 2, 400))
        return Layout(nodes: placed, edges: edges, canvasSize: canvasSize)
    }

    private static func nodeSize(for node: GraphNode, connections: Int) -> CGFloat {
        let base: CGFloat = node.isBox ? 46 : (node.isSubtask ? 26 : 22)
        let growth = CGFloat(min(connections, 8)) * (node.isBox ? 2.5 : 2.0)
        return base + growth
    }
}
