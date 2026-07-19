import SwiftUI

/// A compartment organiser box — the app's namesake visual. The tray is
/// divided into one compartment per item (subtask or linked task); each
/// compartment fills with colour as its work is completed. The hinged lid
/// stays open while anything is outstanding, sits ajar with a dashed tray
/// when the box is empty, and snaps shut with a seal once every
/// compartment is full.
///
/// Legibility cap: past 12 items the tray shows 12 compartments filling
/// proportionally instead of one per item.
struct CompartmentBoxView: View {
    var color: Color
    var completed: Int
    var total: Int

    private var isEmpty: Bool { total == 0 }
    private var isOpen: Bool { !isEmpty && completed < total }
    private var isSealed: Bool { !isEmpty && completed >= total }

    private static let maxCells = 12

    /// How many compartments to draw, and how many of them are filled
    private var cells: (count: Int, filled: Int) {
        guard total > 0 else { return (0, 0) }
        if total <= Self.maxCells { return (total, completed) }
        let filled = Int((Double(completed) / Double(total) * Double(Self.maxCells)).rounded())
        return (Self.maxCells, filled)
    }

    private var lidAngle: Double {
        if isOpen { return -110 }
        if isEmpty { return -20 }
        return 0
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let lidHeight = h * 0.16
            let trayHeight = h - lidHeight
            let cornerRadius = w * 0.10

            VStack(spacing: 0) {
                // Lid — hinged along its bottom edge where it meets the tray
                RoundedRectangle(cornerRadius: lidHeight * 0.4, style: .continuous)
                    .fill(color.opacity(isSealed ? 0.85 : 0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: lidHeight * 0.4, style: .continuous)
                            .strokeBorder(color.opacity(0.7), lineWidth: 1.5)
                    )
                    .frame(width: w * 1.06, height: lidHeight)
                    .rotation3DEffect(
                        .degrees(lidAngle),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .bottom,
                        perspective: 0.4
                    )
                    .zIndex(1)

                // Tray of compartments
                ZStack {
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: cornerRadius,
                        bottomTrailingRadius: cornerRadius,
                        style: .continuous
                    )
                    .fill(color.opacity(0.08))

                    compartmentGrid(width: w, height: trayHeight)
                        .padding(w * 0.07)

                    if isSealed {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: w * 0.30))
                            .foregroundStyle(.white)
                            .shadow(color: color.opacity(0.5), radius: 2)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay(
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: cornerRadius,
                        bottomTrailingRadius: cornerRadius,
                        style: .continuous
                    )
                    .strokeBorder(color.opacity(0.7),
                                  style: StrokeStyle(lineWidth: 1.5,
                                                     dash: isEmpty ? [5, 4] : []))
                )
                .frame(height: trayHeight)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(.spring(response: 0.5, dampingFraction: 0.65), value: completed)
        .animation(.spring(response: 0.5, dampingFraction: 0.65), value: total)
    }

    /// The dividers: a near-square grid, one cell per item, filled cells
    /// coloured in completion order.
    @ViewBuilder
    private func compartmentGrid(width: CGFloat, height: CGFloat) -> some View {
        let (count, filled) = cells
        if count > 0 {
            let columns = Int(ceil(sqrt(Double(count))))
            let rows = Int(ceil(Double(count) / Double(columns)))
            let gap = width * 0.025

            Grid(horizontalSpacing: gap, verticalSpacing: gap) {
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<columns, id: \.self) { column in
                            let index = row * columns + column
                            if index < count {
                                compartmentCell(isFilled: index < filled,
                                                cornerRadius: width * 0.045)
                            } else {
                                // Last row short a divider — the remaining
                                // space reads as one wider compartment
                                Color.clear
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func compartmentCell(isFilled: Bool, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(isFilled
                  ? AnyShapeStyle(LinearGradient(
                        colors: [color.opacity(0.95), color.opacity(0.6)],
                        startPoint: .top, endPoint: .bottom))
                  : AnyShapeStyle(color.opacity(0.10)))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(color.opacity(isFilled ? 0 : 0.35), lineWidth: 1)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    HStack(spacing: 24) {
        CompartmentBoxView(color: .accentBoxes, completed: 0, total: 0)
            .frame(width: 80)
        CompartmentBoxView(color: .accentBoxes, completed: 3, total: 6)
            .frame(width: 80)
        CompartmentBoxView(color: .accentBoxes, completed: 6, total: 6)
            .frame(width: 80)
    }
    .padding()
}
