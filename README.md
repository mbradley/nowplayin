# NowPlayin

Sync your Slack status with the currently playing track in Music.app.

**macOS 14+ (Sonoma) required** for the native app. For older macOS versions, use the [Python CLI](#python-cli-alternative).

## Slack App Setup (one-time)

1. Go to https://api.slack.com/apps → **Create New App** → **From an app manifest**
2. Select your workspace
3. Paste the contents of [`slack-app-manifest.yml`](slack-app-manifest.yml) from this repo
4. Click **Create** → **Install to Workspace** → **Allow**
5. Copy the **User OAuth Token** (starts with `xoxp-`)

## Install

1. Download `NowPlayin-1.0.0.zip` from [Releases](https://github.com/mbradley/nowplayin/releases)
2. Unzip and drag `NowPlayin.app` to Applications
3. Launch NowPlayin — it appears in your menu bar (no dock icon)
4. Click the menu bar icon → **Preferences** → paste your token → **Save Token**
5. Click **Start Syncing**

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
