import SwiftUI
import SwiftData

/// The Links tab: compartment-box rows of small tiles, one per task/subtask
/// currently part of a live dependency chain. Tapping a tile traces its
/// chain — downstream (green, staggered) is everything it blocks, upstream
/// (red, instant) is everything blocking it — and offers "Open"/"Mark
/// complete" from a popover. Completing a tile collapses it and pulses any
/// downstream item that just lost its last remaining blocker. Only
/// directional (blocks/depends-on) edges drive any of this — the app's
/// older, neutral "linked" relationships never show up here at all.
struct ChainReactionLinksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TabRouter.self) private var router
    @Query private var tasks: [TaskItem]
    @Query private var boxes: [TaskBox]

    @State private var selectedID: PersistentIdentifier?
    @State private var revealedIDs: Set<PersistentIdentifier> = []
    @State private var collapsedIDs: Set<PersistentIdentifier> = []
    @State private var freedPulseIDs: Set<PersistentIdentifier> = []
    @State private var overflowSheet: OverflowSheetPayload?

    private var layout: ChainLayout { ChainReactionLayoutEngine.buildLayout(tasks: tasks, boxes: boxes) }

    var body: some View {
        let currentLayout = layout
        let chain = selectedID.map { selectionChain(currentLayout, selected: $0) }

        NavigationStack {
            Group {
                if currentLayout.rows.isEmpty {
                    ContentUnavailableView("No dependency chains yet",
                        systemImage: "arrow.triangle.branch",
                        description: Text("Mark one task or subtask as depending on another and they'll show up here as a chain you can trace and complete"))
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            ForEach(currentLayout.rows) { row in
                                rowView(row, layout: currentLayout, chain: chain)
                            }
                        }
                        .padding()
                        .overlayPreferenceValue(TilePositionKey.self) { anchors in
                            GeometryReader { proxy in
                                if let selectedID, let chain {
                                    ForEach(Array(currentLayout.edges.enumerated()), id: \.offset) { _, edge in
                                        connectorPath(edge, anchors: anchors, proxy: proxy,
                                                     selected: selectedID, chain: chain)
                                    }
                                }
                            }
                            .allowsHitTesting(false)
                        }
                    }
                    .background {
                        // Tapping empty space deselects, same as the popover's
                        // own dismiss — there's no other "background" gesture
                        // target once a selection is active.
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { selectedID = nil }
                    }
                }
            }
            .monogramWatermark(base: Color(.systemBackground))
            .compartmentsTabBar()
            .navigationTitle("Links")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $overflowSheet) { payload in
            overflowSheetView(payload)
        }
    }

    // MARK: - Row / tile layout

    private func rowView(_ row: ChainRow, layout: ChainLayout, chain: SelectionChain?) -> some View {
        let color = Color(hex: row.displayColorHex)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(row.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
            }
            FlowLayout(spacing: 10) {
                ForEach(displayTiles(for: row, chain: chain)) { tile in
                    switch tile {
                    case .item(let item):
                        itemTileView(item, color: color, layout: layout, chain: chain)
                    case .overflow(let count, let ids):
                        overflowTileView(count: count, ids: ids, color: color)
                    }
                }
            }
        }
    }

    private func displayTiles(for row: ChainRow, chain: SelectionChain?) -> [ChainDisplayTile] {
        var tiles = row.items.map(ChainDisplayTile.item)
        if let chain, row.items.contains(where: { $0.id == selectedID }), !chain.downstreamOverflow.isEmpty {
            tiles.append(.overflow(count: chain.downstreamOverflow.count, ids: chain.downstreamOverflow))
        }
        return tiles
    }

    private func itemTileView(_ item: ChainItem, color: Color, layout: ChainLayout, chain: SelectionChain?) -> some View {
        let isSelected = selectedID == item.id
        let state = highlightState(for: item.id, chain: chain, isSelected: isSelected)
        let shape: AnyShape = item.isSubtask
            ? AnyShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            : AnyShape(Circle())
        let isCollapsed = collapsedIDs.contains(item.id)

        return Button {
            guard !isCollapsed else { return }
            if isSelected {
                selectedID = nil
            } else {
                selectedID = item.id
                revealedIDs = [item.id]
                scheduleReveal(for: item.id, layout: layout)
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    shape
                        .fill(color.opacity(state == .dim ? 0.25 : 0.9))
                        .overlay(shape.stroke(borderColor(state, base: color), lineWidth: state == .none ? 0 : 2))
                        .frame(width: 34, height: 34)
                        .scaleEffect(isSelected ? 1.18 : 1)
                        .overlay {
                            if freedPulseIDs.contains(item.id) {
                                FreedPulseRing(shape: shape, color: color)
                            }
                        }

                    if isSelected {
                        badgeView(count: ChainReactionLayoutEngine.directBlockerCount(of: item), color: color)
                    }
                }
                Text(item.title)
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(width: 62)
                    .foregroundStyle(state == .dim ? .secondary : .primary)
            }
        }
        .buttonStyle(.plain)
        .frame(width: isCollapsed ? 0 : nil)
        .opacity(isCollapsed ? 0 : 1)
        .clipped()
        .anchorPreference(key: TilePositionKey.self, value: .center) { [positionKey(for: item.id): $0] }
        .popover(isPresented: Binding(
            get: { isSelected },
            set: { if !$0 { selectedID = nil } }
        )) {
            popoverContent(for: item)
                .presentationCompactAdaptation(.popover)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.68), value: isSelected)
        .animation(.easeOut(duration: 0.25), value: revealedIDs.contains(item.id))
        .animation(.easeInOut(duration: 0.32), value: isCollapsed)
    }

    private func overflowTileView(count: Int, ids: Set<PersistentIdentifier>, color: Color) -> some View {
        Button {
            overflowSheet = OverflowSheetPayload(items: ids.compactMap { layout.itemsByID[$0] }
                .sorted { $0.title < $1.title })
        } label: {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(color, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Text("+\(count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(color)
                    )
                Text("\(count) other\(count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 62)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .anchorPreference(key: TilePositionKey.self, value: .center) { ["overflow": $0] }
    }

    // MARK: - Highlight state

    private enum TileHighlight { case none, selected, downstream, upstream, dim }

    private func highlightState(for id: PersistentIdentifier, chain: SelectionChain?, isSelected: Bool) -> TileHighlight {
        guard let chain else { return .none }
        if isSelected { return .selected }
        if chain.downstreamVisible[id] != nil { return revealedIDs.contains(id) ? .downstream : .dim }
        if chain.upstream.contains(id) { return .upstream }
        return .dim
    }

    private func borderColor(_ state: TileHighlight, base: Color) -> Color {
        switch state {
        case .downstream: .green
        case .upstream: .red
        case .selected: base
        case .none, .dim: .clear
        }
    }

    // MARK: - Badge / popover / overflow sheet

    private func badgeView(count: Int, color: Color) -> some View {
        Text("\(count)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(4)
            .frame(minWidth: 18, minHeight: 18)
            .background(Circle().fill(color))
            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
            .offset(x: 10, y: -10)
    }

    @ViewBuilder
    private func popoverContent(for item: ChainItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                open(item)
            } label: {
                Label(item.isSubtask ? "Open subtask" : "Open task", systemImage: "arrow.up.right")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            Divider()
            Button {
                markComplete(item)
            } label: {
                Label("Mark complete", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .disabled(item.isCompleted)
        }
        .frame(width: 210)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func overflowSheetView(_ payload: OverflowSheetPayload) -> some View {
        NavigationStack {
            List(payload.items) { item in
                Button {
                    overflowSheet = nil
                    open(item)
                } label: {
                    HStack {
                        Text(item.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Blocked tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { overflowSheet = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Actions

    private func open(_ item: ChainItem) {
        selectedID = nil
        switch item.kind {
        case .task(let task):
            router.pendingTaskToOpen = task
            router.selection = .tasks
        case .subtask(let subtask):
            router.pendingBoxToOpen = subtask.box
            router.pendingSubtaskToOpen = subtask
            router.selection = .boxes
        }
    }

    private func markComplete(_ item: ChainItem) {
        let id = item.id
        selectedID = nil
        switch item.kind {
        case .task(let task):
            task.complete(in: modelContext)
        case .subtask(let subtask):
            subtask.isCompleted = true
        }
        withAnimation(.easeInOut(duration: 0.32)) {
            _ = collapsedIDs.insert(id)
        }

        let updatedLayout = ChainReactionLayoutEngine.buildLayout(tasks: tasks, boxes: boxes)
        let freed = ChainReactionLayoutEngine.newlyFreed(after: id, edges: updatedLayout.edges,
                                                         allItems: updatedLayout.itemsByID)
        guard !freed.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            freedPulseIDs.formUnion(freed)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                freedPulseIDs.subtract(freed)
            }
        }
    }

    /// Reveals each downstream tile in turn, depth by depth, so the
    /// cascade visibly ripples outward instead of lighting up all at
    /// once. Aborts if the selection has changed by the time a given
    /// depth's delay elapses.
    private func scheduleReveal(for selected: PersistentIdentifier, layout: ChainLayout) {
        let downstream = ChainReactionLayoutEngine.downstreamChain(from: selected, edges: layout.edges)
        let (visible, _) = ChainReactionLayoutEngine.splitOverflow(downstream)
        for entry in visible {
            let delay = Double(entry.depth) * 0.14
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard selectedID == selected else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                    _ = revealedIDs.insert(entry.id)
                }
            }
        }
    }

    // MARK: - Selection chain

    private struct SelectionChain {
        var downstreamVisible: [PersistentIdentifier: Int]
        var downstreamOverflow: Set<PersistentIdentifier>
        var upstream: Set<PersistentIdentifier>
    }

    private func selectionChain(_ layout: ChainLayout, selected: PersistentIdentifier) -> SelectionChain {
        let downstream = ChainReactionLayoutEngine.downstreamChain(from: selected, edges: layout.edges)
        let (visible, overflow) = ChainReactionLayoutEngine.splitOverflow(downstream)
        let upstream = ChainReactionLayoutEngine.upstreamChain(from: selected, edges: layout.edges)
        return SelectionChain(
            downstreamVisible: Dictionary(uniqueKeysWithValues: visible.map { ($0.id, $0.depth) }),
            downstreamOverflow: Set(overflow),
            upstream: Set(upstream.map(\.id))
        )
    }

    // MARK: - Connector lines

    private func positionKey(for id: PersistentIdentifier) -> String { String(describing: id) }

    private func edgeColor(_ edge: DependencyEdge, selected: PersistentIdentifier, chain: SelectionChain) -> Color? {
        if edge.blockerID == selected || revealedIDs.contains(edge.blockerID) {
            if chain.downstreamOverflow.contains(edge.blockedID) || revealedIDs.contains(edge.blockedID) {
                return .green
            }
        }
        if (edge.blockedID == selected || chain.upstream.contains(edge.blockedID)),
           chain.upstream.contains(edge.blockerID) {
            return .red
        }
        return nil
    }

    @ViewBuilder
    private func connectorPath(_ edge: DependencyEdge, anchors: [String: Anchor<CGPoint>], proxy: GeometryProxy,
                               selected: PersistentIdentifier, chain: SelectionChain) -> some View {
        if let color = edgeColor(edge, selected: selected, chain: chain) {
            let fromKey = chain.downstreamOverflow.contains(edge.blockerID) ? "overflow" : positionKey(for: edge.blockerID)
            let toKey = chain.downstreamOverflow.contains(edge.blockedID) ? "overflow" : positionKey(for: edge.blockedID)
            if fromKey != toKey, let fromAnchor = anchors[fromKey], let toAnchor = anchors[toKey] {
                let from = proxy[fromAnchor]
                let to = proxy[toAnchor]
                Path { path in
                    path.move(to: from)
                    let mid = CGPoint(x: (from.x + to.x) / 2, y: min(from.y, to.y) - 16)
                    path.addQuadCurve(to: to, control: mid)
                }
                .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
    }
}

// MARK: - Supporting types

private enum ChainDisplayTile: Identifiable {
    case item(ChainItem)
    case overflow(count: Int, ids: Set<PersistentIdentifier>)

    var id: String {
        switch self {
        case .item(let item): String(describing: item.id)
        case .overflow: "overflow"
        }
    }
}

private struct OverflowSheetPayload: Identifiable {
    let id = UUID()
    let items: [ChainItem]
}

private struct TilePositionKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGPoint>] = [:]
    static func reduce(value: inout [String: Anchor<CGPoint>], nextValue: () -> [String: Anchor<CGPoint>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// A one-shot expanding, fading ring — fired when a tile loses its last
/// remaining blocker. Self-contained so it animates on its own appearance
/// rather than needing to be driven from the parent's state.
private struct FreedPulseRing: View {
    let shape: AnyShape
    let color: Color
    @State private var animate = false

    var body: some View {
        shape
            .stroke(color, lineWidth: 2)
            .scaleEffect(animate ? 1.7 : 1)
            .opacity(animate ? 0 : 0.8)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) { animate = true }
            }
    }
}

/// A simple wrapping row layout — tiles flow left to right, wrapping onto
/// a new line once they no longer fit the available width.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var width: CGFloat = 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                width = max(width, rowWidth)
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }
        width = max(width, rowWidth)
        height += rowHeight
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
