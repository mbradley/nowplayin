import SwiftUI

struct MenuBarView: View {
    @Bindable var viewModel: NowPlayinViewModel
    var openPreferences: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Current track display
            if let track = viewModel.currentTrack, viewModel.isSyncing {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(.headline)
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack {
                        Image(systemName: track.state == .playing ? "play.fill" : "pause.fill")
                            .font(.caption)
                        Text(track.state == .playing ? "Playing" : "Paused")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()
            }

            // Status message
            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }

            // Start/Stop button
            Button {
                if viewModel.isSyncing {
                    viewModel.stopSyncing()
                } else {
                    viewModel.startSyncing()
                }
            } label: {
                Label(
                    viewModel.isSyncing ? "Stop Syncing" : "Start Syncing",
                    systemImage: viewModel.isSyncing ? "stop.fill" : "play.fill"
                )
            }
            .disabled(!viewModel.hasToken && !viewModel.isSyncing)

            Divider()

            // Preferences
            Button {
                openPreferences()
            } label: {
                Label("Preferences...", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            // Quit
            Button {
                viewModel.clearStatusOnQuit()
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit NowPlayin", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

#Preview("Syncing") {
    MenuBarView(viewModel: {
        let vm = NowPlayinViewModel()
        vm.isSyncing = true
        vm.currentTrack = Track(name: "Bohemian Rhapsody", artist: "Queen", state: .playing)
        return vm
    }(), openPreferences: {})
}

#Preview("Idle") {
    MenuBarView(viewModel: NowPlayinViewModel(), openPreferences: {})
}
