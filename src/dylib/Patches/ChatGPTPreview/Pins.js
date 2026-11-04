/* Account-scoped persistent pins and opaque transient pins for isolated Dia realms. */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.ChatGPTPreviewPins = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  const PIN_KEY_PREFIX = "__dia_chatgpt_preview_pin_v1__:";
  const TRANSIENT_PIN_KEY = "__dia_chatgpt_preview_transient_pin_v1__";
  const ID_RE = /^[A-Za-z0-9_-]{1,128}$/;

  function accountIdFromHydration(win) {
    // Inspect only known loaderData roots and only the narrow user.id field.
    const roots = [win.__reactRouterContext, win.__remixContext];
    for (const root of roots) {
      const loaderData = root && root.state && root.state.loaderData;
      if (!loaderData || typeof loaderData !== "object") continue;
      for (const key of Object.keys(loaderData)) {
        const user = loaderData[key] && loaderData[key].user;
        const id = user && user.id;
        if (typeof id === "string" && ID_RE.test(id)) return id;
      }
    }
    return null;
  }

  function create(win, stateApi, origin) {
    let accountId = accountIdFromHydration(win);
    let persistent = !!accountId;
    let scopeKey = makeScopeKey(accountId);
    let storageKey = accountId ? accountStorageKey(accountId) : TRANSIENT_PIN_KEY;
    let transientPinnedId = accountId ? null : readTransientPinId();

    function accountStorageKey(id) { return id ? PIN_KEY_PREFIX + id : null; }
    function makeScopeKey(id) {
      return id ? "account:" + id : "transient:" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 10);
    }

    function refreshIdentity() {
      const nextId = accountIdFromHydration(win);
      if (nextId === accountId) return false;
      accountId = nextId;
      persistent = !!accountId;
      scopeKey = makeScopeKey(accountId);
      storageKey = accountId ? accountStorageKey(accountId) : TRANSIENT_PIN_KEY;
      transientPinnedId = persistent ? null : readTransientPinId();
      return true;
    }

    function safeStorageRead() {
      if (!persistent || !storageKey) return null;
      try {
        const raw = win.localStorage.getItem(storageKey);
        if (!raw || raw.length > 4096) return null;
        const row = JSON.parse(raw);
        if (!row || !ID_RE.test(row.id) || typeof row.title !== "string" || !Number.isFinite(row.updatedAt)) return null;
        return typeof stateApi.normalizeConversation === "function"
          ? stateApi.normalizeConversation(row, origin)
          : { id: row.id, title: row.title, url: row.url, updatedAt: row.updatedAt };
      } catch (_) { return null; }
    }

    // Transient storage carries only an id; titles and URLs must be re-read from this page's sidebar.
    function readTransientPinId() {
      try {
        const raw = win.localStorage.getItem(TRANSIENT_PIN_KEY);
        if (!raw || raw.length > 256) return null;
        const value = JSON.parse(raw);
        return value && typeof value.id === "string" && ID_RE.test(value.id) ? value.id : null;
      } catch (_) { return null; }
    }

    function persistPin(pinned) {
      if (!storageKey) return;
      try {
        if (pinned && persistent) win.localStorage.setItem(storageKey, JSON.stringify(pinned));
        else if (pinned) win.localStorage.setItem(storageKey, JSON.stringify({ id: pinned.id }));
        else win.localStorage.removeItem(storageKey);
      } catch (_) { /* Storage may be unavailable; in-memory pin still works. */ }
    }

    function refreshTransientPin() { transientPinnedId = readTransientPinId(); return transientPinnedId; }

    const api = { accountIdFromHydration: () => accountIdFromHydration(win), refreshIdentity, safeStorageRead,
      readTransientPinId, refreshTransientPin, persistPin };
    Object.defineProperties(api, {
      accountId: { enumerable: true, get: () => accountId },
      persistent: { enumerable: true, get: () => persistent },
      scopeKey: { enumerable: true, get: () => scopeKey },
      storageKey: { enumerable: true, get: () => storageKey },
      transientPinnedId: { enumerable: true, get: () => transientPinnedId }
    });
    return api;
  }

  return { create, accountIdFromHydration };
});
