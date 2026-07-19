import SwiftUI

/// The opening sequence — "chaos → clarity" in three beats (~2.4s):
///
/// 1. **Scatter**: symbols of a busy life (calls, bills, errands, deadlines)
///    spring outward from the centre — the overload everyone recognises.
/// 2. **The ring forms**: they sweep clockwise into the app's signature
///    progress ring, which draws itself in the four accent colours and is
///    snapped shut by a checkmark (with a success haptic).
/// 3. **Handoff**: the ring rises to reveal the Compartments wordmark,
///    then cross-fades into the dashboard where the real rings take over.
///
/// Tap anywhere to skip. Reduce Motion collapses the whole thing to a
/// simple fade. Backgrounds follow the app's appearance setting.
struct LaunchIntroView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase {
        case hidden, scattered, ringed, logo, branded
    }

    private struct Piece: Identifiable {
        let id: Int
        let symbol: String
        let color: Color
        let scatterOffset: CGSize
        let scatterRotation: Double
        let ringAngle: Double       // degrees, -90 = top
    }

    @State private var phase: Phase = .hidden
    @State private var ringProgress: Double = 0
    @State private var showCheck = false
    @State private var skipped = false

    private let pieces: [Piece]
    private let ringRadius: CGFloat = 100

    init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished

        // The everyday overload: errands, messages, bills, deadlines…
        let symbols = ["checklist", "calendar", "bell.fill", "envelope.fill",
                       "phone.fill", "cart.fill", "clock.fill", "doc.text.fill",
                       "wrench.and.screwdriver.fill", "car.fill", "fork.knife",
                       "creditcard.fill", "figure.run", "exclamationmark.circle.fill"]
        let accents: [Color] = [.accentTasks, .accentHabits, .accentBoxes, .accentAllTasks]

        self.pieces = symbols.enumerated().map { index, symbol in
            // Golden-angle spiral: even spread that still looks organic
            let angle = Double(index) * 137.5 * .pi / 180
            let radius = 70.0 + Double(index % 5) * 18
            return Piece(
                id: index,
                symbol: symbol,
                color: accents[index % accents.count],
                scatterOffset: CGSize(width: cos(angle) * radius,
                                      height: sin(angle) * radius * 0.95),
                scatterRotation: Double((index % 2 == 0 ? 1 : -1) * (8 + index * 3) % 22),
                ringAngle: -90 + Double(index) * (360 / Double(symbols.count))
            )
        }
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            // MARK: Ring + scattering symbols — recede once the logo pops
            let logoShown = phase == .logo || phase == .branded
            ZStack {
                ForEach(pieces) { piece in
                    pieceView(piece)
                }

                ringView
            }
            .scaleEffect(logoShown ? 0.82 : 1)
            .opacity(logoShown ? 0 : 1)
            .offset(y: -20)
            .animation(.easeOut(duration: 0.3), value: logoShown)

            // MARK: The monogram tile — pops out toward the viewer
            MonogramView()
                .frame(width: 150, height: 150)
                .shadow(color: .black.opacity(0.35), radius: 20, y: 12)
                .scaleEffect(logoShown ? 1 : 0.3)
                .opacity(logoShown ? 1 : 0)
                .offset(y: phase == .branded ? -70 : -20)
                .animation(.spring(response: 0.5, dampingFraction: 0.55), value: logoShown)
                .animation(.spring(response: 0.55, dampingFraction: 0.8),
                           value: phase == .branded)

            // MARK: Wordmark
            VStack(spacing: 8) {
                Text("Compartments")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Getting it done…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .offset(y: 70)
            .opacity(phase == .branded ? 1 : 0)
            .offset(y: phase == .branded ? 0 : 14)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15),
                       value: phase == .branded)

            // MARK: Skip hint
            Text("tap to skip")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 24)
                .opacity(phase == .scattered || phase == .ringed ? 1 : 0)
                .animation(.easeInOut(duration: 0.4), value: phase)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: skip)
        .sensoryFeedback(.success, trigger: showCheck) { _, isShown in isShown }
        .task { await runSequence() }
    }

    // MARK: - Subviews

    private var ringView: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 12)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    AngularGradient(
                        colors: [.accentTasks, .accentHabits, .accentBoxes,
                                 .accentAllTasks, .accentTasks],
                        center: .center,
                        startAngle: .degrees(0), endAngle: .degrees(360)),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Image(systemName: "checkmark")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(Color.accentTasks)
                .scaleEffect(showCheck ? 1 : 0.01)
                .animation(.spring(response: 0.45, dampingFraction: 0.6), value: showCheck)
        }
        .frame(width: ringRadius * 2, height: ringRadius * 2)
    }

    @ViewBuilder
    private func pieceView(_ piece: Piece) -> some View {
        let slot = piece.ringAngle * .pi / 180
        let onRing = phase == .ringed || phase == .branded

        Image(systemName: piece.symbol)
            .font(.system(size: 21, weight: .semibold))
            .foregroundStyle(piece.color)
            .rotationEffect(.degrees(phase == .scattered ? piece.scatterRotation : 0))
            .scaleEffect(phase == .hidden ? 0.01 : (onRing ? 0.55 : 1))
            .opacity(onRing ? 0 : 1)
            .offset(offset(for: piece, slot: slot))
            .animation(animation(for: piece), value: phase)
    }

    private func offset(for piece: Piece, slot: Double) -> CGSize {
        switch phase {
        case .hidden:
            return .zero
        case .scattered:
            return piece.scatterOffset
        case .ringed, .logo, .branded:
            return CGSize(width: cos(slot) * ringRadius,
                          height: sin(slot) * ringRadius)
        }
    }

    /// Staggered springs: pieces leave the centre one after another, and
    /// sweep onto the ring clockwise in slot order.
    private func animation(for piece: Piece) -> Animation {
        switch phase {
        case .hidden:
            return .default
        case .scattered:
            return .spring(response: 0.55, dampingFraction: 0.62)
                .delay(Double(piece.id) * 0.026)
        case .ringed, .logo, .branded:
            return .spring(response: 0.5, dampingFraction: 0.85)
                .delay(Double(piece.id) * 0.045)
        }
    }

    // MARK: - Timeline

    private func runSequence() async {
        if reduceMotion {
            // No motion: everything simply fades in, fully formed
            withAnimation(.easeIn(duration: 0.5)) {
                phase = .branded
                ringProgress = 1
                showCheck = true
            }
            try? await Task.sleep(for: .seconds(1.4))
            if !skipped { onFinished() }
            return
        }

        try? await Task.sleep(for: .seconds(0.1))
        guard !skipped else { return }
        withAnimation { phase = .scattered }

        try? await Task.sleep(for: .seconds(0.65))
        guard !skipped else { return }
        withAnimation { phase = .ringed }
        withAnimation(.easeInOut(duration: 0.78)) { ringProgress = 1 }

        try? await Task.sleep(for: .seconds(0.8))
        guard !skipped else { return }
        showCheck = true

        // The tick lands, then the monogram tile pops out toward the viewer
        try? await Task.sleep(for: .seconds(0.45))
        guard !skipped else { return }
        withAnimation { phase = .logo }

        try? await Task.sleep(for: .seconds(0.55))
        guard !skipped else { return }
        withAnimation { phase = .branded }

        try? await Task.sleep(for: .seconds(0.95))
        guard !skipped else { return }
        onFinished()
    }

    private func skip() {
        guard !skipped else { return }
        skipped = true
        withAnimation(.easeOut(duration: 0.25)) {
            phase = .branded
            ringProgress = 1
            showCheck = true
        }
        Task {
            try? await Task.sleep(for: .seconds(0.45))
            onFinished()
        }
    }
}

#Preview {
    LaunchIntroView {}
}
