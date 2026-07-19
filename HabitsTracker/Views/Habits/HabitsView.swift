import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var habits: [Habit]
    @State private var habitToEdit: Habit?
    @State private var showingAddHabit = false
    @State private var referenceDate = Date()
    // Week is the default: 7 fat wedges are comfortably tappable, whereas
    // the month wheel's 30+ slivers are read-only (see below)
    @State private var scope: HabitWheelScope = .week
    @State private var showingCelebration = false

    private var calendar: Calendar { .current }

    var body: some View {
        ZStack {
            habitsNavigationStack

            if showingCelebration {
                HabitCelebrationOverlay {
                    showingCelebration = false
                }
                .zIndex(1)
            }
        }
        .sensoryFeedback(.success, trigger: showingCelebration) { _, newValue in newValue }
    }

    private var habitsNavigationStack: some View {
        NavigationStack {
            List {
                // MARK: Scope menu
                Section {
                    Menu {
                        ForEach(HabitWheelScope.allCases, id: \.self) { option in
                            Button {
                                scope = option
                            } label: {
                                if scope == option {
                                    Label(option.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(option.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "line.3.horizontal")
                            Text(scope.rawValue)
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.primary)
                    }
                }

                // MARK: Radial habit wheel
                Section {
                    VStack(spacing: 4) {
                        HStack {
                            Button {
                                changePeriod(-1)
                            } label: {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.title3)
                            }
                            Spacer()
                            Text(periodTitle)
                                .font(.subheadline.bold())
                            Spacer()
                            Button {
                                changePeriod(1)
                            } label: {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.title3)
                            }
                            .disabled(isCurrentPeriod)
                        }
                        .buttonStyle(.borderless)

                        HabitRingCalendarView(referenceDate: referenceDate, scope: scope,
                                              habits: habits,
                                              interactive: scope == .week,
                                              onToggle: toggleHabit)
                            .frame(height: 340)
                            .frame(maxWidth: .infinity)

                        if scope == .month {
                            Text("Overview — switch to Weekly view to log days")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if habits.count > 10 {
                            Text("Showing the first 10 habits on the wheel")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: All habits (interactive)
                Section("All habits") {
                    ForEach(habits) { habit in
                        HStack {
                            CompletionToggleButton(isCompleted: isDone(habit),
                                                   tint: .accentHabits,
                                                   itemTitle: habit.name) {
                                toggle(habit)
                            }

                            VStack(alignment: .leading) {
                                Text(habit.name)
                                    .strikethrough(isDone(habit))
                                Text(habit.frequency.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { habitToEdit = habit }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            NotificationManager.cancelReminder(for: habits[index])
                            modelContext.delete(habits[index])
                        }
                    }
                }
            }
            .monogramWatermark()
            .navigationTitle("Habits")
            .toolbar {
                Button {
                    showingAddHabit = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView()
            }
            .sheet(item: $habitToEdit) { habit in
                EditHabitView(habit: habit)
            }
            .overlay {
                if habits.isEmpty {
                    ContentUnavailableView("No habits yet",
                        systemImage: "repeat",
                        description: Text("Tap + to add your first habit"))
                }
            }
        }
        .tint(.accentHabits)
    }

    // MARK: - Helpers

    private func isDone(_ habit: Habit) -> Bool {
        habit.isCompleted(on: .now)
    }

    private func toggle(_ habit: Habit) {
        toggleHabit(habit, on: .now)
    }

    private func toggleHabit(_ habit: Habit, on day: Date) {
        let isToday = calendar.isDateInToday(day)
        let wasAllComplete = isToday && allHabitsCompleteToday

        habit.toggleCompletion(on: day, calendar: calendar)

        if isToday && !wasAllComplete && allHabitsCompleteToday {
            showingCelebration = true
        }
    }

    /// True only once every currently-active habit is done for today —
    /// used to fire the celebration exactly on the moment it first happens.
    private var allHabitsCompleteToday: Bool {
        let active = habits.filter { $0.isActive(on: .now) }
        return !active.isEmpty && active.allSatisfy { $0.isCompleted(on: .now) }
    }

    private func changePeriod(_ delta: Int) {
        let component: Calendar.Component = scope == .month ? .month : .weekOfYear
        if let newDate = calendar.date(byAdding: component, value: delta, to: referenceDate) {
            referenceDate = newDate
        }
    }

    private var isCurrentPeriod: Bool {
        switch scope {
        case .month:
            calendar.isDate(referenceDate, equalTo: .now, toGranularity: .month)
        case .week:
            calendar.isDate(referenceDate, equalTo: .now, toGranularity: .weekOfYear)
        }
    }

    private var periodTitle: String {
        switch scope {
        case .month:
            return referenceDate.formatted(.dateTime.month(.wide).year())
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
                return referenceDate.formatted(.dateTime.month().day())
            }
            let start = interval.start
            let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            if calendar.isDate(start, equalTo: end, toGranularity: .month) {
                return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.day()))"
            } else {
                return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
            }
        }
    }
}
