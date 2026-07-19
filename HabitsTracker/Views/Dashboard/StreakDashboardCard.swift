import SwiftUI

private enum StreakScope: Int, CaseIterable {
    case week, month, year

    var label: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }
}

/// The dashboard's streak hero card: a big current-streak count with an
/// encouraging line, a swipeable Week / Month / Year dash view of habit
/// completion, and today's task/best-streak stats underneath. Tapping
/// anywhere on the card jumps to the Habits tab.
struct StreakDashboardCard: View {
    var habits: [Habit]
    var dayCompletion: (Date) -> DayCompletion
    var todayTasksCompleted: Int
    var todayTasksTotal: Int
    var onSelectHabits: () -> Void

    @State private var scope: StreakScope = .week

    /// Scales with Dynamic Type so the dash pages don't clip larger text
    @ScaledMetric(relativeTo: .caption) private var dashPagesHeight: CGFloat = 120

    private var calendar: Calendar { .current }

    private let weekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    private var activeHabitsToday: [Habit] {
        habits.filter { $0.isActive(on: .now) }
    }

    private func isFullyComplete(_ day: Date) -> Bool {
        dayCompletion(day) == .full
    }

    private func hasActiveHabits(_ day: Date) -> Bool {
        habits.contains { $0.isActive(on: day) }
    }

    /// Consecutive fully-completed days ending today. If today isn't
    /// finished yet, it doesn't break the streak — there's still time.
    private var currentStreak: Int {
        var streak = 0
        var day = Date.now
        if !isFullyComplete(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        while hasActiveHabits(day) && isFullyComplete(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    private var longestStreak: Int {
        guard let earliestStart = habits.map(\.startDate).min() else { return 0 }
        var longest = 0
        var running = 0
        var day = earliestStart
        while day <= .now {
            if hasActiveHabits(day) {
                if isFullyComplete(day) {
                    running += 1
                    longest = max(longest, running)
                } else {
                    running = 0
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return max(longest, currentStreak)
    }

    private var encouragement: String {
        if currentStreak == 0 {
            return "Start today"
        }
        if !activeHabitsToday.isEmpty && isFullyComplete(.now) {
            return "All habits done today — keep it going"
        }
        return "Finish today's habits to extend your streak"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Habits Streak")
                    .font(.headline)
                Spacer()
                Image(systemName: "flame.fill")
                    .foregroundStyle(Color.accentHabits)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(currentStreak)")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.accentHabits)
                    Text("day streak")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(encouragement)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                TabView(selection: $scope) {
                    weekDashes.tag(StreakScope.week)
                    monthDashes.tag(StreakScope.month)
                    yearDashes.tag(StreakScope.year)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: dashPagesHeight)

                HStack(spacing: 5) {
                    ForEach(StreakScope.allCases, id: \.self) { option in
                        Circle()
                            .fill(option == scope ? Color.accentHabits : Color.primary.opacity(0.15))
                            .frame(width: 5, height: 5)
                    }
                }
            }

            HStack(spacing: 10) {
                statTile(value: "\(todayTasksCompleted)/\(todayTasksTotal)", label: "tasks today", color: .accentTasks)
                statTile(value: "\(longestStreak)", label: "best streak", color: .accentAllTasks)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelectHabits)
    }

    @ViewBuilder
    private func statTile(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Dash pages

    /// This calendar week, Monday through Sunday, so the "M T W T F S S"
    /// header always lines up regardless of the device's locale.
    private var currentWeekDays: [Date] {
        let weekday = calendar.component(.weekday, from: .now)
        let daysSinceMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysSinceMonday,
                                          to: calendar.startOfDay(for: .now))
        else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    private var weekDashes: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 6) {
                ForEach(currentWeekDays, id: \.self) { day in
                    dash(for: day, cornerRadius: 4)
                        .frame(height: 22)
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dashSummary(days: currentWeekDays, period: "this week"))
    }

    private var monthDays: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: .now),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: .now))
        else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: first) }
    }

    private var monthDashes: some View {
        VStack(spacing: 6) {
            Text(Date.now, format: .dateTime.month(.wide).year())
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(monthDays, id: \.self) { day in
                    dash(for: day, cornerRadius: 3)
                        .frame(height: 14)
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dashSummary(days: monthDays, period: "this month"))
    }

    /// Weeks of the current year as 7-day columns (Sun...Sat), padded with
    /// nils so the grid lines up the same way a GitHub-style graph does.
    private var yearWeeks: [[Date?]] {
        guard let yearStart = calendar.date(from: calendar.dateComponents([.year], from: .now)) else { return [] }
        let dayCount = calendar.range(of: .day, in: .year, for: yearStart)?.count ?? 365
        let allDays = (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: yearStart) }

        let firstWeekday = calendar.component(.weekday, from: yearStart)
        let leadingPad = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leadingPad) + allDays.map { $0 }
        while cells.count % 7 != 0 { cells.append(nil) }

        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    private var yearDashes: some View {
        VStack(spacing: 6) {
            Text(Date.now, format: .dateTime.year())
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 1.5) {
                ForEach(yearWeeks.indices, id: \.self) { weekIndex in
                    VStack(spacing: 1.5) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            if let day = yearWeeks[weekIndex][dayIndex] {
                                dash(for: day, cornerRadius: 1)
                                    .frame(width: 4, height: 4)
                            } else {
                                Color.clear.frame(width: 4, height: 4)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dashSummary(days: yearWeeks.flatMap { $0 }.compactMap { $0 },
                                        period: "this year"))
    }

    /// One VoiceOver sentence summarising a whole dash grid, instead of
    /// dozens of unlabeled coloured rectangles.
    private func dashSummary(days: [Date], period: String) -> String {
        let past = days.filter { $0 <= .now || calendar.isDateInToday($0) }
        let full = past.filter { dayCompletion($0) == .full }.count
        return "\(full) of \(past.count) days fully complete \(period)"
    }

    /// A single dash cell: an empty track, half-filled for a partially
    /// completed day, or fully filled — the same rule on every page.
    private func dash(for day: Date, cornerRadius: CGFloat) -> some View {
        let isFuture = day > .now && !calendar.isDateInToday(day)
        let completion: DayCompletion = isFuture ? .none : dayCompletion(day)

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.primary.opacity(isFuture ? 0.04 : 0.12))

                switch completion {
                case .full:
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.accentHabits)
                case .partial:
                    UnevenRoundedRectangle(
                        topLeadingRadius: cornerRadius,
                        bottomLeadingRadius: cornerRadius,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                    .fill(Color.accentHabits)
                    .frame(width: geo.size.width * 0.5)
                case .none:
                    EmptyView()
                }
            }
        }
    }
}
