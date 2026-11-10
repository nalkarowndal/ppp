#!/usr/bin/env bash
# M1 debug-only real Android touch/input/persistence test using a running x86_64 emulator.
# This script must be invoked after the emulator has successfully booted and installed the APK.
set -euo pipefail
PKG="org.astralchronicle.prototype"
OUT="qa_artifacts/emulator"
mkdir -p "$OUT"
QA_LOG="$OUT/touch-save-restore.log"

log() { echo "$*" | tee -a "$QA_LOG"; }
dumplog() { adb logcat -d -v raw > "$OUT/touch_full_logcat.txt"; }
fail() { log "M1 TOUCH SAVE FAIL: $*"; exit 1; }
check_event() {
  local expected="$1"
  local attempt
  for attempt in $(seq 1 12); do
    dumplog
    if grep -Fq "$expected" "$OUT/touch_full_logcat.txt"; then
      log "PASS $expected"
      return 0
    fi
    sleep 1
  done
  fail "Missing event: $expected"
}

get_target() {
  local action="$1" line x y vis
  dumpLog_unused= # Intentionally do not clear logcat; event lines must remain auditable
  dumplog
  line="$(grep -E "M1_QA_TARGET ${action} x=[0-9]+ y=[0-9]+ visible=1" "$OUT/touch_full_logcat.txt" | tail -n 1 || true)"
  if [[ -z "$line" ]]; then
    return 1
  fi
  x="$(echo "$line" | sed -nE 's/.* x=([0-9]+) y=.*/\1/p')"
  y="$(echo "$line" | sed -nE 's/.* y=([0-9]+) visible=.*/\1/p')"
  if [[ -z "$x" || -z "$y" ]]; then
    return 1
  fi
  if (( x < 10 || x > SCREEN_W - 10 || y < 10 || y > SCREEN_H - 10 )); then
    fail "Button ${action} center is outside screen: ${x},${y}, screen ${SCREEN_W}x${SCREEN_H}"
  fi
  echo "$x $y"
}

tap_target() {
  local action="$1" xy x y
  if ! xy="$(get_target "$action")"; then
    fail "No visible current geometry for ${action}"
  fi
  read -r x y <<< "$xy"
  log "ADB_TOUCH ${action} x=${x} y=${y}"
  adb shell input tap "$x" "$y"
}

# clear only the CI emulator's test package sandbox before the sequence, never a real device.
log "M1 TOUCH SAVE START: clearing emulator-only sandbox"
adb shell pm clear "$PKG" | tee -a "$QA_LOG"
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >> "$QA_LOG"
sleep 10
test -n "$(adb shell pidof "$PKG" || true)" || fail "App process exited before touch test"

SCREEN_SIZE="$(adb shell wm size | grep -Eo '[0-9]+x[0-9]+' | head -1)"
SCREEN_W="${SCREEN_SIZE%x*}"
SCREEN_H="${SCREEN_SIZE#*x}"
log "SCREEN ${SCREEN_W}x${SCREEN_H}"
check_event "M1_UI_READY:"
check_event "M1_QA_RESTORED turn=-1"

# Dismiss Android's immersive confirmation if the OS displays it on a first install.
if ! get_target "STEP" >/dev/null; then
  adb shell input tap "$(( SCREEN_W * 85 / 100 ))" "$(( SCREEN_H * 26 / 100 ))"
  sleep 3
fi

tap_target "STEP"
check_event "M1_QA_EVENT STEP turn=1"
tap_target "RESET"
check_event "M1_QA_EVENT RESET turn=0"
# Use the second STEP after RESET to prove a fresh progression.
adb logcat -c
tap_target "STEP"
check_event "M1_QA_EVENT STEP turn=1"

# Save is lower down the Godot ScrollContainer. Real touch-swipes, never GDScript signal emission.
if ! get_target "SAVE" >/dev/null; then
  for attempt in 1 2 3 4; do
    log "ADB_SWIPE to SAVE attempt ${attempt}"
    adb shell input swipe "$((SCREEN_W/2))" "$((SCREEN_H*75/100))" "$((SCREEN_W/2))" "$((SCREEN_H*27/100))" 560
    sleep 3
    if get_target "SAVE" >/dev/null; then
      break
    fi
  done
fi
tap_target "SAVE"
check_event "M1_QA_EVENT SAVE turn=1 success=1"
adb exec-out screencap -p > "$OUT/after_save_touch.png"

log "ADB_FORCE_STOP and relaunch to verify saved turn from a distinct Android app process"
old_pid="$(adb shell pidof "$PKG" | tr -d '\r')"
adb shell am force-stop "$PKG"
sleep 2
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >> "$QA_LOG"
sleep 8
new_pid="$(adb shell pidof "$PKG" | tr -d '\r' || true)"
test -n "$new_pid" || fail "App did not run after force-stop"
log "PROCESS before=${old_pid} after=${new_pid}"
check_event "M1_UI_READY:"
check_event "M1_QA_RESTORED turn=1"
adb exec-out screencap -p > "$OUT/after_restore_touch.png"
log "M1 TOUCH SAVE RESTORE PASS: real tap STEP/RESET/STEP/SAVE, force-stop, saved turn=1 restored"
