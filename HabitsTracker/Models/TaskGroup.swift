import SwiftData

@Model
class TaskGroup {
    var name: String
    var colorHex: String
    @Relationship(deleteRule: .cascade) var tasks: [TaskItem] = []

    init(name: String, colorHex: String) {
        self.name = name
        self.colorHex = colorHex
    }
}
