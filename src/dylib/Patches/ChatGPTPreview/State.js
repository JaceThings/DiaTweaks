/* Pure state model for the ChatGPT tab preview. No DOM, network, or Dia APIs. */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.ChatGPTPreviewState = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  const ID_RE = /^[A-Za-z0-9_-]{1,128}$/;
  const MAX_TITLE_LENGTH = 300;
  const MAX_CONVERSATIONS = 120;

  function validId(value) {
    return typeof value === "string" && ID_RE.test(value);
  }

  function validTimestamp(value) {
    return Number.isFinite(value) && value >= 0;
  }

  function normalizeConversation(value, origin) {
    if (!value || typeof value !== "object" || !validId(value.id)) return null;
    if (typeof value.title !== "string") return null;
    const title = value.title.trim();
    if (!title || title.length > MAX_TITLE_LENGTH) return null;
    if (!validTimestamp(value.updatedAt)) return null;

    let url;
    try {
      url = new URL(value.url, origin);
    } catch (_) {
      return null;
    }
    let expectedOrigin;
    try {
      expectedOrigin = new URL(origin).origin;
    } catch (_) {
      return null;
    }
    if (url.origin !== expectedOrigin || url.username || url.password) return null;
    if (url.search || url.hash || url.pathname !== "/c/" + value.id) return null;

    return { id: value.id, title, url: url.href, updatedAt: value.updatedAt };
  }

  function createChatGPTPreviewState(options) {
    options = options || {};
    const origin = options.origin || "https://chatgpt.com";
    const maxRecent = Number.isInteger(options.maxRecent) && options.maxRecent > 0 ? options.maxRecent : 3;
    const staleAfterMs = Number.isFinite(options.staleAfterMs) && options.staleAfterMs >= 0 ? options.staleAfterMs : 30000;
    const scopes = new Map();

    function scopeFor(scopeKey) {
      if (typeof scopeKey !== "string" || !scopeKey.trim()) throw new TypeError("scopeKey must be a non-empty string");
      let scope = scopes.get(scopeKey);
      if (!scope) {
        scope = { conversations: new Map(), pinned: null, siteStatuses: new Map() };
        scopes.set(scopeKey, scope);
      }
      return scope;
    }

    function syncConversations(scopeKey, rows, siteStatuses) {
      const scope = scopeFor(scopeKey);
      const byId = new Map();
      const statuses = new Map();
      if (Array.isArray(rows)) {
        for (const row of rows.slice(0, MAX_CONVERSATIONS)) {
          const normalized = normalizeConversation(row, origin);
          if (!normalized) continue;
          const previous = byId.get(normalized.id);
          if (!previous || normalized.updatedAt > previous.updatedAt) byId.set(normalized.id, normalized);
        }
      }
      scope.conversations = byId;
      if (Array.isArray(siteStatuses)) {
        for (const status of siteStatuses) {
          if (!status || !validId(status.id) || (status.activity !== "generating" && status.activity !== "idle") || typeof status.unread !== "boolean" || !validTimestamp(status.observedAt)) continue;
          statuses.set(status.id, {
            activity: status.activity,
            unread: status.activity === "generating" ? false : status.unread,
            observedAt: status.observedAt
          });
        }
      }
      scope.siteStatuses = statuses;
      return snapshot(scopeKey);
    }

    function setPinnedConversation(scopeKey, row) {
      const scope = scopeFor(scopeKey);
      scope.pinned = row == null ? null : normalizeConversation(row, origin);
      return snapshot(scopeKey);
    }

    function snapshot(scopeKey, now) {
      const scope = scopeFor(scopeKey);
      now = validTimestamp(now) ? now : Date.now();
      const pinned = scope.pinned;
      const recent = Array.from(scope.conversations.values())
        .filter((row) => !pinned || row.id !== pinned.id)
        .sort((a, b) => b.updatedAt - a.updatedAt || a.id.localeCompare(b.id))
        .slice(0, maxRecent)
        .map((row) => presentConversation(row, scope, now));
      return { scopeKey, recent, pinned: pinned ? presentConversation(pinned, scope, now) : null };
    }

    function findConversation(scopeKey, id) {
      const scope = scopeFor(scopeKey);
      if (scope.pinned && scope.pinned.id === id) return Object.assign({}, scope.pinned);
      const row = scope.conversations.get(id);
      return row ? Object.assign({}, row) : null;
    }

    function conversation(scopeKey, id, now) {
      const scope = scopeFor(scopeKey);
      const row = scope.pinned && scope.pinned.id === id ? scope.pinned : scope.conversations.get(id);
      if (!row) return null;
      now = validTimestamp(now) ? now : Date.now();
      return presentConversation(row, scope, now);
    }

    function presentConversation(row, scope, now) {
      const status = scope.siteStatuses.get(row.id);
      let activity = "unknown";
      const stale = !!status && now - status.observedAt > staleAfterMs;
      if (status) activity = stale ? "stale" : status.activity;
      return {
        id: row.id,
        title: row.title,
        url: row.url,
        updatedAt: row.updatedAt,
        activity,
        activityObservedAt: status ? status.observedAt : null,
        unread: status && !stale ? status.unread : null
      };
    }

    return { syncConversations, setPinnedConversation, snapshot, findConversation, conversation };
  }

  return { createChatGPTPreviewState, normalizeConversation };
});
