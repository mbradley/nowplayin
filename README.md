# nowplayin

Sync your Slack status with the currently playing track in Music.app (macOS only).

## Slack App Setup (one-time)

1. Go to https://api.slack.com/apps → **Create New App** → **From an app manifest**
2. Select your workspace
3. Paste the contents of [`slack-app-manifest.yml`](slack-app-manifest.yml) from this repo
4. Click **Create** → **Install to Workspace** → **Allow**
5. Copy the **User OAuth Token** (starts with `xoxp-`)

## Install

### Option A: Quick start (local clone)

```bash
git clone https://github.com/mbradley/nowplayin.git
cd nowplayin
./run.sh --token xoxp-your-token
./run.sh
```

### Option B: Install as CLI tool

```bash
pipx install git+https://github.com/mbradley/nowplayin.git
nowplayin --token xoxp-your-token
nowplayin
```

## Usage

### Mac App

After installing via pipx, double-click `NowPlayin.app` (in this repo or download it). On first launch it prompts for your token, then runs in the background.

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

# Poll every 30 seconds instead of 10
nowplayin --interval 30

# Keep status visible when paused (default: clears on pause)
nowplayin --keep-on-pause
```

## Token Setup

Save it once (stored in `~/.config/nowplayin/token`):

```bash
nowplayin --token xoxp-your-token
```

Or set an environment variable:

```bash
export SLACK_TOKEN="xoxp-your-token"
```

## Behavior

- Updates Slack status to "🎵 Song - Artist" when music is playing
- Clears status when playback stops or pauses (unless `--keep-on-pause`)
- Exits cleanly if you manually change your Slack status
- Clears status on Ctrl+C or when Music.app quits
