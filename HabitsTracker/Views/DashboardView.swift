import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var allTasks: [TaskItem]
    @Query private var groups: [TaskGroup]
    @Query private var habits: [Habit]
    @Query private var shoppingItems: [ShoppingItem]
    @Binding var tabSelection: AppTab

    /// Scales with Dynamic Type so "12 left" still fits inside the ring
    @ScaledMetric(relativeTo: .caption2) private var groupRingSize: CGFloat = 54

    private var calendar: Calendar { .current }

    // MARK: - Task helpers

    private var todayTasks: [TaskItem] {
        allTasks.filter { calendar.isDateInToday($0.dueDate) }
    }

    private var todayCompletedCount: Int {
        todayTasks.filter(\.isCompleted).count
    }

    /// Today's tasks with incomplete urgent items pinned to the top
    private var sortedTodayTasks: [TaskItem] {
        todayTasks.sorted { a, b in
            let aUrgent = a.priority == .urgent && !a.isCompleted
            let bUrgent = b.priority == .urgent && !b.isCompleted
            if aUrgent != bUrgent { return aUrgent }
            return a.dueDate < b.dueDate
        }
    }

    /// Every task, regardless of due date, that hasn't been completed yet
    private var allOutstandingTasks: [TaskItem] {
        allTasks.filter { !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }
    }

    // MARK: - Habit helpers

    private var activeHabits: [Habit] {
        habits.filter { $0.isActive(on: .now) }
    }

    private func habitsDoneToday(_ index: HabitCompletionIndex) -> Int {
        activeHabits.filter { index.isCompleted($0, on: .now) }.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                // Built once per render: every streak/dash/ring habit check
                // below is a table lookup instead of a completedDates scan.
                let habitIndex = HabitCompletionIndex(habits: habits)
                VStack(spacing: 20) {

                    // MARK: Shopping list ring — tap goes straight to the
                    // list. Gone once everything's bought, not just when
                    // the list is cleared.
                    if shoppingItems.contains(where: { !$0.isChecked }) {
                        let purchased = shoppingItems.filter(\.isChecked).count
                        NavigationLink {
                            ShoppingListView()
                        } label: {
                            ZStack {
                                RingView(progress: Double(purchased) / Double(shoppingItems.count),
                                         color: .accentShopping, lineWidth: 14)
                                    .frame(width: 160, height: 160)

                                VStack(spacing: 6) {
                                    Image(systemName: "basket")
                                        .font(.system(size: 38))
                                        .foregroundStyle(Color.accentShopping)
                                    Text("\(purchased)/\(shoppingItems.count)")
                                        .font(.title3.bold().monospacedDigit())
                                        .foregroundStyle(.primary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "Shopping list, \(purchased) of \(shoppingItems.count) items in the basket")
                    }

                    // MARK: Today's tasks
                    if !todayTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Tasks")
                                    .font(.headline)
                                Text(Date.now, format: .dateTime.weekday(.wide).day().month())
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            // Completed tasks drop off this card (the ring
                            // still counts them; the Tasks tab's Completed
                            // filter still lists them)
                            let outstandingToday = sortedTodayTasks.filter { !$0.isCompleted }
                            if outstandingToday.isEmpty {
                                Text("All done for today — nice work!")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 4)
                            } else {
                                ForEach(outstandingToday) { task in
                                    if task.priority == .urgent {
                                        // Quiet urgency: a tinted wash — the row's
                                        // own red stripe and triangle carry the signal
                                        TaskRowView(task: task)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .background(.red.opacity(0.12),
                                                        in: RoundedRectangle(cornerRadius: 10))
                                    } else {
                                        TaskRowView(task: task)
                                            .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }

                    // MARK: Streak
                    StreakDashboardCard(
                        habits: habits,
                        dayCompletion: habitIndex.dayCompletion(on:),
                        todayTasksCompleted: todayCompletedCount,
                        todayTasksTotal: todayTasks.count,
                        onSelectHabits: { tabSelection = .habits }
                    )

                    // MARK: Group rings — every task in the group, not just today's
                    if !groups.isEmpty {
                        let tasksByGroup = Dictionary(
                            grouping: allTasks.filter { $0.group != nil },
                            by: { $0.group!.persistentModelID })
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 18) {
                                ForEach(groups) { group in
                                    let groupTasks = tasksByGroup[group.persistentModelID] ?? []
                                    let completedCount = groupTasks.filter(\.isCompleted).count
                                    let outstandingCount = groupTasks.count - completedCount
                                    // Tapping a ring drills into just that
                                    // group's tasks
                                    NavigationLink {
                                        GroupTasksView(group: group)
                                    } label: {
                                        VStack(spacing: 6) {
                                            ZStack {
                                                RingView(progress: groupTasks.isEmpty
                                                             ? 0
                                                             : Double(completedCount) / Double(groupTasks.count),
                                                         color: Color(hex: group.colorHex),
                                                         lineWidth: 7)
                                                    .frame(width: groupRingSize, height: groupRingSize)
                                                if outstandingCount == 0 && !groupTasks.isEmpty {
                                                    Image(systemName: "checkmark")
                                                        .font(.caption.bold())
                                                        .foregroundStyle(Color(hex: group.colorHex))
                                                } else {
                                                    Text("\(outstandingCount) left")
                                                        .font(.caption2.bold())
                                                        .foregroundStyle(.primary)
                                                }
                                            }
                                            .frame(width: groupRingSize + 10, height: groupRingSize + 10)
                                            .background(Circle().fill(Color.primary.opacity(0.06)))

                                            Text(group.name)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(
                                        "\(group.name), \(outstandingCount) tasks left")
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 6)
                        }
                        .scrollClipDisabled()

                        Text("All-time progress by group")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    // MARK: Overview — the day as a compartment tray. Cells
                    // fill as things complete; finishing every task and
                    // habit seals the lid.
                    DayTrayView(tasksCompleted: todayCompletedCount,
                                tasksTotal: todayTasks.count,
                                habitsDone: habitsDoneToday(habitIndex),
                                habitsTotal: activeHabits.count,
                                allTimeCompleted: allTasks.filter(\.isCompleted).count,
                                allTimeTotal: allTasks.count)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    // MARK: Outstanding tasks — a static preview instead of a
                    // scroll view nested inside the page scroll
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Outstanding Tasks")
                                .font(.headline)
                            Spacer()
                            if !allOutstandingTasks.isEmpty {
                                Button {
                                    tabSelection = .tasks
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("See all")
                                        Image(systemName: "arrow.right")
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }

                        if allOutstandingTasks.isEmpty {
                            Text("Nothing outstanding — nice work!")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(allOutstandingTasks.prefix(5)) { task in
                                    TaskRowView(task: task)
                                }
                            }
                            if allOutstandingTasks.count > 5 {
                                Text("and \(allOutstandingTasks.count - 5) more…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .monogramWatermark(base: Color(.systemBackground))
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        InsightsView()
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                    }
                    .accessibilityLabel("Insights")
                }
            }
        }
    }
}
