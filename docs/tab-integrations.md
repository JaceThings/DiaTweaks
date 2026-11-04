# Website tab integrations

Website previews use normal StdPatch patches. Each website owns one folder in `src/dylib/Patches/` and one `DP_PATCH`: its Settings row, saved switch, availability and verification come from that existing mechanism. ChatGPT is the first included adapter, disabled by default. There is no separate plugin loader or configuration format for Settings.

`src/dylib/TabIntegrations/TabIntegrations.h` is the shared API. It supplies:

- One registry of enabled website descriptors, with exact HTTPS origin allowlists and an optional path filter. If two enabled adapters match the same URL, neither handles it.
- Tab tracking for regular tabs and Favorites; a Dia native hover window, centered positioning, dismissal and the observed native opacity fade. It suppresses the original info card only for the matching tab while the integration is showing.
- Exact-tab selection before navigation. Adapters call `navigateToURL:` instead of changing a tab URL themselves.
- Per-page script installation, version checks, snapshots and JSON commands. A shared polling loop runs while a script adapter is enabled. Switching origins or disabling an adapter invalidates cached results and pending callbacks; another adapter remains active.
- Compact native rows with whole-row clicks, hover feedback, title truncation, optional working/unread status and a separate optional pin action. Working takes precedence over unread.

The host uses private Dia classes. Missing host components disable the adapter rather than replacing the UI with a generic popover. A website's selectors and snapshot schema belong to its own folder, not the shared framework. This API is source-level infrastructure within DiaTweaks, not a stable binary SDK for third-party dylibs.

## Add a website

The small, compilable example is [`tests/fixtures/tab-integrations/ExamplePreview`](../tests/fixtures/tab-integrations/ExamplePreview). Copy that folder into `src/dylib/Patches/`, change the website, identifiers and content, then run `make`. No Makefile, Settings or shared hook changes are needed. The fixture itself is outside the shipped source tree, so it does not add an Example setting to releases.

1. Define a static `DPTabIntegration` and a normal `DP_PATCH`. Wire `.install`, `.apply` and `.verify` to `DPTabIntegrationInstall`, `DPTabIntegrationApply` and `DPTabIntegrationVerify`. Keep the descriptor alive for the process lifetime. Give the patch a unique key and the page API a unique namespace.
2. List bare HTTPS origins with `DPIntegrationOrigins("https://example.com")`. Scheme, host and effective port must match; credentials and lookalike hosts are rejected. If needed, supply `.matchesURL` to further restrict paths. It cannot expand the origin allowlist.
3. Subclass `DPTabIntegrationPreview`. Build AppKit content in `loadView`/`viewDidLoad`, update `preferredContentSize` when it changes, and release timers or subscriptions in `stop`. The host calls `stop` on dismissal. Use `self.integration`, `self.tab` and `DPTabIntegrationTabWindow` to select the relevant window's pages. Prefer `DPTabIntegrationPageForTab(site, tab)` for selection. It rejects ambiguous scripting/page URLs; a stale scripting URL is tolerated only when the same window has exactly one adapter tab and one page for that origin. `DPTabIntegrationPageForURL` remains available for strict URL-only selection.
4. For DOM data, add `integration.json`, for example `{"scripts":["Collector.js"]}`. Scripts run in the listed order and are bundled automatically into the dylib; they are local trusted code, not downloaded from the website. `scriptKey` is the folder name. Native-only previews omit the script fields and manifest.
5. Install `window.YourUniqueNamespace = { version: 1, snapshot() { return {...}; }, dispose() {...} }`. `snapshot()` must synchronously return JSON metadata. Make installation idempotent. The shared bridge disposes a mismatched previous version before installing the new one. `dispose()` must disconnect every observer, timer and listener the adapter owns.
6. Read `DPTabIntegrationPages(site, window)` and each page's `snapshot`. `DPTabIntegrationRead(page)` requests an immediate refresh. To invoke an adapter action, use `DPTabIntegrationCommand(page, @"method", @[argument])`; arguments are JSON data and its resulting snapshot refreshes the cache. The bridge rejects stale callbacks and checks the origin again inside the page. Adapters must still validate all returned fields before displaying or navigating them.

## Shared cache

`DPTabIntegrationCache` stores the last accepted metadata in memory. It is bound to the native page, provider and browser; it never shares values merely because two tabs have the same URL. `freshFor` defaults to six seconds and `maxAge` to one hour; adapters can override both. Observing a different scope clears the old value even when the new fetch has no usable data. Native navigation, page disposal and disabling the provider invalidate its cache automatically, without clearing other providers.

Use `.snapshotChanged(page)` to validate a received snapshot and update the cache before any card opens. A nil snapshot means navigation/disposal; temporary read failure leaves the last transport snapshot in place. Only the adapter decides whether the website supplied usable data and what identifies its account scope. Nil scope means no new identity observation, as with a failed fetch; it does not confirm logout. If identity is lost without a replacement scope, call `invalidate` instead of reusing the old value:

```objc
DPTabIntegrationCache *cache = DPTabIntegrationCacheForPage(page);
[cache observeValue:validatedMetadataOrNil scope:accountScope receivedAt:page.receivedAt];
NSDictionary *metadata = [cache valueAtTime:NSDate.timeIntervalSinceReferenceDate];
BOOL live = [cache isFreshAtTime:NSDate.timeIntervalSinceReferenceDate];
```

Pass nil metadata for a temporary failure or missing markup; pass an empty dictionary/array field only when the site confirmed an empty result. Use `live` to distinguish cached content and suppress website-specific status indicators or actions that require a live page. The ExamplePreview fixture uses this same API with a title dictionary, while ChatGPT uses conversation metadata and its observed account scope. The common cache contains no ChatGPT fields or selectors and does not write data to disk.

The shared transport accepts a dictionary snapshot up to 256 KiB. It does not impose a website-specific schema or define what “unread” means. Use the site's own indicators; stale or missing data must remain unknown. Keep collection limited to the metadata needed for the preview. Do not collect message bodies, credentials or account-wide history to implement a tab list. Document any adapter-owned storage and make account boundaries explicit.

## Checks

Run `make test-integrations test-chatgpt` and `make`. The first target checks deterministic script discovery, manifest validation, two-provider routing and isolation, toggle cleanup, stale callbacks, origin/namespace guards and command serialization. It also compiles the second-site fixture against the public API. The ChatGPT target checks its state, DOM adapter and native rows. Neither target installs or relaunches Dia.

Before submitting, follow `CONTRIBUTING.md`: exercise both sidebar and top tabs, each tweak on and off, regular tabs and Favorites. Test navigation, leaving the origin, repeated hover/dismissal, page reload and disabled cleanup. Add adapter-specific fixtures, including missing markup, and record the visible feature/animation in Dia. `make test` installs the build and relaunches Dia; use a dedicated test installation if you need to preserve your working one. Automated fixtures cannot establish compatibility with a live website or all native hover behavior.
