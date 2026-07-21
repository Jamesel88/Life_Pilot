import SwiftData
import Foundation

/// The user's local profile — no account, no login. Identity for sync is
/// their iCloud account; this is just how the app addresses and pictures
/// them. Single instance by convention (first(_:) wins).
@Model
final class UserProfile {
    var name: String = ""
    @Attribute(.externalStorage) var photoData: Data?
    var createdAt: Date = Date.now

    init(name: String, photoData: Data? = nil) {
        self.name = name
        self.photoData = photoData
    }
}

extension UserProfile {
    /// "JL" from "James Lane" — the avatar fallback when there's no photo
    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }
        return letters.isEmpty ? "" : String(letters).uppercased()
    }
}
