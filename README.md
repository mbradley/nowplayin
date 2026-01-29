# NowPlayin

Sync your Slack status with the currently playing track in Music.app.

**macOS 14+ (Sonoma) required** for the native app. For older macOS versions, use the [Python CLI](#python-cli-alternative).

## Slack App Setup (one-time)

1. Go to https://api.slack.com/apps and click **Create New App**
2. Select **From an app manifest**
3. Choose your workspace from the dropdown, then click **Next**
4. Switch the format toggle from **JSON** to **YAML**
5. Delete the placeholder content and paste the contents of [`slack-app-manifest.yml`](slack-app-manifest.yml) from this repo
6. Click **Next**, review the summary, then click **Create**
7. On the app page, click **Install to Workspace**
8. Review the permissions and click **Allow**
9. In the left sidebar, click **OAuth & Permissions**
10. Under "OAuth Tokens for Your Workspace", copy the **User OAuth Token** (starts with `xoxp-`)

## Install

1. Download from [Releases](https://github.com/mbradley/nowplayin/releases):
   - **DMG** (recommended): Open and drag to Applications
   - **ZIP**: Unzip and drag `NowPlayin.app` to Applications
2. Launch NowPlayin — it appears in your menu bar (no dock icon)
3. Click the menu bar icon → **Preferences** → paste your token → **Save Token**
4. Click **Start Syncing**

The app is signed and notarized — no Gatekeeper warnings.

## Usage

Click the menu bar icon to:
- **Start/Stop Syncing** — toggle status updates
- **Preferences** — configure token, polling interval, and options

### Preferences

- **Polling Interval** — how often to check Music.app (5-60 seconds)
- **Keep status when paused** — don't clear status when music is paused
- **Launch at Login** — start automatically when you log in

## Behavior

- Updates Slack status to "🎵 Song - Artist" when music is playing
- Clears status when playback stops or pauses (unless "keep when paused" is enabled)
- Stops syncing if you manually change your Slack status (doesn't overwrite it)
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

# Save token
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
