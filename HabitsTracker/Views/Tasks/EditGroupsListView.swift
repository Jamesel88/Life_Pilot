import SwiftUI
import SwiftData

/// The dedicated "manage groups" screen, reached from the Tasks menu
/// sidebar — replaces the old cramped dropdown so groups are legible and
/// have room for a colour swatch and a real row height.
struct EditGroupsListView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var groups: [TaskGroup]
    @State private var showingAddGroup = false
    @State private var groupToEdit: TaskGroup?

    var body: some View {
        NavigationStack {
            List {
                if groups.isEmpty {
                    Text("No groups yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(groups) { group in
                        Button {
                            groupToEdit = group
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(hex: group.colorHex))
                                    .frame(width: 14, height: 14)
                                Text(group.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                Button {
                    showingAddGroup = true
                } label: {
                    Label("Add Group", systemImage: "plus.circle")
                }
            }
            .navigationTitle("Edit Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingAddGroup) {
            AddGroupView()
        }
        .sheet(item: $groupToEdit) { group in
            EditGroupView(group: group)
        }
    }
}
