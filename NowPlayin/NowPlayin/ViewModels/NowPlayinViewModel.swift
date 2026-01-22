import Foundation
import SwiftUI

@Observable
final class NowPlayinViewModel {
    var isSyncing = false
    var currentTrack: Track?
    var statusMessage = ""
    var hasToken: Bool = false

    // Settings stored in UserDefaults
    var pollingInterval: Double {
        get { UserDefaults.standard.double(forKey: "pollingInterval").clamped(to: 5...60) }
        set { UserDefaults.standard.set(newValue, forKey: "pollingInterval") }
    }

    var keepOnPause: Bool {
        get { UserDefaults.standard.bool(forKey: "keepOnPause") }
        set { UserDefaults.standard.set(newValue, forKey: "keepOnPause") }
    }

    private var pollingTask: Task<Void, Never>?
    private var lastStatusText: String?
    private var hasSetStatus = false
    private var shouldClearOnExit = true
    private var cachedToken: String?

    init() {
        if UserDefaults.standard.object(forKey: "pollingInterval") == nil {
            UserDefaults.standard.set(10.0, forKey: "pollingInterval")
        }
        refreshTokenStatus()
    }

    func refreshTokenStatus() {
        cachedToken = KeychainService.loadToken()
        hasToken = cachedToken != nil
    }

    func startSyncing() {
        guard !isSyncing else { return }

        refreshTokenStatus()
        guard let token = cachedToken else {
            statusMessage = "No token configured"
            return
        }

        isSyncing = true
        hasSetStatus = false
        shouldClearOnExit = true
        lastStatusText = nil
        statusMessage = "Starting..."

        pollingTask = Task { @MainActor in
            await pollLoop(token: token)
        }
    }

    func stopSyncing(clearStatus: Bool = true) {
        pollingTask?.cancel()
        pollingTask = nil
        isSyncing = false

        if clearStatus, let token = cachedToken, lastStatusText != nil {
            Task {
                _ = try? await SlackService.clearStatus(token: token)
            }
        }

        currentTrack = nil
        lastStatusText = nil
        hasSetStatus = false
        statusMessage = ""
    }

    func clearStatusOnQuit() {
        guard shouldClearOnExit, let token = cachedToken, lastStatusText != nil else { return }

        let semaphore = DispatchSemaphore(value: 0)
        Task {
            _ = try? await SlackService.clearStatus(token: token)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 2)
    }

    @MainActor
    private func pollLoop(token: String) async {
        while !Task.isCancelled {
            if !MusicService.isMusicAppRunning() {
                if lastStatusText != nil {
                    statusMessage = "Music.app not running"
                    _ = try? await SlackService.clearStatus(token: token)
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

            if hasSetStatus {
                if let current = try? await SlackService.getStatus(token: token) {
                    if !current.text.isEmpty && !SlackService.isOurStatus(current.emoji) {
                        statusMessage = "Status changed externally"
                        shouldClearOnExit = false
                        stopSyncing(clearStatus: false)
                        return
                    }
                }
            }

            if newStatus != lastStatusText {
                if !newStatus.isEmpty {
                    statusMessage = "Updating status..."
                    do {
                        _ = try await SlackService.setStatus(token: token, text: newStatus)
                        hasSetStatus = true
                        statusMessage = ""
                    } catch {
                        statusMessage = "Error: \(error.localizedDescription)"
                    }
                } else if lastStatusText != nil {
                    statusMessage = "Clearing status..."
                    _ = try? await SlackService.clearStatus(token: token)
                    statusMessage = ""
                }
                lastStatusText = newStatus
            }

            try? await Task.sleep(for: .seconds(pollingInterval))
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        if self == 0 { return range.lowerBound }
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
