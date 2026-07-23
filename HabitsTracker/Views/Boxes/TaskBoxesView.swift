import SwiftUI
import SwiftData

/// The Boxes tab — one tile per TaskBox. Each tile's lid is open while the
/// box has outstanding items and its contents rise as items are completed.
struct TaskBoxesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskBox.createdAt) private var boxes: [TaskBox]
    @State private var showingAddBox = false
    @State private var boxPendingDeletion: TaskBox?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(boxes) { box in
                        NavigationLink {
                            TaskBoxDetailView(box: box)
                        } label: {
                            BoxTileView(box: box)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                boxPendingDeletion = box
                            } label: {
                                Label("Delete Box", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding()
            }
            .monogramWatermark(base: Color(.systemBackground))
            .compartmentsTabBar()
            .navigationTitle("Compartments")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddBox = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddBox) {
                AddTaskBoxView()
            }
            .overlay {
                if boxes.isEmpty {
                    ContentUnavailableView("No compartment boxes yet",
                        systemImage: "square.split.2x2",
                        description: Text("Tap + to create one for a bigger task — every subtask becomes a compartment"))
                }
            }
            .alert("Delete this box?",
                   isPresented: Binding(get: { boxPendingDeletion != nil },
                                        set: { if !$0 { boxPendingDeletion = nil } })) {
                Button("Cancel", role: .cancel) { boxPendingDeletion = nil }
                Button("Delete", role: .destructive) {
                    if let box = boxPendingDeletion {
                        modelContext.delete(box)
                    }
                    boxPendingDeletion = nil
                }
            } message: {
                if let box = boxPendingDeletion {
                    Text("Subtasks inside \"\(box.name)\" will be deleted too. Linked tasks stay on the Tasks tab. This can't be undone.")
                }
            }
        }
        .tint(.accentBoxes)
    }
}

private struct BoxTileView: View {
    let box: TaskBox

    private var boxColor: Color { Color(hex: box.displayColorHex) }

    var body: some View {
        VStack(spacing: 10) {
            CompartmentBoxView(color: boxColor,
                               completed: box.completedCount,
                               total: box.totalCount)
                .frame(width: 72, height: 72)
                .padding(.top, 10)

            Text(box.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Text(box.isEmpty
                 ? "Empty"
                 : "\(box.completedCount)/\(box.totalCount) done")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            // Slim progress bar — the tile reads at a glance without
            // studying the box graphic
            Capsule()
                .fill(boxColor.opacity(0.18))
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(boxColor)
                            .frame(width: geo.size.width * box.progress)
                    }
                }
                .padding(.horizontal, 22)

            // Name the group, not just its colour — two similar hues are
            // otherwise ambiguous at tile size
            if let group = box.group {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: group.colorHex))
                        .frame(width: 6, height: 6)
                    Text(group.name)
                        .lineLimit(1)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            // Tinted with the box's own colour so the grid reads as a
            // shelf of distinct boxes, not grey cards
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(boxColor.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(boxColor.opacity(0.25), lineWidth: 1)
                )
        )
        .animation(.spring(response: 0.5, dampingFraction: 0.65), value: box.progress)
    }
}
