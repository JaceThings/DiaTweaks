/* Metadata-only Claude sidebar reader and shared conversation runtime adapter. */
(function (root, factory) {
  const runtime = typeof module === "object" && module.exports
    ? require("../../TabIntegrations/ConversationRuntime.js")
    : root.DPConversationRuntime;
  const api = factory(runtime);
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root && root.document && runtime && !root.DiaClaudePreview) {
    root.DiaClaudePreview = api.install(root);
  }
})(typeof globalThis !== "undefined" ? globalThis : this, function (runtime) {
  "use strict";

  const ORIGIN = "https://claude.ai";
  const ID = /^[A-Za-z0-9_-]{1,128}$/;
  const MAX_ROWS = 120;

  function conversationURL(id, value) {
    if (typeof id !== "string" || !ID.test(id) || typeof value !== "string" || value.length > 4096) return null;
    let url;
    try { url = new URL(value, ORIGIN); } catch (_) { return null; }
    if (url.origin !== ORIGIN || url.username || url.password || url.search || url.hash || url.pathname !== "/chat/" + id) return null;
    return url.href;
  }

  function titleFromRow(row) {
    if (!row || typeof row.querySelector !== "function") return "";
    const label = row.querySelector("[data-row-label] .dframe-fade-label");
    if (!label || typeof label.cloneNode !== "function") return "";
    const copy = label.cloneNode(true);
    if (typeof copy.querySelectorAll === "function") {
      for (const extra of Array.from(copy.querySelectorAll('[role="status"], .sr-only'))) {
        if (extra && typeof extra.remove === "function") extra.remove();
      }
    }
    return typeof copy.textContent === "string" ? copy.textContent.trim() : "";
  }

  function read(win) {
    if (!win || !win.location || win.location.origin !== ORIGIN || !win.document) {
      return { scopeKey: null, sourceStatus: "unavailable", rows: [] };
    }
    if (win.location.pathname === "/login" || win.location.pathname.startsWith("/login/")) {
      return { scopeKey: null, sourceStatus: "signed-out", rows: [] };
    }
    const sidebar = win.document.querySelector("aside.dframe-sidebar");
    const recents = sidebar && sidebar.querySelector('[data-testid="sidebar-recents"]');
    if (!recents) return { scopeKey: null, sourceStatus: "unavailable", rows: [] };

    const rows = [], seen = new Set();
    function collectAnchors(container, recent) {
      if (!container || rows.length >= MAX_ROWS) return;
      const anchors = container.querySelectorAll('a[href]');
      for (const anchor of Array.from(anchors || []).slice(0, MAX_ROWS - rows.length)) {
        const rawURL = typeof anchor.getAttribute === "function" ? anchor.getAttribute("href") : anchor.href;
        let url;
        try { url = new URL(rawURL, ORIGIN); } catch (_) { continue; }
        const match = /^\/chat\/([A-Za-z0-9_-]{1,128})$/.exec(url.pathname);
        if (!match || !conversationURL(match[1], rawURL) || seen.has(match[1])) continue;
        const row = typeof anchor.closest === "function" ? anchor.closest("[data-row]") : null;
        const title = titleFromRow(row);
        if (!title || title.length > 300) continue;
        seen.add(match[1]);
        const working = !!(row && typeof row.querySelector === "function" && row.querySelector('[data-attention="working"]'));
        rows.push({ id: match[1], title, url: ORIGIN + "/chat/" + match[1], activity: working ? "generating" : "unknown", unread: false, recent });
      }
    }
    collectAnchors(recents, true);
    const pinned = sidebar.querySelector('[data-testid="sidebar-pinned"]');
    collectAnchors(pinned, false);
    // No empty-account marker has been verified; a mounted but blank sidebar may still be loading.
    return { scopeKey: null, sourceStatus: rows.length ? "ready" : "unavailable", rows };
  }

  function install(win) {
    if (!runtime || typeof runtime.create !== "function") throw new TypeError("conversation runtime is unavailable");
    if (!win || !win.document) throw new TypeError("install requires a browser window");
    const adapter = runtime.create({
      window: win,
      namespace: "DiaClaudePreview",
      origin: ORIGIN,
      read: function () { return read(win); },
      conversationURL
    });
    return adapter;
  }

  return { install, read, conversationURL };
});
