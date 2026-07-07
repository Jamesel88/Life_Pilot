import SwiftUI
import SwiftData

struct EditHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var habit: Habit

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { habit.reminderTime != nil },
            set: { on in
                habit.reminderTime = on ? Date() : nil
                NotificationManager.scheduleReminder(for: habit)
            }
        )
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $habit.name)

                Picker("Frequency", selection: $habit.frequency) {
                    ForEach(HabitFrequency.allCases, id: \.self) { f in
                        Text(f.label).tag(f)
                    }
                }
                Section("Reminder") {
                    Toggle("Remind me", isOn: reminderBinding)
                    if habit.reminderTime != nil {
                        DatePicker("Time",
                                   selection: Binding(
                                       get: { habit.reminderTime ?? Date() },
                                       set: { habit.reminderTime = $0
                                              NotificationManager.scheduleReminder(for: habit) }
                                   ),
                                   displayedComponents: .hourAndMinute)
                    }
                }
                .pickerStyle(.segmented)

                DatePicker("Starts", selection: $habit.startDate, displayedComponents: .date)
            }
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
