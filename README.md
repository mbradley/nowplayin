# NowPlayin

Sync your Slack status with the currently playing track in Music.app.

**macOS 14+ (Sonoma) required** for the native app. For older macOS versions, use the [Python CLI](#python-cli-alternative).

## Get Your Slack Token

1. Visit https://slack.nowplayin.workers.dev
2. Click **Add to Slack**
3. Authorize for your workspace (see [Slack Permissions](PRIVACY.md#slack-permissions) for what we do and don't access)
4. Copy the token displayed (starts with `xoxp-`)

**Multiple workspaces?** Repeat these steps for each Slack workspace you want to sync.

## Install

1. Download from [Releases](https://github.com/mbradley/nowplayin/releases):
   - **DMG** (recommended): Open and drag to Applications
   - **ZIP**: Unzip and drag `NowPlayin.app` to Applications
2. Launch NowPlayin — it appears in your menu bar (no dock icon)
3. Click the menu bar icon → **Preferences** → **Workspaces** → **Add Workspace**
4. Paste your token and click **Add**
5. Click **Start Syncing**

The app is signed and notarized — no Gatekeeper warnings.

**Keychain access:** The app requests keychain access to securely store your Slack tokens. Tokens never leave your Mac except to communicate with Slack. See [PRIVACY.md](PRIVACY.md) for details.

## Usage

Click the menu bar icon to:
- **Start/Stop Syncing** — toggle status updates
- **Preferences** — configure token, polling interval, and options

### Preferences

- **Workspaces** — add, remove, and manage your Slack workspaces
- **Polling Interval** — how often to check Music.app (5-60 seconds)
- **Keep status when paused** — don't clear status when music is paused
- **Launch at Login** — start automatically when you log in

## Behavior

- Updates Slack status to "🎵 Song - Artist" across all configured workspaces
- Clears status when playback stops or pauses (unless "keep when paused" is enabled)
- Clears status when you quit the app

## Building from Source

Requires Xcode 15+ and macOS 14+.

```bash
git clone https://github.com/mbradley/nowplayin.git
cd nowplayin/NowPlayin
open NowPlayin.xcodeproj
# Set your Team in Signing & Capabilities, then Build & Run
```

For distribution builds:
```bash
# Set signing team in Xcode first, then:
export APPLE_ID="your@email.com"
export TEAM_ID="XXXXXXXXXX"
export APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
./scripts/build-release.sh
```

## Python CLI (alternative)

For older macOS versions or terminal-based usage:

```bash
# Install
pipx install git+https://github.com/mbradley/nowplayin.git

# Save token (get yours at https://slack.nowplayin.workers.dev)
nowplayin --token xoxp-your-token

# Run
nowplayin              # foreground
nowplayin --daemon     # background
nowplayin --stop       # stop daemon
nowplayin --status     # check if running

# Options
nowplayin --interval 30      # poll every 30s
nowplayin --keep-on-pause    # keep status when paused
```
