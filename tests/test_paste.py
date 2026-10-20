"""Exercise routing and input behavior without controlling any real applications."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "paste-image-remote.sh"
APPS = {
    "ghostty": "com.mitchellh.ghostty",
    "iterm": "com.googlecode.iterm2",
    "terminal": "com.apple.Terminal",
}

OSASCRIPT = r'''#!/bin/bash
printf '%s\n' "$*" >> "$TEST_ROOT/events"
case "$*" in
    *NSWorkspace*)
        if [ -n "${CHANGED_FOCUS:-}" ]; then echo com.example.other; else echo "$CLIP_APP"; fi ;;
    *'return id of focused terminal'*) echo test-terminal ;;
    *'return tty'*) echo /dev/ttys042 ;;
    *'PNGf'*)
        file=$(printf '%s\n' "$*" | sed -n 's/.*POSIX file "\([^"]*\)".*/\1/p')
        cp "$TEST_ROOT/image.png" "$file" ;;
    *'input text'*|*'write text'*|*'keystroke'*) : ;;
    *) echo "Unexpected scripting call: $*" >&2; exit 1 ;;
esac
'''


class RoutingTests(unittest.TestCase):
    def run_script(self, app, remote=False, dry=False, changed=False):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            cache = root / ".cache/a"
            cache.mkdir(parents=True)
            (cache / "clip-terminals").write_text("test-terminal\tttys042\n")
            (root / "image.png").write_bytes(b"test image payload")
            commands = {
                "osascript": OSASCRIPT,
                "date": '#!/bin/bash\necho test-fixture\n',
                "ps": '#!/bin/bash\n[ -z "${TEST_REMOTE:-}" ] || echo "ttys042 123 ssh -p 2222 test-host"\n',
                "ssh": '#!/bin/bash\nprintf "%s\\n" "$*" > "$TEST_ROOT/ssh-args"\ncat > "$TEST_ROOT/upload"\n',
            }
            for name, body in commands.items():
                command = bin_dir / name
                command.write_text(body)
                command.chmod(0o755)
            env = {k: v for k, v in os.environ.items() if not k.startswith("CLIP_")}
            env.update(HOME=tmp, PATH=f"{bin_dir}:/usr/bin:/bin", TEST_ROOT=tmp,
                       CLIP_APP=app)
            if remote:
                env["TEST_REMOTE"] = "1"
            if dry:
                env["CLIP_DRY_RUN"] = "1"
            if changed:
                env["CHANGED_FOCUS"] = "1"
            # The stub date makes this test-owned artifact deterministic.
            artifact = Path("/tmp/clip-test-fixture.png")
            try:
                result = subprocess.run(["bash", str(SCRIPT)], env=env,
                                        capture_output=True, text=True, timeout=10)
                events = (root / "events").read_text() if (root / "events").exists() else ""
                upload = (root / "upload").read_bytes() if (root / "upload").exists() else None
                args = (root / "ssh-args").read_text() if (root / "ssh-args").exists() else ""
                return result, events, upload, args
            finally:
                artifact.unlink(missing_ok=True)

    def test_local_input_for_each_terminal(self):
        for name, app in APPS.items():
            with self.subTest(app=name):
                result, events, upload, _ = self.run_script(app)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
                self.assertIn("local:/tmp/clip-test-fixture.png", result.stdout)
                self.assertIsNone(upload)
                if name == "ghostty":
                    self.assertIn("input text", events)
                elif name == "iterm":
                    self.assertIn('write text "/tmp/clip-test-fixture.png" newline false', events)
                else:
                    self.assertIn('keystroke "/tmp/clip-test-fixture.png"', events)
                    self.assertNotIn("do script", events)

    def test_remote_upload_for_each_terminal(self):
        for app in APPS.values():
            with self.subTest(app=app):
                result, _, upload, args = self.run_script(app, remote=True)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
                self.assertEqual(upload, b"test image payload")
                self.assertIn("-p 2222", args)
                self.assertIn("BatchMode=yes", args)
                self.assertIn("test-host", args)
                self.assertIn("umask 077; cat > /tmp/clip-test-fixture.png", args)
                self.assertIn("test-host:/tmp/clip-test-fixture.png", result.stdout)

    def test_dry_run_uploads_without_typing(self):
        result, events, upload, _ = self.run_script(APPS["terminal"], remote=True, dry=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIsNotNone(upload)
        self.assertNotIn("keystroke", events)
        self.assertIn("would paste", result.stdout)

    def test_focus_change_prevents_input(self):
        for app in APPS.values():
            with self.subTest(app=app):
                result, events, _, _ = self.run_script(app, changed=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Terminal focus changed", result.stdout)
                for instruction in ("input text", "write text", "keystroke"):
                    self.assertNotIn(instruction, events)

    def test_unrelated_app_is_rejected(self):
        result, events, upload, _ = self.run_script("com.example.other")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Focus Ghostty", result.stdout)
        self.assertEqual(events, "")
        self.assertIsNone(upload)


if __name__ == "__main__":
    unittest.main()
