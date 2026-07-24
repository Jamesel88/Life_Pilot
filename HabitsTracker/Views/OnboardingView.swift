import SwiftUI
import SwiftData
import PhotosUI

/// First-launch walkthrough: welcome, then one page each for creating a
/// task, a group, and a habit — every step optional — ending on the
/// compartment-box concept. Runs once ever (see hasCompletedOnboarding in
/// HabitsTrackerApp); "Skip tour" bails out at any point.
struct OnboardingView: View {
    var onFinished: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var page = 0

    @State private var profileName = ""
    @State private var profilePhotoData: Data?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var taskTitle = ""
    @State private var groupName = ""
    @State private var selectedColorHex = "34C759"
    @State private var habitName = ""
    @State private var habitFrequency: HabitFrequency = .daily

    private let groupColors = ["34C759", "FF9F0A", "409CFF",
                               "FF6B8A", "AF7AC5", "4DCCC7"]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip tour") { onFinished() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }

                TabView(selection: $page) {
                    welcomePage.tag(0)
                    profilePage.tag(1)
                    taskPage.tag(2)
                    groupPage.tag(3)
                    habitPage.tag(4)
                    boxesPage.tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        pageLayout {
            MonogramView()
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
            Text("Welcome to Compartments")
                .font(.system(.title, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
            Text("Tasks, habits, and life's bigger jobs — sorted into compartments that fill up as you get things done.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } footer: {
            primaryButton("Get started") { advance() }
        }
    }

    private var profilePage: some View {
        pageLayout {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let data = profilePhotoData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.accentBoxes.opacity(0.18)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(Color.accentBoxes)
                            )
                    }
                }
                .frame(width: 84, height: 84)
                .clipShape(Circle())

                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentBoxes)
                        .background(Circle().fill(Color(.systemBackground)))
                }
                .accessibilityLabel("Add profile photo")
            }
            Text("Make it yours")
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text("A name for your greeting, a photo if you like. No account, no sign-in — everything stays on your device and your own iCloud.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            TextField("Your name", text: $profileName)
                .textContentType(.name)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 8)
        } footer: {
            primaryButton(profileName.trimmingCharacters(in: .whitespaces).isEmpty
                          && profilePhotoData == nil ? "Continue" : "Create profile") {
                createProfileIfProvided()
                advance()
            }
            skipButton()
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            photoPickerItem = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                profilePhotoData = image.preparingThumbnail(
                    of: CGSize(width: 512, height: 512))?.pngData() ?? data
            }
        }
    }

    private var taskPage: some View {
        pageLayout {
            LoopingCheckDemo()
                .frame(height: 64)
            Text("Add your first task")
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text("Tasks live on the Tasks tab and today's show up on your dashboard. Try adding one — or type things like \"Dentist tomorrow 3pm\" in quick add later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            TextField("e.g. Book the car in", text: $taskTitle)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 8)
        } footer: {
            primaryButton(taskTitle.trimmingCharacters(in: .whitespaces).isEmpty
                          ? "Continue" : "Add task") {
                createTaskIfNamed()
                advance()
            }
            skipButton()
        }
    }

    private var groupPage: some View {
        pageLayout {
            LoopingGroupDemo()
                .frame(height: 74)
            Text("Colour-code with groups")
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text("Groups sort tasks by person or area of life — Work, Home, the kids — each with its own colour everywhere in the app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            TextField("e.g. Work", text: $groupName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 8)
            HStack(spacing: 12) {
                ForEach(groupColors, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(
                                    selectedColorHex == hex ? 0.8 : 0), lineWidth: 2.5)
                        )
                        .onTapGesture { selectedColorHex = hex }
                        .accessibilityLabel("Colour option")
                        .accessibilityAddTraits(selectedColorHex == hex ? [.isSelected] : [])
                }
            }
        } footer: {
            primaryButton(groupName.trimmingCharacters(in: .whitespaces).isEmpty
                          ? "Continue" : "Create group") {
                createGroupIfNamed()
                advance()
            }
            skipButton()
        }
    }

    private var habitPage: some View {
        pageLayout {
            LoopingStreakDemo()
                .frame(height: 64)
            Text("Build a habit")
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text("Habits tick over daily, weekly, or monthly — keep a streak going and watch the flame grow on your dashboard.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            TextField("e.g. Read 20 minutes", text: $habitName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 8)
            Picker("Frequency", selection: $habitFrequency) {
                ForEach(HabitFrequency.allCases, id: \.self) { frequency in
                    Text(frequency.label).tag(frequency)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 8)
        } footer: {
            primaryButton(habitName.trimmingCharacters(in: .whitespaces).isEmpty
                          ? "Continue" : "Start habit") {
                createHabitIfNamed()
                advance()
            }
            skipButton()
        }
    }

    private var boxesPage: some View {
        pageLayout {
            LoopingBoxDemo()
                .frame(width: 110, height: 110)
            Text("Box up the big stuff")
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text("Bigger jobs — moving house, a tax return — become compartment boxes. Every subtask fills a compartment, and the lid seals when the whole job's done. You can even scan a photo of a written list to fill one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } footer: {
            primaryButton("Start organising") { onFinished() }
        }
    }

    // MARK: - Layout pieces

    private func pageLayout(@ViewBuilder content: () -> some View,
                            @ViewBuilder footer: () -> some View) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 12)
            content()
            Spacer(minLength: 12)
            footer()
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 44)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentBoxes)
    }

    private func skipButton() -> some View {
        Button("Skip this step") { advance() }
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func advance() {
        withAnimation { page += 1 }
    }

    // MARK: - Creation

    private func createProfileIfProvided() {
        let name = profileName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty || profilePhotoData != nil else { return }
        modelContext.insert(UserProfile(name: name, photoData: profilePhotoData))
    }

    private func createTaskIfNamed() {
        let title = taskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let task = TaskItem(title: title, dueDate: Calendar.current.startOfDay(for: .now))
        modelContext.insert(task)
        try? modelContext.save()
        NotificationManager.scheduleReminder(for: task)
    }

    private func createGroupIfNamed() {
        let name = groupName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        modelContext.insert(TaskGroup(name: name, colorHex: selectedColorHex))
    }

    private func createHabitIfNamed() {
        let name = habitName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        modelContext.insert(Habit(name: name, frequency: habitFrequency))
    }
}

#Preview {
    OnboardingView {}
}

// MARK: - Live looping demos
//
// Real production views (CompletionToggleButton, RingView,
// CompartmentBoxView), just driven by a repeating loop instead of user
// input — a "gif-style" preview of each feature that needs no external
// image assets and is always pixel-faithful to the real UI. Each cancels
// its loop task on disappear so paging away during onboarding doesn't
// leave background timers running.

private struct LoopingCheckDemo: View {
    @State private var isChecked = false
    @State private var loopTask: Task<Void, Never>?

    var body: some View {
        CompletionToggleButton(isCompleted: isChecked, itemTitle: "Book the car in") {}
            .scaleEffect(2.2)
            .allowsHitTesting(false)
            .onAppear(perform: startLoop)
            .onDisappear { loopTask?.cancel() }
    }

    private func startLoop() {
        loopTask?.cancel()
        loopTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.0))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isChecked = true }
                try? await Task.sleep(for: .seconds(1.4))
                guard !Task.isCancelled else { return }
                withAnimation { isChecked = false }
            }
        }
    }
}

private struct LoopingGroupDemo: View {
    @State private var colorIndex = 0
    @State private var loopTask: Task<Void, Never>?
    private let colors: [Color] = [.accentTasks, .accentHabits, .accentAllTasks]

    var body: some View {
        ZStack {
            RingView(progress: 0.7, color: colors[colorIndex], lineWidth: 10)
                .frame(width: 70, height: 70)
            Circle()
                .fill(colors[colorIndex])
                .frame(width: 14, height: 14)
        }
        .onAppear(perform: startLoop)
        .onDisappear { loopTask?.cancel() }
    }

    private func startLoop() {
        loopTask?.cancel()
        loopTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.1))
                guard !Task.isCancelled else { return }
                withAnimation { colorIndex = (colorIndex + 1) % colors.count }
            }
        }
    }
}

private struct LoopingStreakDemo: View {
    @State private var streak = 0
    @State private var loopTask: Task<Void, Never>?
    private let maxStreak = 12

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color.accentHabits)
            Text("\(streak) day streak")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentHabits)
                .contentTransition(.numericText())
                .monospacedDigit()
        }
        .onAppear(perform: startLoop)
        .onDisappear { loopTask?.cancel() }
    }

    private func startLoop() {
        loopTask?.cancel()
        loopTask = Task {
            while !Task.isCancelled {
                for value in 0...maxStreak {
                    guard !Task.isCancelled else { return }
                    try? await Task.sleep(for: .seconds(0.18))
                    withAnimation { streak = value }
                }
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                withAnimation { streak = 0 }
                try? await Task.sleep(for: .seconds(0.3))
            }
        }
    }
}

private struct LoopingBoxDemo: View {
    @State private var completed = 0
    @State private var loopTask: Task<Void, Never>?
    private let total = 6

    var body: some View {
        CompartmentBoxView(color: .accentBoxes, completed: completed, total: total)
            .onAppear(perform: startLoop)
            .onDisappear { loopTask?.cancel() }
    }

    private func startLoop() {
        loopTask?.cancel()
        loopTask = Task {
            while !Task.isCancelled {
                for step in 0...total {
                    guard !Task.isCancelled else { return }
                    try? await Task.sleep(for: .seconds(0.45))
                    withAnimation { completed = step }
                }
                try? await Task.sleep(for: .seconds(1.1))
                guard !Task.isCancelled else { return }
                withAnimation { completed = 0 }
                try? await Task.sleep(for: .seconds(0.3))
            }
        }
    }
}
