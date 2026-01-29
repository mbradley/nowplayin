import SwiftUI

@main
struct NowPlayinApp: App {
    @State private var viewModel = NowPlayinViewModel()
    @State private var preferencesWindow: NSWindow?
    @State private var onboardingWindow: NSWindow?
    @State private var hasCheckedOnboarding = false

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel, openPreferences: openPreferencesWindow)
                .onAppear {
                    checkOnboarding()
                }
        } label: {
            Image(systemName: viewModel.isSyncing ? "music.note" : "music.note.slash")
        }
        .menuBarExtraStyle(.menu)
    }

    private func checkOnboarding() {
        guard !hasCheckedOnboarding else { return }
        hasCheckedOnboarding = true

        if !viewModel.hasCompletedOnboarding || viewModel.showOnboardingOnLaunch {
            DispatchQueue.main.async {
                openOnboardingWindow()
            }
        }
    }

    private func openOnboardingWindow() {
        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let onboardingView = OnboardingView(
            showOnLaunch: Binding(
                get: { viewModel.showOnboardingOnLaunch },
                set: { viewModel.showOnboardingOnLaunch = $0 }
            ),
            onDismiss: {
                viewModel.hasCompletedOnboarding = true
                onboardingWindow?.close()
                onboardingWindow = nil
            }
        )
        let hostingController = NSHostingController(rootView: onboardingView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to NowPlayin"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 420, height: 420))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        onboardingWindow = window
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
