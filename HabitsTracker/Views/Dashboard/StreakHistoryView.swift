import SwiftUI

/// Week / Month / Year habit-streak history — the retrospective half of
/// the old streak card, now living on the Insights page. Every dash is a
/// day: empty track, half-filled for a partial day, fully filled when
/// every active habit was done.
struct StreakHistoryView: View {
    var dayCompletion: (Date) -> DayCompletion

    private enum Scope: String, CaseIterable {
        case week = "Week", month = "Month", year = "Year"
    }

    @State private var scope: Scope = .week

    private var calendar: Calendar { .current }
    private let weekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(spacing: 12) {
            Picker("Period", selection: $scope) {
                ForEach(Scope.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)

            switch scope {
            case .week: weekDashes
            case .month: monthDashes
            case .year: yearDashes
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Week

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dashSummary(days: currentWeekDays, period: "this week"))
    }

    // MARK: - Month

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dashSummary(days: monthDays, period: "this month"))
    }

    // MARK: - Year

    /// Weeks of the current year as 7-day columns, nil-padded so the grid
    /// lines up the same way a GitHub-style graph does.
    private var yearWeeks: [[Date?]] {
        guard let yearStart = calendar.date(from: calendar.dateComponents([.year], from: .now))
        else { return [] }
        let dayCount = calendar.range(of: .day, in: .year, for: yearStart)?.count ?? 365
        let allDays = (0..<dayCount).compactMap {
            calendar.date(byAdding: .day, value: $0, to: yearStart)
        }

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dashSummary(days: yearWeeks.flatMap { $0 }.compactMap { $0 },
                                        period: "this year"))
    }

    // MARK: - Shared

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
