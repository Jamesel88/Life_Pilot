import SwiftUI

/// The Compartments monogram — five compartment cells forming a "C" —
/// drawn in SwiftUI so it can animate. Uses the exact 120-unit layout and
/// fixed colours of the app icon (see the icon render script), so the tile
/// on screen matches the tile on the home screen.
struct MonogramView: View {
    /// Include the charcoal app-icon plate behind the cells
    var showsPlate: Bool = true

    private struct Cell {
        let rect: CGRect
        let color: Color
    }

    private static let cells: [Cell] = [
        Cell(rect: CGRect(x: 26, y: 22, width: 30, height: 22),
             color: Color(red: 52/255, green: 199/255, blue: 89/255)),     // green
        Cell(rect: CGRect(x: 62, y: 22, width: 30, height: 22),
             color: Color(red: 255/255, green: 159/255, blue: 10/255)),    // orange
        Cell(rect: CGRect(x: 26, y: 49, width: 30, height: 22),
             color: Color(red: 64/255, green: 156/255, blue: 255/255)),    // blue
        Cell(rect: CGRect(x: 26, y: 76, width: 30, height: 22),
             color: Color(red: 199/255, green: 158/255, blue: 115/255)),   // tan
        Cell(rect: CGRect(x: 62, y: 76, width: 30, height: 22),
             color: Color(red: 142/255, green: 142/255, blue: 147/255).opacity(0.85)) // grey
    ]

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / 120
            ZStack(alignment: .topLeading) {
                if showsPlate {
                    RoundedRectangle(cornerRadius: 27 * scale, style: .continuous)
                        .fill(Color(red: 0.110, green: 0.110, blue: 0.118))
                }
                ForEach(Array(Self.cells.enumerated()), id: \.offset) { _, cell in
                    RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
                        .fill(cell.color)
                        .frame(width: cell.rect.width * scale,
                               height: cell.rect.height * scale)
                        .offset(x: cell.rect.minX * scale,
                                y: cell.rect.minY * scale)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Page watermark

/// The logo as a faint, centred watermark behind a page's content.
private struct MonogramWatermark: ViewModifier {
    var baseColor: Color

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background {
                ZStack {
                    baseColor.ignoresSafeArea()
                    MonogramView(showsPlate: false)
                        .frame(width: 230)
                        .opacity(0.05)
                }
            }
    }
}

extension View {
    /// Apply to a List/Form (default grouped background) or pass
    /// `base: Color(.systemBackground)` for plain scroll pages.
    func monogramWatermark(base: Color = Color(.systemGroupedBackground)) -> some View {
        modifier(MonogramWatermark(baseColor: base))
    }
}

#Preview {
    VStack(spacing: 30) {
        MonogramView()
            .frame(width: 120)
        MonogramView(showsPlate: false)
            .frame(width: 120)
    }
    .padding()
}
