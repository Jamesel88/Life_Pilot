import SwiftUI
import SwiftData
import Charts

/// Trends and totals across the whole app — reached from the chart button
/// on the dashboard. Task completions per day (from completedAt, so the
/// chart builds up from the day this feature shipped), per-habit 30-day
/// consistency, and how the compartment boxes are doing.
struct InsightsView: View {
    @Query private var allTasks: [TaskItem]
    @Query private var habits: [Habit]
    @Query private var boxes: [TaskBox]

    private var calendar: Calendar { .current }

    private struct DayCount: Identifiable {
        let day: Date
        let count: Int
        var id: Date { day }
    }

    /// Tasks completed on each of the last 14 days
    private var completionsByDay: [DayCount] {
        let start = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -13, to: .now) ?? .now)
        var counts: [Date: Int] = [:]
        for task in allTasks {
            guard let completedAt = task.completedAt, completedAt >= start else { continue }
            counts[calendar.startOfDay(for: completedAt), default: 0] += 1
        }
        return (0..<14).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start)
            else { return nil }
            return DayCount(day: day, count: counts[day] ?? 0)
        }
    }

    var body: some View {
        List {
            // MARK: Tasks
            Section("Tasks — last 14 days") {
                let series = completionsByDay
                if series.allSatisfy({ $0.count == 0 }) {
                    Text("Complete tasks and they'll start counting here")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Chart(series) { entry in
                        BarMark(
                            x: .value("Day", entry.day, unit: .day),
                            y: .value("Completed", entry.count)
                        )
                        .foregroundStyle(Color.accentTasks)
                        .cornerRadius(3)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.day(), centered: true)
                        }
                    }
                    .frame(height: 160)
                    .padding(.vertical, 6)
                }

                statRow("Completed all time",
                        value: "\(allTasks.filter(\.isCompleted).count)",
                        color: .accentTasks)
                statRow("Outstanding",
                        value: "\(allTasks.filter { !$0.isCompleted }.count)",
                        color: .accentAllTasks)
            }

            // MARK: Habits
            Section("Habit streak") {
                if habits.isEmpty {
                    Text("No habits yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    let index = HabitCompletionIndex(habits: habits)
                    StreakHistoryView(dayCompletion: index.dayCompletion(on:))
                    statRow("Current streak",
                            value: "\(index.currentStreak()) days",
                            color: .accentHabits)
                    statRow("Best streak",
                            value: "\(index.longestStreak()) days",
                            color: .accentHabits)
                }
            }

            Section("Habit consistency — last 30 days") {
                if habits.isEmpty {
                    Text("No habits yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    let index = HabitCompletionIndex(habits: habits)
                    ForEach(habits) { habit in
                        habitRow(habit, index: index)
                    }
                }
            }

            // MARK: Compartments
            Section("Compartments") {
                let sealed = boxes.filter { !$0.isEmpty && !$0.isOpen }.count
                let filled = boxes.reduce(0) { $0 + $1.completedCount }
                let total = boxes.reduce(0) { $0 + $1.totalCount }
                statRow("Boxes sealed", value: "\(sealed)/\(boxes.count)",
                        color: .accentBoxes)
                statRow("Compartments filled", value: "\(filled)/\(total)",
                        color: .accentBoxes)
            }
        }
        .monogramWatermark()
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// One habit's consistency: the share of the last 30 days on which its
    /// period counted as done (works for daily, weekly, and monthly alike).
    @ViewBuilder
    private func habitRow(_ habit: Habit, index: HabitCompletionIndex) -> some View {
        let days = (0..<30).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: .now)
        }
        let activeDays = days.filter { habit.isActive(on: $0) }
        let doneDays = activeDays.filter { index.isCompleted(habit, on: $0) }.count
        let rate = activeDays.isEmpty ? 0 : Double(doneDays) / Double(activeDays.count)

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(habit.name)
                Spacer()
                Text("\(Int((rate * 100).rounded()))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: rate)
                .tint(.accentHabits)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(habit.name), \(Int((rate * 100).rounded())) percent of the last 30 days")
    }

    @ViewBuilder
    private func statRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }
}
