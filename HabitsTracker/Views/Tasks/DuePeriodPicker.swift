import SwiftUI

/// "Which week" / "Which month" — lets a vague-window task target a
/// specific upcoming period instead of always the current one. Offers the
/// next 12 periods; `selection` is the chosen period's start date (the
/// caller derives the stored anchor from it).
struct DuePeriodPicker: View {
    let window: DueWindow      // .week or .month
    @Binding var selection: Date

    private var calendar: Calendar { .current }

    private var component: Calendar.Component {
        window == .week ? .weekOfYear : .month
    }

    private var options: [Date] {
        guard let currentStart = calendar.dateInterval(of: component, for: .now)?.start
        else { return [selection] }
        var dates = (0..<12).compactMap {
            calendar.date(byAdding: component, value: $0, to: currentStart)
        }
        // A task anchored outside the offered range (e.g. an old one being
        // edited) keeps its period selectable
        if !dates.contains(selection) {
            dates.insert(selection, at: 0)
        }
        return dates
    }

    var body: some View {
        Picker(window == .week ? "Which week" : "Which month", selection: $selection) {
            ForEach(options, id: \.self) { periodStart in
                Text(label(for: periodStart)).tag(periodStart)
            }
        }
    }

    private func label(for periodStart: Date) -> String {
        switch window {
        case .week:
            if calendar.isDate(periodStart, equalTo: .now, toGranularity: .weekOfYear) {
                return "This week"
            }
            if let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: .now),
               calendar.isDate(periodStart, equalTo: nextWeek, toGranularity: .weekOfYear) {
                return "Next week"
            }
            return "Week of \(periodStart.formatted(.dateTime.day().month()))"
        case .month:
            if calendar.isDate(periodStart, equalTo: .now, toGranularity: .month) {
                return "This month"
            }
            if calendar.isDate(periodStart, equalTo: .now, toGranularity: .year) {
                return periodStart.formatted(.dateTime.month(.wide))
            }
            return periodStart.formatted(.dateTime.month(.wide).year())
        default:
            return periodStart.formatted(date: .abbreviated, time: .omitted)
        }
    }
}
