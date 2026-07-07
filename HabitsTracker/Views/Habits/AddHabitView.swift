import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var frequency: HabitFrequency = .daily
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var hasReminder = false
    @State private var reminderTime = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Name (e.g. Read 20 minutes)", text: $name)
                }

                Section("Repeats") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(HabitFrequency.allCases, id: \.self) { f in
                            Text(f.label).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Duration") {
                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                    Toggle("End date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("Ends", selection: $endDate,
                                   in: startDate..., displayedComponents: .date)
                        Section("Reminder") {
                            Toggle("Remind me", isOn: $hasReminder)
                            if hasReminder {
                                DatePicker("Time", selection: $reminderTime,
                                           displayedComponents: .hourAndMinute)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let habit = Habit(name: name,
                                          frequency: frequency,
                                          startDate: startDate,
                                          endDate: hasEndDate ? endDate : nil,
                                          reminderTime: hasReminder ? reminderTime : nil)
                        modelContext.insert(habit)
                        NotificationManager.scheduleReminder(for: habit)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
