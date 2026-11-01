#!/usr/bin/env python3
"""Export Settings metadata without executing the macOS patch code."""
import argparse
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'shared' / 'features.json'


def string_field(body, name, default=''):
    match = re.search(r'\.' + name + r'\s*=\s*@("(?:[^"\\]|\\.)*")', body)
    return json.loads(match[1]) if match else default


def catalog():
    features = []
    for path in sorted((ROOT / 'src/dylib/Patches').rglob('*.m')):
        source = path.read_text(encoding='utf-8')
        registrations = list(re.finditer(r'DP_PATCH\(\w+\)\s*\{(.*?)\n\};', source, re.S))
        if len(registrations) != len(re.findall(r'^\s*DP_PATCH\(\w+\)', source, re.M)):
            raise ValueError(f'Unrecognized patch registration format in {path}')
        for registration in registrations:
            body = registration[1]
            order = re.search(r'\.order\s*=\s*(\d+)', body)
            if not order:
                raise ValueError(f'Missing order in {path}')
            feature = {key: string_field(body, key) for key in
                       ('key', 'title', 'detail', 'section', 'requires', 'disabledBy')}
            if not all(feature[k] for k in ('key', 'title', 'detail')):
                raise ValueError(f'Missing feature metadata in {path}')
            feature.update(kind='toggle', order=int(order[1]),
                           defaultOn=bool(re.search(r'\.defaultOn\s*=\s*YES', body)),
                           source=path.relative_to(ROOT).as_posix())
            features.append(feature)
    by_key = {feature['key']: feature for feature in features}
    if not features or len(by_key) != len(features):
        raise ValueError('Empty catalog or duplicate feature key')
    for feature in features:
        for field in ('requires', 'disabledBy'):
            if feature[field] and feature[field] not in by_key:
                raise ValueError(f"Unknown {field}: {feature[field]}")
        seen = {feature['key']}
        parent = feature
        while parent['requires']:
            parent = by_key[parent['requires']]
            if parent['key'] in seen:
                raise ValueError('Feature dependency cycle')
            seen.add(parent['key'])
        if not feature['section']:
            feature['section'] = parent['section'] or 'Other'
    overview = ROOT / 'src/dylib/Settings/Overview.m'
    command = re.search(r'DPGroupTabsItem\s*=\s*\{\s*NULL,\s*@(".*?"),\s*@(".*?"),\s*@(".*?"),',
                        overview.read_text(encoding='utf-8'))
    if not command:
        raise ValueError('Group Tabs command metadata not found')
    features.append(dict(key=json.loads(command[1]), title=json.loads(command[2]),
                         detail=json.loads(command[3]), section='Commands', kind='command',
                         order=100, requires='', disabledBy='', defaultOn=False,
                         source=overview.relative_to(ROOT).as_posix()))
    return dict(schemaVersion=1, features=sorted(features, key=lambda f: f['order']))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    text = json.dumps(catalog(), ensure_ascii=False, indent=2) + '\n'
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text(encoding='utf-8') != text:
            raise SystemExit('Feature catalog is stale: run scripts/sync-feature-catalog.py')
        print('Feature catalog matches the macOS registrations')
    else:
        OUTPUT.parent.mkdir(exist_ok=True)
        OUTPUT.write_text(text, encoding='utf-8')
        print(f'Wrote {OUTPUT}')
