# Privacy Policy

**Last updated:** January 29, 2026

NowPlayin is designed with privacy in mind. We do not collect, store, or transmit any of your personal data.

## What the App Does

NowPlayin reads the currently playing track from Apple Music and updates your Slack status. That's it.

## Data Storage

All data is stored locally on your Mac:

- **Slack token** — Stored securely in the macOS Keychain
- **Preferences** — Stored in UserDefaults (standard macOS app preferences)

No data is stored on external servers controlled by the developer.

## Slack Permissions

When you authorize NowPlayin, Slack shows these permissions:

| Slack says | What we actually do |
|------------|---------------------|
| "View profile details about people in your workspace" | **We don't.** This permission comes from the `users.profile:read` scope, but we only read *your own* status to detect manual changes. We never access other users' profiles. |
| "View information about your identity" | We use this only to verify your token works. |
| "Edit your profile information and status" | **Yes, this is something we do.** We update your status with the currently playing track. We don't modify any other profile information. |

### Why these permissions?

Slack's `users.profile:read` and `users.profile:write` scopes are broad by design. We request the minimum scopes needed to:
1. Read your current status (to avoid overwriting manual changes)
2. Write your status (to show what's playing)

We cannot request narrower permissions — Slack doesn't offer status-only scopes.

## Network Communication

The app communicates only with:

- **Slack API** (`slack.com`) — To read and update your Slack status

The app does not communicate with any other servers. There is no telemetry, analytics, crash reporting, or usage tracking of any kind.

## Data We Collect

None. We do not collect any data.

## Third-Party Services

Your Slack token and status updates are subject to [Slack's Privacy Policy](https://slack.com/privacy-policy).

## Contact

If you have questions about this privacy policy, please open an issue on the [GitHub repository](https://github.com/mbradley/nowplayin).
