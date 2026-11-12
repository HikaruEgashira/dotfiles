import importlib.util
import json
from pathlib import Path
import stat
import tempfile
import unittest


spec = importlib.util.spec_from_file_location(
    "renderer", Path(__file__).resolve().parents[1] / "modules/programs/cliproxyapi/render-config.py"
)
renderer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(renderer)


class ConfigTest(unittest.TestCase):
    def test_secret_is_data(self):
        secret = 'quote"\nserver: {host: 0.0.0.0}\n$(touch /tmp/unwanted)'
        result = renderer.render({"keys": ["@CLIENT_KEY@"], "port": 8317}, {"CLIENT_KEY": secret})
        self.assertEqual(json.loads(json.dumps(result)), {"keys": [secret], "port": 8317})

    def test_missing_secret_fails_closed(self):
        with self.assertRaisesRegex(ValueError, "Missing credential: CLIENT_KEY"):
            renderer.render(["@CLIENT_KEY@"], {})

    def test_atomic_replacement_has_private_permissions(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "config.yaml"
            path.write_text("old")
            path.chmod(0o644)
            renderer.write_private(path, "new")
            self.assertEqual(path.read_text(), "new")
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            self.assertEqual(list(Path(tmp).iterdir()), [path])


if __name__ == "__main__":
    unittest.main()
