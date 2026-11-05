/* Optional metadata-only conversation adapter: validation, identity and preview-only pins. */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.DPConversationRuntime = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  const ID = /^[A-Za-z0-9_-]{1,128}$/;
  function create(options) {
    const win = options.window;
    if (!win || win.location.origin !== options.origin || typeof options.read !== "function"
        || typeof options.conversationURL !== "function" || !options.namespace) {
      throw new TypeError("conversation adapter requires an exact origin, reader and URL validator");
    }
    let scope = null;
    let pinnedId = null;
    let pinned = null;
    let catalog = new Map();
    let disposed = false;
    let storageUnavailable = false;
    let actionable = false;

    function normalize(row) {
      if (!row || typeof row !== "object" || typeof row.id !== "string" || !ID.test(row.id)
          || typeof row.title !== "string") return null;
      const title = row.title.trim();
      if (!title || title.length > 300) return null;
      const canonical = options.conversationURL(row.id, row.url);
      let url;
      try { url = new URL(canonical); } catch (_) { return null; }
      if (!canonical || url.origin !== options.origin || url.username || url.password || url.search || url.hash) return null;
      const activity = ["generating", "idle", "unknown"].includes(row.activity) ? row.activity : "unknown";
      return { id: row.id, title, url: url.href, activity, unread: activity !== "generating" && row.unread === true };
    }
    function storageKey() { return scope && options.persistentPins !== false ? "__dia_conversation_pin_v1__:" + options.namespace + ":" + encodeURIComponent(scope) : null; }
    function storedPin() {
      const key = storageKey();
      if (!key || storageUnavailable) return pinnedId;
      try {
        const value = win.localStorage.getItem(key);
        return typeof value === "string" && ID.test(value) ? value : null;
      } catch (_) { return pinnedId; }
    }
    function collect() {
      const value = options.read() || {};
      const nextScope = typeof value.scopeKey === "string" && value.scopeKey.length > 0 && value.scopeKey.length <= 512
        ? value.scopeKey : null;
      const status = ["ready", "empty", "unavailable", "signed-out", "identity-lost"].includes(value.sourceStatus)
        ? value.sourceStatus : "unavailable";
      if (nextScope !== scope || status === "signed-out" || status === "identity-lost") {
        scope = nextScope;
        pinnedId = pinned = null;
        catalog.clear();
        storageUnavailable = false;
      }
      if (scope) pinnedId = storedPin();
      const rows = [], recent = [], seen = new Set();
      const candidates = Array.isArray(value.rows) ? value.rows.slice(0, 120) : [];
      for (const candidate of candidates) {
        const row = normalize(candidate);
        if (!row || seen.has(row.id)) continue;
        seen.add(row.id);
        rows.push(row);
        if (candidate.recent !== false) recent.push(row);
      }
      const usable = (status === "ready" || status === "empty") && Array.isArray(value.rows)
        && !(candidates.length && !rows.length) && !(status === "empty" && candidates.length);
      actionable = usable;
      if (usable) {
        catalog = new Map(rows.map(row => [row.id, row]));
        // An off-screen pin can retain its last metadata only within a confirmed identity.
        pinned = pinnedId ? catalog.get(pinnedId) || (scope && pinned && pinned.id === pinnedId
          ? Object.assign({}, pinned, { activity: "unknown", unread: false }) : null) : null;
      }
      if (status === "signed-out" || status === "identity-lost") {
        scope = null;
        pinnedId = pinned = null;
        catalog.clear();
      }
      return {
        scopeKey: scope,
        sourceStatus: !usable && (status === "ready" || status === "empty") ? "unavailable" : status,
        recent: usable ? recent.slice(0, 3) : [],
        pinned: usable ? pinned : null
      };
    }
    const runtime = win.DPTabIntegrationRuntime.create({
      window: win, version: options.version || 1, collect,
      // Native scheduler owns polling; the reader is cheap, bounded, and reads metadata only.
      observeMutations: false,
      commands: {
        pin(id) {
          collect();
          if (!actionable) return;
          if (id !== null && (typeof id !== "string" || !ID.test(id) || !catalog.has(id))) return;
          pinnedId = id;
          pinned = id === null ? null : catalog.get(id);
          const key = storageKey();
          if (key) try {
            if (id === null) win.localStorage.removeItem(key);
            else win.localStorage.setItem(key, id);
          } catch (_) { storageUnavailable = true; /* Keep only the document-local pin. */ }
        }
      }
    });
    const disposeRuntime = runtime.dispose;
    runtime.dispose = function () {
      if (disposed) return;
      disposed = true;
      disposeRuntime();
      catalog.clear();
      pinned = pinnedId = scope = null;
      if (win[options.namespace] === runtime) delete win[options.namespace];
    };
    return runtime;
  }
  return { create };
});
