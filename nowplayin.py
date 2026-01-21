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


def get_slack_token():
    """Get Slack token from environment or .env file."""
    token = os.environ.get("SLACK_TOKEN")
    if token:
        return token

    # Try loading from .env file
    env_path = os.path.join(os.path.dirname(__file__), ".env")
    if os.path.exists(env_path):
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line.startswith("SLACK_TOKEN="):
                    return line.split("=", 1)[1].strip().strip('"').strip("'")

    return None


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
    args = parser.parse_args()

    token = get_slack_token()
    if not token:
        print("Error: SLACK_TOKEN not found.", file=sys.stderr)
        print("Set it as an environment variable or in a .env file.", file=sys.stderr)
        sys.exit(1)

    # Track state
    last_status_text = None
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

        # Check if user manually changed status
        current = get_slack_status(token)
        if current:
            current_text = current.get("status_text", "")
            current_emoji = current.get("status_emoji", "")
            # If we previously set a status and it's now different (and not empty)
            # and it doesn't match our emoji, user changed it
            if last_status_text and current_text and not is_our_status(current_emoji):
                print(f"Status changed externally to: {current_text}")
                print("Exiting without clearing status.")
                should_clear_on_exit = False
                sys.exit(0)

        # Update status if changed
        if new_status != last_status_text:
            if new_status:
                print(f"♫ {track['name']} - {track['artist']}")
                set_slack_status(token, new_status)
            else:
                if last_status_text:
                    print("Playback stopped/paused. Clearing status.")
                    clear_slack_status(token)
            last_status_text = new_status

        time.sleep(args.interval)


if __name__ == "__main__":
    main()
