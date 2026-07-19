import SwiftUI
import SwiftData

/// A month calendar of the user's own tasks — dots mark days with work
/// (coloured by group), tapping a day lists its tasks below. Vague-window
/// tasks appear on their anchor day (the period's last day).
struct CalendarTasksView: View {
    @Query(sort: \TaskItem.dueDate) private var allTasks: [TaskItem]
    @State private var displayedMonth = Date.now
    @State private var selectedDay = Date.now
    @State private var taskToEdit: TaskItem?

    private var calendar: Calendar { .current }

    var body: some View {
        List {
            // MARK: Month grid
            Section {
                VStack(spacing: 10) {
                    monthHeader
                    weekdayHeader
                    monthGrid
                }
                .padding(.vertical, 4)
            }

            // MARK: Selected day's tasks
            Section {
                let dayTasks = tasks(on: selectedDay)
                if dayTasks.isEmpty {
                    Text("Nothing due this day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(dayTasks) { task in
                        TaskRowView(task: task)
                            .contentShape(Rectangle())
                            .onTapGesture { taskToEdit = task }
                    }
                }
            } header: {
                Text(selectedDay, format: .dateTime.weekday(.wide).day().month())
            }
        }
        .monogramWatermark()
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $taskToEdit) { task in
            EditTaskView(task: task)
        }
    }

    // MARK: - Pieces

    private var monthHeader: some View {
        HStack {
            Button {
                changeMonth(-1)
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title3)
            }
            Spacer()
            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.subheadline.bold())
            Spacer()
            Button {
                changeMonth(1)
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3)
            }
        }
        .buttonStyle(.borderless)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)
        let dayTasks = tasks(on: day)

        Button {
            selectedDay = day
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isSelected ? Color.white
                                     : isToday ? Color.accentTasks : .primary)

                HStack(spacing: 2) {
                    ForEach(Array(dayTasks.prefix(3).enumerated()), id: \.offset) { _, task in
                        Circle()
                            .fill(dotColor(for: task))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentTasks : .clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.formatted(.dateTime.day().month())), \(dayTasks.count) tasks")
    }

    private func dotColor(for task: TaskItem) -> Color {
        if task.isCompleted { return .secondary.opacity(0.5) }
        if let group = task.group { return Color(hex: group.colorHex) }
        return .accentTasks
    }

    // MARK: - Data

    private func tasks(on day: Date) -> [TaskItem] {
        allTasks.filter { calendar.isDate($0.dueDate, inSameDayAs: day) }
    }

    /// The displayed month as 7-column cells, nil-padded so day 1 lands
    /// under its weekday.
    private var monthCells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let dayCount = calendar.range(of: .day, in: .month, for: displayedMonth)?.count
        else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leadingPad = (firstWeekday - calendar.firstWeekday + 7) % 7
        let days: [Date?] = (0..<dayCount).map {
            calendar.date(byAdding: .day, value: $0, to: interval.start)
        }
        return Array(repeating: nil, count: leadingPad) + days
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private func changeMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}
