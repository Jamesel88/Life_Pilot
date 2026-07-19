import SwiftUI

/// The circle/checkmark completion button used on every row that can be
/// ticked off (tasks, box subtasks, habits). One definition keeps the
/// size, weight, colour rules, hit area, and VoiceOver behaviour
/// identical everywhere.
struct CompletionToggleButton: View {
    var isCompleted: Bool
    var tint: Color = .success
    /// The item's name, read out by VoiceOver ("Buy milk, not completed")
    var itemTitle: String = ""
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isCompleted ? tint : Color.secondary)
                // Pad the tap target toward the 44pt minimum without
                // changing the visual footprint of the row
                .contentShape(Rectangle().inset(by: -12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(itemTitle.isEmpty
            ? (isCompleted ? "Completed" : "Not completed")
            : "\(itemTitle), \(isCompleted ? "completed" : "not completed")")
        .accessibilityHint("Double tap to toggle")
    }
}
