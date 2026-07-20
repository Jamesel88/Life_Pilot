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

/// Mini version of the app's dashboard day-tray: compartments of cells
/// with the sealing lid. One slot per domain; the lid closes once every
/// task and habit for the day is done.
private struct WidgetDayTray: View {
    struct Slot {
        let completed: Int
        let total: Int
        let color: Color
    }

    var slots: [Slot]
    var isSealed: Bool
    var cellCap: Int = 6

    private let trayColor = Color(hex: "C79E73")

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(trayColor.opacity(isSealed ? 0.85 : 0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(trayColor.opacity(0.7), lineWidth: 1)
                )
                .frame(height: 10)
                .padding(.horizontal, -3)
                .rotation3DEffect(
                    .degrees(isSealed ? 0 : -110),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .bottom,
                    perspective: 0.4
                )
                .zIndex(1)

            HStack(spacing: 0) {
                ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                    cellGrid(slot)
                        .padding(4)
                    if index < slots.count - 1 {
                        Rectangle()
                            .fill(trayColor.opacity(0.8))
                            .frame(width: 1.5)
                    }
                }
            }
            .overlay(
                UnevenRoundedRectangle(bottomLeadingRadius: 8,
                                       bottomTrailingRadius: 8,
                                       style: .continuous)
                    .strokeBorder(trayColor.opacity(0.8), lineWidth: 1.5)
            )
            .overlay {
                if isSealed {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .shadow(color: trayColor.opacity(0.6), radius: 2)
                }
            }
        }
    }

    @ViewBuilder
    private func cellGrid(_ slot: Slot) -> some View {
        if slot.total == 0 {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(slot.color.opacity(0.3),
                              style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let count = min(slot.total, cellCap)
            let filled = slot.total <= cellCap
                ? slot.completed
                : Int((Double(slot.completed) / Double(slot.total) * Double(cellCap)).rounded())
            let columns = Int(ceil(sqrt(Double(count))))
            let rows = Int(ceil(Double(count) / Double(columns)))

            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<columns, id: \.self) { column in
                            let index = row * columns + column
                            if index < count {
                                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                    .fill(index < filled
                                          ? slot.color : slot.color.opacity(0.15))
                            } else {
                                Color.clear
                            }
                        }
                    }
                }
            }
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
        .description("Today's tasks and habits as a compartment tray that seals when you're done.")
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
    /// Shopping appears only while something is still left to buy — a
    /// fully bought (or empty) list drops out of every layout
    private var hasShopping: Bool { shoppingTotal > 0 && shoppingChecked < shoppingTotal }

    private let shoppingColor = Color(red: 0.30, green: 0.80, blue: 0.78)

    private var tasksProgress: Double {
        todayTotal > 0 ? Double(todayCompleted) / Double(todayTotal) : 0
    }
    private var boxesInProgress: Int {
        entry.snapshot?.boxes.filter { $0.total > 0 && $0.completed < $0.total }.count ?? 0
    }

    /// Same rule as the app's dashboard tray: every task and habit done
    private var isSealed: Bool {
        (todayTotal + habitsTotal) > 0
            && todayCompleted >= todayTotal
            && habitsDone >= habitsTotal
    }

    private var traySlots: [WidgetDayTray.Slot] {
        var slots = [
            WidgetDayTray.Slot(completed: todayCompleted, total: todayTotal, color: .green),
            WidgetDayTray.Slot(completed: habitsDone, total: habitsTotal, color: .orange)
        ]
        if hasShopping {
            slots.append(WidgetDayTray.Slot(completed: shoppingChecked,
                                            total: shoppingTotal, color: shoppingColor))
        }
        return slots
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
            HStack(spacing: 16) {
                WidgetDayTray(slots: traySlots, isSealed: isSealed)
                    .frame(width: 124, height: 92)
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
                WidgetDayTray(slots: traySlots, isSealed: isSealed, cellCap: 9)
                    .frame(height: 170)
                    .padding(.horizontal, 8)
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
                WidgetDayTray(slots: traySlots, isSealed: isSealed)
                    .frame(height: 82)
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
