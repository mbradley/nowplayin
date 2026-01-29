import Foundation
import SwiftUI

@Observable
final class NowPlayinViewModel {
    var isSyncing = false
    var currentTrack: Track?
    var statusMessage = ""

    // Multi-workspace support
    var workspaces: [Workspace] = []
    var workspaceStatuses: [String: String] = [:]  // workspace.id -> error message

    var hasWorkspaces: Bool { !workspaces.isEmpty }

    // Settings stored in UserDefaults
    var pollingInterval: Double {
        get { UserDefaults.standard.double(forKey: "pollingInterval").clamped(to: 5...60) }
        set { UserDefaults.standard.set(newValue, forKey: "pollingInterval") }
    }

    var keepOnPause: Bool {
        get { UserDefaults.standard.bool(forKey: "keepOnPause") }
        set { UserDefaults.standard.set(newValue, forKey: "keepOnPause") }
    }

    var showOnboardingOnLaunch: Bool {
        get { UserDefaults.standard.object(forKey: "showOnboardingOnLaunch") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showOnboardingOnLaunch") }
    }

    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    private var pollingTask: Task<Void, Never>?
    private var lastStatusText: String?
    private var hasSetStatus = false
    private var shouldClearOnExit = true

    private static let workspacesKey = "workspaces"

    init() {
        if UserDefaults.standard.object(forKey: "pollingInterval") == nil {
            UserDefaults.standard.set(10.0, forKey: "pollingInterval")
        }
        loadWorkspaces()
        migrateLegacyTokenIfNeeded()
    }

    // MARK: - Workspace Management

    func loadWorkspaces() {
        guard let data = UserDefaults.standard.data(forKey: Self.workspacesKey),
              let decoded = try? JSONDecoder().decode([Workspace].self, from: data) else {
            workspaces = []
            return
        }
        workspaces = decoded
    }

    func saveWorkspaces() {
        guard let data = try? JSONEncoder().encode(workspaces) else { return }
        UserDefaults.standard.set(data, forKey: Self.workspacesKey)
    }

    func addWorkspace(token: String) async throws -> Workspace {
        let info = try await SlackService.getWorkspaceInfo(token: token)
        let workspace = Workspace(id: info.teamId, name: info.teamName)

        // Check if workspace already exists
        if workspaces.contains(where: { $0.id == workspace.id }) {
            throw WorkspaceError.alreadyExists
        }

        // Save token to keychain
        guard KeychainService.saveToken(token, for: workspace) else {
            throw WorkspaceError.keychainError
        }

        workspaces.append(workspace)
        saveWorkspaces()
        return workspace
    }

    func removeWorkspace(_ workspace: Workspace) {
        KeychainService.deleteToken(for: workspace)
        workspaces.removeAll { $0.id == workspace.id }
        workspaceStatuses.removeValue(forKey: workspace.id)
        saveWorkspaces()
    }

    private func migrateLegacyTokenIfNeeded() {
        // Only migrate if we have no workspaces and a legacy token exists
        guard workspaces.isEmpty,
              let legacyToken = KeychainService.loadLegacyToken() else {
            return
        }

        Task { @MainActor in
            do {
                _ = try await addWorkspace(token: legacyToken)
                KeychainService.deleteLegacyToken()
            } catch {
                // Keep legacy token if migration fails
            }
        }
    }

    // MARK: - Syncing

    func startSyncing() {
        guard !isSyncing else { return }
        guard hasWorkspaces else {
            statusMessage = "No workspaces configured"
            return
        }

        isSyncing = true
        hasSetStatus = false
        shouldClearOnExit = true
        lastStatusText = nil
        workspaceStatuses = [:]
        statusMessage = "Starting..."

        pollingTask = Task { @MainActor in
            await pollLoop()
        }
    }

    func stopSyncing(clearStatus: Bool = true) {
        pollingTask?.cancel()
        pollingTask = nil
        isSyncing = false

        if clearStatus && lastStatusText != nil {
            Task {
                await clearAllWorkspaceStatuses()
            }
        }

        currentTrack = nil
        lastStatusText = nil
        hasSetStatus = false
        statusMessage = ""
    }

    func clearStatusOnQuit() {
        guard shouldClearOnExit, lastStatusText != nil, hasWorkspaces else { return }

        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await clearAllWorkspaceStatuses()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 2)
    }

    private func clearAllWorkspaceStatuses() async {
        await withTaskGroup(of: Void.self) { group in
            for workspace in workspaces {
                group.addTask {
                    guard let token = KeychainService.loadToken(for: workspace) else { return }
                    _ = try? await SlackService.clearStatus(token: token)
                }
            }
        }
    }

    @MainActor
    private func pollLoop() async {
        while !Task.isCancelled {
            if !MusicService.isMusicAppRunning() {
                if lastStatusText != nil {
                    statusMessage = "Music.app not running"
                    await clearAllWorkspaceStatuses()
                }
                stopSyncing(clearStatus: false)
                return
            }

            guard let track = MusicService.getCurrentTrack() else {
                try? await Task.sleep(for: .seconds(pollingInterval))
                continue
            }

            currentTrack = track

            let newStatus: String
            if track.state == .playing {
                newStatus = track.statusText
            } else if track.state == .paused && keepOnPause {
                newStatus = track.statusText
            } else {
                newStatus = ""
            }

            if newStatus != lastStatusText {
                await updateAllWorkspaceStatuses(newStatus: newStatus)
                lastStatusText = newStatus
            }

            try? await Task.sleep(for: .seconds(pollingInterval))
        }
    }

    private func updateAllWorkspaceStatuses(newStatus: String) async {
        if !newStatus.isEmpty {
            statusMessage = "Updating status..."
        } else if lastStatusText != nil {
            statusMessage = "Clearing status..."
        }

        await withTaskGroup(of: Void.self) { group in
            for workspace in workspaces {
                group.addTask {
                    await self.updateWorkspaceStatus(workspace, newStatus: newStatus)
                }
            }
        }

        // Update status message based on results
        let errorCount = workspaceStatuses.values.filter { !$0.isEmpty }.count
        if errorCount == 0 {
            statusMessage = ""
            if !newStatus.isEmpty {
                hasSetStatus = true
            }
        } else if errorCount == workspaces.count {
            statusMessage = "All workspaces failed"
        } else {
            statusMessage = "\(errorCount) workspace(s) had errors"
        }
    }

    @MainActor
    private func updateWorkspaceStatus(_ workspace: Workspace, newStatus: String) async {
        guard let token = KeychainService.loadToken(for: workspace) else {
            workspaceStatuses[workspace.id] = "No token"
            return
        }

        do {
            if !newStatus.isEmpty {
                _ = try await SlackService.setStatus(token: token, text: newStatus)
            } else {
                _ = try await SlackService.clearStatus(token: token)
            }
            workspaceStatuses[workspace.id] = ""
        } catch {
            workspaceStatuses[workspace.id] = error.localizedDescription
        }
    }
}

enum WorkspaceError: Error, LocalizedError {
    case alreadyExists
    case keychainError

    var errorDescription: String? {
        switch self {
        case .alreadyExists: return "Workspace already added"
        case .keychainError: return "Failed to save token"
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        if self == 0 { return range.lowerBound }
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
