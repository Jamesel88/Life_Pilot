import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var groups: [TaskGroup]

    @State private var title = ""
    @State private var dueDate = Date()
    @State private var hasTime = false
    @State private var priority: Priority = .normal
    @State private var selectedGroup: TaskGroup?

    // For creating a new colour code inline
    @State private var showingNewGroup = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("What needs doing?", text: $title)
                }

                Section("When") {
                    DatePicker("Date", selection: $dueDate,
                               displayedComponents: hasTime ? [.date, .hourAndMinute] : [.date])
                    Toggle("Specific time", isOn: $hasTime)
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases, id: \.self) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Group") {
                    Picker("Group", selection: $selectedGroup) {
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
                    Button("Create New Group") { showingNewGroup = true }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let task = TaskItem(title: title, dueDate: dueDate,
                                            hasTime: hasTime, priority: priority,
                                            group: selectedGroup)
                        modelContext.insert(task)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }.sheet(isPresented: $showingNewGroup) {
                AddGroupView()
            }
        }
    }
}
