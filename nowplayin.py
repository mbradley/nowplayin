#!/usr/bin/env python3
"""
Now Playing → Slack Status Tool

Monitors Music.app and keeps your Slack status in sync with the currently playing track.
"""

import argparse
import os
import signal
import subprocess
import sys
import time

import requests

# Status emoji
STATUS_EMOJI = ":musical_note:"


CONFIG_DIR = os.path.expanduser("~/.config/nowplayin")
PID_FILE = os.path.join(CONFIG_DIR, "pid")


def get_slack_token():
    """Get Slack token from config file, environment, or .env file."""
    # 1. Check ~/.config/nowplayin/token
    token_path = os.path.join(CONFIG_DIR, "token")
    if os.path.exists(token_path):
        with open(token_path) as f:
            token = f.read().strip()
            if token:
                return token

    # 2. Check environment variable
    token = os.environ.get("SLACK_TOKEN")
    if token:
        return token

    # 3. Try loading from .env file in script directory
    env_path = os.path.join(os.path.dirname(__file__), ".env")
    if os.path.exists(env_path):
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line.startswith("SLACK_TOKEN="):
                    return line.split("=", 1)[1].strip().strip('"').strip("'")

    return None


def save_token(token):
    """Save token to config file."""
    os.makedirs(CONFIG_DIR, exist_ok=True)
    token_path = os.path.join(CONFIG_DIR, "token")
    with open(token_path, "w") as f:
        f.write(token)
    os.chmod(token_path, 0o600)
    print(f"Token saved to {token_path}")


def daemonize():
    """Fork into background."""
    if os.fork() > 0:
        sys.exit(0)
    os.setsid()
    if os.fork() > 0:
        sys.exit(0)
    sys.stdout.flush()
    sys.stderr.flush()
    with open("/dev/null", "r") as devnull:
        os.dup2(devnull.fileno(), sys.stdin.fileno())
    with open("/dev/null", "w") as devnull:
        os.dup2(devnull.fileno(), sys.stdout.fileno())
        os.dup2(devnull.fileno(), sys.stderr.fileno())


def write_pid():
    """Write PID file."""
    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))


def read_pid():
    """Read PID from file, return None if not exists or invalid."""
    if not os.path.exists(PID_FILE):
        return None
    try:
        with open(PID_FILE) as f:
            return int(f.read().strip())
    except (ValueError, IOError):
        return None


def is_running():
    """Check if daemon is already running."""
    pid = read_pid()
    if pid is None:
        return False
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def stop_daemon():
    """Stop the running daemon."""
    pid = read_pid()
    if pid is None:
        print("Not running.")
        return False
    try:
        os.kill(pid, signal.SIGTERM)
        print(f"Stopped (pid {pid})")
        os.remove(PID_FILE)
        return True
    except OSError:
        print("Not running.")
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
        return False


def is_music_app_running():
    """Check if Music.app is running."""
    script = '''
    tell application "System Events"
        return (name of processes) contains "Music"
    end tell
    '''
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True,
        text=True
    )
    return result.stdout.strip() == "true"


def get_current_track():
    """
    Get current track info from Music.app.

    Returns:
        dict with 'name', 'artist', 'state' keys, or None if Music.app not available
        state is 'playing', 'paused', or 'stopped'
    """
    script = '''
    tell application "Music"
        if player state is playing then
            set trackName to name of current track
            set trackArtist to artist of current track
            return "playing|" & trackName & "|" & trackArtist
        else if player state is paused then
            set trackName to name of current track
            set trackArtist to artist of current track
            return "paused|" & trackName & "|" & trackArtist
        else
            return "stopped||"
        end if
    end tell
    '''
    try:
        result = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode != 0:
            return None

        output = result.stdout.strip()
        parts = output.split("|", 2)
        if len(parts) == 3:
            return {
                "state": parts[0],
                "name": parts[1],
                "artist": parts[2]
            }
    except (subprocess.TimeoutExpired, Exception):
        pass

    return None


def format_status_text(track_info):
    """Format track info as status text."""
    if not track_info or not track_info.get("name"):
        return ""
    return f"{track_info['name']} - {track_info['artist']}"


def get_slack_status(token):
    """
    Get current Slack status.

    Returns:
        dict with 'status_text' and 'status_emoji', or None on error
    """
    response = requests.post(
        "https://slack.com/api/users.profile.get",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    data = response.json()
    if data.get("ok"):
        profile = data.get("profile", {})
        return {
            "status_text": profile.get("status_text", ""),
            "status_emoji": profile.get("status_emoji", "")
        }
    return None


def set_slack_status(token, text, emoji=STATUS_EMOJI):
    """Set Slack status."""
    response = requests.post(
        "https://slack.com/api/users.profile.set",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        },
        json={
            "profile": {
                "status_text": text,
                "status_emoji": emoji if text else ""
            }
        },
        timeout=10
    )
    data = response.json()
    if not data.get("ok"):
        error = data.get("error", "unknown error")
        print(f"Failed to set Slack status: {error}", file=sys.stderr)
        return False
    return True


def clear_slack_status(token):
    """Clear Slack status."""
    return set_slack_status(token, "", "")


def is_our_status(status_emoji):
    """Check if the current status was set by us."""
    return status_emoji == STATUS_EMOJI


def main():
    parser = argparse.ArgumentParser(
        description="Sync your Slack status with Music.app"
    )
    parser.add_argument(
        "--interval",
        type=int,
        default=10,
        help="Polling interval in seconds (default: 10)"
    )
    parser.add_argument(
        "--keep-on-pause",
        action="store_true",
        help="Keep showing track when paused (default: clear on pause)"
    )
    parser.add_argument(
        "--daemon", "-d",
        action="store_true",
        help="Run in background"
    )
    parser.add_argument(
        "--stop",
        action="store_true",
        help="Stop the background daemon"
    )
    parser.add_argument(
        "--token",
        type=str,
        help="Save Slack token to ~/.config/nowplayin/token"
    )
    parser.add_argument(
        "--status",
        action="store_true",
        help="Check if daemon is running"
    )
    args = parser.parse_args()

    # Handle --token
    if args.token:
        save_token(args.token)
        return

    # Handle --status
    if args.status:
        if is_running():
            print(f"Running (pid {read_pid()})")
        else:
            print("Not running.")
        return

    # Handle --stop
    if args.stop:
        stop_daemon()
        return

    # Check for already running daemon
    if args.daemon and is_running():
        print(f"Already running (pid {read_pid()})")
        sys.exit(1)

    token = get_slack_token()
    if not token:
        print("Error: SLACK_TOKEN not found.", file=sys.stderr)
        print("Run: nowplayin --token xoxp-...", file=sys.stderr)
        print("Or set SLACK_TOKEN environment variable.", file=sys.stderr)
        sys.exit(1)

    # Daemonize if requested
    if args.daemon:
        print(f"Starting daemon...")
        daemonize()
        write_pid()

    # Track state
    last_status_text = None
    has_set_status = False  # True once we've set at least one status
    should_clear_on_exit = True

    def handle_exit(signum=None, frame=None):
        nonlocal should_clear_on_exit
        print("\nExiting...")
        if should_clear_on_exit and last_status_text:
            print("Clearing Slack status...")
            clear_slack_status(token)
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_exit)
    signal.signal(signal.SIGTERM, handle_exit)

    print("Now Playing → Slack Status")
    print(f"Polling every {args.interval} seconds. Press Ctrl+C to stop.")
    print()

    while True:
        # Check if Music.app is running
        if not is_music_app_running():
            if last_status_text:
                print("Music.app not running. Clearing status and exiting.")
                clear_slack_status(token)
            else:
                print("Music.app not running. Exiting.")
            sys.exit(0)

        # Get current track
        track = get_current_track()

        if track is None:
            # Error getting track info, skip this iteration
            time.sleep(args.interval)
            continue

        # Determine what status should be
        if track["state"] == "playing":
            new_status = format_status_text(track)
        elif track["state"] == "paused" and args.keep_on_pause:
            new_status = format_status_text(track)
        else:
            new_status = ""

        # Check if user manually changed status (only after we've set at least one)
        current = get_slack_status(token)
        if current and has_set_status:
            current_text = current.get("status_text", "")
            current_emoji = current.get("status_emoji", "")
            # If there's a status with a different emoji, user set it manually
            if current_text and not is_our_status(current_emoji):
                print(f"Status changed externally to: {current_text}")
                print("Exiting without clearing status.")
                should_clear_on_exit = False
                sys.exit(0)

        # Update status if changed
        if new_status != last_status_text:
            if new_status:
                print(f"♫ {track['name']} - {track['artist']}")
                set_slack_status(token, new_status)
                has_set_status = True
            else:
                if last_status_text:
                    print("Playback stopped/paused. Clearing status.")
                    clear_slack_status(token)
            last_status_text = new_status

        time.sleep(args.interval)


if __name__ == "__main__":
    main()
