import SwiftData

@Model
class TaskGroup {
    var name: String = ""
    var colorHex: String = "888888"
    @Relationship(deleteRule: .cascade) var tasks: [TaskItem] = []

    init(name: String, colorHex: String) {
        self.name = name
        self.colorHex = colorHex
    }
}
