/* t3.chat sidebar metadata adapter. This intentionally reads no account/auth storage. */
(function (root, factory) {
  const runtime = typeof module === "object" && module.exports
    ? require("../../TabIntegrations/ConversationRuntime.js")
    : root.DPConversationRuntime;
  const api = factory(runtime);
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.DiaT3PreviewCollector = api;
  if (root && root.document && runtime && !root.DiaT3Preview && api.validPageURL(root.location.href))
    root.DiaT3Preview = api.install(root, runtime);
})(typeof globalThis !== "undefined" ? globalThis : this, function (defaultRuntime) {
  "use strict";

  const ORIGIN = "https://t3.chat";
  const ID = /^[A-Za-z0-9_-]{1,128}$/;
  const ROW_SELECTOR = 'a[data-testid^="thread-link-"][href]';
  const SIDEBAR_SELECTOR = '[data-sidebar="sidebar"]';

  function conversationURL(id, supplied) {
    if (typeof id !== "string" || !ID.test(id)) return null;
    const expected = ORIGIN + "/chat/" + id;
    if (supplied == null) return expected;
    if (typeof supplied !== "string") return null;
    try {
      const url = new URL(supplied);
      if (url.origin !== ORIGIN || url.username || url.password || url.search || url.hash
          || url.pathname !== "/chat/" + id) return null;
      return expected;
    } catch (_) { return null; }
  }

  function validPageURL(value) {
    try {
      const url = new URL(value);
      return url.origin === ORIGIN && !url.username && !url.password && !url.search && !url.hash
        && (url.pathname === "/" || /^\/chat\/[A-Za-z0-9_-]{1,128}$/.test(url.pathname));
    } catch (_) { return false; }
  }

  function read(document, guestDocumentScope) {
    if (!document || typeof document.querySelector !== "function")
      return { sourceStatus: "unavailable", scopeKey: null, rows: [] };
    const guestLogin = document.querySelector('[data-sidebar="footer"] a[aria-label="Login"]');
    const scopeKey = guestLogin && typeof guestDocumentScope === "string" ? guestDocumentScope : null;
    const sidebar = document.querySelector(SIDEBAR_SELECTOR);
    if (!sidebar || typeof sidebar.querySelectorAll !== "function")
      return { sourceStatus: "unavailable", scopeKey, rows: [] };

    const links = sidebar.querySelectorAll(ROW_SELECTOR);
    const candidates = Array.from(links || []).slice(0, 120);
    const rows = [];
    const seen = new Set();
    for (const link of candidates) {
      let href;
      try { href = new URL(link.getAttribute("href"), ORIGIN); } catch (_) { continue; }
      if (href.origin !== ORIGIN || href.username || href.password || href.search || href.hash) continue;
      const match = /^\/chat\/([A-Za-z0-9_-]{1,128})$/.exec(href.pathname);
      if (!match || seen.has(match[1])) continue;
      if (link.getAttribute("data-testid") !== "thread-link-" + match[1]) continue;

      const row = typeof link.closest === "function" ? link.closest('[data-sidebar="menu-item"]') : null;
      if (!row || typeof row.querySelector !== "function") continue;
      const input = row.querySelector('input[aria-label="Thread title"][type="text"]');
      // The title is an input value on t3.chat; textContent is empty by design.
      const title = input && typeof input.value === "string" ? input.value.trim() : "";
      if (!title || title.length > 300) continue;
      seen.add(match[1]);
      rows.push({
        id: match[1], title, url: conversationURL(match[1], href.href),
        activity: "unknown", unread: false
      });
    }
    const busy = typeof sidebar.querySelector === "function"
      && !!sidebar.querySelector('[role="progressbar"], [aria-busy="true"], .animate-spin');
    const sourceStatus = rows.length ? "ready" : !candidates.length && guestLogin && !busy ? "empty" : "unavailable";
    return { sourceStatus, scopeKey, rows };
  }

  function install(win, runtime) {
    runtime = runtime || (win && win.DPConversationRuntime) || defaultRuntime;
    if (!win || !runtime || typeof runtime.create !== "function")
      throw new TypeError("t3.chat preview requires DPConversationRuntime");
    if (!validPageURL(win.location.href)) return null;
    if (win.DiaT3Preview?.version === 1) return win.DiaT3Preview;
    // This opaque token exists only in this JS document. It is not account identity and
    // is withdrawn as soon as the observed guest Login link disappears.
    const guestDocumentScope = "guest-document:" + Date.now().toString(36) + ":" + Math.random().toString(36).slice(2);
    const adapter = runtime.create({
      window: win, namespace: "DiaT3Preview", origin: ORIGIN, version: 1,
      read: () => read(win.document, guestDocumentScope), conversationURL, persistentPins: false,
    });
    win.DiaT3Preview = adapter;
    return adapter;
  }

  return { ORIGIN, conversationURL, validPageURL, read, install };
});
