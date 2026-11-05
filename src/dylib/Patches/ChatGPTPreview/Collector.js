/* Passive, metadata-only page adapter for ChatGPTPreviewState. */
(function (root, factory) {
  const deps = typeof module === "object" && module.exports
    ? { pins: require("./Pins.js"), sidebar: require("./Sidebar.js"), lifecycle: require("./Lifecycle.js") }
    : { pins: root.ChatGPTPreviewPins, sidebar: root.ChatGPTPreviewSidebar, lifecycle: root.ChatGPTPreviewLifecycle };
  const api = factory(deps);
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root && root.document && root.ChatGPTPreviewState && !root.DiaChatGPTPreview) {
    root.DiaChatGPTPreview = api.install(root, root.ChatGPTPreviewState);
  }
})(typeof globalThis !== "undefined" ? globalThis : this, function (deps) {
  "use strict";

  function install(win, stateApi) {
    if (!win || !win.document || !stateApi || typeof stateApi.createChatGPTPreviewState !== "function") {
      throw new TypeError("install requires a window and ChatGPTPreviewState API");
    }
    if (!deps.pins || !deps.sidebar || !deps.lifecycle) throw new TypeError("ChatGPTPreview modules are unavailable");

    const doc = win.document;
    const origin = win.location && win.location.origin;
    if (!origin || origin !== "https://chatgpt.com") throw new TypeError("collector only supports chatgpt.com");

    const pinStore = deps.pins.create(win, stateApi, origin);
    const sidebarReader = deps.sidebar.create(win, origin);
    let model = stateApi.createChatGPTPreviewState({ origin, maxRecent: 3, staleAfterMs: 5000 });
    const catalog = new Map();
    let pinned = null;
    let sourceLoaded = false;
    let sourceStatus = "no-sidebar-data";
    let disposed = false;
    let scheduled = null;
    let lifecycle;

    function refreshIdentity() {
      if (!pinStore.refreshIdentity()) return false;
      model = stateApi.createChatGPTPreviewState({ origin, maxRecent: 3, staleAfterMs: 5000 });
      pinned = null;
      catalog.clear();
      sourceLoaded = false;
      sourceStatus = "no-sidebar-data";
      const stored = pinStore.safeStorageRead();
      if (stored) {
        model.setPinnedConversation(pinStore.scopeKey, stored);
        pinned = model.findConversation(pinStore.scopeKey, stored.id);
      }
      return true;
    }

    function setPinned(row, shouldPersist) {
      model.setPinnedConversation(pinStore.scopeKey, row || null);
      pinned = row ? model.findConversation(pinStore.scopeKey, row.id) : null;
      if (shouldPersist) pinStore.persistPin(pinned);
    }

    function currentConversationTitle(id) {
      const row = catalog.get(id) || model.findConversation(pinStore.scopeKey, id);
      return row && row.title ? row.title : "";
    }

    function collect() {
      if (disposed) return null;
      refreshIdentity();
      const now = Date.now();
      const sidebar = sidebarReader.read();
      sourceLoaded = sidebar.found;
      sourceStatus = !sidebar.found ? "no-sidebar-data" : sidebar.rows.length ? "ready" : "empty";
      catalog.clear();
      for (const row of sidebar.pinCandidates) catalog.set(row.id, row);
      model.syncConversations(pinStore.scopeKey, sidebar.rows, sidebar.statuses);

      if (pinStore.persistent && pinned) model.setPinnedConversation(pinStore.scopeKey, pinned);
      else if (pinStore.persistent) {
        const stored = pinStore.safeStorageRead();
        if (stored) setPinned(stored, false);
      } else {
        const transientPinnedId = pinStore.refreshTransientPin();
        const currentRow = transientPinnedId ? catalog.get(transientPinnedId) : null;
        setPinned(currentRow, false);
      }

      const conversationId = sidebarReader.currentConversationId();
      if (conversationId) {
        const title = currentConversationTitle(conversationId);
        if (title && !catalog.has(conversationId)) {
          const row = { id: conversationId, title, url: origin + "/c/" + conversationId, updatedAt: now };
          catalog.set(conversationId, row);
          model.syncConversations(pinStore.scopeKey, sidebar.rows.concat([row]), sidebar.statuses);
          if (pinned) model.setPinnedConversation(pinStore.scopeKey, pinned);
        }
      }
      return makeSnapshot(now);
    }

    function makeSnapshot(now) {
      const value = model.snapshot(pinStore.scopeKey, now);
      const currentConversation = sidebarReader.currentConversationId();
      return Object.assign(value, {
        observedAt: now,
        currentConversationId: currentConversation,
        current: currentConversation ? model.conversation(pinStore.scopeKey, currentConversation, now) : null,
        scopeStatus: pinStore.persistent ? "account" : "transient",
        sourceLoaded,
        sourceStatus,
        sourceLabel: "sidebar recent chats"
      });
    }

    function scheduleCollect() {
      if (disposed || scheduled != null) return;
      scheduled = win.setTimeout(() => { scheduled = null; collect(); }, 100);
    }

    function onStorage(event) {
      refreshIdentity();
      if (!event || event.key !== pinStore.storageKey) return;
      if (!pinStore.persistent) {
        const transientPinnedId = pinStore.refreshTransientPin();
        const row = transientPinnedId ? catalog.get(transientPinnedId) : null;
        setPinned(row, false);
        scheduleCollect();
        return;
      }
      let next = null;
      if (typeof event.newValue === "string" && event.newValue.length <= 4096) {
        try {
          const row = JSON.parse(event.newValue);
          if (row && /^[A-Za-z0-9_-]{1,128}$/.test(row.id) && typeof row.title === "string" && Number.isFinite(row.updatedAt)) {
            next = typeof stateApi.normalizeConversation === "function" ? stateApi.normalizeConversation(row, origin) : row;
          }
        } catch (_) { /* Ignore malformed state. */ }
      }
      setPinned(next, false);
      scheduleCollect();
    }

    const pin = function (id) {
      if (disposed) return makeSnapshot(Date.now());
      refreshIdentity();
      if (id == null) setPinned(null, true);
      else if (typeof id === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(id)) {
        const row = catalog.get(id) || (pinStore.persistent ? model.findConversation(pinStore.scopeKey, id) : null);
        if (row) setPinned(row, true);
      }
      return collect();
    };

    const snapshot = function () { return collect(); };
    const api = { version: 3, snapshot, pin, dispose };
    Object.defineProperties(api, {
      scopeKey: { enumerable: true, get: () => pinStore.scopeKey },
      scopeStatus: { enumerable: true, get: () => pinStore.persistent ? "account" : "transient" }
    });
    function dispose() {
      if (disposed) return;
      disposed = true;
      if (scheduled != null) win.clearTimeout(scheduled);
      lifecycle.dispose();
      if (win.DiaChatGPTPreview === api) {
        try { delete win.DiaChatGPTPreview; }
        catch (_) { win.DiaChatGPTPreview = undefined; }
      }
    }

    const initialPin = pinStore.safeStorageRead();
    setPinned(initialPin, false);
    lifecycle = deps.lifecycle.create(win, doc, scheduleCollect, onStorage, collect);
    lifecycle.start();
    collect();
    return api;
  }

  return { install, accountIdFromHydration: deps.pins.accountIdFromHydration };
});
