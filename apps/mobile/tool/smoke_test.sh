#!/usr/bin/env bash
# Opens the app on an Android emulator and checks it keeps running (big update 2: no broken app on /download again).
# Usage: tool/smoke_test.sh <apk> <out-dir>. Exit code 1 = the app crashed or closed; the crash log is printed.
set -uo pipefail
APK="$1"; OUT="$2"; PKG=com.solutiontee.cbt
mkdir -p "$OUT"
adb wait-for-device
adb install -r "$APK" || { echo "::error::Could not install the APK"; exit 1; }
adb logcat -c; adb logcat -b crash -c || true
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
ok=1
for t in 5 10 15 20 25 30 35 40; do
  sleep 5
  if ! adb shell pidof "$PKG" >/dev/null; then ok=0; echo "App not running after ${t}s"; break; fi
done
adb exec-out screencap -p > "$OUT/screen.png" || true
adb logcat -d > "$OUT/logcat.txt" || true
adb logcat -d -b crash > "$OUT/crash.txt" || true
# Only crashes of our app count (the emulator's own apps, e.g. Gmail, sometimes crash on their own).
ours=0; grep -q "Process: $PKG" "$OUT/crash.txt" && ours=1
if [ "$ours" = 1 ] || [ "$ok" = 0 ]; then
  echo "::error::The app crashed or closed on the emulator"
  echo "----- crash buffer -----"; cat "$OUT/crash.txt"
  echo "----- AndroidRuntime / FATAL -----"; grep -E "AndroidRuntime|FATAL|DEBUG  |Process: $PKG" "$OUT/logcat.txt" | tail -150
  exit 1
fi
echo "The app opened and kept running for 40 seconds."
