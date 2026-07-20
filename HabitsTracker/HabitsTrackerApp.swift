import SwiftUI
import SwiftData

@main
struct HabitsTrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var showLaunchIntro = true
    @AppStorage("appAppearance") private var appearance: AppAppearance = .dark
    /// Once ever: flips true the first time the walkthrough finishes (or
    /// is skipped) and never shows again
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showLaunchIntro {
                    LaunchIntroView {
                        withAnimation(.easeOut(duration: 0.4)) {
                            showLaunchIntro = false
                        }
                    }
                    .transition(.opacity)
                } else if !hasCompletedOnboarding {
                    OnboardingView {
                        withAnimation(.easeOut(duration: 0.4)) {
                            hasCompletedOnboarding = true
                        }
                    }
                    .transition(.opacity)
                } else {
                    MainTabView()
                        .task {
                            NotificationManager.requestPermission()
                        }
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(appearance.colorScheme)
            .onChange(of: scenePhase) { _, phase in
                // Hand the widgets fresh numbers whenever the app leaves
                // the foreground (.inactive catches locks and the app
                // switcher, not just the home swipe)
                if phase == .background || phase == .inactive {
                    WidgetBridge.writeSnapshot(container: Self.sharedModelContainer)
                }
            }
        }
        .modelContainer(Self.sharedModelContainer)
    }

    /// Local-only for now — see TODO.md for what's needed to switch this
    /// to `cloudKitDatabase: .automatic` and sync across devices. Not
    /// private — App Intents (Siri/Shortcuts) need to reach it too.
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([Habit.self, TaskGroup.self, TaskItem.self,
                             TaskBox.self, BoxSubtask.self, SubtaskPhoto.self,
                             ShoppingItem.self])
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Unrecoverable — the app is storage-backed — but crash with a
            // diagnosable message instead of a bare try! trap.
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
