# nowplayin

Sync your Slack status with the currently playing track in Music.app (macOS only).

## Slack App Setup (one-time)

1. Go to https://api.slack.com/apps → **Create New App** → **From an app manifest**
2. Select your workspace
3. Paste the contents of [`slack-app-manifest.yml`](slack-app-manifest.yml) from this repo
4. Click **Create** → **Install to Workspace** → **Allow**
5. Copy the **User OAuth Token** (starts with `xoxp-`)

## Install

### Option A: Standalone App (easiest)

1. Download `NowPlayin.app` from [Releases](https://github.com/mbradley/nowplayin/releases)
2. Unzip and move to Applications folder
3. Double-click to run
4. Paste your token when prompted

The app is signed and notarized by Apple — no Gatekeeper warnings.

### Option B: CLI + App (for terminal users)

```bash
# Install the CLI
pipx install git+https://github.com/mbradley/nowplayin.git

# Clone repo for the app wrapper
git clone https://github.com/mbradley/nowplayin.git
```

Then either:
- Double-click `NowPlayin.app` from the cloned repo, or
- Run `nowplayin --daemon` from terminal

### Option C: Build Standalone App Yourself

```bash
git clone https://github.com/mbradley/nowplayin.git
cd nowplayin
python3 -m venv venv
source venv/bin/activate
pip install requests pyinstaller
pyinstaller --name "NowPlayin" --windowed --onedir --noconfirm \
  --add-data "nowplayin.py:." --hidden-import requests launcher.py
# App is in dist/NowPlayin.app
```

## Usage

### Mac App

Double-click `NowPlayin.app`. On first launch it prompts for your token, saves it, and starts syncing. Shows a notification when running.

To stop: `nowplayin --stop` (CLI) or Activity Monitor → quit "NowPlayin"

### CLI

```bash
# Save your token (one-time)
nowplayin --token xoxp-your-token

# Run in foreground
nowplayin

# Run as background daemon
nowplayin --daemon

# Check if running
nowplayin --status

# Stop the daemon
nowplayin --stop

# Options
nowplayin --interval 30      # Poll every 30s instead of 10
nowplayin --keep-on-pause    # Keep status when paused
```

## Behavior

- Updates Slack status to "🎵 Song - Artist" when music is playing
- Clears status when playback stops or pauses (unless `--keep-on-pause`)
- Exits cleanly if you manually change your Slack status
- Clears status on Ctrl+C or when Music.app quits
