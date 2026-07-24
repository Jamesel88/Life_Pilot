import SwiftUI
import SwiftData

struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: TaskItem

    /// The period containing the task's anchor date, re-anchoring on change
    private var periodBinding: Binding<Date> {
        Binding(
            get: {
                guard let component = task.dueWindow.calendarComponent,
                      let interval = Calendar.current.dateInterval(of: component,
                                                                   for: task.dueDate)
                else { return task.dueDate }
                return interval.start
            },
            set: { newStart in
                if let anchor = task.dueWindow.anchorDate(from: newStart) {
                    task.dueDate = anchor
                }
            })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $task.title)
                }

                Section("Notes") {
                    TextField("Anything else worth noting?",
                              text: $task.notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("When") {
                    Picker("When", selection: $task.dueWindow.animation()) {
                        ForEach(DueWindow.allCases, id: \.self) { window in
                            Text(window.segmentLabel).tag(window)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: task.dueWindow) { _, newValue in
                        // Vague windows anchor to the period's last day
                        if let anchor = newValue.anchorDate() {
                            task.dueDate = anchor
                            task.hasTime = false
                        }
                    }

                    if task.dueWindow == .day {
                        DatePicker("Date", selection: $task.dueDate,
                                   displayedComponents: task.hasTime ? [.date, .hourAndMinute] : [.date])
                        Toggle("Specific time", isOn: $task.hasTime)
                    } else {
                        if task.dueWindow == .week || task.dueWindow == .month {
                            DuePeriodPicker(window: task.dueWindow, selection: periodBinding)
                        }
                        LabeledContent("Due by") {
                            Text(task.dueDate, format: .dateTime.weekday().day().month())
                        }
                    }
                }

                Section("Repeat") {
                    Picker("Repeat", selection: $task.repeatRule) {
                        ForEach(TaskRepeat.allCases, id: \.self) { rule in
                            Text(rule.label).tag(rule)
                        }
                    }
                }

                Section {
                    Toggle("Mark as urgent", isOn: $task.isUrgent)
                        .tint(.red)
                }

                Section("Linked Tasks") {
                    LinkedTasksEditorView(task: task)
                }

                Section("Group") {
                    GroupPicker(selection: $task.group)
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                // Date/time may have changed — reschedule (no-op cancel
                // if the task is completed)
                NotificationManager.scheduleReminder(for: task)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
