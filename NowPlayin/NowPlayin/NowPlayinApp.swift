import SwiftUI

@main
struct NowPlayinApp: App {
    @State private var viewModel = NowPlayinViewModel()
    @State private var preferencesWindow: NSWindow?

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel, openPreferences: openPreferencesWindow)
        } label: {
            Image(systemName: viewModel.isSyncing ? "music.note" : "music.note.slash")
        }
        .menuBarExtraStyle(.menu)
    }

    private func openPreferencesWindow() {
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let preferencesView = PreferencesView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: preferencesView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "NowPlayin Preferences"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 400, height: 420))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        preferencesWindow = window
    }
}
