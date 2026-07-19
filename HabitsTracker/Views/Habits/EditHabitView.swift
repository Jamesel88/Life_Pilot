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

    private var hasEndDateBinding: Binding<Bool> {
        Binding(
            get: { habit.endDate != nil },
            set: { on in habit.endDate = on ? (habit.endDate ?? Date()) : nil }
        )
    }

    private var endDateBinding: Binding<Date> {
        Binding(
            get: { habit.endDate ?? Date() },
            set: { habit.endDate = $0 }
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
                .pickerStyle(.segmented)

                if habit.frequency == .weekly {
                    Stepper("\(habit.timesPerWeek)x per week", value: $habit.timesPerWeek, in: 1...7)
                }

                Section("Duration") {
                    DatePicker("Starts", selection: $habit.startDate, displayedComponents: .date)
                    Toggle("End date", isOn: hasEndDateBinding)
                    if habit.endDate != nil {
                        DatePicker("Ends", selection: endDateBinding,
                                   in: habit.startDate..., displayedComponents: .date)
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
