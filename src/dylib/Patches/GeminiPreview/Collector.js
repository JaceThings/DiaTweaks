/* Gemini sidebar metadata only. No message bodies, network or authentication stores. */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root && root.document && root.DPConversationRuntime && !root.DiaGeminiPreview)
    root.DiaGeminiPreview = api.install(root);
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";
  const ORIGIN = "https://gemini.google.com";
  const PATH = /^\/(?:u\/[0-9]+\/)?app\/([A-Za-z0-9_-]{1,128})$/;

  function conversationURL(id, value) {
    let url;
    try { url = new URL(value, ORIGIN); } catch (_) { return null; }
    const match = PATH.exec(url.pathname);
    return url.origin === ORIGIN && !url.username && !url.password && !url.search && !url.hash
      && match && match[1] === id ? ORIGIN + url.pathname : null;
  }
  function identity(doc) {
    // Read the already-visible Google account label, never Google auth globals or cookies.
    const account = doc.querySelector("a.mavatar-footer-left[aria-label]");
    const label = account && account.getAttribute("aria-label");
    const email = typeof label === "string" && label.match(/[^\s()<>]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/);
    return email && email[0].length <= 254 ? "account:" + email[0].toLowerCase() : null;
  }
  function read(win) {
    const doc = win.document;
    const scopeKey = identity(doc);
    const list = doc.querySelector('conversations-list[data-test-id="all-conversations"]');
    if (!list) return { scopeKey, sourceStatus: "unavailable", rows: [] };
    const rows = [];
    const anchors = Array.from(list.querySelectorAll("a[href]")).slice(0, 120);
    for (const anchor of anchors) {
      let url;
      try { url = new URL(anchor.getAttribute("href"), ORIGIN); } catch (_) { continue; }
      const match = PATH.exec(url.pathname);
      if (!match || !conversationURL(match[1], url.href)) continue;
      const titleNode = anchor.querySelector(".title-text");
      const title = titleNode && titleNode.textContent;
      const container = anchor.closest("gem-nav-list-item");
      rows.push({ id: match[1], title, url: ORIGIN + url.pathname, activity: "unknown", unread: false,
        recent: !(container && container.querySelector(".conversation-pin-icon")) });
    }
    // Without a verified empty-account marker, a blank list is not evidence to erase a cache.
    return { scopeKey, sourceStatus: rows.length ? "ready" : "unavailable", rows };
  }
  function install(win) {
    return win.DPConversationRuntime.create({ window: win, origin: ORIGIN, namespace: "DiaGeminiPreview",
      version: 1, read: () => read(win), conversationURL });
  }
  return { install, read, conversationURL };
});
