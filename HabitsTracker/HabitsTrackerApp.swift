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
                // Coming back to the foreground is also the moment to
                // sweep away any reminder left over from a task that was
                // completed or deleted while the app wasn't running
                if phase == .active {
                    NotificationManager.pruneStaleTaskReminders(container: Self.sharedModelContainer)
                }
            }
        }
        .modelContainer(Self.sharedModelContainer)
    }

    /// Flip to true ONLY after adding the iCloud → CloudKit capability to
    /// the Life-Pilot target in Xcode (container iCloud.com.jameslane.compartments).
    /// The schema is already CloudKit-compatible (all relationships
    /// optional with inverses). With the flag false the store stays
    /// local-only, exactly as before.
    static let cloudKitSyncEnabled = false

    /// Not private — App Intents (Siri/Shortcuts) need to reach it too.
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([Habit.self, TaskGroup.self, TaskItem.self, TaskPhoto.self,
                             TaskBox.self, BoxSubtask.self, SubtaskPhoto.self,
                             ShoppingItem.self, UserProfile.self])
        let configuration = cloudKitSyncEnabled
            ? ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            : ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Unrecoverable — the app is storage-backed — but crash with a
            // diagnosable message instead of a bare try! trap.
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
