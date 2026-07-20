import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: TaskItem

    var body: some View {
        HStack {
            // Priority at a glance: a quiet edge stripe instead of louder
            // per-row treatments. Normal priority (and completed rows)
            // stay unmarked.
            if let stripe = priorityStripeColor {
                Capsule()
                    .fill(stripe)
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
            }

            Spacer()

            if let group = task.group {
                Circle()
                    .fill(Color(hex: group.colorHex))
                    .frame(width: 12, height: 12)
            }

            if task.priority == .urgent && !task.isCompleted {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
        .sensoryFeedback(.success, trigger: task.isCompleted) { _, isNowComplete in
            isNowComplete
        }
    }

    private var priorityStripeColor: Color? {
        guard !task.isCompleted else { return nil }
        switch task.priority {
        case .urgent: return .red
        case .high: return .orange
        case .normal: return nil
        case .low: return .gray
        }
    }

    private func toggleCompletion() {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? .now : nil
        if task.isCompleted {
            NotificationManager.cancelReminder(for: task)
            if let next = task.nextOccurrence() {
                modelContext.insert(next)
                // Save first so the new task's permanent ID backs its
                // notification identifier
                try? modelContext.save()
                NotificationManager.scheduleReminder(for: next)
            }
        } else {
            NotificationManager.scheduleReminder(for: task)
        }
    }
}
