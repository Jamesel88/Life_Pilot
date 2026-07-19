import SwiftUI
import SwiftData

struct EditGroupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var group: TaskGroup

    @State private var color: Color
    @State private var showingDeleteConfirmation = false

    init(group: TaskGroup) {
        self.group = group
        _color = State(initialValue: Color(hex: group.colorHex))
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (e.g. James, Louise, Work)", text: $group.name)
                ColorPicker("Ring colour", selection: $color, supportsOpacity: false)
                    .onChange(of: color) { _, newValue in
                        group.colorHex = newValue.contrastClamped().toHex()
                    }

                Section("Preview") {
                    HStack {
                        Spacer()
                        RingView(progress: 0.7, color: color, lineWidth: 12)
                            .frame(width: 80, height: 80)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Button("Delete Colour Code", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle("Edit Colour Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete this colour code?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    modelContext.delete(group)
                    dismiss()
                }
            } message: {
                Text("Tasks assigned to \"\(group.name)\" will be deleted too. This can't be undone.")
            }
        }
        .presentationDetents([.medium])
    }
}
