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
            pageIcon("checklist", color: .accentTasks)
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
            pageIcon("circle.grid.2x2", color: .accentAllTasks)
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
            pageIcon("repeat", color: .accentHabits)
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
            CompartmentBoxView(color: .accentBoxes, completed: 4, total: 6)
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

    private func pageIcon(_ symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 44))
            .foregroundStyle(color)
            .frame(height: 64)
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
