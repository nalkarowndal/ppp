#!/usr/bin/env python3
"""M1 physical Android arm64 QA. Never run automatically in CI.

Only one selected, authorized, non-emulator Android phone is supported. The program
will NOT uninstall an app, clear package data, clear logcat, change device settings,
or modify unrelated apps. For safety it refuses a phone that already has the M1 app.
Physical device screenshots still require a human cutout/Korean-font visual review.

Example (PowerShell, after explicitly preparing a disposable test phone):
  py -3 scripts/qa/android_physical_device_qa.py --apk ".\astral-chronicle-m1-debug.apk" --run
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

PACKAGE = "org.astralchronicle.prototype"
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
QA_LINE = re.compile(r"(M1_UI_READY|M1_QA_|SceneShaderGLES3|CanvasShaderGLES3|FATAL EXCEPTION)")
TARGET = re.compile(r"M1_QA_TARGET (STEP|RESET|SAVE) x=(\d+) y=(\d+) visible=([01])")
SAFE = re.compile(r"M1_QA_SAFE_AREA x=(\d+) y=(\d+) width=(\d+) height=(\d+) cutouts=(\d+)")
SIZE = re.compile(r"(\d+)x(\d+)")

def self_test() -> None:
    samples = [
        "M1_QA_TARGET STEP x=419 y=1020 visible=1",
        "M1_QA_TARGET SAVE x=530 y=1339 visible=0",
    ]
    assert TARGET.search(samples[0]).groups() == ("STEP", "419", "1020", "1")
    assert TARGET.search(samples[1]).group(4) == "0"
    assert SAFE.search("M1_QA_SAFE_AREA x=0 y=80 width=1080 height=1760 cutouts=1")
    assert SIZE.search("Physical size: 1080x2400").groups() == ("1080", "2400")
    assert PNG_MAGIC == bytes.fromhex("89504e470d0a1a0a")
    print("ANDROID PHYSICAL QA SCRIPT SELF-TEST PASS (NO DEVICE CONNECTED)")

class Device:
    def __init__(self, adb: str, serial: str):
        self.adb, self.serial = adb, serial

    def cmd(self, *parts: str, timeout: int = 30, binary: bool = False, check: bool = True):
        args = [self.adb, "-s", self.serial, *map(str, parts)]
        p = subprocess.run(args, capture_output=True, timeout=timeout, check=False)
        if check and p.returncode != 0:
            stderr = p.stderr.decode("utf-8", errors="replace").strip()
            raise RuntimeError(f"ADB command failed (exit {p.returncode}, {' '.join(parts[:2])}): {stderr[:600]}")
        if binary:
            return p
        return p.stdout.decode("utf-8", errors="replace").strip()

    def prop(self, name: str) -> str:
        return self.cmd("shell", "getprop", name)

    def pid(self) -> str:
        return self.cmd("shell", "pidof", "-s", PACKAGE, check=False).strip()

    def app_events(self, pid: str) -> str:
        # --pid restricts returned logcat to this game's process. Never export all
        # personal device logs. No 'adb logcat -c' on a real user's phone.
        log = self.cmd("logcat", "--pid=" + pid, "-d", "-v", "raw", timeout=30)
        return "\n".join(line for line in log.splitlines() if QA_LINE.search(line))

def connected(adb: str, serial: str | None) -> str:
    p = subprocess.run([adb, "devices", "-l"], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=20)
    if p.returncode:
        raise RuntimeError("adb devices failed; install Android SDK Platform Tools")
    lines = [x.split()[0] for x in p.stdout.splitlines()[1:] if len(x.split()) >= 2 and x.split()[1] == "device"]
    if serial:
        if serial not in lines:
            raise RuntimeError("Selected device is not connected and authorized in 'adb devices'")
        return serial
    if len(lines) != 1:
        raise RuntimeError("Expected exactly one authorized device; specify --serial when more than one is connected")
    return lines[0]

def verify_physical(d: Device) -> dict:
    model = d.prop("ro.product.model")
    abi = d.prop("ro.product.cpu.abilist")
    qemu = [d.prop("ro.kernel.qemu"), d.prop("ro.boot.qemu")]
    hardware = d.prop("ro.hardware").lower()
    if any(v == "1" for v in qemu) or hardware in {"ranchu", "goldfish", "qemu"} or model.lower().startswith(("sdk_gphone", "android sdk built for")):
        raise RuntimeError("Emulator detected: this test is for a physical ARM64 phone only")
    if "arm64-v8a" not in abi:
        raise RuntimeError("Connected device does not advertise arm64-v8a ABI")
    sdk = int(d.prop("ro.build.version.sdk") or "0")
    if sdk < 26:
        raise RuntimeError("Android API 26+ is required for this logcat --pid based QA script")
    width, height = map(int, SIZE.search(d.cmd("shell", "wm", "size")).groups())
    density = d.cmd("shell", "wm", "density")
    if width <= 0 or height <= 0:
        raise RuntimeError("Invalid physical screen dimensions")
    return {"model": model, "android_api": sdk, "android_release": d.prop("ro.build.version.release"),
            "abi": "arm64-v8a", "resolution": [width, height], "density": density,
            "device_type": "physical-phone"}

def wait_pid(d: Device, max_wait: int = 20) -> str:
    until = time.monotonic() + max_wait
    while time.monotonic() < until:
        pid = d.pid()
        if pid:
            return pid
        time.sleep(.5)
    raise RuntimeError("Godot Android process not running")

def wait_event(d: Device, pid: str, marker: str, old_count: int = 0, seconds: int = 20) -> str:
    until = time.monotonic() + seconds
    while time.monotonic() < until:
        if d.pid() != pid:
            raise RuntimeError(f"App process exited while waiting for {marker}")
        log = d.app_events(pid)
        if log.count(marker) > old_count:
            return log
        time.sleep(.6)
    raise RuntimeError("No logcat event after physical input: " + marker)

def latest_target(log: str, action: str) -> tuple[int, int, bool]:
    matches = [m for m in TARGET.finditer(log) if m.group(1) == action]
    if not matches:
        raise RuntimeError("Missing Godot target coordinates: " + action)
    m = matches[-1]
    return int(m.group(2)), int(m.group(3)), m.group(4) == "1"

def check_safe_area(log: str, width: int, height: int) -> tuple[int, int, int, int, int]:
    matches = list(SAFE.finditer(log))
    if not matches:
        raise RuntimeError("Godot Android safe-area telemetry missing; cannot assess notch safety")
    x, y, w, h, cutouts = map(int, matches[-1].groups())
    if w <= 0 or h <= 0 or x < 0 or y < 0 or x + w > width or y + h > height:
        raise RuntimeError(f"Invalid Android safe area: {x},{y} {w}x{h}; screen {width}x{height}")
    return x, y, w, h, cutouts

def take_screen(d: Device, directory: Path, name: str) -> None:
    p = d.cmd("exec-out", "screencap", "-p", binary=True, timeout=30)
    if p.returncode or not p.stdout.startswith(PNG_MAGIC):
        raise RuntimeError("adb exec-out screencap returned an invalid PNG")
    (directory / name).write_bytes(p.stdout)

def do_run(d: Device, apk: Path, directory: Path, metadata: dict) -> None:
    evidence: list[str] = []
    width, height = metadata["resolution"]
    first_pid = None
    def track(msg: str):
        evidence.append(msg)
        print(msg)
    def save_events(pid: str, phase: str):
        (directory / (phase + "_events.txt")).write_text(d.app_events(pid), encoding="utf-8")

    # Abort rather than overwrite/uninstall an existing package that may hold real data.
    if "package:" in d.cmd("shell", "pm", "path", PACKAGE, check=False):
        raise RuntimeError("M1 package is already installed. Refusing to overwrite or erase possible save data. Use a clean dedicated test device/user.")
    track("PACKAGE SAFE: not previously installed; will use adb install WITHOUT -r or uninstall")
    result = d.cmd("install", str(apk), timeout=180)
    if "Success" not in result:
        raise RuntimeError("Android APK installation did not report Success: " + result[-200:])
    track("PHYSICAL APK INSTALL PASS: fresh install; existing apps/data untouched")
    d.cmd("shell", "monkey", "-p", PACKAGE, "-c", "android.intent.category.LAUNCHER", "1", timeout=30)
    pid = wait_pid(d)
    first_pid = pid
    log = wait_event(d, pid, "M1_QA_RESTORED turn=-1", seconds=30)
    safe = check_safe_area(log, width, height)
    metadata["godot_safe_area"] = list(safe)
    track("PHYSICAL FIRST LAUNCH PASS: no old M1 debug save; safe area reported " + str(safe))
    take_screen(d, directory, "01_first_launch.png")
    save_events(pid, "first_launch")

    def touch(action: str, event: str):
        current = d.app_events(pid)
        x, y, visible = latest_target(current, action)
        if not visible:
            for i in range(4):
                # Swipe inside the game region. Do not change Android navigation settings.
                d.cmd("shell", "input", "swipe", str(width//2), str(height*75//100),
                      str(width//2), str(height*30//100), "500")
                time.sleep(1)
                x, y, visible = latest_target(d.app_events(pid), action)
                if visible:
                    break
        if not visible:
            raise RuntimeError(f"{action} button remains clipped/invisible even after scrolling")
        sx, sy, sw, sh, _ = safe
        if not (sx <= x < sx+sw and sy <= y < sy+sh):
            raise RuntimeError(f"{action} at ({x},{y}) lies OUTSIDE Godot Android safe area {safe}")
        if not (0 <= x < width and 0 <= y < height):
            raise RuntimeError(f"{action} at ({x},{y}) lies outside physical display")
        before = d.app_events(pid).count(event)
        d.cmd("shell", "input", "tap", str(x), str(y))
        wait_event(d, pid, event, old_count=before, seconds=18)
        track(f"PHYSICAL TOUCH PASS: {action} ({x},{y}) -> {event}")
    touch("STEP", "M1_QA_EVENT STEP turn=1")
    touch("RESET", "M1_QA_EVENT RESET turn=0")
    touch("STEP", "M1_QA_EVENT STEP turn=1")
    touch("SAVE", "M1_QA_EVENT SAVE turn=1 success=1")
    time.sleep(1)
    take_screen(d, directory, "02_after_save.png")
    save_events(pid, "after_save")
    d.cmd("shell", "am", "force-stop", PACKAGE)
    if d.pid():
        time.sleep(1)
    d.cmd("shell", "monkey", "-p", PACKAGE, "-c", "android.intent.category.LAUNCHER", "1", timeout=30)
    restarted_pid = wait_pid(d)
    if restarted_pid == first_pid:
        raise RuntimeError("Cannot prove a separate Android process (PID unexpectedly unchanged)")
    wait_event(d, restarted_pid, "M1_QA_RESTORED turn=1", seconds=30)
    time.sleep(1)
    take_screen(d, directory, "03_after_restart.png")
    save_events(restarted_pid, "after_restart")
    track(f"PHYSICAL SAVE RESTORE PASS: force-stop -> NEW PID -> turn 1 persisted (process IDs excluded from shared report)")
    track("VISUAL HUMAN QA STILL REQUIRED: review all PNGs for Korean glyphs, notch, overlaps, 19.5:9 or 20:9 safe areas")
    (directory / "qa_events.txt").write_text("\n".join(evidence) + "\n", encoding="utf-8")
    (directory / "metadata.json").write_text(json.dumps(metadata, indent=2, ensure_ascii=False), encoding="utf-8")

def main():
    p = argparse.ArgumentParser(description="Safely validate M1 on ONE physical ARM64 Android test phone")
    p.add_argument("--apk", type=Path, help="Path to arm64 debug APK")
    p.add_argument("--serial", help="Explicit ADB serial if more than one device is attached (not recorded)")
    p.add_argument("--adb", default="adb", help="adb executable from Android SDK Platform Tools")
    p.add_argument("--out", type=Path, default=Path("qa_artifacts/android_physical"))
    p.add_argument("--run", action="store_true", help="Explicitly authorize fresh APK install + touch QA on the selected phone")
    p.add_argument("--self-test", action="store_true", help="Pure parser checks without adb, installation, or device access")
    args = p.parse_args()
    if args.self_test:
        self_test()
        return
    if not args.apk or not args.apk.is_file():
        p.error("Provide an existing arm64 debug APK via --apk")
    adb = shutil.which(args.adb)
    if not adb:
        p.error("ADB not available in PATH. Install Android SDK Platform Tools")
    serial = connected(adb, args.serial)
    d = Device(adb, serial)
    metadata = verify_physical(d)
    print("PHYSICAL PHONE DETECTED:", metadata["model"], "Android API", metadata["android_api"], "screen", metadata["resolution"])
    if not args.run:
        print("DRY RUN ONLY: no APK installed, no app touched. Add --run to explicitly authorize QA on a CLEAN test phone.")
        return
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    directory = args.out / ("run_" + stamp)
    directory.mkdir(parents=True, exist_ok=False)
    metadata["apk_sha256"] = hashlib.sha256(args.apk.read_bytes()).hexdigest()
    try:
        do_run(d, args.apk.resolve(), directory, metadata)
        print("PHYSICAL DEVICE AUTOMATED QA PASS (HUMAN SCREEN REVIEW STILL PENDING):", directory)
    except Exception as exc:
        (directory / "FAILURE.txt").write_text(str(exc) + "\n", encoding="utf-8")
        pid = d.pid()
        if pid:
            try:
                (directory / "failure_app_events.txt").write_text(d.app_events(pid), encoding="utf-8")
                take_screen(d, directory, "failure_screen.png")
            except Exception:
                pass
        print("PHYSICAL DEVICE QA FAIL:", exc, file=sys.stderr)
        print("EVIDENCE:", directory, file=sys.stderr)
        raise SystemExit(1)

if __name__ == "__main__":
    main()
