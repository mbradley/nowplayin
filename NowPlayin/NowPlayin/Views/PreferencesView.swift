import SwiftUI

struct PreferencesView: View {
    @Bindable var viewModel: NowPlayinViewModel

    @State private var isAddingWorkspace = false
    @State private var tokenInput = ""
    @State private var addWorkspaceMessage = ""
    @State private var isAddingToken = false
    @State private var launchAtLogin = false

    private let oauthURL = URL(string: "https://api.slack.com/apps")!

    var body: some View {
        Form {
            Section("Slack Workspaces") {
                if viewModel.workspaces.isEmpty {
                    Text("No workspaces configured")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(viewModel.workspaces) { workspace in
                        WorkspaceRow(
                            workspace: workspace,
                            errorMessage: viewModel.workspaceStatuses[workspace.id],
                            onRemove: {
                                viewModel.removeWorkspace(workspace)
                            }
                        )
                    }
                }

                if isAddingWorkspace {
                    VStack(alignment: .leading, spacing: 8) {
                        SecureField("Paste token (xoxp-...)", text: $tokenInput)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button("Add") {
                                addWorkspace()
                            }
                            .disabled(tokenInput.isEmpty || isAddingToken)

                            Button("Cancel") {
                                isAddingWorkspace = false
                                tokenInput = ""
                                addWorkspaceMessage = ""
                            }

                            if isAddingToken {
                                ProgressView()
                                    .scaleEffect(0.5)
                            }

                            if !addWorkspaceMessage.isEmpty {
                                Text(addWorkspaceMessage)
                                    .font(.caption)
                                    .foregroundStyle(addWorkspaceMessage.contains("Added") ? .green : .red)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    Button("Add Workspace...") {
                        isAddingWorkspace = true
                    }
                }

                Link("Get token from Slack", destination: oauthURL)
                    .font(.caption)
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

    private func addWorkspace() {
        guard !tokenInput.isEmpty else { return }
        isAddingToken = true
        addWorkspaceMessage = ""

        Task { @MainActor in
            do {
                let workspace = try await viewModel.addWorkspace(token: tokenInput)
                addWorkspaceMessage = "Added \(workspace.name)"
                tokenInput = ""
                isAddingWorkspace = false
            } catch {
                addWorkspaceMessage = error.localizedDescription
            }
            isAddingToken = false
        }
    }
}

struct WorkspaceRow: View {
    let workspace: Workspace
    let errorMessage: String?
    let onRemove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.name)
                    .font(.body)
                Text(workspace.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let error = errorMessage, !error.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(error)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            Button(role: .destructive) {
                onRemove()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }
}

#Preview {
    PreferencesView(viewModel: NowPlayinViewModel())
}
