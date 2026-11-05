/* Read conversation metadata and native row status from ChatGPT's sidebar only. */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.ChatGPTPreviewSidebar = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  const MAX_LINKS = 120;
  const ID_RE = /^[A-Za-z0-9_-]{1,128}$/;

  function create(win, origin) {
    const doc = win.document;

    function sidebarRoot() {
      try { return doc.querySelector('nav[aria-label="Chat history"]'); }
      catch (_) { return null; }
    }

    function conversationRow(anchor) {
      let node = anchor;
      for (let depth = 0; node && depth <= 5; depth += 1, node = node.parentElement) {
        if (node.getAttribute && node.getAttribute("role") === "group" && node.hasAttribute && node.hasAttribute("data-sidebar-cycle-item")) return node;
      }
      return null;
    }

    function rowHasSitePin(row) {
      if (!row || typeof row.querySelector !== "function") return false;
      try { return !!row.querySelector('button[aria-label="Unpin chat"]'); }
      catch (_) { return false; }
    }

    function siteRowStatus(row, id, observedAt) {
      if (!row || typeof row.querySelector !== "function") return null;
      let working = false;
      let unread = false;
      try { working = !!row.querySelector('span[role="status"][aria-label="Working"]'); }
      catch (_) { /* No recognized busy marker: use the supported row's idle fallback. */ }
      if (!working) {
        try { unread = !!row.querySelector(".block.size-2.shrink-0.rounded-full.bg-info-solid"); }
        catch (_) { /* No recognized unread marker. */ }
      }
      return { id, activity: working ? "generating" : "idle", unread: !working && unread, observedAt };
    }

    function read() {
      const root = sidebarRoot();
      if (!root) return { found: false, rows: [], pinCandidates: [], statuses: [] };
      let anchors = [];
      try { anchors = Array.from(root.querySelectorAll("a[href]")).slice(0, MAX_LINKS); }
      catch (_) { anchors = []; }
      const rows = [];
      const candidateById = new Map();
      const statusById = new Map();
      const recentIds = new Set();
      const now = Date.now();
      for (const anchor of anchors) {
        let url;
        try { url = new URL(anchor.href || anchor.getAttribute("href"), origin); }
        catch (_) { continue; }
        const canonical = url.origin === origin && new RegExp("^/c/([A-Za-z0-9_-]{1,128})$").exec(url.pathname);
        const project = url.origin === origin && new RegExp("^/g/g-p-[A-Za-z0-9_-]{1,128}/c/([A-Za-z0-9_-]{1,128})$").exec(url.pathname);
        const match = canonical || project;
        if (!match || url.search || url.hash || !ID_RE.test(match[1])) continue;
        const row = conversationRow(anchor);
        const rowTitle = row && row.getAttribute ? row.getAttribute("aria-label") : null;
        const ariaTitle = typeof anchor.getAttribute === "function" ? anchor.getAttribute("aria-label") : null;
        const title = String(rowTitle || ariaTitle || anchor.textContent || "").trim();
        if (!title || title.length > 300) continue;
        // Project links can supply a pin candidate but never count as recent chats.
        const item = { id: match[1], title, url: origin + "/c/" + match[1], updatedAt: now - rows.length };
        const existing = candidateById.get(match[1]);
        if (!existing || canonical) candidateById.set(match[1], item);
        const status = siteRowStatus(row, match[1], now);
        if (status && (!statusById.has(match[1]) || canonical)) statusById.set(match[1], status);
        if (!project && !rowHasSitePin(row) && !recentIds.has(match[1])) {
          recentIds.add(match[1]);
          rows.push(item);
        }
      }
      return { found: true, rows, pinCandidates: Array.from(candidateById.values()), statuses: Array.from(statusById.values()) };
    }

    function currentConversationId() {
      let url;
      try { url = new URL(win.location.href); }
      catch (_) { return null; }
      const match = url.origin === origin && /^\/c\/([A-Za-z0-9_-]{1,128})$/.exec(url.pathname);
      return match ? match[1] : null;
    }

    return { read, currentConversationId };
  }

  return { create };
});
