import SwiftUI

/// The dashboard overview as a compartment tray — the app's own metaphor
/// instead of nested progress rings. Three compartments (today's tasks,
/// habits, all time) hold one cell per item; cells fill as things are
/// completed. The lid stays open while today still has work and snaps
/// shut with a seal once every task and habit for the day is done — the
/// whole day, boxed.
struct DayTrayView: View {
    var tasksCompleted: Int
    var tasksTotal: Int
    var habitsDone: Int
    var habitsTotal: Int
    var allTimeCompleted: Int
    var allTimeTotal: Int
    /// Tapping a compartment jumps to that section — Tasks/Habits tab,
    /// or wherever the caller wants "all time" history shown (Insights).
    var onTapTasks: () -> Void = {}
    var onTapHabits: () -> Void = {}
    var onTapAllTime: () -> Void = {}

    private var trayColor: Color { .accentBoxes }

    /// Today counts as sealed when every task and habit is done. All-time
    /// never seals the day — it's a history shelf, not today's work.
    private var isSealed: Bool {
        (tasksTotal + habitsTotal) > 0
            && tasksCompleted >= tasksTotal
            && habitsDone >= habitsTotal
    }

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 0) {
                // Lid — hinged along the tray's top edge
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(trayColor.opacity(isSealed ? 0.85 : 0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(trayColor.opacity(0.7), lineWidth: 1.5)
                    )
                    .frame(height: 24)
                    .padding(.horizontal, -6)
                    .rotation3DEffect(
                        .degrees(isSealed ? 0 : -110),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .bottom,
                        perspective: 0.4
                    )
                    .zIndex(1)

                // Tray of three compartments — each one taps through to
                // its own section
                HStack(spacing: 0) {
                    compartmentButton(label: "Tasks today", completed: tasksCompleted,
                                      total: tasksTotal, color: .accentTasks,
                                      action: onTapTasks)
                    divider
                    compartmentButton(label: "Habits", completed: habitsDone,
                                      total: habitsTotal, color: .accentHabits,
                                      action: onTapHabits)
                    divider
                    compartmentButton(label: "All time", completed: allTimeCompleted,
                                      total: allTimeTotal, color: .accentAllTasks,
                                      action: onTapAllTime)
                }
                .padding(6)
                .frame(height: 148)
                .overlay(
                    UnevenRoundedRectangle(bottomLeadingRadius: 14,
                                           bottomTrailingRadius: 14,
                                           style: .continuous)
                        .strokeBorder(trayColor.opacity(0.8), lineWidth: 2.5)
                        .allowsHitTesting(false)
                )
                .overlay {
                    if isSealed {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                            .shadow(color: trayColor.opacity(0.6), radius: 3)
                            .transition(.scale.combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                }
            }

            // Labels under their compartments — decorative captions only;
            // the compartments above are the tap targets
            HStack(spacing: 0) {
                trayLabel("Tasks today", value: "\(tasksCompleted)/\(tasksTotal)",
                          color: .accentTasks)
                trayLabel("Habits", value: "\(habitsDone)/\(habitsTotal)",
                          color: .accentHabits)
                trayLabel("All time", value: "\(allTimeCompleted)/\(allTimeTotal)",
                          color: .accentAllTasks)
            }
            .accessibilityHidden(true)

            if isSealed {
                Text("Day sealed — everything's done!")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(trayColor)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.65), value: isSealed)
        .animation(.spring(response: 0.5, dampingFraction: 0.65), value: tasksCompleted)
        .animation(.spring(response: 0.5, dampingFraction: 0.65), value: habitsDone)
        .animation(.spring(response: 0.5, dampingFraction: 0.65), value: allTimeCompleted)
    }

    private var divider: some View {
        Rectangle()
            .fill(trayColor.opacity(0.8))
            .frame(width: 2)
            .padding(.vertical, -6)
    }

    @ViewBuilder
    private func compartment(label: String, completed: Int, total: Int,
                             color: Color) -> some View {
        VStack(spacing: 6) {
            TrayCellGrid(completed: completed, total: total, color: color)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// A compartment as a tap target: its own button with an accessibility
    /// label describing that section's progress.
    private func compartmentButton(label: String, completed: Int, total: Int,
                                   color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            compartment(label: label, completed: completed, total: total, color: color)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(completed) of \(total) done")
    }

    @ViewBuilder
    private func trayLabel(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

}

/// One compartment's cells: one per item, filling in completion order.
/// Same rules as the compartment boxes — capped at 12 cells, proportional
/// beyond, and a single dashed cell when the compartment is empty.
struct TrayCellGrid: View {
    var completed: Int
    var total: Int
    var color: Color
    var maxCells: Int = 12

    var body: some View {
        if total == 0 {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(color.opacity(0.3),
                              style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let cellCount = min(total, maxCells)
            let filled = total <= maxCells
                ? completed
                : Int((Double(completed) / Double(total) * Double(maxCells)).rounded())
            let columns = Int(ceil(sqrt(Double(cellCount))))
            let rows = Int(ceil(Double(cellCount) / Double(columns)))

            Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<columns, id: \.self) { column in
                            let index = row * columns + column
                            if index < cellCount {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(index < filled
                                          ? AnyShapeStyle(color)
                                          : AnyShapeStyle(color.opacity(0.10)))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .strokeBorder(
                                                color.opacity(index < filled ? 0 : 0.35),
                                                lineWidth: 1)
                                    )
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

#Preview {
    VStack(spacing: 30) {
        DayTrayView(tasksCompleted: 3, tasksTotal: 5,
                    habitsDone: 2, habitsTotal: 4,
                    allTimeCompleted: 12, allTimeTotal: 31)
        DayTrayView(tasksCompleted: 5, tasksTotal: 5,
                    habitsDone: 4, habitsTotal: 4,
                    allTimeCompleted: 16, allTimeTotal: 31)
    }
    .padding(30)
}
