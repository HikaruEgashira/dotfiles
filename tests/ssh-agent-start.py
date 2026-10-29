#!/usr/bin/env python3
import importlib.util
import errno
from pathlib import Path
import socket
import shutil
import os
import subprocess
import sys
import time
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location(
    "agent_start", Path(__file__).resolve().parents[1] / "scripts/ssh-agent-start.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class StaleSocketTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="agent-", dir="/tmp")
        self.addCleanup(self.directory.cleanup)
        self.path = str(Path(self.directory.name) / "agent.sock")

    def test_missing_socket(self):
        module.clear_stale_socket(self.path)
        self.assertFalse(Path(self.path).exists())

    def test_refused_socket_is_removed(self):
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
            server.bind(self.path)
        module.clear_stale_socket(self.path)
        self.assertFalse(Path(self.path).exists())

    def test_live_socket_is_preserved(self):
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
            server.bind(self.path)
            server.listen(1)
            inode = Path(self.path).stat().st_ino
            with self.assertRaisesRegex(RuntimeError, "already listening"):
                module.clear_stale_socket(self.path)
            self.assertEqual(Path(self.path).stat().st_ino, inode)

    def test_probe_failure_does_not_remove_socket(self):
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
            server.bind(self.path)
        for error in (PermissionError(errno.EACCES, "denied"), TimeoutError()):
            with patch.object(socket.socket, "connect", side_effect=error):
                with self.assertRaises(OSError):
                    module.clear_stale_socket(self.path)
            self.assertTrue(Path(self.path).is_socket())

    def test_agent_recovers_after_forced_exit(self):
        launcher = Path(__file__).resolve().parents[1] / "scripts/ssh-agent-start.py"
        environment = dict(os.environ, SSH_AUTH_SOCK=self.path)
        for _ in range(2):
            process = subprocess.Popen(
                [sys.executable, str(launcher), self.path, shutil.which("ssh-agent")],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
            )
            try:
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    result = subprocess.run(
                        [shutil.which("ssh-add"), "-l"], env=environment,
                        capture_output=True, timeout=2,
                    )
                    if result.returncode == 1:
                        break
                    if process.poll() is not None:
                        self.fail(process.stderr.read().decode())
                    time.sleep(0.05)
                else:
                    self.fail("agent never accepted a connection")
            finally:
                if process.poll() is None:
                    process.kill()
                process.wait(timeout=5)
                process.stderr.close()
            self.assertTrue(Path(self.path).is_socket())

    def test_file_and_symlink_are_preserved(self):
        path = Path(self.path)
        path.write_text("keep")
        with self.assertRaisesRegex(RuntimeError, "non-socket"):
            module.clear_stale_socket(self.path)
        self.assertEqual(path.read_text(), "keep")
        link = path.with_name("link")
        link.symlink_to(path)
        with self.assertRaisesRegex(RuntimeError, "non-socket"):
            module.clear_stale_socket(str(link))
        self.assertTrue(link.is_symlink())


if __name__ == "__main__":
    unittest.main()
