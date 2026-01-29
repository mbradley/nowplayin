import Foundation

struct SlackStatus {
    let text: String
    let emoji: String
}

struct WorkspaceInfo {
    let teamId: String
    let teamName: String
    let userId: String
}

enum SlackError: Error, LocalizedError {
    case apiError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .apiError(let message): return message
        case .networkError(let error): return error.localizedDescription
        }
    }
}

enum SlackService {
    static let statusEmoji = ":musical_note:"
    private static let baseURL = "https://slack.com/api"

    static func getStatus(token: String) async throws -> SlackStatus? {
        let url = URL(string: "\(baseURL)/users.profile.get")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        guard let ok = json["ok"] as? Bool, ok else {
            let error = json["error"] as? String ?? "unknown error"
            throw SlackError.apiError(error)
        }

        guard let profile = json["profile"] as? [String: Any] else {
            return nil
        }

        let text = profile["status_text"] as? String ?? ""
        let emoji = profile["status_emoji"] as? String ?? ""

        return SlackStatus(text: text, emoji: emoji)
    }

    static func setStatus(token: String, text: String, emoji: String = statusEmoji) async throws -> Bool {
        let url = URL(string: "\(baseURL)/users.profile.set")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let profile: [String: Any] = [
            "status_text": text,
            "status_emoji": text.isEmpty ? "" : emoji
        ]
        let body: [String: Any] = ["profile": profile]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SlackError.apiError("Invalid response")
        }

        guard let ok = json["ok"] as? Bool else {
            throw SlackError.apiError("Missing ok field")
        }

        if !ok {
            let error = json["error"] as? String ?? "unknown error"
            throw SlackError.apiError(error)
        }

        return true
    }

    static func clearStatus(token: String) async throws -> Bool {
        try await setStatus(token: token, text: "", emoji: "")
    }

    static func isOurStatus(_ emoji: String) -> Bool {
        emoji == statusEmoji
    }

    static func getWorkspaceInfo(token: String) async throws -> WorkspaceInfo {
        let url = URL(string: "\(baseURL)/auth.test")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SlackError.apiError("Invalid response")
        }

        guard let ok = json["ok"] as? Bool, ok else {
            let error = json["error"] as? String ?? "unknown error"
            throw SlackError.apiError(error)
        }

        guard let teamId = json["team_id"] as? String,
              let teamName = json["team"] as? String,
              let userId = json["user_id"] as? String else {
            throw SlackError.apiError("Missing required fields")
        }

        return WorkspaceInfo(teamId: teamId, teamName: teamName, userId: userId)
    }
}
