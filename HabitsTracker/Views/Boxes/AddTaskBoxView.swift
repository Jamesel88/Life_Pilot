import SwiftUI
import SwiftData

struct AddTaskBoxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var color = Color.brown
    @State private var selectedGroup: TaskGroup?
    @State private var showingScanList = false
    @State private var pendingSubtasks: [ListScanner.ScannedTask] = []

    /// Group colour wins when a group is selected
    private var previewColor: Color {
        if let selectedGroup {
            Color(hex: selectedGroup.colorHex)
        } else {
            color
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (e.g. Move house, Tax return)", text: $name)

                // MARK: Scan subtasks from a photo (once the box is named)
                Section {
                    if !pendingSubtasks.isEmpty {
                        ForEach(pendingSubtasks) { subtask in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(subtask.title)
                                if subtask.matchedDate {
                                    Text(subtask.dueDate,
                                         format: .dateTime.day().month())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            pendingSubtasks.remove(atOffsets: indexSet)
                        }
                    }

                    Button {
                        showingScanList = true
                    } label: {
                        Label(pendingSubtasks.isEmpty
                              ? "Scan a list of subtasks"
                              : "Scan another list",
                              systemImage: "text.viewfinder")
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Subtasks")
                } footer: {
                    if name.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("Name the box first, then you can scan a photo of a list — each line becomes a compartment.")
                    } else if pendingSubtasks.isEmpty {
                        Text("Each line of the photo becomes a compartment. Lines with a date keep it.")
                    }
                }

                BoxColorPickerRow(color: $color, group: selectedGroup)

                GroupPicker(selection: $selectedGroup.animation())

                // Live preview — shows the real compartments once scanned
                Section("Preview") {
                    HStack {
                        Spacer()
                        if pendingSubtasks.isEmpty {
                            CompartmentBoxView(color: previewColor, completed: 4, total: 6)
                                .frame(width: 90, height: 90)
                        } else {
                            CompartmentBoxView(color: previewColor,
                                               completed: 0,
                                               total: pendingSubtasks.count)
                                .frame(width: 90, height: 90)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Compartment Box")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let box = TaskBox(name: name, colorHex: color.contrastClamped().toHex(),
                                          group: selectedGroup)
                        modelContext.insert(box)
                        for pending in pendingSubtasks {
                            let subtask = BoxSubtask(
                                title: pending.title,
                                dueDate: pending.matchedDate ? pending.dueDate : nil)
                            subtask.box = box
                            modelContext.insert(subtask)
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showingScanList) {
            ScanListView(undatedCaption: "No date") { proposals in
                pendingSubtasks.append(contentsOf: proposals)
            }
        }
    }
}
