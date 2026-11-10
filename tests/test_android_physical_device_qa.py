"""Offline safety and parser tests; no phone is contacted or modified."""
import importlib.util
from pathlib import Path
import unittest

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("qa", root / "scripts/qa/android_physical_device_qa.py")
qa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qa)

class FakeDevice:
    def __init__(self, emulator=False, installed=False):
        self.emulator, self.installed, self.commands = emulator, installed, []
    def prop(self, key):
        return {
            "ro.product.model": "QA example phone",
            "ro.product.cpu.abilist": "arm64-v8a,armeabi-v7a",
            "ro.kernel.qemu": "1" if self.emulator else "0",
            "ro.boot.qemu": "0",
            "ro.hardware": "qcom",
            "ro.build.version.sdk": "35",
            "ro.build.version.release": "15",
        }.get(key, "")
    def cmd(self, *args, **kwargs):
        self.commands.append(args)
        if args[:3] == ("shell", "wm", "size"):
            return "Physical size: 1080x2400"
        if args[:3] == ("shell", "wm", "density"):
            return "Physical density: 420"
        if args[:3] == ("shell", "pm", "path"):
            return "package:/data/app/example/base.apk" if self.installed else ""
        raise AssertionError(f"Unexpected command: {args}")

class PhysicalQATests(unittest.TestCase):
    def test_safe_parsers(self):
        qa.self_test()
        rect = qa.check_safe_area("M1_QA_SAFE_AREA x=0 y=82 width=1080 height=2250 cutouts=1", 1080, 2400)
        self.assertEqual(rect, (0, 82, 1080, 2250, 1))
        self.assertEqual(qa.latest_target("M1_QA_TARGET STEP x=419 y=1020 visible=1", "STEP"), (419, 1020, True))
        self.assertEqual(qa.latest_target("M1_QA_TARGET SAVE x=530 y=1339 visible=0", "SAVE"), (530, 1339, False))

    def test_safe_area_invalid_bounds(self):
        with self.assertRaises(RuntimeError):
            qa.check_safe_area("M1_QA_SAFE_AREA x=0 y=85 width=1080 height=2400 cutouts=1", 1080, 2400)

    def test_reject_emulators(self):
        with self.assertRaises(RuntimeError):
            qa.verify_physical(FakeDevice(emulator=True))

    def test_accept_arm64_physical_hardware_without_writes(self):
        fake = FakeDevice()
        metadata = qa.verify_physical(fake)
        self.assertEqual(metadata["device_type"], "physical-phone")
        self.assertEqual(metadata["resolution"], [1080, 2400])
        self.assertTrue(all(args[0] == "shell" for args in fake.commands))
        self.assertFalse(any("install" in args or "clear" in args for args in fake.commands))

    def test_refuse_preexisting_package_before_install_or_touch(self):
        fake = FakeDevice(installed=True)
        with self.assertRaisesRegex(RuntimeError, "already installed"):
            qa.do_run(fake, Path("never-install.apk"), Path("."), {"resolution": [1080, 2400]})
        self.assertEqual(fake.commands, [("shell", "pm", "path", qa.PACKAGE)])

if __name__ == "__main__":
    unittest.main()
