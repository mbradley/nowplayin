#!/usr/bin/env python3
"""
NowPlayin Launcher - Standalone macOS app

Prompts for token on first run, then starts the daemon.
"""

import os
import subprocess
import sys

CONFIG_DIR = os.path.expanduser("~/.config/nowplayin")
TOKEN_FILE = os.path.join(CONFIG_DIR, "token")
PID_FILE = os.path.join(CONFIG_DIR, "pid")


def osascript(script):
    """Run AppleScript and return output."""
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True,
        text=True
    )
    return result.stdout.strip(), result.returncode


def notify(message, title="NowPlayin"):
    """Show macOS notification."""
    osascript(f'display notification "{message}" with title "{title}"')


def alert(message, title="NowPlayin", info=""):
    """Show alert dialog."""
    script = f'display alert "{title}" message "{message}"'
    if info:
        script += f' & "\n\n{info}"'
    script += " as critical"
    osascript(script)


def prompt_for_token():
    """Prompt user for Slack token."""
    script = '''
    display dialog "Enter your Slack token (starts with xoxp-):" default answer "" with title "NowPlayin Setup" with icon note
    '''
    result = subprocess.run(
        ["osascript", "-e", script, "-e", "text returned of result"],
        capture_output=True,
        text=True
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def is_running():
    """Check if daemon is already running."""
    if not os.path.exists(PID_FILE):
        return False, None
    try:
        with open(PID_FILE) as f:
            pid = int(f.read().strip())
        os.kill(pid, 0)
        return True, pid
    except (ValueError, IOError, OSError):
        return False, None


def get_token():
    """Get token from file."""
    if os.path.exists(TOKEN_FILE):
        with open(TOKEN_FILE) as f:
            return f.read().strip()
    return None


def save_token(token):
    """Save token to file."""
    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(TOKEN_FILE, "w") as f:
        f.write(token)
    os.chmod(TOKEN_FILE, 0o600)


def main():
    # Check if already running
    running, pid = is_running()
    if running:
        notify(f"Already running (pid {pid})")
        return

    # Get or prompt for token
    token = get_token()
    if not token:
        token = prompt_for_token()
        if not token:
            return  # User cancelled

        if not token.startswith("xoxp-"):
            alert("Invalid token", info="Token should start with xoxp-")
            return

        save_token(token)

    # Import and run the daemon
    # We import here to avoid loading everything if we're just checking status
    import nowplayin

    # Inject the token
    os.environ["SLACK_TOKEN"] = token

    # Check Music.app first
    if not nowplayin.is_music_app_running():
        alert("Music.app not running", info="Start Music.app and try again.")
        return

    # Daemonize and run
    notify("Syncing Music.app to Slack status")

    sys.argv = ["nowplayin", "--daemon"]
    nowplayin.main()


if __name__ == "__main__":
    main()
