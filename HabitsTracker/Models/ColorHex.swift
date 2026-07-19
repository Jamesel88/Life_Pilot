import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
extension Color {
    /// Nudge a user-picked colour's brightness into a mid range so group
    /// dots, rings, and box tints stay visible against both light and dark
    /// backgrounds. Hue and saturation are untouched — the colour still
    /// reads as "theirs". Apply when saving, not when rendering.
    func contrastClamped() -> Color {
        var hue: CGFloat = 0, saturation: CGFloat = 0
        var brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getHue(&hue, saturation: &saturation,
                             brightness: &brightness, alpha: &alpha)
        let clamped = min(max(brightness, 0.35), 0.85)
        guard clamped != brightness else { return self }
        return Color(hue: hue, saturation: saturation, brightness: clamped)
    }

    func toHex() -> String {
        let components = UIColor(self).cgColor.components ?? [0, 0, 0]
        let r = Int((components[0]) * 255)
        let g = Int((components.count > 1 ? components[1] : components[0]) * 255)
        let b = Int((components.count > 2 ? components[2] : components[0]) * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
