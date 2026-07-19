import Foundation
import SwiftData

/// PersistentIdentifier is Codable but not directly usable where a stable
/// String is needed (AppEntity IDs, notification identifiers). This is the
/// single codec for round-tripping it through a String — launch-stable,
/// unlike `hashValue`, which is re-seeded every process launch.
extension PersistentIdentifier {
    var encodedString: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return data.base64EncodedString()
    }

    init?(encodedString: String) {
        guard let data = Data(base64Encoded: encodedString),
              let decoded = try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
        else { return nil }
        self = decoded
    }
}
