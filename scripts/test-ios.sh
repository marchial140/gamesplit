#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodebuild >/dev/null || ! command -v xcrun >/dev/null; then
    echo 'Vérification iOS impossible : macOS, Xcode et un simulateur iOS 17+ sont requis.' >&2
    exit 69
fi
simulator_id="${GAMESPLIT_SIMULATOR_ID:-}"
if [ -z "$simulator_id" ]; then
    simulator_id="$(xcrun simctl list devices available -j | python3 -c '
import json,sys,re
for runtime, devices in json.load(sys.stdin)["devices"].items():
    version=re.search(r"iOS-(\d+)",runtime)
    if version and int(version[1]) >= 17:
        for device in devices:
            if device.get("isAvailable") and "iPhone" in device["name"]:
                print(device["udid"]); sys.exit(0)
sys.exit("Aucun simulateur iPhone iOS 17+ disponible.")')"
fi
xcodebuild -project GameSplit.xcodeproj -scheme GameSplit \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -derivedDataPath .build/Xcode CODE_SIGNING_ALLOWED=NO build test
