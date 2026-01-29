import Foundation

struct Workspace: Identifiable, Codable, Equatable {
    let id: String       // Slack team ID (T12345678)
    let name: String     // Display name (Acme Corp)

    var keychainAccount: String { "nowplayin-token-\(id)" }
}
