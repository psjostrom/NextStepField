#!/bin/bash
set -euo pipefail

SDK="/Users/persjo/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc"
KEY="$HOME/Library/Application Support/Garmin/ConnectIQ/developer_key.der"
DEVICE="fr970"

mkdir -p build

echo "=== Building NextStepField ==="
"$SDK/bin/monkeyc" \
    -f monkey.jungle \
    -o build/NextStepField.prg \
    -d "$DEVICE" \
    -y "$KEY" \
    -w
echo "    -> build/NextStepField.prg"

echo ""
ls -lh build/NextStepField.prg
