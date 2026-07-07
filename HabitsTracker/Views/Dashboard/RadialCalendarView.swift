import SwiftUI

enum DayCompletion {
    case none, partial, full
}

struct RadialCalendarView: View {
    var month: Date
    var dayCompletion: (Date) -> DayCompletion
    var selectedDay: Date? = nil
    var onTapDay: ((Date) -> Void)? = nil

    private var calendar: Calendar { .current }

    /// All days in the displayed month
    private var days: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let first = calendar.date(
                  from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }
        return range.compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: first)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2 - 20
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let centerRingRadius = size * 0.22

            ZStack {
                // Spokes from fully-completed days in to the centre ring
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    if dayCompletion(day) == .full {
                        let angle = Double(index) / Double(days.count) * 2 * .pi - .pi / 2
                        Path { path in
                            path.move(to: CGPoint(x: center.x + cos(angle) * centerRingRadius,
                                                   y: center.y + sin(angle) * centerRingRadius))
                            path.addLine(to: CGPoint(x: center.x + cos(angle) * radius,
                                                      y: center.y + sin(angle) * radius))
                        }
                        .stroke(Color.orange.opacity(0.55), lineWidth: 1)
                    }
                }

                // Ring around the centre month/year label
                Circle()
                    .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                    .frame(width: centerRingRadius * 2, height: centerRingRadius * 2)
                    .position(center)

                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    let angle = Double(index) / Double(days.count) * 2 * .pi - .pi / 2
                    dayDot(for: day)
                        .position(x: center.x + cos(angle) * radius,
                                  y: center.y + sin(angle) * radius)
                }

                VStack(spacing: 2) {
                    Text(month, format: .dateTime.month(.wide))
                        .font(.headline)
                    Text(month, format: .dateTime.year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .position(center)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func dayDot(for day: Date) -> some View {
        let completion = dayCompletion(day)
        let isFuture = day > .now && !calendar.isDateInToday(day)
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false

        ZStack {
            Circle()
                .fill(Color.white.opacity(isFuture ? 0.07 : 0.16))
            PieSlice(fraction: completion == .full ? 1 : (completion == .partial ? 0.5 : 0))
                .fill(Color.orange)
        }
        .frame(width: 13, height: 13)
        .overlay {
            if isSelected {
                Circle().stroke(.white, lineWidth: 2)
            } else if calendar.isDateInToday(day) {
                Circle().stroke(.orange.opacity(0.7), lineWidth: 1.5)
            }
        }
        .contentShape(Circle().inset(by: -8))
        .onTapGesture { onTapDay?(day) }
    }
}

/// A filled pie wedge sweeping clockwise from the top, covering the given
/// fraction of the circle (0 = nothing, 0.5 = half disc, 1 = full disc).
private struct PieSlice: Shape {
    var fraction: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard fraction > 0 else { return path }
        if fraction >= 1 {
            path.addEllipse(in: rect)
            return path
        }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let segments = 16
        let startAngle = -Double.pi / 2
        let endAngle = startAngle + 2 * .pi * Double(fraction)

        path.move(to: center)
        for i in 0...segments {
            let t = startAngle + (endAngle - startAngle) * Double(i) / Double(segments)
            path.addLine(to: CGPoint(x: center.x + radius * CGFloat(cos(t)),
                                      y: center.y + radius * CGFloat(sin(t))))
        }
        path.closeSubpath()
        return path
    }
}
