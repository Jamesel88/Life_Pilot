import SwiftUI
import SwiftData

struct AddGroupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var color = Color.green

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (e.g. James, Louise, Work)", text: $name)
                ColorPicker("Ring colour", selection: $color, supportsOpacity: false)

                // Live preview
                Section("Preview") {
                    HStack {
                        Spacer()
                        RingView(progress: 0.7, color: color, lineWidth: 12)
                            .frame(width: 80, height: 80)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Colour Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let group = TaskGroup(name: name, colorHex: color.contrastClamped().toHex())
                        modelContext.insert(group)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
