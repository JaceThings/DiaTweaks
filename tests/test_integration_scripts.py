"""Tests for deterministic provider-script packaging."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
BUILDER = REPO / "scripts" / "build-integration-scripts.py"
RUNTIME = REPO / "src" / "dylib" / "TabIntegrations" / "AdapterRuntime.js"


class IntegrationScriptBuilderTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "providers"
        self.root.mkdir()
        self.output = Path(self.temp.name) / "out" / "scripts.json"

    def provider(self, name, config, files=None):
        folder = self.root / name
        folder.mkdir(parents=True)
        (folder / "integration.json").write_text(json.dumps(config), encoding="utf-8")
        for path, source in (files or {}).items():
            target = folder / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(source, encoding="utf-8")
        return folder

    def run_builder(self):
        return subprocess.run(
            [sys.executable, str(BUILDER), str(self.output), "--source-root", str(self.root)],
            text=True, capture_output=True, check=False,
        )

    def test_bundles_ordered_sources_as_deterministic_utf8_json(self):
        self.provider("Zeta", {"scripts": ["State.js", "nested/Collector.js"]}, {
            "State.js": "window.state = '雪';\n",
            "nested/Collector.js": "window.collect = true;",
        })
        self.provider("Alpha", {"scripts": ["one.js", "two.js"]}, {
            "one.js": "first()",
            "two.js": "second()",
        })
        result = self.run_builder()
        self.assertEqual(result.returncode, 0, result.stderr)
        bundled = self.output.read_text(encoding="utf-8")
        self.assertEqual(bundled, json.dumps({
            "Alpha": "first()\n;\nsecond()",
            "Zeta": "window.state = '雪';\n\n;\nwindow.collect = true;",
        }, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n")
        self.assertEqual(json.loads(bundled)["Zeta"].split("\n;\n")[1], "window.collect = true;")

    def test_empty_source_root_builds_empty_mapping(self):
        result = self.run_builder()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text(encoding="utf-8")), {})

    def test_optional_runtime_is_prepended_and_false_keeps_custom_bundle_unchanged(self):
        self.provider("WithRuntime", {"runtime": True, "scripts": ["Collector.js"]}, {"Collector.js": "adapter()"})
        self.provider("CustomOnly", {"runtime": False, "scripts": ["Collector.js"]}, {"Collector.js": "custom()"})
        result = self.run_builder()
        self.assertEqual(result.returncode, 0, result.stderr)
        mapping = json.loads(self.output.read_text(encoding="utf-8"))
        runtime_source = RUNTIME.read_text(encoding="utf-8")
        self.assertTrue(mapping["WithRuntime"].startswith(runtime_source + "\n;\nadapter()"))
        self.assertEqual(mapping["CustomOnly"], "custom()")

    def test_rejects_non_boolean_runtime_option(self):
        self.provider("BadRuntime", {"runtime": "yes", "scripts": ["Collector.js"]}, {"Collector.js": "adapter()"})
        result = self.run_builder()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("'runtime' must be a boolean", result.stderr)

    def test_conversation_helper_is_opt_in_and_precedes_provider(self):
        self.provider("Chats", {"runtime": True, "conversations": True, "scripts": ["Collector.js"]}, {"Collector.js": "adapter()"})
        result = self.run_builder()
        self.assertEqual(result.returncode, 0, result.stderr)
        source = json.loads(self.output.read_text(encoding="utf-8"))["Chats"]
        self.assertEqual(source, RUNTIME.read_text(encoding="utf-8") + "\n;\n" + RUNTIME.with_name("ConversationRuntime.js").read_text(encoding="utf-8") + "\n;\nadapter()")

    def test_conversation_option_rejects_wrong_type_and_missing_runtime(self):
        for config in [{"conversations": True}, {"runtime": True, "conversations": "true"}]:
            with self.subTest(config=config):
                self.provider("BadConversations", dict(config, scripts=["Collector.js"]), {"Collector.js": "adapter()"})
                result = self.run_builder()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("'conversations'", result.stderr)
                for file in (self.root / "BadConversations").iterdir(): file.unlink()
                (self.root / "BadConversations").rmdir()

    def test_rejects_malformed_configs_and_missing_files(self):
        invalid_configs = [[], {"scripts": "State.js"}, {"scripts": []}, {"other": []}]
        for index, config in enumerate(invalid_configs):
            with self.subTest(config=config):
                folder = self.root / f"Bad{index}"
                folder.mkdir()
                (folder / "integration.json").write_text(json.dumps(config), encoding="utf-8")
                result = self.run_builder()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("integration.json", result.stderr)
                (folder / "integration.json").unlink()
        self.provider("Missing", {"scripts": ["absent.js"]})
        result = self.run_builder()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing", result.stderr)
        self.assertFalse(self.output.exists())

    def test_rejects_absolute_and_escaping_script_paths(self):
        external = Path(self.temp.name) / "outside.js"
        external.write_text("unsafe()", encoding="utf-8")
        for script_path in [str(external), "../outside.js", "folder/../../outside.js", "bad\\path.js"]:
            with self.subTest(script_path=script_path):
                self.provider("Bad", {"scripts": [script_path]})
                result = self.run_builder()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("invalid JavaScript path", result.stderr) if Path(script_path).is_absolute() else self.assertTrue(result.stderr)
                for child in (self.root / "Bad").iterdir():
                    if child.is_dir():
                        for nested in child.iterdir(): nested.unlink()
                        child.rmdir()
                    else:
                        child.unlink()
                (self.root / "Bad").rmdir()

    def test_rejects_script_symlink_that_escapes_provider_folder(self):
        external = Path(self.temp.name) / "outside.js"
        external.write_text("unsafe()", encoding="utf-8")
        folder = self.root / "Symlink"
        folder.mkdir()
        (folder / "integration.json").write_text(json.dumps({"scripts": ["alias.js"]}), encoding="utf-8")
        try:
            (folder / "alias.js").symlink_to(external)
        except (OSError, NotImplementedError):
            self.skipTest("symlinks unavailable")
        result = self.run_builder()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("escapes provider folder", result.stderr)

    def test_rejects_provider_symlink_outside_source_root(self):
        outside = Path(self.temp.name) / "OutsideProvider"
        outside.mkdir()
        (outside / "integration.json").write_text(json.dumps({"scripts": ["x.js"]}), encoding="utf-8")
        (outside / "x.js").write_text("unsafe()", encoding="utf-8")
        try:
            (self.root / "Linked").symlink_to(outside, target_is_directory=True)
        except (OSError, NotImplementedError):
            self.skipTest("symlinks unavailable")
        result = self.run_builder()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("provider folder escapes", result.stderr)


if __name__ == "__main__":
    unittest.main()
