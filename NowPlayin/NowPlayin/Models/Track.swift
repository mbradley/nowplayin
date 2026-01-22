import Foundation

enum PlayerState: String {
    case playing
    case paused
    case stopped
}

struct Track: Equatable {
    let name: String
    let artist: String
    let state: PlayerState

    var statusText: String {
        guard !name.isEmpty else { return "" }
        return "\(name) - \(artist)"
    }
}
