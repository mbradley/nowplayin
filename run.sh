#!/bin/bash
set -e

cd "$(dirname "$0")"

# Check for token
if [ -z "$SLACK_TOKEN" ] && [ ! -f .env ]; then
    echo "Error: SLACK_TOKEN not set and no .env file found."
    echo ""
    echo "Set up your token:"
    echo "  export SLACK_TOKEN=\"xoxp-...\""
    echo "  or"
    echo "  cp .env.example .env && edit .env"
    exit 1
fi

# Create venv if needed
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
    venv/bin/pip install -q requests
    echo "Done."
    echo ""
fi

# Run
exec venv/bin/python -u nowplayin.py "$@"
