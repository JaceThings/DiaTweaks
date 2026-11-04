#!/usr/bin/env python3
"""Bundle provider JavaScript declared by integration.json files into deterministic JSON."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


DEFAULT_SOURCE_ROOT = Path(__file__).resolve().parents[1] / "src" / "dylib" / "Patches"


class BuildError(Exception):
    pass


def read_provider(folder: Path) -> str:
    config_path = folder / "integration.json"
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise BuildError(f"{config_path}: cannot read valid UTF-8 JSON: {error}") from error
    if not isinstance(config, dict):
        raise BuildError(f"{config_path}: expected a JSON object")
    scripts = config.get("scripts")
    if not isinstance(scripts, list) or not scripts:
        raise BuildError(f"{config_path}: 'scripts' must be a non-empty array of relative .js paths")

    root = folder.resolve()
    parts: list[str] = []
    for name in scripts:
        if not isinstance(name, str) or not name or "\\" in name:
            raise BuildError(f"{config_path}: script paths must be non-empty relative paths")
        relative = Path(name)
        if relative.is_absolute() or relative.suffix != ".js":
            raise BuildError(f"{config_path}: invalid JavaScript path {name!r}")
        path = (folder / relative).resolve()
        try:
            path.relative_to(root)
        except ValueError as error:
            raise BuildError(f"{config_path}: script path escapes provider folder: {name!r}") from error
        if not path.is_file():
            raise BuildError(f"{config_path}: script file is missing: {name!r}")
        try:
            parts.append(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError) as error:
            raise BuildError(f"{path}: cannot read UTF-8 JavaScript: {error}") from error
    return "\n;\n".join(parts)


def build_mapping(source_root: Path) -> dict[str, str]:
    if not source_root.is_dir():
        raise BuildError(f"source root is not a directory: {source_root}")
    root = source_root.resolve()
    result: dict[str, str] = {}
    for folder in sorted(source_root.iterdir(), key=lambda path: path.name):
        if not folder.is_dir():
            continue
        resolved = folder.resolve()
        try:
            resolved.relative_to(root)
        except ValueError as error:
            if (folder / "integration.json").exists():
                raise BuildError(f"provider folder escapes source root: {folder.name!r}") from error
            continue
        if (resolved / "integration.json").is_file():
            result[folder.name] = read_provider(resolved)
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="output JSON file")
    parser.add_argument("--source-root", type=Path, default=DEFAULT_SOURCE_ROOT,
                        help="provider folder root (default: src/dylib/Patches)")
    args = parser.parse_args(argv)
    try:
        mapping = build_mapping(args.source_root)
        encoded = json.dumps(mapping, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("w", encoding="utf-8", newline="\n") as output:
            output.write(encoded)
    except (BuildError, OSError) as error:
        print(f"build-integration-scripts: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
