//
//  CompartmentsWidgets.swift
//  CompartmentsWidgets
//
//  Home/lock screen widgets. Data arrives via the JSON snapshot the app
//  writes into the shared App Group container whenever it backgrounds —
//  widgets can't open the app's SwiftData store directly.
//

import WidgetKit
import SwiftUI

// MARK: - Shared snapshot (keep in sync with WidgetBridge in the app)

struct WidgetSnapshot: Codable {
    var updatedAt: Date
    var todayCompleted: Int
    var todayTotal: Int
    var habitsDone: Int
    var habitsTotal: Int
    // Optional so snapshots written before the shopping feature still decode
    var shoppingChecked: Int?
    var shoppingTotal: Int?
    var boxes: [BoxSnapshot]

    struct BoxSnapshot: Codable {
        var name: String
        var completed: Int
        var total: Int
        var colorHex: String
    }
}

private let appGroupID = "group.HabitsTrackerV1.HabitsTracker"
private let snapshotFilename = "widget-snapshot.json"

private func loadSnapshot() -> WidgetSnapshot? {
    guard let directory = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    else { return nil }
    guard let data = try? Data(contentsOf: directory.appendingPathComponent(snapshotFilename))
    else { return nil }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try? decoder.decode(WidgetSnapshot.self, from: data)
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

// MARK: - Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now,
                                 snapshot: loadSnapshot() ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: loadSnapshot())
        // The app pushes a fresh snapshot whenever it backgrounds; this is
        // just a fallback cadence
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

extension WidgetSnapshot {
    static let sample = WidgetSnapshot(
        updatedAt: .now, todayCompleted: 3, todayTotal: 5,
        habitsDone: 2, habitsTotal: 4,
        shoppingChecked: 5, shoppingTotal: 10,
        boxes: [
            BoxSnapshot(name: "Move house", completed: 4, total: 6, colorHex: "B08968"),
            BoxSnapshot(name: "Tax return", completed: 1, total: 4, colorHex: "409CFF"),
            BoxSnapshot(name: "Garden", completed: 2, total: 3, colorHex: "34C759")
        ])
}

// MARK: - Shared pieces

private struct RingShape: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// Mini version of the app's compartment tray (capped at 12 cells)
private struct MiniCompartmentGrid: View {
    var completed: Int
    var total: Int
    var color: Color

    var body: some View {
        let cellCount = min(max(total, 1), 12)
        let filled = total <= 12
            ? completed
            : Int((Double(completed) / Double(max(total, 1)) * 12).rounded())
        let columns = Int(ceil(sqrt(Double(cellCount))))
        let rows = Int(ceil(Double(cellCount) / Double(columns)))

        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            ForEach(0..<rows, id: \.self) { row in
                GridRow {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        if index < cellCount {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(index < filled ? color : color.opacity(0.15))
                        } else {
                            Color.clear
                        }
                    }
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(color.opacity(0.6), lineWidth: 1.5)
        )
    }
}

// MARK: - Today Rings widget

struct TodayRingsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayRingsWidget", provider: SnapshotProvider()) { entry in
            TodayRingsView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Progress")
        .description("Your task and habit rings for today.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct TodayRingsView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var todayCompleted: Int { entry.snapshot?.todayCompleted ?? 0 }
    private var todayTotal: Int { entry.snapshot?.todayTotal ?? 0 }
    private var habitsDone: Int { entry.snapshot?.habitsDone ?? 0 }
    private var habitsTotal: Int { entry.snapshot?.habitsTotal ?? 0 }
    private var shoppingChecked: Int { entry.snapshot?.shoppingChecked ?? 0 }
    private var shoppingTotal: Int { entry.snapshot?.shoppingTotal ?? 0 }
    /// The shopping ring only appears while the list has items on it
    private var hasShopping: Bool { shoppingTotal > 0 }

    private let shoppingColor = Color(red: 0.30, green: 0.80, blue: 0.78)

    private var tasksProgress: Double {
        todayTotal > 0 ? Double(todayCompleted) / Double(todayTotal) : 0
    }
    private var habitsProgress: Double {
        habitsTotal > 0 ? Double(habitsDone) / Double(habitsTotal) : 0
    }
    private var shoppingProgress: Double {
        shoppingTotal > 0 ? Double(shoppingChecked) / Double(shoppingTotal) : 0
    }
    private var boxesInProgress: Int {
        entry.snapshot?.boxes.filter { $0.total > 0 && $0.completed < $0.total }.count ?? 0
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            if hasShopping {
                Text("Tasks \(todayCompleted)/\(todayTotal) · Shop \(shoppingChecked)/\(shoppingTotal)")
            } else {
                Text("Tasks \(todayCompleted)/\(todayTotal) · Habits \(habitsDone)/\(habitsTotal)")
            }

        case .accessoryCircular:
            Gauge(value: tasksProgress) {
                Image(systemName: "checklist")
            } currentValueLabel: {
                Text("\(todayCompleted)/\(todayTotal)")
            }
            .gaugeStyle(.accessoryCircularCapacity)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: "checklist")
                    Text("\(todayCompleted)/\(todayTotal) tasks today")
                }
                HStack(spacing: 5) {
                    Image(systemName: "repeat")
                    Text("\(habitsDone)/\(habitsTotal) habits")
                }
                if hasShopping {
                    HStack(spacing: 5) {
                        Image(systemName: "basket")
                        Text("\(shoppingChecked)/\(shoppingTotal) shopping")
                    }
                }
            }
            .font(.caption2)

        case .systemMedium:
            HStack(spacing: 18) {
                rings(outer: 92, lineWidth: hasShopping ? 9 : 11)
                VStack(alignment: .leading, spacing: 7) {
                    statLine(color: .green, label: "Tasks today",
                             value: "\(todayCompleted)/\(todayTotal)")
                    statLine(color: .orange, label: "Habits",
                             value: "\(habitsDone)/\(habitsTotal)")
                    if hasShopping {
                        statLine(color: shoppingColor, label: "Shopping",
                                 value: "\(shoppingChecked)/\(shoppingTotal)")
                    }
                    statLine(color: Color(hex: "B08968"), label: "Boxes open",
                             value: "\(boxesInProgress)")
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)

        case .systemLarge:
            VStack(spacing: 18) {
                rings(outer: 150, lineWidth: hasShopping ? 13 : 15)
                HStack(spacing: 12) {
                    largeStat(color: .green, label: "tasks today",
                              value: "\(todayCompleted)/\(todayTotal)")
                    largeStat(color: .orange, label: "habits",
                              value: "\(habitsDone)/\(habitsTotal)")
                    if hasShopping {
                        largeStat(color: shoppingColor, label: "shopping",
                                  value: "\(shoppingChecked)/\(shoppingTotal)")
                    }
                    largeStat(color: Color(hex: "B08968"), label: "boxes open",
                              value: "\(boxesInProgress)")
                }
            }

        default: // systemSmall
            VStack(spacing: 8) {
                rings(outer: 74, lineWidth: hasShopping ? 7 : 9)
                HStack(spacing: 8) {
                    Text("\(todayCompleted)/\(todayTotal)")
                        .foregroundStyle(.green)
                    Text("\(habitsDone)/\(habitsTotal)")
                        .foregroundStyle(.orange)
                    if hasShopping {
                        Text("\(shoppingChecked)/\(shoppingTotal)")
                            .foregroundStyle(shoppingColor)
                    }
                }
                .font(.caption.bold().monospacedDigit())
            }
        }
    }

    /// Tasks outside, habits inside — and a third teal shopping ring in
    /// the middle while the list has items. Ring gaps scale off the line
    /// width so two- and three-ring layouts both breathe.
    private func rings(outer: CGFloat, lineWidth: CGFloat) -> some View {
        let step = (lineWidth + 3) * 2
        return ZStack {
            RingShape(progress: tasksProgress, color: .green, lineWidth: lineWidth)
                .frame(width: outer, height: outer)
            RingShape(progress: habitsProgress, color: .orange, lineWidth: lineWidth)
                .frame(width: outer - step, height: outer - step)
            if hasShopping {
                RingShape(progress: shoppingProgress, color: shoppingColor,
                          lineWidth: lineWidth)
                    .frame(width: outer - step * 2, height: outer - step * 2)
            }
        }
    }

    private func statLine(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(label)
                .font(.subheadline)
            Spacer(minLength: 4)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(color)
        }
    }

    private func largeStat(color: Color, label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Compartment Box widget

struct CompartmentBoxWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CompartmentBoxWidget", provider: SnapshotProvider()) { entry in
            CompartmentBoxWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Compartment Boxes")
        .description("Watch your boxes fill up as you complete their compartments.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CompartmentBoxWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    /// Boxes still being worked on first, then the rest — the small
    /// widget shows the first, medium shows 3, large shows 4.
    private var orderedBoxes: [WidgetSnapshot.BoxSnapshot] {
        let boxes = entry.snapshot?.boxes ?? []
        let open = boxes.filter { $0.total > 0 && $0.completed < $0.total }
        let rest = boxes.filter { !($0.total > 0 && $0.completed < $0.total) }
        return open + rest
    }

    var body: some View {
        let boxes = orderedBoxes
        if boxes.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "square.split.2x2")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("No boxes yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            switch family {
            case .systemMedium:
                HStack(spacing: 14) {
                    ForEach(Array(boxes.prefix(3).enumerated()), id: \.offset) { _, box in
                        boxColumn(box)
                    }
                }
                .frame(maxWidth: .infinity)

            case .systemLarge:
                VStack(spacing: 14) {
                    ForEach(Array(boxes.prefix(4).enumerated()), id: \.offset) { _, box in
                        boxRow(box)
                    }
                    Spacer(minLength: 0)
                }

            default: // systemSmall
                boxColumn(boxes[0])
            }
        }
    }

    private func boxColumn(_ box: WidgetSnapshot.BoxSnapshot) -> some View {
        let color = Color(hex: box.colorHex)
        return VStack(spacing: 6) {
            MiniCompartmentGrid(completed: box.completed, total: box.total, color: color)
                .frame(width: 74, height: 60)
            Text(box.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text("\(box.completed)/\(box.total) done")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func boxRow(_ box: WidgetSnapshot.BoxSnapshot) -> some View {
        let color = Color(hex: box.colorHex)
        let progress = box.total > 0 ? Double(box.completed) / Double(box.total) : 0
        return HStack(spacing: 12) {
            MiniCompartmentGrid(completed: box.completed, total: box.total, color: color)
                .frame(width: 64, height: 52)
            VStack(alignment: .leading, spacing: 5) {
                Text(box.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(box.total == 0 ? "Empty"
                     : box.completed >= box.total ? "Sealed ✓"
                     : "\(box.completed)/\(box.total) done")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Capsule()
                    .fill(color.opacity(0.18))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(color)
                                .frame(width: geo.size.width * progress)
                        }
                    }
            }
        }
    }
}
