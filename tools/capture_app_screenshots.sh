#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DERIVED="$ROOT/build/simulator"
OUT="$ROOT/MarketingAssets/Screenshots"
BUNDLE_ID="com.tokyonasu.zettaiosunayo"

pick_device() {
  python3 - "$@" <<'PY'
import json, subprocess, sys
preferred = sys.argv[1:]
raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"], text=True)
devices = []
for runtime, items in json.loads(raw).get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for item in items:
        if item.get("isAvailable"):
            devices.append(item)
for name in preferred:
    for item in devices:
        if item.get("name") == name:
            print(item["udid"])
            raise SystemExit
for item in devices:
    print(item["udid"])
    raise SystemExit
raise SystemExit("No available iOS simulator")
PY
}

boot_device() {
  local udid="$1"
  xcrun simctl shutdown all >/dev/null 2>&1 || true
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b
}

capture_set() {
  local folder="$1"
  local udid="$2"
  mkdir -p "$OUT/$folder"
  rm -f "$OUT/$folder"/*.png
  xcrun simctl install "$udid" "$APP_PATH"
  local presets=(home missions actions failed survived)
  local names=(01-home 02-missions 03-actions 04-failed 05-survived)
  for i in "${!presets[@]}"; do
    xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch "$udid" "$BUNDLE_ID" --screenshot-mode "--screenshot-preset=${presets[$i]}" >/dev/null
    sleep 2
    xcrun simctl io "$udid" screenshot "$OUT/$folder/${names[$i]}.png"
  done
}

normalize_folder() {
  local folder="$1"
  local width="$2"
  local height="$3"
  python3 - "$OUT/$folder" "$width" "$height" <<'PY'
from pathlib import Path
from PIL import Image
import sys

folder = Path(sys.argv[1])
target = (int(sys.argv[2]), int(sys.argv[3]))

def cover(im, size):
    w, h = im.size
    tw, th = size
    scale = max(tw / w, th / h)
    resized = im.resize((round(w * scale), round(h * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - tw) // 2
    top = (resized.height - th) // 2
    return resized.crop((left, top, left + tw, top + th))

for path in sorted(folder.glob("*.png")):
    im = Image.open(path).convert("RGB")
    if im.size != target:
        cover(im, target).save(path)
        print(f"normalized {path} -> {target}")
PY
}

rm -rf "$DERIVED"
xcodebuild build \
  -project ZettaiOsunaYo.xcodeproj \
  -scheme ZettaiOsunaYo \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$DERIVED"

APP_PATH="$(find "$DERIVED/Build/Products/Debug-iphonesimulator" -maxdepth 2 -name "ZettaiOsunaYo.app" -print -quit)"
if [ -z "${APP_PATH:-}" ]; then
  echo "Simulator app was not built"
  exit 1
fi

IPHONE_67="$(pick_device "iPhone 16 Pro Max" "iPhone 15 Pro Max" "iPhone 14 Pro Max")"
IPHONE_65="$(pick_device "iPhone 11 Pro Max" "iPhone XS Max" "iPhone 16 Plus" "iPhone 15 Plus")"
IPHONE_55="$(pick_device "iPhone 8 Plus" "iPhone 7 Plus" "iPhone 6s Plus")"
IPAD_129="$(pick_device "iPad Pro 13-inch (M4)" "iPad Pro (12.9-inch) (6th generation)" "iPad Air 13-inch (M3)")"

boot_device "$IPHONE_67"
capture_set "iphone_69" "$IPHONE_67"
capture_set "iphone_67" "$IPHONE_67"

boot_device "$IPHONE_65"
capture_set "iphone_65" "$IPHONE_65"

boot_device "$IPHONE_55"
capture_set "iphone_55" "$IPHONE_55"

boot_device "$IPAD_129"
capture_set "ipad_129" "$IPAD_129"

normalize_folder "iphone_65" 1242 2688
normalize_folder "iphone_55" 1242 2208
normalize_folder "ipad_129" 2048 2732

xcrun simctl shutdown all >/dev/null 2>&1 || true
