import AppIntents
import SwiftData
import Foundation

// PersistentIdentifier isn't EntityIdentifierConvertible, so App Intents
// can't use it directly as an AppEntity.ID — it round-trips through the
// shared PersistentIdentifier String codec instead.

struct HabitEntity: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
    static var defaultQuery = HabitEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct HabitEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [HabitEntity] {
        let context = ModelContext(HabitsTrackerApp.sharedModelContainer)
        return identifiers.compactMap { encoded in
            guard let persistentID = PersistentIdentifier(encodedString: encoded),
                  let habit = context.model(for: persistentID) as? Habit
            else { return nil }
            return HabitEntity(id: encoded, name: habit.name)
        }
    }

    @MainActor
    func suggestedEntities() async throws -> [HabitEntity] {
        let context = ModelContext(HabitsTrackerApp.sharedModelContainer)
        let habits = try context.fetch(FetchDescriptor<Habit>())
        return habits
            .filter { $0.isActive(on: .now) }
            .map { HabitEntity(id: $0.persistentModelID.encodedString, name: $0.name) }
    }
}

struct CompleteHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Habit"
    static var description = IntentDescription("Marks a habit as done for today.")

    @Parameter(title: "Habit")
    var habit: HabitEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(HabitsTrackerApp.sharedModelContainer)
        guard let persistentID = PersistentIdentifier(encodedString: habit.id),
              let model = context.model(for: persistentID) as? Habit
        else {
            return .result(dialog: "Couldn't find that habit.")
        }
        if !model.hasLoggedCompletion(on: .now) {
            model.completedDates.append(.now)
            try? context.save()
        }
        return .result(dialog: "Logged \(model.name).")
    }
}

struct HabitsAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CompleteHabitIntent(),
            phrases: [
                "Log \(\.$habit) in \(.applicationName)",
                "Complete \(\.$habit) in \(.applicationName)"
            ],
            shortTitle: "Log habit",
            systemImageName: "flame.fill"
        )
    }
}
