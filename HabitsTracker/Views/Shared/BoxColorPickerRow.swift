import SwiftUI

/// The "Box colour" form row: a free colour picker while no group is
/// assigned, and a read-only swatch labelled "Matches group" once one is —
/// the group's colour always wins. Shared by the box add and edit sheets.
struct BoxColorPickerRow: View {
    @Binding var color: Color
    var group: TaskGroup?

    var body: some View {
        if let group {
            LabeledContent("Box colour") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: group.colorHex))
                        .frame(width: 16, height: 16)
                    Text("Matches group")
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            ColorPicker("Box colour", selection: $color, supportsOpacity: false)
        }
    }
}
