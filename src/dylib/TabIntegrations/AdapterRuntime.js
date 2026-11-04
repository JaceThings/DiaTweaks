/* Shared optional lifecycle helper for page integration adapters. */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.DPTabIntegrationRuntime = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  const RESERVED = new Set(["version", "snapshot", "dispose", "refresh", "disposed"]);
  const PROTOTYPE_NAMES = new Set(Object.getOwnPropertyNames(Object.prototype));

  function create(options) {
    options = options || {};
    const win = options.window || (typeof window !== "undefined" ? window : null);
    if (!win || !win.document) throw new TypeError("runtime requires a browser window");
    if (!Number.isInteger(options.version) || options.version < 1) throw new TypeError("runtime requires a positive integer version");
    if (typeof options.collect !== "function") throw new TypeError("runtime requires a collect function");

    const policy = options.collectPolicy || "every-read";
    if (!["every-read", "dirty", "interval"].includes(policy)) throw new TypeError("unknown collectPolicy");
    const debounceMs = bounded(options.debounceMs, 100, 0, 10000);
    const pollMs = bounded(options.pollMs, 1200, 100, 60000);
    const maxAgeMs = bounded(options.maxAgeMs, 0, 0, 3600000);
    const now = typeof options.now === "function" ? options.now : Date.now;
    const doc = win.document;
    let scope = options.root || doc.documentElement || doc;
    if (typeof scope === "string") scope = doc.querySelector(scope);
    if (!scope) throw new TypeError("runtime root did not resolve");

    const commands = options.commands == null ? {} : options.commands;
    if (!commands || typeof commands !== "object" || Array.isArray(commands)) throw new TypeError("commands must be an object");
    const commandEntries = [];
    for (const name of Object.keys(commands)) {
      const command = commands[name];
      if (!/^[A-Za-z_$][\w$]*$/.test(name) || RESERVED.has(name) || PROTOTYPE_NAMES.has(name) || typeof command !== "function") {
        throw new TypeError("invalid adapter command: " + name);
      }
      commandEntries.push([name, command]);
    }

    let disposed = false;
    let dirty = true;
    let collectedAt = 0;
    let value;
    let collectionError = null;
    let debounceTimer = null;
    let pollTimer = null;
    let observer = null;
    const listeners = [];

    function cancelDebounce() {
      if (debounceTimer == null) return;
      if (typeof win.clearTimeout === "function") win.clearTimeout(debounceTimer);
      debounceTimer = null;
    }

    function collectNow() {
      if (disposed) return value;
      cancelDebounce();
      value = options.collect();
      collectedAt = now();
      dirty = false;
      collectionError = null;
      return value;
    }

    function needsCollection(force) {
      if (force || policy === "every-read" || dirty || collectedAt === 0) return true;
      return maxAgeMs > 0 && now() - collectedAt >= maxAgeMs;
    }

    function snapshot(force) {
      if (disposed) return value;
      if (needsCollection(force)) {
        try { return collectNow(); }
        catch (error) { collectionError = error; throw error; }
      }
      if (collectionError) throw collectionError;
      return value;
    }

    function invalidate() {
      if (disposed) return;
      dirty = true;
      if (debounceTimer != null || typeof win.setTimeout !== "function") return;
      debounceTimer = win.setTimeout(function () {
        debounceTimer = null;
        if (disposed) return;
        try { collectNow(); }
        catch (error) { collectionError = error; }
      }, debounceMs);
    }

    function addListener(target, type, handler) {
      if (!target || typeof target.addEventListener !== "function" || typeof type !== "string") return;
      target.addEventListener(type, handler);
      listeners.push([target, type, handler]);
    }

    if (options.observeMutations !== false && typeof win.MutationObserver === "function") {
      try {
        observer = new win.MutationObserver(invalidate);
      observer.observe(scope, options.mutationOptions || { childList: true, subtree: true, attributes: true, characterData: true });
      } catch (_) { observer = null; }
    }
    for (const event of Array.isArray(options.events) ? options.events : []) {
      if (typeof event === "string") addListener(win, event, invalidate);
      else if (event && typeof event === "object") addListener(event.target || win, event.type, invalidate);
    }
    if (policy === "interval" && typeof win.setInterval === "function") {
      pollTimer = win.setInterval(invalidate, pollMs);
    }

    const api = {
      version: options.version,
      snapshot,
      refresh: function () { return snapshot(true); },
      get disposed() { return disposed; },
      dispose: function () {
        if (disposed) return;
        disposed = true;
        if (debounceTimer != null && typeof win.clearTimeout === "function") win.clearTimeout(debounceTimer);
        if (pollTimer != null && typeof win.clearInterval === "function") win.clearInterval(pollTimer);
        if (observer) observer.disconnect();
        for (const entry of listeners) entry[0].removeEventListener(entry[1], entry[2]);
        listeners.length = 0;
        observer = null;
        debounceTimer = null;
        pollTimer = null;
      }
    };

    for (const [name, command] of commandEntries) {
      Object.defineProperty(api, name, {
        enumerable: true,
        value: function (...args) {
          if (disposed) return value;
          const result = command(...args);
          if (options.refreshAfterCommand !== false) snapshot(true);
          return result;
        }
      });
    }
    return api;
  }

  function bounded(value, fallback, min, max) {
    if (value == null) return fallback;
    if (!Number.isFinite(value)) throw new TypeError("runtime timing values must be finite numbers");
    return Math.max(min, Math.min(max, value));
  }

  return { create };
});
