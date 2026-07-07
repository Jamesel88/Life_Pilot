import SwiftUI
import SwiftData

struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: TaskItem
    @Query private var groups: [TaskGroup]

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $task.title)
                }

                Section("When") {
                    DatePicker("Date", selection: $task.dueDate,
                               displayedComponents: task.hasTime ? [.date, .hourAndMinute] : [.date])
                    Toggle("Specific time", isOn: $task.hasTime)
                }

                Section("Priority") {
                    Picker("Priority", selection: $task.priority) {
                        ForEach(Priority.allCases, id: \.self) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Group") {
                    Picker("Group", selection: $task.group) {
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
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
