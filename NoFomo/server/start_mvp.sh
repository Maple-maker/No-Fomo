#!/usr/bin/env bash
# NoFomo Radar MVP — startup script
# Starts the Python radar server on port 3001
# Requires: BRAVE_API_KEY in .env

cd "$(dirname "$0")"
echo "Starting NoFomo Radar MVP..."
echo "Brave key: $(grep BRAVE_API_KEY .env | head -1 | cut -c1-10)..."
python3 radar_mvp.py