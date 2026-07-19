import SwiftData
import Foundation

/// One line on the shopping list. Deliberately simpler than TaskItem —
/// no dates, groups, or priorities; groceries just need adding, ticking
/// off, and clearing.
@Model
class ShoppingItem {
    var name: String = ""
    var isChecked: Bool = false
    var createdAt: Date = Date.now

    init(name: String) {
        self.name = name
    }
}
