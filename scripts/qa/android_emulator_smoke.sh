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
sleep 8
# First-run Android immersive-mode system confirmation hides the entire Godot UI.
# On Pixel 6 emulator (1080x2400), "Got it" is at approximately 85% x, 26% y.
# Derive coordinates from the actual emulated screen dimensions.
SCREEN_SIZE="$(adb shell wm size | grep -Eo '[0-9]+x[0-9]+' | head -1)"
SCREEN_W="${SCREEN_SIZE%x*}"
SCREEN_H="${SCREEN_SIZE#*x}"
ACK_X="$((SCREEN_W * 85 / 100))"
ACK_Y="$((SCREEN_H * 26 / 100))"
adb shell input tap "$ACK_X" "$ACK_Y"
echo "EMULATOR TEST: dismissed first-run fullscreen notice at $ACK_X,$ACK_Y" | tee "$OUT/immersive_notice.txt"
sleep 35
adb shell pidof "$PKG" | tee "$OUT/first_pid.txt"
test -s "$OUT/first_pid.txt"
adb exec-out screencap -p > "$OUT/first_launch.png"
# In case an immersive system dialog remains, fail rather than treating its screenshot as the game.
adb shell uiautomator dump /sdcard/astral_ui_dump.xml >/dev/null 2>&1 || true
adb shell cat /sdcard/astral_ui_dump.xml > "$OUT/ui_hierarchy.xml" 2>/dev/null || true
if grep -Fq "Viewing full screen" "$OUT/ui_hierarchy.xml"; then
  echo "ANDROID EMULATOR FAIL: immersive notice still blocks Godot UI"
  exit 1
fi

echo "EMULATOR TEST: force-stop and new process"
adb shell am force-stop "$PKG"
sleep 2
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 | tee "$OUT/restart.txt"
sleep 35
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

adb shell uiautomator dump /sdcard/astral_ui_dump_after_restart.xml >/dev/null 2>&1 || true
adb shell cat /sdcard/astral_ui_dump_after_restart.xml > "$OUT/restart_ui_hierarchy.xml" 2>/dev/null || true
if grep -Eiq "isn't responding|not responding|has stopped|Viewing full screen" "$OUT/restart_ui_hierarchy.xml"; then
  echo "ANDROID EMULATOR FAIL: system crash/ANR or immersive-mode overlay obscures game"
  exit 1
fi
adb logcat -d -v time > "$OUT/full_logcat.txt" || true
grep -Ei 'Godot|M1_UI_READY|AndroidRuntime|FATAL EXCEPTION|Fatal signal|SIGSEGV|SIGABRT' "$OUT/full_logcat.txt" > "$OUT/godot_diagnostics.txt" || true
adb logcat -d -v time -s AndroidRuntime:E libc:F Godot:E > "$OUT/critical_logcat.txt" || true
if grep -E "CanvasShaderGLES3: Program linking failed|Fragment shader active uniforms exceed GL_MAX_FRAGMENT_UNIFORM_VECTORS" "$OUT/full_logcat.txt"; then
  echo "ANDROID EMULATOR FAIL: Godot GLES3 shader link failed on current graphics driver"
  exit 1
fi
if ! grep -Fq "M1_UI_READY" "$OUT/full_logcat.txt"; then
  echo "ANDROID EMULATOR FAIL: Godot main UI did not log readiness"
  exit 1
fi
if grep -E "FATAL EXCEPTION|Fatal signal|SIGSEGV|SIGABRT" "$OUT/critical_logcat.txt"; then
  echo "ANDROID EMULATOR FAIL: fatal Android/app exception"
  exit 1
fi
echo "ANDROID EMULATOR PASS: x86_64 APK installed, launched, force-stopped and reopened with screenshots"
