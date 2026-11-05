# Website tab integrations

Website previews are ordinary `DP_PATCH` adapters. Each provider owns one folder in `src/dylib/Patches/`; its Settings switch, saved preference, availability checks, and verification use the existing patch system. Providers are disabled by default. There are no built-in Gmail, Amazon, or Google adapters; those names below are illustrative kinds of integrations only.

The native backend in `src/dylib/TabIntegrations/` owns origin routing, tab selection, hover presentation, lifecycle, snapshot transport, memory-only cache invalidation, command routing, and shared diagnostics. An adapter owns its website-specific selectors, snapshot schema, identity rules, navigation decisions, and actions. A provider can use the standard list UI or replace it with fully custom AppKit UI and data handling.

## Create an adapter

Run:

```sh
scripts/new-integration ExamplePreview --origin https://example.com
```

Or use `make integration NAME=ExamplePreview ORIGIN=https://example.com`; add `CUSTOM=1` for a fully custom view.

This creates `src/dylib/Patches/ExamplePreview/` with a normal `DP_PATCH`, `integration.json`, a JavaScript collector, a `DPTabIntegrationListPreview` subclass, and a local synthetic page/test runner. It requires a bare HTTPS origin, rejects invalid names and existing folders, and stages the complete output before installing it without replacing a concurrently-created folder. Use `--custom` to start with a plain `DPTabIntegrationPreview` subclass instead. `--root /path/to/checkout` is available for isolated generation and tests.

Generated adapters use `.requires = @"extendedIntegrations"` and `.section = @"Websites"`, placing their individual switches inside the existing **Extended Integrations** Settings page. The shared registry follows parent requirements when deciding whether a provider is active. Turning the master off clears dependent caches and stops collection without rewriting the website's saved switch; future adapters can use the same grouping.

The standard preview imports `TabIntegrations/ListPreview.h` and implements only `-listContent`. Return a `DPTabIntegrationListContent` populated with `DPTabIntegrationItem` rows. Items can have arbitrary subtitles and status text, working/unread/pinned states, a primary action, additional per-item actions, and custom row views through `viewProvider`. The shared renderer handles updates, layout, loading and empty states, whole-row primary actions, and separately targeted action buttons. Set `state` and `statusText` from the provider's validated data so cached, live, signed-out, unavailable, and empty states stay distinct.

For example, a provider can map any validated record shape into an item and bind actions to its own collector command:

```objc
DPTabIntegrationItem *item = [[DPTabIntegrationItem alloc] initWithTitle:validatedTitle];
item.identifier = validatedIdentifier;
item.subtitle = validatedSubtitle;
item.statusText = validatedStatus;
item.primaryAction = [[DPTabIntegrationAction alloc] initWithTitle:@"Open" handler:^(DPTabIntegrationContext *context, DPTabIntegrationItem *selected) {
    [context performCommand:@"openRecord" arguments:@[selected.identifier ?: @""]];
}];
item.actions = @[[[DPTabIntegrationAction alloc] initWithTitle:@"Refresh record" handler:^(DPTabIntegrationContext *context, DPTabIntegrationItem *selected) {
    [context performCommand:@"refreshRecord" arguments:@[selected.identifier ?: @""]];
}]];
```

Those command names and arguments are examples; define the matching handlers in that adapter's collector and validate the item fields before creating the row. A custom `viewProvider` can draw a different row for data that does not fit the standard title/subtitle layout. Put provider-owned data in `item.representedObject` for custom views and actions. Custom rows retain their preferred height; a fully custom preview controls its own width and layout, including scrolling or progress views.

The standard list shows two direct actions plus an overflow menu when more than three actions are supplied. Long lists scroll within a 420-point default viewport rather than silently dropping items; set `content.maximumHeight` to change that size, or zero to leave it unconstrained. Actions are disabled for cached data unless `enabledWhenCached` is explicitly enabled; safe open/navigation actions can opt in, while writes should usually wait for fresh data. Working/unread indicators are suppressed centrally for cached standard rows. A custom row owns its own interaction and stale-state policy. Set `content.revision` when hidden action payloads, handlers or custom view content change without a change to the standard display fields. This invalidates the rendered view without requiring the host to understand the provider's data schema.

For complete UI control, use `--custom`. The generated class subclasses `DPTabIntegrationPreview`; it creates its controls in `-loadView` and updates them in `-update`. Build any AppKit view and use `self.context` for the latest snapshot, cache, receive time, URL string, and diagnostics. Call `[self.context performCommand:arguments:]` for a website action and `[self.context refresh]` to request current data. The shared base calls `-update` on the common observation/timing cycle, including cache and loading deadlines; custom views can avoid rebuilding unchanged content. There is no need for a per-site polling timer. Navigate with `[self navigateToURL:...]`, which selects the exact tab before navigating.

Navigation resolves that tab's backing page after selection, revalidates its actual origin/provider, and loads the destination through ArcCore's native navigation controller. Dia's scripting `URL` property can remain stale and its setter can return without navigating; a focus change or a scripting getter is not sufficient evidence that a conversation opened. Live checks should compare the destination with the actual web contents or document URL. Missing or ambiguous backing pages fail closed.

For an unrelated custom schema, validate each value before use and choose any layout you need:

```objc
NSDictionary *snapshot = self.context.snapshot;
id count = snapshot[@"openCount"];
NSString *summary = [count isKindOfClass:NSNumber.class]
    ? [NSString stringWithFormat:@"%ld open records", [count integerValue]]
    : @"Open count unavailable";
self.summaryLabel.stringValue = summary;
```

Both variants come with a sample collector. Edit its `collect()` to return the smallest useful website-specific JSON object. Add command handlers in the runtime `commands` map when the preview needs actions; commands take JSON arguments, run within the provider's namespace and origin, then refresh the snapshot. The collector is trusted local code bundled with the dylib, never code downloaded from the site.

## Website data and identity

The manifest declares `{"runtime": true, "scripts": ["Collector.js"]}`. The build inserts the shared `DPTabIntegrationRuntime` helper before provider scripts. Use `DPTabIntegrationRuntime.create({version, collect, commands})` to build a collector, and guard its installation by namespace/version as the generated wrapper does. It returns a versioned snapshot/dispose interface and scopes any optional observers, event listeners, or timers to that collector. Its default collection policy is `every-read`; choose another policy only when the site signals all relevant changes and identity state reliably. `dirty` supports scoped mutation/event invalidation, `interval` also supports a periodic invalidation, and `maxAgeMs` bounds reuse between collections. The native bridge pulls synchronous JSON object snapshots; it does not offer a JavaScript-to-native push channel. Keep selectors, account semantics, and schema validation in the provider folder. Providers with an existing collector can omit `runtime` and implement the same snapshot/dispose contract directly, as ChatGPT does for its account and pin lifecycle.

The snapshot schema is deliberately arbitrary. Validate all fields in native code before displaying them, opening a URL, or enabling an action. Refresh account identity as part of collection; represent signed-out, unknown, and confirmed-empty states separately. Scope cached values to the account or workspace identity the site confirms, and invalidate them when identity is lost. Without a reliable identity rule, leave data uncached. Collect only the content needed for the preview and document those fields; the framework does not impose conversation-shaped data. Credentials and unrelated account history are outside the preview's purpose. A mail summary, order/tracking summary, or AI overview can each use a different schema and presentation.

### Optional conversation defaults

Conversation-style providers can opt into `{"runtime": true, "conversations": true, "scripts": ["Collector.js"]}`. This prepends `ConversationRuntime.js` after the general runtime. Create a collector with `DPConversationRuntime.create({window, namespace, origin, read, conversationURL})`; `read()` returns `{scopeKey, sourceStatus, rows}`, and `conversationURL(id, url)` must return a validated canonical conversation URL or null. The shared helper bounds and deduplicates metadata, exposes three recent rows plus one preview-only pin, gives working status precedence over unread, and persists only the pinned ID under a provider/account-specific storage key. A candidate with `recent: false` can resolve an existing preview pin without consuming a recent slot. Set `persistentPins: false` for a confirmed document-scoped guest context. An off-screen retained pin has unknown activity until the website exposes its status again.

The native `DPTabIntegrationConversationPreview` is an optional standard list renderer for the matching snapshot contract. Set `providerTitle` in `makePreview` before loading its view, and set the descriptor's `snapshotChanged` callback to `DPConversationSnapshotChanged`. The helper's snapshots contain `{scopeKey, sourceStatus, recent, pinned}`. Rows contain `{id, title, url, activity, unread}`; IDs use letters, digits, `_` and `-`, titles are bounded to 300 characters, activity is `generating`, `idle` or `unknown`, and unread is a boolean. The native renderer validates the envelope and URLs independently. Each site's descriptor should also filter allowed conversation paths.

Recognized source states are `ready`, `empty`, `unavailable`, `signed-out` and `identity-lost`. Only a confirmed, stable account/workspace `scopeKey` allows cached fallback or persistent pins. Unknown identity can show live rows and keep a document-local pin, but must remain uncached. Sign-out and identity loss clear retained metadata. Each adapter still owns its selectors, identity evidence and canonical routes; these defaults do not establish compatibility with a website. Read only the site's conversation metadata and explicit status markers, and leave unsupported statuses unknown. Custom schemas and views can continue to omit these conversation helpers entirely.

Use `DPIntegrationOrigins("https://example.com")` for exact HTTPS origin matching; a path filter can narrow a provider but cannot broaden its origin allowlist. Keep the static `DPTabIntegration` descriptor alive for process lifetime, use a unique patch key and JavaScript namespace, and wire its normal install/apply/verify callbacks to the shared backend. Use `.classes = DPTabIntegrationClasses` to inherit Dia dependency checks without copying private class names. A provider with no page collector can omit `scriptKey`, `scriptNamespace`, and `scriptVersion` and use native-only data.

## Lifecycle, cache and diagnostics

`self.context` exposes the resolved page's snapshot and the shared cache without exposing mutable transport state or private browser objects. The public page properties are read-only. The base preview registers a shared update subscription; `stop` and host dismissal cancel it. Custom subclasses that override `stop` should call `super` for base cleanup. All transport polls and preview subscriptions use the common scheduler. Optional descriptor fields `refreshInterval`, `backgroundRefreshInterval` and `requestTimeout` default to 0.5, 2 and 10 seconds; intervals are bounded by the scheduler's 0.5-second cadence. Failed reads back off without accelerating a deliberately slower provider. Retry and completion callbacks are guarded against navigation, disable and browser ownership changes.

Validate observations in `snapshotChanged(page)` and populate the cache before a preview opens:

```objc
DPTabIntegrationCache *cache = DPTabIntegrationCacheForPage(page);
[cache observeValue:validatedMetadata scope:confirmedAccountScope receivedAt:page.receivedAt];
```

Nil metadata means a temporary failure; confirmed empty data should be an explicit empty value in the provider's schema. A changed scope clears old metadata even if the new observation has no data. A missing scope does not prove logout: call `invalidate` when identity is known to be lost. The cache is per-page/provider/browser, memory-only, fresh for six seconds and retained for up to one hour by default; `freshFor` and `maxAge` are configurable. Native navigation, disposal, disable and ownership changes invalidate it. Read with `valueAtTime:` and `isFreshAtTime:` to map live/cached/missing data into your own content state.

Context diagnostics contain codes/counts/ages and cache state, with no page content or URLs. Codes include `reading`, `ready`, `not-requested`, `timeout`, `transport-unavailable`, `invalid-descriptor`, `script-unavailable`, `read-failed`, `disposed`, `no-provider`, `no-matching-page` and `disabled`. `ready` means the transport received a JSON object; the adapter must still distinguish unsupported markup, authentication state and empty data in its own schema. No matching page can also mean ambiguous duplicate tabs; another tab's cache is never borrowed.

## Verify and extend

The sanitized [`ExamplePreview` fixture](../tests/fixtures/tab-integrations/ExamplePreview) is kept outside the shipped patch tree. Its native preview renders a standard list, and its DOM collector reads only the page title. Use it as a second-provider compilation example; copy it into `src/dylib/Patches/` only when you want to enable the example patch in a local build.

Run the generated collector fixture with `node src/dylib/Patches/ExamplePreview/test-collector.js` after generating it in the source tree. It uses only the adjacent synthetic `page.html` and Node's built-in `vm` module. Run the scaffold checks with `python3 -B -m unittest discover -s tests -p 'test_new_integration.py'` and integration checks with `make test-integrations`. The scaffold tests validate names/origins, overwrite protection, output shape, run both generated collectors against synthetic data, and compile both generated Objective-C variants on macOS. The integration checks cover script bundling, routing, provider isolation, lifecycle, cache, and commands. Neither installs or relaunches Dia. A live-site test is still needed to check current markup, account transitions, navigation, and real hover behavior.
