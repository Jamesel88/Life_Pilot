import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: TaskItem

    var body: some View {
        HStack {
            // A quiet red edge stripe for urgent tasks only — everything
            // else (and completed rows) stays unmarked.
            if task.isUrgent && !task.isCompleted {
                Capsule()
                    .fill(Color.red)
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)
            }

            CompletionToggleButton(isCompleted: task.isCompleted,
                                   itemTitle: task.title) {
                toggleCompletion()
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(task.title)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    if task.repeatRule != .never {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let windowDescription = task.dueWindowDescription {
                    Text("\(windowDescription) · by \(task.dueDate, format: .dateTime.day().month())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if task.hasTime {
                    Text(task.dueDate, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !task.allLinkedTasks.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "link")
                        Text("\(task.allLinkedTasks.count)")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                if !(task.photos ?? []).isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "photo")
                        Text("\((task.photos ?? []).count)")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let group = task.group {
                Circle()
                    .fill(Color(hex: group.colorHex))
                    .frame(width: 12, height: 12)
            }

            if task.isUrgent && !task.isCompleted {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
        .sensoryFeedback(.success, trigger: task.isCompleted) { _, isNowComplete in
            isNowComplete
        }
    }

    private func toggleCompletion() {
        if task.isCompleted {
            task.isCompleted = false
            task.completedAt = nil
            NotificationManager.scheduleReminder(for: task)
        } else {
            task.complete(in: modelContext)
        }
    }
}
