import SwiftUI

struct OnboardingView: View {
    @Binding var showOnLaunch: Bool
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Welcome to NowPlayin")
                .font(.title)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 16) {
                InfoRow(
                    icon: "menubar.rectangle",
                    title: "Menu Bar App",
                    description: "NowPlayin lives in your menu bar. Look for the music note icon at the top of your screen."
                )

                InfoRow(
                    icon: "key.fill",
                    title: "Slack Token Required",
                    description: "You'll need to configure a Slack user token (xoxp-...) in Preferences before syncing can start."
                )

                InfoRow(
                    icon: "book.fill",
                    title: "Setup Instructions",
                    description: "See the README for step-by-step instructions on creating your Slack token."
                )

                Link(destination: URL(string: "https://github.com/mbradley/nowplayin#readme")!) {
                    Label("Open README on GitHub", systemImage: "arrow.up.right.square")
                }
                .padding(.leading, 36)
            }
            .padding(.horizontal)

            Spacer()

            Toggle("Show this window on every launch", isOn: $showOnLaunch)
                .toggleStyle(.checkbox)

            Button("Get Started") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(30)
        .frame(width: 480, height: 500)
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    OnboardingView(showOnLaunch: .constant(true), onDismiss: {})
}
