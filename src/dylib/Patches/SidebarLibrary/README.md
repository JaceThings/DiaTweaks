# Sidebar Library

An optional native AppKit Library beside the current page. Enable **Sidebar Library** in DiaTweaks settings. The default shortcut is ⇧⌘L and can be changed in the same settings pane.

- Media, Downloads and native archived tabs have independent searches and section filters where appropriate.
- The footer entry opens Library in vertical tabs; the trailing header entry supports horizontal tabs. Back returns to the original footer position.
- Recent-download hover preview is enabled by default and has its own **Recent downloads preview** switch. Its file rows support opening and context menus.
- Media uses white-backed frames, centered whole-frame hover growth, native file URL dragging, Quick Look, and a Refresh recovery action. Downloads and Archive use neutral row selection and native drag payloads.
- Active downloads show circular progress and readable time estimates. Progress updates keep completed thumbnails and visible rows in place.
- Category icons follow the native profile accent; utility controls use neutral label contrast at a 16-point glyph size. The selected layered-pages entry icon falls back to the original books symbol if unavailable.
- First-space edge scrolling follows the gesture continuously, including reversal and cancellation. During a transition, captured native sidebar surfaces move beside Library; native view layout cannot reset their positions and expose overlapping pins. Discrete swipe events remain a fallback for devices without a phased scroll stream.

## Data and lifecycle

Downloads come from Dia's native download bridge and stay within the selected profile. Media combines completed image/video download records across all normal profiles; private contexts are excluded. There is no demo-only filter or scan of unrelated Desktop files. Older unavailable-file records remain visible with a placeholder and an availability tooltip. The active scripting profile name is resolved against Chromium's profile registry so delayed browser attachments cannot show another profile's Downloads or Archive. Media and tables use separate immutable snapshots; reloads wait until a drag ends.

Library hides are reversible metadata: Options offers Show Hidden Items and Restore All Hidden Items. Clear Library Archive hides that profile's records from Library after confirmation; it does not delete Dia's native archive/history. Archive controls are therefore labeled Hide and Open in New Tab, with fast accessible tooltips. Downloads Move to Trash uses the native recoverable Trash action.

The default-on **Thanos removal effect** child setting controls all Library hide/clear dust. Turning it off removes immediately and cleans up any active effect. Particles sample the correctly oriented source, drift upward-right, and fade over about 0.82 seconds with a shared short-lived clock and an 8,000-particle total budget. Reduce Motion also skips the effect.

Thumbnail decoding has two workers and a 24 MB cache; all coalesced callers complete. Favicons use four workers, origin/profile coalescing, an 8 MB cache, short retryable misses, and a read-only native database fallback. Work starts from native changes or visible requests, with no periodic network/file polling. Horizontal grain reuses the upstream Sidebar Grain renderer; the inner rounded corner belongs to the content surface beside the navigation rail.

Archive reads the current native profile's auto-archive store. It does not substitute browser history. Opening an archived item uses Dia's existing browser action. Library does not delete the original downloaded files or rewrite the native archive store.

Expanded geometry preserves native requested frames and restores them when Library closes, the sidebar hides or slides away, or the host moves to another window. Native background material fills the expanded region. Horizontal controls reserve room within the existing native tab header and coordinate with the optional Sidebar Navigation patch's layout notifications.

Programmatic transitions use a short-lived monitor clock with coalesced main-thread updates. It stops at completion/cancellation and retains an AppKit display-link fallback. Interactive gestures directly update progress instead of triggering a timed animation at the first scroll event. The full-width Library view moves through its real AppKit frame so scroll views paint the correct visible region during partial reveals; the website keeps its native viewport width and is translated aside. Reduce Motion settles immediately.

## Validation

Build with `make`. Run upstream/local checks with `make check`, and the isolated Library regression fixtures with:

```
scripts/check-sidebar-library
```

These fixtures exercise stable thumbnails across repeated download progress updates, progress/pause/completion, ETA units, scroll viewport right-edge geometry, partial/reversed/cancelled and overswiped gestures, delivery of unclaimed native scroll prefixes, joined-edge geometry, native hide/unhide and frame restoration, animation-clock cancellation, focus restoration, separate Media snapshots, obsolete collection indexes, missing/reappearing files, drag reload deferral, Refresh glyph centering and a small tilt/return, centered Media hover, and recent-card click/context-menu/accessibility routing. They use isolated AppKit views and disposable fixture files, without changing browser profiles or installed binaries.

Live compatibility evidence and the remaining manual interaction checks are recorded outside this module in `work/sidebar-library-checks/`. Diagnostic runners and state/timing exporters are compiled only with `DPLIBRARY_DIAGNOSTICS` or `DPLIBRARY_FOLLOWUP`; they are absent from production builds.

The optional Tasks and Easels patches contribute their own Library sections. Spaces management and Boosts are not included.

Interaction reference: [Jitter deleted-file recovery](https://mobbin.com/screens/39776f3c-dbfa-45cb-8d42-850c8f5add9e) informed the separate hidden-items recovery flow; native Dia behavior remains authoritative.

Scrolling reconciles hover against actual pointer and clipped bounds as Library scroll positions change; it does not rely solely on tracking-area exit events or use a polling timer.

Downloads retains Dia’s history records for moved/deleted files, with crossed-out titles and an unavailable-file status. Native removals and replacement history snapshots (including empty snapshots) remove rows. File availability refreshes on opening Library, Refresh, and application activation; no continuous polling is used. Archive quick tips clear on pointer reconciliation, hidden/recycled buttons, detach and window key loss.
