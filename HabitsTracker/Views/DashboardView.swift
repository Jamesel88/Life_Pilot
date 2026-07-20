import SwiftUI
import SwiftData

/// The Today page: greeting header, the hero day-tray (with the habit
/// streak folded into its footer), a slim shopping chip, one unified
/// "Up next" task list, and group chips. One focal object, one visual
/// language, one screen.
struct DashboardView: View {
    @Query private var allTasks: [TaskItem]
    @Query private var groups: [TaskGroup]
    @Query private var habits: [Habit]
    @Query private var shoppingItems: [ShoppingItem]
    @Binding var tabSelection: AppTab
    @AppStorage("userName") private var userName = ""

    private var calendar: Calendar { .current }

    // MARK: - Task helpers

    private var todayTasks: [TaskItem] {
        allTasks.filter { calendar.isDateInToday($0.dueDate) }
    }

    private var todayCompletedCount: Int {
        todayTasks.filter(\.isCompleted).count
    }

    /// Today's outstanding tasks, urgent first
    private var outstandingToday: [TaskItem] {
        todayTasks
            .filter { !$0.isCompleted }
            .sorted { a, b in
                let aUrgent = a.priority == .urgent
                let bUrgent = b.priority == .urgent
                if aUrgent != bUrgent { return aUrgent }
                return a.dueDate < b.dueDate
            }
    }

    /// Every task, regardless of due date, that hasn't been completed yet
    private var allOutstandingTasks: [TaskItem] {
        allTasks.filter { !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }
    }

    /// Upcoming outstanding tasks beyond today, for the "later" section
    private var laterTasks: [TaskItem] {
        allOutstandingTasks.filter { !calendar.isDateInToday($0.dueDate) }
    }

    // MARK: - Habit helpers

    private var activeHabits: [Habit] {
        habits.filter { $0.isActive(on: .now) }
    }

    private func habitsDoneToday(_ index: HabitCompletionIndex) -> Int {
        activeHabits.filter { index.isCompleted($0, on: .now) }.count
    }

    private var greeting: String {
        let hour = calendar.component(.hour, from: .now)
        let base = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        let name = userName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? base : "\(base), \(name)"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                // Built once per render: every streak/dash habit check
                // below is a table lookup instead of a completedDates scan.
                let habitIndex = HabitCompletionIndex(habits: habits)
                VStack(alignment: .leading, spacing: 16) {
                    header

                    heroCard(habitIndex)

                    streakStrip(habitIndex)

                    shoppingChip

                    sectionLabel("Up next")
                    upNextCard

                    if !groups.isEmpty {
                        sectionLabel("Groups")
                        groupChips
                    }
                }
                .padding()
            }
            .monogramWatermark(base: Color(.systemBackground))
            .compartmentsTabBar()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                .font(.caption2.weight(.semibold))
                .kerning(1.5)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(greeting)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Spacer()
                NavigationLink {
                    InsightsView()
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.title3)
                        .foregroundStyle(Color.accentBoxes)
                }
                .accessibilityLabel("Insights")
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Hero: the day tray, compartments only

    private func heroCard(_ index: HabitCompletionIndex) -> some View {
        DayTrayView(tasksCompleted: todayCompletedCount,
                    tasksTotal: todayTasks.count,
                    habitsDone: habitsDoneToday(index),
                    habitsTotal: activeHabits.count,
                    allTimeCompleted: allTasks.filter(\.isCompleted).count,
                    allTimeTotal: allTasks.count)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [Color.accentBoxes.opacity(0.14),
                                                  Color.accentBoxes.opacity(0.05)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.accentBoxes.opacity(0.35), lineWidth: 1)
                    )
            )
    }

    // MARK: - Streak strip: habits' own tinted moment, out of the tray

    @ViewBuilder
    private func streakStrip(_ index: HabitCompletionIndex) -> some View {
        if !habits.isEmpty {
            // Leads to the answer, not the chore list: Insights holds the
            // week/month/year streak history (Habits stays one tab away)
            NavigationLink {
                InsightsView()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentHabits)
                    Text("\(index.currentStreak()) day streak")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(Color.accentHabits)
                    Spacer()
                    weekDashes(index)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [Color.accentHabits.opacity(0.13),
                                                      Color.accentHabits.opacity(0.04)],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.accentHabits.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(index.currentStreak()) day habit streak. Opens streak history.")
        }
    }

    /// This week Monday–Sunday as compact dashes, same rules as the old
    /// streak card (future days muted, partial days half-strength)
    @ViewBuilder
    private func weekDashes(_ index: HabitCompletionIndex) -> some View {
        let weekday = calendar.component(.weekday, from: .now)
        let daysSinceMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysSinceMonday,
                                   to: calendar.startOfDay(for: .now)) ?? .now
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }

        HStack(spacing: 4) {
            ForEach(days, id: \.self) { day in
                let isFuture = day > .now && !calendar.isDateInToday(day)
                let completion: DayCompletion = isFuture ? .none : index.dayCompletion(on: day)
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(completion == .full
                          ? Color.accentHabits
                          : completion == .partial
                              ? Color.accentHabits.opacity(0.45)
                              : Color.primary.opacity(isFuture ? 0.06 : 0.12))
                    .frame(width: 15, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(days.filter { $0 <= .now && index.dayCompletion(on: $0) == .full }.count) of 7 days fully complete this week")
    }

    // MARK: - Shopping chip

    @ViewBuilder
    private var shoppingChip: some View {
        // Gone once everything's bought, not just when the list is cleared
        if shoppingItems.contains(where: { !$0.isChecked }) {
            let purchased = shoppingItems.filter(\.isChecked).count
            let remaining = shoppingItems.count - purchased
            NavigationLink {
                ShoppingListView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "basket")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentShopping)
                    Text("Shopping")
                        .font(.subheadline.weight(.semibold))

                    Capsule()
                        .fill(Color.accentShopping.opacity(0.18))
                        .frame(height: 4)
                        .overlay(alignment: .leading) {
                            GeometryReader { geo in
                                Capsule()
                                    .fill(Color.accentShopping)
                                    .frame(width: geo.size.width
                                           * Double(purchased) / Double(shoppingItems.count))
                            }
                        }

                    Text("\(remaining) left")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(Color.accentShopping)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Shopping list, \(remaining) items left to buy")
        }
    }

    // MARK: - Up next

    private var upNextCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if allOutstandingTasks.isEmpty {
                Text("Nothing outstanding — nice work!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                if outstandingToday.isEmpty && !todayTasks.isEmpty {
                    Text("All done for today — nice work!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                }

                ForEach(outstandingToday) { task in
                    if task.priority == .urgent {
                        // Quiet urgency: a tinted wash — the row's own red
                        // stripe and triangle carry the signal
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

                if !laterTasks.isEmpty {
                    laterDivider
                    ForEach(laterTasks.prefix(3)) { task in
                        TaskRowView(task: task)
                            .padding(.vertical, 4)
                            .opacity(0.55)
                    }
                }

                Button {
                    tabSelection = .tasks
                } label: {
                    HStack(spacing: 4) {
                        Text("See all")
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 2)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var laterDivider: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
            Text("LATER")
                .font(.system(size: 9, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(.tertiary)
            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Groups: stacked rows in one card, with trailing progress bars

    private var groupChips: some View {
        let tasksByGroup = Dictionary(
            grouping: allTasks.filter { $0.group != nil },
            by: { $0.group!.persistentModelID })

        return VStack(spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.element.persistentModelID) { index, group in
                let groupTasks = tasksByGroup[group.persistentModelID] ?? []
                let completed = groupTasks.filter(\.isCompleted).count
                let outstanding = groupTasks.count - completed
                let progress = groupTasks.isEmpty
                    ? 0 : Double(completed) / Double(groupTasks.count)
                let color = Color(hex: group.colorHex)

                NavigationLink {
                    GroupTasksView(group: group)
                } label: {
                    HStack(spacing: 10) {
                        // One compartment cell filling in the group's
                        // colour — the tray's language, row-sized
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(color.opacity(0.15))
                            GeometryReader { geo in
                                VStack {
                                    Spacer(minLength: 0)
                                    Rectangle()
                                        .fill(color)
                                        .frame(height: geo.size.height * progress)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        .frame(width: 16, height: 16)

                        Text(group.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Capsule()
                            .fill(color.opacity(0.18))
                            .frame(width: 64, height: 4)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(color)
                                    .frame(width: 64 * progress)
                            }

                        Text(outstanding == 0 && !groupTasks.isEmpty
                             ? "Done ✓" : "\(outstanding) left")
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(color)
                            .frame(minWidth: 46, alignment: .trailing)

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(group.name), \(outstanding) tasks left")

                if index < groups.count - 1 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.07))
                        .frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Shared bits

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .kerning(1.4)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 4)
    }
}
