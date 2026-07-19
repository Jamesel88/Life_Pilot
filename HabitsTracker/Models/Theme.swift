import SwiftUI

/// The app's semantic palette. Every domain has one accent used for its
/// tab tint, rings, and buttons, with separate light/dark values so
/// nothing washes out in either appearance. Retune colours here, not at
/// call sites.
extension Color {
    /// Tasks domain (and the "today" ring)
    static let accentTasks = Color(light: Color(red: 0.16, green: 0.62, blue: 0.33),
                                   dark: Color(red: 0.35, green: 0.84, blue: 0.45))
    /// Habits domain (rings, streaks, celebration)
    static let accentHabits = Color(light: Color(red: 0.95, green: 0.55, blue: 0.10),
                                    dark: Color(red: 1.00, green: 0.65, blue: 0.26))
    /// Boxes domain
    static let accentBoxes = Color(light: Color(red: 0.62, green: 0.48, blue: 0.32),
                                   dark: Color(red: 0.78, green: 0.62, blue: 0.45))
    /// The all-time tasks ring
    static let accentAllTasks = Color(light: Color(red: 0.10, green: 0.46, blue: 0.90),
                                      dark: Color(red: 0.35, green: 0.65, blue: 1.00))
    /// Shopping list ring and affordances
    static let accentShopping = Color(light: Color(red: 0.05, green: 0.52, blue: 0.53),
                                      dark: Color(red: 0.30, green: 0.80, blue: 0.78))
    /// Completion state — checkmarks and "done" affordances
    static let success = Color(light: Color(red: 0.16, green: 0.62, blue: 0.33),
                               dark: Color(red: 0.35, green: 0.84, blue: 0.45))

    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}
