# Feature catalog

`features.json` exports the existing macOS patch registrations into a portable
Settings catalog. It contains the same keys, titles, descriptions, groups,
ordering, defaults, requirements and visibility conflicts, plus the existing
Group Tabs by Domain command. It contains no platform-specific view selectors.

After changing Mac registrations, run:

```sh
python3 scripts/sync-feature-catalog.py
python3 scripts/sync-feature-catalog.py --check
```

The Mac registrations remain authoritative during this migration. The Windows
Settings build compiles this JSON into its native row definitions. This shares
metadata; it does not automatically port behavior. Windows adapters must report
capabilities and implement each feature. A Mac default of on is not permission
to enable a feature whose Windows implementation is unavailable.

Current Windows support: `hideSidebarButton` has a session adapter. The other
eight patches and the tab-grouping command are unavailable. They are shown in
the experimental native Settings panel with disabled controls.
