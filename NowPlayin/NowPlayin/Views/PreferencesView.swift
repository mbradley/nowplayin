import SwiftUI

struct PreferencesView: View {
    @Bindable var viewModel: NowPlayinViewModel

    @State private var tokenInput = ""
    @State private var tokenSaveMessage = ""
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section("Slack Token") {
                SecureField("Token (xoxp-...)", text: $tokenInput)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save Token") {
                        saveToken()
                    }
                    .disabled(tokenInput.isEmpty)

                    if viewModel.hasToken {
                        Button("Delete Token", role: .destructive) {
                            deleteToken()
                        }
                    }

                    Spacer()

                    if !tokenSaveMessage.isEmpty {
                        Text(tokenSaveMessage)
                            .font(.caption)
                            .foregroundStyle(tokenSaveMessage.contains("saved") ? .green : .red)
                    }
                }

                if viewModel.hasToken {
                    Label("Token configured", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Label("No token configured", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }

            Section("Sync Settings") {
                HStack {
                    Text("Polling Interval")
                    Slider(value: $viewModel.pollingInterval, in: 5...60, step: 5) {
                        Text("Polling Interval")
                    }
                    Text("\(Int(viewModel.pollingInterval))s")
                        .monospacedDigit()
                        .frame(width: 30, alignment: .trailing)
                }

                Toggle("Keep status when paused", isOn: $viewModel.keepOnPause)
            }

            Section("System") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            try LaunchAtLoginService.setEnabled(newValue)
                        } catch {
                            launchAtLogin = !newValue
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 420)
        .onAppear {
            launchAtLogin = LaunchAtLoginService.isEnabled
        }
    }

    private func saveToken() {
        guard !tokenInput.isEmpty else { return }
        if KeychainService.saveToken(tokenInput) {
            tokenSaveMessage = "Token saved in Keychain"
            tokenInput = ""
            viewModel.refreshTokenStatus()
        } else {
            tokenSaveMessage = "Failed to save token"
        }
    }

    private func deleteToken() {
        KeychainService.deleteToken()
        tokenSaveMessage = "Token deleted"
        viewModel.refreshTokenStatus()
    }
}
