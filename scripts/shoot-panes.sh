#!/bin/zsh
# Screenshot every pane of the built app into build/shots/ (layout debugging).
cd "${0:A:h}/.."
mkdir -p build.noindex/shots
APP="build.noindex/AK820 Pro.app/Contents/MacOS/AK820 Pro"
for p in lighting colours screen mapping macros settings; do
    "$APP" --pane $p &
    PID=$!
    sleep 2.5
    WID=$(swift -e "import CoreGraphics; let l = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as! [[String: Any]]; for w in l where (w[\"kCGWindowOwnerPID\"] as? Int) == $PID && (w[\"kCGWindowLayer\"] as? Int) == 0 { print(w[\"kCGWindowNumber\"]!); break }" 2>/dev/null)
    [[ -n "$WID" ]] && screencapture -x -o -l$WID build.noindex/shots/$p.png
    kill $PID
    wait $PID 2>/dev/null
done
ls build.noindex/shots
