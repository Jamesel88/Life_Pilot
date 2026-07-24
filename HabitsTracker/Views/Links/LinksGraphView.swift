import SwiftUI
import SwiftData

/// A pannable, pinch-zoomable map of every linked task, compartment box,
/// and individually-linked subtask — Obsidian-graph-view style, in the
/// app's own compartment/accent visual language. Only tasks and boxes
/// participate (habits were never part of the linking system); only
/// items actually linked to something show up at all.
struct LinksGraphView: View {
    @Query private var tasks: [TaskItem]
    @Query private var boxes: [TaskBox]
    @State private var taskToEdit: TaskItem?
    @State private var showingBoxDetail = false
    @State private var selectedBox: TaskBox?
    @State private var subtaskToEdit: BoxSubtask?
    /// 0 = every node collapsed at the canvas centre, 1 = final layout.
    /// Animated once on appear so the whole map springs outward from the
    /// middle of the screen instead of popping straight into place.
    @State private var growth: CGFloat = 0

    private var layout: GraphLayoutEngine.Layout {
        GraphLayoutEngine.buildLayout(tasks: tasks, boxes: boxes)
    }

    var body: some View {
        NavigationStack {
            Group {
                if layout.nodes.isEmpty {
                    ContentUnavailableView("No linked items yet",
                        systemImage: "link",
                        description: Text("Link tasks to each other, to a whole compartment box, or to one of its subtasks, and they'll show up here as a map you can explore"))
                } else {
                    let currentLayout = layout
                    PannableZoomableView(contentSize: currentLayout.canvasSize) {
                        graphContent(currentLayout)
                    }
                    .ignoresSafeArea(edges: [.bottom, .horizontal])
                    .onAppear {
                        growth = 0
                        withAnimation(.spring(response: 0.9, dampingFraction: 0.75)) {
                            growth = 1
                        }
                    }
                }
            }
            .monogramWatermark(base: Color(.systemBackground))
            .compartmentsTabBar()
            .navigationTitle("Links")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $taskToEdit) { task in
            EditTaskView(task: task)
        }
        .sheet(item: $subtaskToEdit) { subtask in
            if let box = subtask.box {
                SubtaskEditorView(box: box, subtask: subtask)
            }
        }
        .navigationDestination(isPresented: $showingBoxDetail) {
            if let selectedBox {
                TaskBoxDetailView(box: selectedBox)
            }
        }
    }

    private func graphContent(_ layout: GraphLayoutEngine.Layout) -> some View {
        let positions = Dictionary(uniqueKeysWithValues: layout.nodes.map { ($0.id, $0) })
        let centre = CGPoint(x: layout.canvasSize.width / 2, y: layout.canvasSize.height / 2)

        return ZStack(alignment: .topLeading) {
            GrowthEdgesCanvas(growth: growth, edges: layout.edges,
                             positions: positions, centre: centre)
                .frame(width: layout.canvasSize.width, height: layout.canvasSize.height)

            ForEach(layout.nodes) { placed in
                nodeView(placed)
                    .position(interpolated(placed.position, centre: centre))
            }
        }
        .frame(width: layout.canvasSize.width, height: layout.canvasSize.height)
    }

    /// Blends a node's final position toward the canvas centre as
    /// `growth` goes from 0 to 1 — the "springing outward" effect.
    private func interpolated(_ final: CGPoint, centre: CGPoint) -> CGPoint {
        CGPoint(x: centre.x + (final.x - centre.x) * growth,
               y: centre.y + (final.y - centre.y) * growth)
    }

    @ViewBuilder
    private func nodeView(_ placed: PlacedNode) -> some View {
        switch placed.node.kind {
        case .box(let box):
            Button {
                selectedBox = box
                showingBoxDetail = true
            } label: {
                VStack(spacing: 4) {
                    CompartmentBoxView(color: Color(hex: box.displayColorHex),
                                       completed: box.completedCount, total: box.totalCount)
                        .frame(width: placed.size, height: placed.size)
                        .opacity(placed.node.isCompleted ? 0.5 : 1)
                    Text(box.name)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .frame(width: 84)
                        .opacity(growth)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(box.name), compartment box")

        case .task(let task):
            Button {
                taskToEdit = task
            } label: {
                VStack(spacing: 4) {
                    Circle()
                        .fill(placed.node.color.opacity(placed.node.isCompleted ? 0.35 : 0.9))
                        .frame(width: placed.size, height: placed.size)
                    Text(task.title)
                        .font(.caption2)
                        .foregroundStyle(placed.node.isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                        .frame(width: 74)
                        .opacity(growth)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(task.title), task\(task.isCompleted ? ", completed" : "")")

        case .subtask(let subtask):
            // A rounded square (not a circle) so it reads as distinct from
            // a plain task node at a glance, tinted with its parent box's
            // colour to visually tie it back to that box.
            Button {
                subtaskToEdit = subtask
            } label: {
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: placed.size * 0.28, style: .continuous)
                        .fill(placed.node.color.opacity(subtask.isCompleted ? 0.35 : 0.9))
                        .frame(width: placed.size, height: placed.size)
                    Text(subtask.title)
                        .font(.caption2)
                        .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                        .frame(width: 74)
                        .opacity(growth)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(subtask.title), subtask\(subtask.isCompleted ? ", completed" : "")")
        }
    }
}

/// The connecting lines, animated in step with the nodes — Canvas
/// doesn't interpolate its own drawing across an ordinary state change,
/// so this conforms to Animatable itself: SwiftUI re-invokes `body` with
/// intermediate `growth` values throughout the spring, and each edge is
/// stroked between its endpoints' own centre-to-final blend at that
/// instant. Fades in alongside the growth so nothing appears as a messy
/// knot of overlapping lines at the very start.
private struct GrowthEdgesCanvas: View, Animatable {
    var growth: CGFloat
    let edges: [GraphEdge]
    let positions: [PersistentIdentifier: PlacedNode]
    let centre: CGPoint

    var animatableData: CGFloat {
        get { growth }
        set { growth = newValue }
    }

    var body: some View {
        Canvas { context, _ in
            for edge in edges {
                guard let from = positions[edge.fromID], let to = positions[edge.toID]
                else { continue }
                var path = Path()
                path.move(to: interpolated(from.position))
                path.addLine(to: interpolated(to.position))
                context.stroke(path, with: .color(from.node.color.opacity(0.35 * growth)),
                               lineWidth: 1.2)
            }
        }
    }

    private func interpolated(_ final: CGPoint) -> CGPoint {
        CGPoint(x: centre.x + (final.x - centre.x) * growth,
               y: centre.y + (final.y - centre.y) * growth)
    }
}
