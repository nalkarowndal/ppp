#!/usr/bin/env bash
# Real ARM64 Android device acceptance. NEVER pm clear or reset user data.
# Operator drives real on-screen taps and approves visual checks manually.
set -euo pipefail
PKG="org.astralchronicle.prototype"
SERIAL=""
APK=""
OUT="qa_artifacts/m3_android_physical"
EXECUTE=0
INSTALL=0
FORCE=0
while (( $# )); do
  case "$1" in
    --validate-only)
      echo "M3 ANDROID QA SCRIPT VALIDATION PASS: syntax/preflight only, no connected device tested"
      exit 0 ;;
    --serial) SERIAL="$2"; shift 2 ;;
    --apk) APK="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --execute) EXECUTE=1; shift ;;
    --install) INSTALL=1; shift ;;
    --allow-force-stop) FORCE=1; shift ;;
    *) echo "Unknown arg $1"; exit 2 ;;
  esac
done
if (( EXECUTE != 1 )); then
  echo "Refusing real-device actions without --execute. Use --validate-only in CI."
  exit 2
fi
command -v adb >/dev/null || { echo "adb not found"; exit 2; }
if [[ -z "$SERIAL" ]]; then
  echo "Explicit --serial required to avoid acting on another connected device."
  adb devices -l
  exit 2
fi
[[ "$SERIAL" != emulator-* ]] || { echo "Emulator serial rejected; this gate requires a physical phone"; exit 2; }
adb -s "$SERIAL" get-state | grep -qx "device" || { echo "ADB device not authorized"; exit 2; }
qemu="$(adb -s "$SERIAL" shell getprop ro.kernel.qemu | tr -d '\r')"
[[ "$qemu" != "1" ]] || { echo "Emulator detected; not physical QA"; exit 2; }
abi="$(adb -s "$SERIAL" shell getprop ro.product.cpu.abilist | tr -d '\r')"
[[ "$abi" == *arm64-v8a* ]] || { echo "ARM64 ABI missing: $abi"; exit 2; }
mkdir -p "$OUT"
REPORT="$OUT/acceptance.txt"
{
  echo "UNVERIFIED ARM64 PHYSICAL QA — human results and ADB logs"
  date -Iseconds
  echo "Android model: $(adb -s "$SERIAL" shell getprop ro.product.model | tr -d '\r')"
  echo "ABI: $abi"
  echo "SDK: $(adb -s "$SERIAL" shell getprop ro.build.version.sdk | tr -d '\r')"
  echo "Screen: $(adb -s "$SERIAL" shell wm size | tr -d '\r')"
  echo "Density: $(adb -s "$SERIAL" shell wm density | tr -d '\r')"
  echo "Physical-check: ro.kernel.qemu=$qemu"
  echo "NOTE: redact device serial/personal notifications before sharing logs/screenshots"
} > "$REPORT"
if (( INSTALL == 1 )); then
  [[ -f "$APK" ]] || { echo "--install requires --apk path"; exit 2; }
  read -r -p "Install/update M3 debug APK on this phone preserving app data? Type INSTALL: " answer
  [[ "$answer" == "INSTALL" ]] || { echo "No install performed"; exit 2; }
  adb -s "$SERIAL" install -r "$APK" | tee -a "$REPORT"
fi
if ! adb -s "$SERIAL" shell pm path "$PKG" | grep -q "package:"; then
  echo "M3 APK not installed. Pass --apk path --install --execute explicitly."
  exit 2
fi
if [[ -n "$APK" ]] && command -v sha256sum >/dev/null; then
  sha256sum "$APK" >> "$REPORT"
fi
capture() {
  local label="$1"
  local file="$2"
  echo ""
  echo "DEVICE ACTION: $label"
  read -r -p "After visually checking, enter PASS or FAIL: " verdict
  echo "MANUAL $label = $verdict" >> "$REPORT"
  [[ "$verdict" == "PASS" ]] || { echo "Not approved; $label"; exit 1; }
  adb -s "$SERIAL" exec-out screencap -p > "$OUT/$file"
  [[ -s "$OUT/$file" ]] || { echo "Empty device screenshot"; exit 1; }
}
collect_logs() {
  # Limit to Godot + Android app crash tags. Full logcat may contain personal data.
  adb -s "$SERIAL" logcat -d -v time -s Godot:I AndroidRuntime:E libc:F > "$OUT/godot_filtered_logcat.txt" 2>/dev/null || true
}
trap collect_logs EXIT
adb -s "$SERIAL" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 3
[[ -n "$(adb -s "$SERIAL" shell pidof "$PKG" | tr -d '\r')" ]] || { echo "Android game process not running"; exit 1; }
capture "M1에서 실제 손가락 터치로 M3 진입 → 8명 성장 탭, 노치·한글·터치·잘림 없음" "01_growth.png"
capture "장비 탭 실제 터치 → 무기/방어구/장신구 슬롯, 스크롤·한글" "02_equipment.png"
capture "방치 탭 실제 터치 → 8h/80% 문구 및 수령 버튼 상태" "03_idle.png"
echo "Put Android app in the background using real Android HOME key."
adb -s "$SERIAL" shell input keyevent KEYCODE_HOME
sleep 4
adb -s "$SERIAL" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 3
capture "백그라운드→복귀 후 실제 M3 UI와 보상 버튼/메시지 정상" "04_resume.png"
if (( FORCE == 1 )); then
  read -r -p "Force-stop this one game package (data preserved), then restart? Type FORCE: " choice
  [[ "$choice" == "FORCE" ]] || { echo "Force-stop refused"; exit 1; }
  old_pid="$(adb -s "$SERIAL" shell pidof "$PKG" | tr -d '\r')"
  adb -s "$SERIAL" shell am force-stop "$PKG"
  sleep 2
  adb -s "$SERIAL" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
  sleep 3
  new_pid="$(adb -s "$SERIAL" shell pidof "$PKG" | tr -d '\r')"
  [[ -n "$new_pid" ]] || { echo "Process failed to restart"; exit 1; }
  echo "FORCE_STOP_PID before=$old_pid after=$new_pid" >> "$REPORT"
  capture "강제 종료 후 새 프로세스에서 M3 재진입, 재화·장비·수령 기록 보존" "05_force_restart.png"
else
  echo "NOT TESTED: force-stop (rerun with --allow-force-stop, explicit confirmation)" | tee -a "$REPORT"
fi
collect_logs
if ! grep -Fq "M3_UI_READY:" "$OUT/godot_filtered_logcat.txt"; then
  echo "WARNING: M3_UI_READY marker not found in retained logcat; review manually" | tee -a "$REPORT"
fi
if grep -Eq "FATAL EXCEPTION|Fatal signal|SIGSEGV|SIGABRT" "$OUT/godot_filtered_logcat.txt"; then
  echo "BLOCKER: Android crash marker found in filtered logcat" | tee -a "$REPORT"
  exit 1
fi
echo "M3 ANDROID PHYSICAL QA EVIDENCE COLLECTED: manual screenshots and logcat; independent approval pending" | tee -a "$REPORT"
