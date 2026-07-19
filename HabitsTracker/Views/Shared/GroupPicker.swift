import SwiftUI
import SwiftData

/// The standard "Group" form row — a picker of every colour code plus
/// "None". Shared by the task and box add/edit sheets so the group UI
/// can't drift between them. Pass `$selection.animation()` if the caller
/// wants dependent rows to animate.
struct GroupPicker: View {
    @Binding var selection: TaskGroup?
    @Query private var groups: [TaskGroup]

    var body: some View {
        Picker("Group", selection: $selection) {
            Text("None").tag(TaskGroup?.none)
            ForEach(groups) { group in
                HStack {
                    Circle()
                        .fill(Color(hex: group.colorHex))
                        .frame(width: 10, height: 10)
                    Text(group.name)
                }
                .tag(Optional(group))
            }
        }
    }
}
