import SwiftUI
import SwiftData

struct EditTaskBoxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var box: TaskBox

    @State private var color: Color
    @State private var showingDeleteConfirmation = false

    init(box: TaskBox) {
        self.box = box
        _color = State(initialValue: Color(hex: box.colorHex))
    }

    /// Group colour wins when a group is assigned
    private var previewColor: Color {
        if let group = box.group {
            Color(hex: group.colorHex)
        } else {
            color
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $box.name)

                BoxColorPickerRow(color: $color, group: box.group)
                    .onChange(of: color) { _, newValue in
                        box.colorHex = newValue.contrastClamped().toHex()
                    }

                GroupPicker(selection: $box.group.animation())

                Section("Preview") {
                    HStack {
                        Spacer()
                        CompartmentBoxView(color: previewColor,
                                           completed: box.completedCount,
                                           total: box.totalCount)
                            .frame(width: 90, height: 90)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Button("Delete Box", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle("Edit Compartment Box")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete this box?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    modelContext.delete(box)
                    dismiss()
                }
            } message: {
                Text("Subtasks inside \"\(box.name)\" will be deleted too. Linked tasks stay on the Tasks tab. This can't be undone.")
            }
        }
        .presentationDetents([.medium])
    }
}
