"""Protect actual Android phones from M2 emulator-only touch QA."""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


class EmulatorGuardTests(unittest.TestCase):
    def test_rejects_real_phone_before_screen_capture_or_touch(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "adb").write_text(
                '#!/bin/sh\n'
                'printf "%s\\n" "$*" >> "$FAKE_ADB_CALLS"\n'
                'if [ "$*" = "shell getprop ro.kernel.qemu" ]; then echo 0; fi\n'
                'if [ "$*" = "shell getprop ro.boot.qemu" ]; then echo 0; fi\n',
                encoding="utf-8",
            )
            (root / "adb").chmod(0o755)
            commands = root / "calls.log"
            env = os.environ.copy()
            env["PATH"] = str(root) + os.pathsep + env.get("PATH", "")
            env["FAKE_ADB_CALLS"] = str(commands)
            result = subprocess.run(
                ["bash", str(REPO / "scripts/qa/android_emulator_m2_battle.sh")],
                cwd=root, env=env, capture_output=True, text=True, timeout=20,
                check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("refusing to touch a physical Android device", result.stdout)
            lines = commands.read_text(encoding="utf-8").splitlines()
            self.assertEqual(lines, ["shell getprop ro.kernel.qemu", "shell getprop ro.boot.qemu",
                                     "shell getprop ro.kernel.qemu"])
            forbidden = ("screencap", "logcat", "input", "install", "force-stop",
                         "monkey", "pm clear", "wm size", "pm path")
            self.assertTrue(all(not any(word in line for word in forbidden)
                                for line in lines), lines)


if __name__ == "__main__":
    unittest.main()
