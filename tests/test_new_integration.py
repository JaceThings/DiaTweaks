from __future__ import annotations

import importlib.util
from importlib.machinery import SourceFileLoader
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/new-integration"
SPEC = importlib.util.spec_from_loader("new_integration", SourceFileLoader("new_integration", str(SCRIPT)))
new_integration = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(new_integration)


class NewIntegrationTests(unittest.TestCase):
    def test_generates_default_and_custom_adapters(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            default = new_integration.generate(root, "ExamplePreview", "https://example.com")
            custom = new_integration.generate(root, "CustomPreview", "https://shop.example:8443", custom=True)

            self.assertEqual(set(path.name for path in default.iterdir()),
                             {"ExamplePreview.m", "Collector.js", "integration.json", "page.html", "test-collector.js"})
            config = json.loads((default / "integration.json").read_text())
            self.assertEqual(config, {"runtime": True, "scripts": ["Collector.js"]})
            source = (default / "ExamplePreview.m").read_text()
            self.assertIn('DPIntegrationOrigins("https://example.com")', source)
            self.assertIn("DPTabIntegrationListPreview", source)
            self.assertIn("context.URLString", source)
            self.assertIn("DPTabIntegrationDefaultEmptyMessage", source)
            custom_source = (custom / "CustomPreview.m").read_text()
            self.assertIn("DPTabIntegrationPreview", custom_source)
            self.assertNotIn("DPTabIntegrationListPreview", custom_source)
            self.assertIn("- (void)loadView", custom_source)
            self.assertIn("- (void)update", custom_source)
            self.assertIn('DPIntegrationOrigins("https://shop.example:8443")', custom_source)

    def test_cli_root_option_and_origin_canonicalization(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            result = subprocess.run([str(SCRIPT), "Example", "--origin", "https://[::1]:443", "--root", temporary],
                                    check=True, capture_output=True, text=True)
            self.assertIn("created", result.stdout)
            source = Path(temporary) / "src/dylib/Patches/Example/Example.m"
            self.assertIn('DPIntegrationOrigins("https://[::1]")', source.read_text())

    def test_name_origin_and_overwrite_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for name in ("../Escape", "lowercase", "A" * 65, "Bad-Name"):
                with self.subTest(name=name), self.assertRaises(ValueError):
                    new_integration.generate(root, name, "https://example.com")
            for origin in ("http://example.com", "https://user@example.com", "https://example.com/a",
                           "https://example.com?x=1", "https://example.com:bad", "https://example.com:0"):
                with self.subTest(origin=origin), self.assertRaises(ValueError):
                    new_integration.generate(root, "SafeName", origin)
            new_integration.generate(root, "SafeName", "https://example.com")
            with self.assertRaises(FileExistsError):
                new_integration.generate(root, "SafeName", "https://example.com")
            self.assertFalse((root / "src/dylib/Patches/Escape").exists())

    def test_atomic_publish_refuses_existing_empty_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            parent = Path(temporary)
            source, target = parent / "stage", parent / "target"
            source.mkdir()
            target.mkdir()
            with self.assertRaises(FileExistsError):
                new_integration.rename_directory_exclusive(source, target)
            self.assertTrue(source.is_dir())
            self.assertTrue(target.is_dir())

    @unittest.skipUnless(shutil.which("clang") and __import__("sys").platform == "darwin",
                         "Objective-C fixture compilation requires macOS clang")
    def test_both_generated_variants_compile(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            default = new_integration.generate(root, "GeneratedList", "https://example.com")
            custom = new_integration.generate(root, "GeneratedCustom", "https://example.org", custom=True)
            for source in (default / "GeneratedList.m", custom / "GeneratedCustom.m"):
                subprocess.run([
                    "clang", "-fsyntax-only", "-fobjc-arc", "-arch", "arm64",
                    "-mmacosx-version-min=14.0", "-Isrc/dylib", str(source),
                ], cwd=ROOT, check=True, capture_output=True, text=True)

    @unittest.skipUnless(shutil.which("node"), "generated collector fixture requires Node.js")
    def test_generated_collectors_run_with_synthetic_fixture_in_both_modes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            folders = [
                new_integration.generate(root, "GeneratedList", "https://example.com"),
                new_integration.generate(root, "GeneratedCustom", "https://example.org", custom=True),
            ]
            runtime = ROOT / "src/dylib/TabIntegrations/AdapterRuntime.js"
            for folder in folders:
                result = subprocess.run(["node", str(folder / "test-collector.js"), str(runtime)],
                                        cwd=ROOT, check=True, capture_output=True, text=True)
                self.assertIn("collector fixture passed", result.stdout)

    def test_fixture_uses_synthetic_only_data(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            folder = new_integration.generate(Path(temporary), "SafeExample", "https://example.com")
            html = (folder / "page.html").read_text()
            self.assertIn("Synthetic SafeExample page", html)
            self.assertNotIn("https://", html)


if __name__ == "__main__":
    unittest.main()
