#!/usr/bin/env bash
# M2-5 actual ADB touch against an isolated Android x86_64 EMULATOR.
# Must only run after scripts/qa/android_emulator_interaction.sh, on CI emulator.
# It is not an arm64 physical-device test and never runs on real phones.
set -euo pipefail
PKG="org.astralchronicle.prototype"
OUT="qa_artifacts/emulator/m2"
mkdir -p "$OUT"
LOG="$OUT/m2_adb_touch.log"
full_log="$OUT/m2_logcat.txt"
log() { echo "$*" | tee -a "$LOG"; }
EMULATOR_GUARD_OK=0
fail() {
  log "M2_5_ANDROID_EMULATOR_FAIL: $*"
  # Never capture another person's display or logcat on a connected phone.
  if [[ "$EMULATOR_GUARD_OK" -eq 1 ]]; then
    adb exec-out screencap -p > "$OUT/failure.png" || true
    adb logcat -d -v raw > "$full_log" || true
  fi
  exit 1
}
for property in ro.kernel.qemu ro.boot.qemu; do
  val="$(adb shell getprop "$property" | tr -d '\r')"
  log "EMULATOR_GUARD $property=$val"
done
[ "$(adb shell getprop ro.kernel.qemu | tr -d '\r')" = "1" ] || fail "refusing to touch a physical Android device"
ABI="$(adb shell getprop ro.product.cpu.abi | tr -d '\r')"
[[ "$ABI" == *x86* ]] || fail "refusing non-x86 emulator ABI: $ABI"
EMULATOR_GUARD_OK=1
[ "$(adb shell pm path "$PKG" | grep -c 'package:')" -ge 1 ] || fail "test APK not installed"
screen="$(adb shell wm size | grep -Eo '[0-9]+x[0-9]+' | head -1)"
SCREEN_W="${screen%x*}"
SCREEN_H="${screen#*x}"
log "EMULATOR_SCREEN ${SCREEN_W}x${SCREEN_H} abi=$ABI"

# M1 saved debug turn is intentionally preserved by the preceding emulator job.
adb logcat -c
adb shell am force-stop "$PKG"
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
wait_for() {
  local token="$1" attempt
  for attempt in $(seq 1 18); do
    adb logcat -d -v raw > "$full_log"
    if grep -Fq "$token" "$full_log"; then
      log "VERIFIED $token"
      return 0
    fi
    sleep 1
  done
  fail "missing application marker: $token"
}
wait_for "M1_UI_READY"
adb exec-out screencap -p > "$OUT/01_m1_relaunch.png"

get_target() {
  local action="$1" line
  adb logcat -d -v raw > "$full_log"
  line="$(grep -E "M2_5_QA_TARGET ${action} x=[0-9]+ y=[0-9]+ visible=[01]" "$full_log" | tail -n 1 || true)"
  [[ -n "$line" && "$line" == *"visible=1"* ]] || return 1
  local x y
  x="$(sed -nE 's/.* x=([0-9]+) y=.*/\1/p' <<< "$line")"
  y="$(sed -nE 's/.* y=([0-9]+) visible=.*/\1/p' <<< "$line")"
  [[ -n "$x" && -n "$y" ]] || return 1
  if (( x < 10 || x > SCREEN_W - 10 || y < 10 || y > SCREEN_H - 10 )); then
    fail "target outside screen: $action at $x,$y"
  fi
  echo "$x $y"
}
tap() {
  local action="$1" coords x y
  coords="$(get_target "$action")" || fail "button $action not visible or no geometry event"
  read -r x y <<< "$coords"
  log "ADB_TAP $action x=$x y=$y"
  adb shell input tap "$x" "$y"
}
swipe_up() {
  adb shell input swipe "$((SCREEN_W/2))" "$((SCREEN_H*75/100))" "$((SCREEN_W/2))" "$((SCREEN_H*29/100))" 430
  sleep 2
}
# M2 launcher is AFTER M1 SAVE, so the player must swipe to it.
for i in 1 2 3 4 5 6; do
  if get_target ENTER >/dev/null; then break; fi
  log "ADB_SWIPE find ENTER attempt=$i"
  swipe_up
done
tap ENTER
wait_for "M2_5_BATTLE_READY allies=3 enemies=3"
wait_for "M2_5_QA_SAFE_AREA"
adb exec-out screencap -p > "$OUT/02_m2_battle_initial.png"

for i in 1 2 3 4 5 6; do
  if get_target AUTO >/dev/null && get_target SPEED >/dev/null; then break; fi
  log "ADB_SWIPE find AUTO/SPEED attempt=$i"
  swipe_up
done
tap AUTO
wait_for "M2_5_QA_ACTION AUTO enabled=0"
tap SPEED
wait_for "M2_5_QA_ACTION SPEED value=2"
adb exec-out screencap -p > "$OUT/03_m2_controls_after_touch.png"
tap RESTART
wait_for "M2_5_QA_ACTION RESTART ticks=0"
tap BACK
wait_for "M2_5_QA_ACTION BACK"
wait_for "M1_UI_READY"
adb exec-out screencap -p > "$OUT/04_m1_return.png"

# Check that every captured PNG is a normal-sized Android screenshot.
python3 - "$OUT" <<'PY'
from pathlib import Path
import struct, sys
folder = Path(sys.argv[1])
for path in sorted(folder.glob('*.png')):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or len(data) < 8000:
        raise SystemExit(f"BAD_ANDROID_SCREENSHOT {path} size={len(data)}")
    w, h = struct.unpack(">II", data[16:24])
    if min(w,h) < 300 or max(w,h) < 600:
        raise SystemExit(f"BAD_ANDROID_DIMENSIONS {path}: {w}x{h}")
    print("M2_5_EMULATOR_PNG", path.name, w, h)
PY
log "M2_5_ANDROID_EMULATOR_PASS: actual x86_64 ADB taps ENTER/AUTO/SPEED/RESTART/BACK with 4 screenshots"
