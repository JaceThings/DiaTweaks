/* Own browser listeners, polling and mutation observation for a collector instance. */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.ChatGPTPreviewLifecycle = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  const POLL_MS = 1200;

  function create(win, doc, scheduleCollect, onStorage, collect) {
    const handlers = [];
    let mutationObserver = null;
    let interval = null;

    function on(target, type, handler) {
      if (!target || typeof target.addEventListener !== "function") return;
      target.addEventListener(type, handler);
      handlers.push([target, type, handler]);
    }

    function start() {
      on(win, "storage", onStorage);
      on(win, "focus", scheduleCollect);
      on(win, "blur", scheduleCollect);
      on(doc, "visibilitychange", scheduleCollect);
      on(win, "popstate", scheduleCollect);
      on(win, "hashchange", scheduleCollect);
      if (typeof win.MutationObserver === "function") {
        try {
          mutationObserver = new win.MutationObserver(scheduleCollect);
          mutationObserver.observe(doc.documentElement || doc, { childList: true, subtree: true, attributes: true, attributeFilter: ["href", "aria-label", "class"] });
        } catch (_) { mutationObserver = null; }
      }
      if (typeof win.setInterval === "function") interval = win.setInterval(collect, POLL_MS);
    }

    function dispose() {
      if (interval != null) win.clearInterval(interval);
      if (mutationObserver) mutationObserver.disconnect();
      for (const entry of handlers) entry[0].removeEventListener(entry[1], entry[2]);
      handlers.length = 0;
    }

    return { start, dispose, get handlerCount() { return handlers.length; } };
  }

  return { create };
});
