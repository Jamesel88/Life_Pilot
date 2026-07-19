import SwiftUI

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let xFraction: CGFloat      // 0...1, starting horizontal position
    let driftX: CGFloat         // small horizontal wobble as it falls
    let restYFraction: CGFloat  // 0...1, where it settles near the bottom
    let rotation: Double
    let size: CGFloat
    let delay: Double
    let duration: Double
}

/// Confetti that falls from above the screen and piles up near the
/// bottom, then just sits there — it isn't tied to the message card's
/// lifetime, so it stays put until the whole overlay is dismissed. A
/// single easeIn animation per piece (gravity: starts slow, speeds up)
/// keeps this cheap even with a full pile of pieces on screen at once.
private struct ConfettiView: View {
    @State private var animate = false
    private let pieces: [ConfettiPiece]

    private static let colors: [Color] = [.orange, .green, .blue, .pink, .yellow, .purple]

    init() {
        var generated: [ConfettiPiece] = []
        for _ in 0..<90 {
            generated.append(ConfettiPiece(
                color: Self.colors.randomElement() ?? .orange,
                xFraction: .random(in: 0.02...0.98),
                driftX: .random(in: -30...30),
                restYFraction: .random(in: 0.8...0.97),
                rotation: .random(in: 180...540),
                size: .random(in: 8...15),
                delay: .random(in: 0...0.5),
                duration: .random(in: 0.8...1.3)
            ))
        }
        self.pieces = generated
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    let startX = geo.size.width * piece.xFraction
                    let endX = startX + piece.driftX
                    let endY = geo.size.height * piece.restYFraction

                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 0.6)
                        .rotationEffect(.degrees(animate ? piece.rotation : 0))
                        .position(x: animate ? endX : startX, y: animate ? endY : -40)
                        .animation(.easeIn(duration: piece.duration).delay(piece.delay), value: animate)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}

/// The "all habits done for today" celebration: confetti falls and piles
/// up at the bottom of the screen behind a message card. Nothing
/// auto-dismisses — it stays until the user taps "Nice" or the dimmed
/// background.
struct HabitCelebrationOverlay: View {
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            ConfettiView()
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Text("Well done!")
                    .font(.title2.weight(.bold))
                Text("You're Getting It Done today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Nice", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .tint(.accentHabits)
                    .padding(.top, 6)
            }
            .padding(28)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(40)
        }
    }
}
