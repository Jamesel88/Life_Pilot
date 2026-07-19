import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var notes = ""
    @State private var dueDate = Date()
    @State private var hasTime = false
    @State private var dueWindow: DueWindow = .day
    @State private var periodStart: Date = .now
    @State private var priority: Priority = .normal
    @State private var repeatRule: TaskRepeat = .never
    @State private var selectedGroup: TaskGroup?

    // For creating a new colour code inline
    @State private var showingNewGroup = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("What needs doing?", text: $title)
                }

                Section("Notes") {
                    TextField("Anything else worth noting?",
                              text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("When") {
                    Picker("When", selection: $dueWindow.animation()) {
                        ForEach(DueWindow.allCases, id: \.self) { window in
                            Text(window.segmentLabel).tag(window)
                        }
                    }
                    .pickerStyle(.segmented)

                    if dueWindow == .day {
                        DatePicker("Date", selection: $dueDate,
                                   displayedComponents: hasTime ? [.date, .hourAndMinute] : [.date])
                        Toggle("Specific time", isOn: $hasTime)
                    } else {
                        if dueWindow == .week || dueWindow == .month {
                            DuePeriodPicker(window: dueWindow, selection: $periodStart)
                        }
                        if let anchor = dueWindow.anchorDate(from: periodStart) {
                            LabeledContent("Due by") {
                                Text(anchor, format: .dateTime.weekday().day().month())
                            }
                        }
                    }
                }
                .onChange(of: dueWindow) { _, newValue in
                    // Reset to the current period when switching windows
                    if let component = newValue.calendarComponent {
                        periodStart = Calendar.current
                            .dateInterval(of: component, for: .now)?.start ?? .now
                    }
                }

                Section("Repeat") {
                    Picker("Repeat", selection: $repeatRule) {
                        ForEach(TaskRepeat.allCases, id: \.self) { rule in
                            Text(rule.label).tag(rule)
                        }
                    }
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
                    GroupPicker(selection: $selectedGroup)
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
                        let task = TaskItem(
                            title: title,
                            dueDate: dueWindow.anchorDate(from: periodStart) ?? dueDate,
                            hasTime: dueWindow == .day && hasTime,
                            dueWindow: dueWindow,
                            priority: priority,
                            group: selectedGroup, repeatRule: repeatRule)
                        task.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        modelContext.insert(task)
                        try? modelContext.save()
                        NotificationManager.scheduleReminder(for: task)
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
