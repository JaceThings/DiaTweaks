# ChatGPT tab preview

An experimental, off-by-default patch for `chatgpt.com`. Enable **ChatGPT Tab Preview** in Settings → Patches → Sidebar & Tab Bar, or run `diatweaks enable chatgptPreview` after installing a build containing it.

Hover a regular tab or Favorite to show three recent chats from ChatGPT's sidebar. The preview's pin button reserves one separate row; its conversation is removed from the three recent rows. Clicking anywhere in a conversation row activates the hovered tab and navigates it, keeping its Dia profile. The card closes first; navigation waits until Dia reports the exact tab as selected. The pin button remains a separate click target. ChatGPT's own pin buttons are not changed.

The list is hosted inside Dia's own `TabHoverMenuPopoverWindow` and `TabHoverMenuPopoverWindowRootViewController`. Their `ARCUI.PopoverBackgroundView` supplies the material, borders, corners and shadow. The patch adds its conversation content to that component's content view through AppKit; it does not write private Swift fields or register a fabricated `TabCustomPreviewProvider`. The tab tracking, positioning and dismissal logic are still supplied by this patch. While its card is active, the original tab-info card for that exact tab is suppressed to avoid overlapping previews. Conversation rows highlight on hover; the compact list truncates long titles. This host was exercised on Dia 1.55.1 and is a private implementation detail that a Dia update can change. If its classes or content slot are missing, the patch does not substitute a generic popover.

Fade-in and fade-out match the native preview's observed opacity animation on Dia 1.55.1: 100 ms with cubic Bézier control points `(0.25, 0.46, 0.45, 0.94)`. The native background layer fades; the window is removed only after fade-out completes. A dismissal in progress does not intercept clicks, and reopening the same host invalidates the old dismissal. Native spring/position animations are not reproduced. These fade lifecycle transitions need a live Dia check; the standalone native row tests do not cover them.

The recent list follows the sidebar's regular chat order. Project groups and ChatGPT's built-in pinned section are excluded, since their sidebar positions do not establish recency. This is not an account-wide history API or a background history download.

## Status and pins

- A spinner follows the conversation row's native `role="status"` / `aria-label="Working"` indicator. It covers thinking, tools and output without guessing from message text or the composer state.
- A blue dot follows ChatGPT's native completed/unread marker in that conversation row (`size-2 rounded-full bg-info-solid`). Working takes precedence over the dot. The dot disappears when the website removes it; the preview does not maintain an independent unread counter or mark replies read on hover.
- Missing conversation rows, discarded renderers, unsupported markup and stale observations have unknown status. Duplicate ChatGPT tabs on the exact same URL in one window are ambiguous: their snapshots are withheld rather than using another document’s indicators. If Dia’s scripting URL stays at the homepage after entering a conversation, the single-tab/single-page case can still resolve within that same window. The preview does not infer completion from missing output or message counts. An unopened conversation can still show status if ChatGPT supplies its indicator in the sidebar.
- Dia's isolated JavaScript environment may not expose an account identifier. In that case the saved pin contains only its conversation ID. It is displayed only when the current page's sidebar resolves that ID, taking the title from the current page. A pin outside the loaded sidebar will remain hidden until its entry is loaded again.
- Status comes from the same sidebar snapshot as the displayed list. Other documents' message observations do not override those website indicators.

Only the preview's dedicated local-storage keys are accessed. The adapter does not read authentication tokens, cookies, message text or message IDs, call private history endpoints, or send data to another service. Disabling the patch closes its hover windows, removes its tracking areas and disposes its page observers.


## Cache and unavailable pages

Successful sidebar observations populate the shared `DPTabIntegrationCache` memory cache before the hover card opens. The cache belongs to a live native page and its browser/account scope. It keeps the last validated titles and preview pin across temporary fetch failures and missing sidebar markup. Cached metadata expires after an hour without a successful observation. A confirmed empty sidebar replaces the previous list. Observed account-scope changes, native URL navigation, page disposal, leaving the site and disabling the patch clear it; moving the page to another browser cannot reuse it. This cache is not shared with another tab or written to disk, and does not survive quitting Dia.

Cached lists show **Cached** in the header. Their working/unread indicators are suppressed, and pin editing is disabled until fresh data returns; conversation links remain usable. A cache miss shows loading for at most six seconds after opening the card, then an unavailable message directing you to open ChatGPT. Ambiguous or entirely untracked pages do not borrow another page’s cache.

## Checks

Run `make` and `make test-chatgpt` on Apple Silicon macOS with Command Line Tools and Node.js. The latter runs the pure state and DOM-adapter suites, then compiles and runs native URL/transport/row checks. It does not replace or reopen your installed Dia.

For acceptance testing in Dia, test both sidebar and top tabs, regular tabs and Favorites, and the patch on and off. Check hover dismissal, changing the preview pin, navigation, generating in a background conversation, and seeing its completed reply. Repeat after signing out or changing accounts. The generic `make test` verifies installed tracking areas; it cannot establish authenticated ChatGPT data or output-state behavior without those interactions.

When a ChatGPT tab exists, the generic `make test` also creates an undisplayed native host and verifies that the conversation content fits its content slot. This checks the real Dia components rather than mock classes. That command relaunches Dia and replaces the installed library, so use it only in a dedicated local test installation.

The repository requires a maintainer-created wiki page and preview recording before a new tweak can merge. This local note does not replace that release requirement.
