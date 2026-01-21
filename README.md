# nowplayin

Sync your Slack status with the currently playing track in Music.app.

## Slack App Setup (one-time)

1. Create a Slack App at https://api.slack.com/apps
   - Click "Create New App" → "From scratch"
   - Name it "Now Playing" and select your workspace

2. Add the OAuth scope:
   - Go to "OAuth & Permissions" in the sidebar
   - Under "User Token Scopes", add `users.profile:write`

3. Install to your workspace:
   - Click "Install to Workspace" and authorize

4. Copy the **User OAuth Token** (starts with `xoxp-`)

## Install

### Option A: Quick start (local clone)

```bash
git clone https://github.com/mbradley/nowplayin.git
cd nowplayin
export SLACK_TOKEN="xoxp-your-token"
./run.sh
```

### Option B: Install as CLI tool

```bash
pipx install git+https://github.com/mbradley/nowplayin.git
nowplayin --token xoxp-your-token
nowplayin
```

## Usage

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
