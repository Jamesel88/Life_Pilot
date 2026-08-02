import SwiftUI
import SwiftData
import PhotosUI

struct EditTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: TaskItem

    @State private var photosData: [Data]
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var viewerPhoto: PhotoViewerItem?

    init(task: TaskItem) {
        self.task = task
        let existing = (task.photos ?? []).sorted { $0.createdAt < $1.createdAt }
        _photosData = State(initialValue: existing.map(\.data))
    }

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

                PhotoAttachmentsSection(photosData: $photosData,
                                        pickerItems: $pickerItems,
                                        viewerPhoto: $viewerPhoto)
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                // Date/time may have changed — reschedule (no-op cancel
                // if the task is completed)
                NotificationManager.scheduleReminder(for: task)
                reconcilePhotos()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            photosData.append(data)
                        }
                    }
                    pickerItems = []
                }
            }
            .sheet(item: $viewerPhoto) { item in
                PhotoViewerSheet(data: item.data)
            }
        }
    }

    /// Reconciles the staged photo bytes against `task.photos` on the way
    /// out — keep unchanged photos, delete removed ones, insert only new
    /// ones, so untouched image blobs aren't rewritten on every dismiss.
    private func reconcilePhotos() {
        var pending = photosData
        for photo in (task.photos ?? []).sorted(by: { $0.createdAt < $1.createdAt }) {
            if let index = pending.firstIndex(of: photo.data) {
                pending.remove(at: index)
            } else {
                modelContext.delete(photo)
            }
        }
        for data in pending {
            let photo = TaskPhoto(data: data)
            photo.task = task
            modelContext.insert(photo)
        }
    }
}
