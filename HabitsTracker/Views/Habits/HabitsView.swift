import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var habits: [Habit]
    @State private var habitToEdit: Habit?
    @State private var showingAddHabit = false
    @State private var referenceDate = Date()
    @State private var scope: HabitWheelScope = .month

    private var calendar: Calendar { .current }

    var body: some View {
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
                                              habits: habits, onToggle: toggleHabit)
                            .frame(height: 340)
                            .frame(maxWidth: .infinity)

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
                            Button {
                                toggle(habit)
                            } label: {
                                Image(systemName: isDone(habit)
                                      ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(isDone(habit) ? .orange : .secondary)
                            }
                            .buttonStyle(.plain)

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
    }

    // MARK: - Helpers

    private func isDone(_ habit: Habit) -> Bool {
        habit.isCompleted(on: .now)
    }

    private func toggle(_ habit: Habit) {
        toggleHabit(habit, on: .now)
    }

    private func toggleHabit(_ habit: Habit, on day: Date) {
        if habit.isCompleted(on: day) {
            habit.completedDates.removeAll {
                calendar.isDate($0, equalTo: day, toGranularity: habit.granularity)
            }
        } else {
            habit.completedDates.append(day)
        }
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
