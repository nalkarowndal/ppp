#!/usr/bin/env bash
# M1 emulator startup verification. Does NOT prove real-device touch UX.
set -euo pipefail

PKG="org.astralchronicle.prototype"
APK="builds/astral-chronicle-m1-emulator-x86_64.apk"
OUT="qa_artifacts/emulator"
mkdir -p "$OUT"
test -s "$APK"

echo "EMULATOR TEST: device properties"
adb wait-for-device
adb shell getprop ro.product.cpu.abi | tee "$OUT/abi.txt"
adb shell wm size | tee "$OUT/resolution.txt"
adb shell getprop sys.boot_completed | tee "$OUT/boot_completed.txt"
adb shell settings put system accelerometer_rotation 0 || true
adb shell settings put system user_rotation 0 || true

echo "EMULATOR TEST: install APK"
adb install -r -t "$APK" | tee "$OUT/install.txt"
adb shell pm path "$PKG" | tee "$OUT/package_path.txt"
grep -Fq "package:" "$OUT/package_path.txt"

# Separate app logcat from emulator boot diagnostics.
adb logcat -c
echo "EMULATOR TEST: cold launch"
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 | tee "$OUT/launch.txt"
sleep 12
adb shell pidof "$PKG" | tee "$OUT/first_pid.txt"
test -s "$OUT/first_pid.txt"
adb exec-out screencap -p > "$OUT/first_launch.png"

echo "EMULATOR TEST: force-stop and new process"
adb shell am force-stop "$PKG"
sleep 2
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 | tee "$OUT/restart.txt"
sleep 9
adb shell pidof "$PKG" | tee "$OUT/restart_pid.txt"
test -s "$OUT/restart_pid.txt"
adb exec-out screencap -p > "$OUT/restart_launch.png"

# Minimal PNG structure validation with Python standard library.
python3 - "$OUT/first_launch.png" "$OUT/restart_launch.png" <<'PY'
from pathlib import Path
import struct, sys
for name in sys.argv[1:]:
    data = Path(name).read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or len(data) < 10000:
        raise SystemExit(f"INVALID EMULATOR SCREENSHOT: {name} ({len(data)} bytes)")
    w, h = struct.unpack(">II", data[16:24])
    if min(w, h) < 300 or max(w, h) < 600:
        raise SystemExit(f"IMPLAUSIBLE EMULATOR SIZE: {name}: {w}x{h}")
    print("EMULATOR SCREENSHOT PASS:", name, w, h)
PY

adb logcat -d -v time -s AndroidRuntime:E libc:F Godot:E > "$OUT/critical_logcat.txt" || true
if grep -E "FATAL EXCEPTION|Fatal signal|SIGSEGV|SIGABRT" "$OUT/critical_logcat.txt"; then
  echo "ANDROID EMULATOR FAIL: fatal Android/app exception"
  exit 1
fi
echo "ANDROID EMULATOR PASS: x86_64 APK installed, launched, force-stopped and reopened with screenshots"
