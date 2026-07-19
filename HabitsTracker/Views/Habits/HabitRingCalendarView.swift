import SwiftUI
import SwiftData

enum HabitWheelScope: String, CaseIterable {
    case week = "Weekly view"
    case month = "Monthly view"
}

/// A wheel with one concentric ring per habit (up to 10), scoped to either
/// the displayed week or month. Each ring is divided into a wedge per day;
/// tapping a wedge toggles that habit's completion for that day. The day
/// wedges leave a notch open (no cells drawn there) so the habit names can
/// sit in a clean, flat legend instead of floating text on top of the rings.
struct HabitRingCalendarView: View {
    var referenceDate: Date
    var scope: HabitWheelScope
    var habits: [Habit]
    /// When false the wheel is a read-only overview — month-scope wedges
    /// are too small to be honest tap targets.
    var interactive: Bool = true
    var onToggle: (Habit, Date) -> Void

    private var calendar: Calendar { .current }

    private static let palette: [Color] = [
        .orange, .blue, .green, .pink, .purple,
        .teal, .yellow, .red, .indigo, .mint
    ]

    /// Only the first 10 habits get a ring — that's what fits legibly on the wheel.
    private var ringedHabits: [Habit] { Array(habits.prefix(10)) }

    /// Degrees left empty (just before day 1, at the top) for the habit legend.
    private let notchDegrees: Double = 78

    private var days: [Date] {
        switch scope {
        case .month:
            guard let range = calendar.range(of: .day, in: .month, for: referenceDate),
                  let first = calendar.date(
                      from: calendar.dateComponents([.year, .month], from: referenceDate))
            else { return [] }
            return range.compactMap {
                calendar.date(byAdding: .day, value: $0 - 1, to: first)
            }
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate)
            else { return [] }
            return (0..<7).compactMap {
                calendar.date(byAdding: .day, value: $0, to: interval.start)
            }
        }
    }

    private func color(for ringIndex: Int) -> Color {
        Self.palette[ringIndex % Self.palette.count]
    }

    /// Angle span for a given day-of-month index, with a small gap on either
    /// side so cells read as a grid. Day 1 starts at the top (-90°) and the
    /// wheel sweeps clockwise through `360 - notchDegrees`, leaving the rest
    /// of the circle (just before day 1) empty for the legend.
    private func angleRange(dayIndex: Int, total: Int) -> (start: Angle, end: Angle) {
        let sweep = 360.0 - notchDegrees
        let step = sweep / Double(max(total, 1))
        let gap = 1.2
        let start = -90 + Double(dayIndex) * step + gap / 2
        let end = -90 + Double(dayIndex + 1) * step - gap / 2
        return (.degrees(start), .degrees(end))
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(x: center.x + radius * CGFloat(cos(angle.radians)),
                y: center.y + radius * CGFloat(sin(angle.radians)))
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outerRadius = size / 2 - 14
            let innerRadius = size * 0.13
            let ringCount = max(ringedHabits.count, 1)
            let ringWidth = (outerRadius - innerRadius) / CGFloat(ringCount)

            ZStack {
                // MARK: Day labels around the rim
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    let (start, end) = angleRange(dayIndex: index, total: days.count)
                    let mid = Angle(radians: (start.radians + end.radians) / 2)
                    Text(dayLabel(for: day))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                        .position(point(center: center, radius: outerRadius + 10, angle: mid))
                }

                // MARK: Habit rings (innermost = first habit)
                ForEach(Array(ringedHabits.enumerated()), id: \.element.persistentModelID) { ringIndex, habit in
                    let rInner = innerRadius + CGFloat(ringIndex) * ringWidth
                    let rOuter = rInner + ringWidth - 1.5
                    let tint = color(for: ringIndex)

                    ForEach(Array(days.enumerated()), id: \.element) { dayIndex, day in
                        let (start, end) = angleRange(dayIndex: dayIndex, total: days.count)
                        let active = habit.isActive(on: day)
                        let done = active && habit.isCompleted(on: day)
                        let cell = AnnularSegment(innerRadius: rInner, outerRadius: rOuter,
                                                   startAngle: start, endAngle: end)

                        cell
                            .fill(done ? tint : tint.opacity(active ? 0.14 : 0.05))
                            .contentShape(cell)
                            .onTapGesture {
                                guard interactive, active else { return }
                                onToggle(habit, day)
                            }
                            .accessibilityLabel(
                                "\(habit.name), \(day.formatted(.dateTime.month().day())), \(done ? "done" : "not done")")
                    }
                }

                // MARK: Habit legend, sitting in the notch — never over the rings
                legend(center: center, innerRadius: innerRadius, outerRadius: outerRadius)

                VStack(spacing: 2) {
                    switch scope {
                    case .month:
                        Text(referenceDate, format: .dateTime.month(.wide))
                            .font(.caption.bold())
                        Text(referenceDate, format: .dateTime.year())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    case .week:
                        Text("Week of")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(days.first ?? referenceDate, format: .dateTime.month(.abbreviated).day())
                            .font(.caption.bold())
                    }
                }
                .position(center)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func dayLabel(for day: Date) -> String {
        switch scope {
        case .month:
            return String(calendar.component(.day, from: day))
        case .week:
            return day.formatted(.dateTime.weekday(.abbreviated))
        }
    }

    @ViewBuilder
    private func legend(center: CGPoint, innerRadius: CGFloat, outerRadius: CGFloat) -> some View {
        let notchMidAngle = Angle.degrees(-90 - notchDegrees / 2)
        let anchor = point(center: center, radius: (innerRadius + outerRadius) / 2, angle: notchMidAngle)

        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(ringedHabits.enumerated()), id: \.element.persistentModelID) { index, habit in
                HStack(spacing: 4) {
                    Circle()
                        .fill(color(for: index))
                        .frame(width: 6, height: 6)
                    Text(habit.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(color(for: index))
                        .lineLimit(1)
                }
            }
        }
        .frame(width: outerRadius * 0.78, alignment: .leading)
        .position(anchor)
    }
}

/// A single ring-and-wedge cell: the area between two radii, swept between two angles.
private struct AnnularSegment: Shape {
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let segments = 8

        func point(_ radius: CGFloat, _ angle: Double) -> CGPoint {
            CGPoint(x: center.x + radius * CGFloat(cos(angle)),
                    y: center.y + radius * CGFloat(sin(angle)))
        }

        var path = Path()
        path.move(to: point(outerRadius, startAngle.radians))
        for i in 0...segments {
            let t = startAngle.radians + (endAngle.radians - startAngle.radians) * Double(i) / Double(segments)
            path.addLine(to: point(outerRadius, t))
        }
        for i in 0...segments {
            let t = endAngle.radians + (startAngle.radians - endAngle.radians) * Double(i) / Double(segments)
            path.addLine(to: point(innerRadius, t))
        }
        path.closeSubpath()
        return path
    }
}
