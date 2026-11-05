"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const Runtime = require("../src/dylib/TabIntegrations/AdapterRuntime.js");
const Conversations = require("../src/dylib/TabIntegrations/ConversationRuntime.js");
const Collector = require("../src/dylib/Patches/T3Preview/Collector.js");
const vm = require("node:vm");

function makeRow({ id, title, href, testId } = {}) {
  const input = { value: title };
  const anchor = {
    getAttribute(name) {
      if (name === "href") return href || "/chat/" + id;
      if (name === "data-testid") return testId || "thread-link-" + id;
      return null;
    },
    closest(selector) { return selector === '[data-sidebar="menu-item"]' ? row : null; },
    textContent: "", // Native markup keeps the title in input.value.
  };
  const row = {
    querySelector(selector) {
      return selector === 'input[aria-label="Thread title"][type="text"]' ? input : null;
    },
  };
  return { anchor, row, input };
}

function fixture({ rows = [], sidebar = true, href = "https://t3.chat/", footerLogin = true, busy = false } = {}) {
  const links = rows.map(makeRow);
  let showLogin = footerLogin;
  const nav = { querySelector: () => busy ? {} : null, querySelectorAll: selector => selector === 'a[data-testid^="thread-link-"][href]' ? links.map(x => x.anchor) : [] };
  const document = {
    querySelector(selector) {
      if (selector === '[data-sidebar="sidebar"]') return sidebar ? nav : null;
      // Guest login footer is intentionally irrelevant to local conversation availability.
      if (selector === '[data-sidebar="footer"] a[aria-label="Login"]') return showLogin ? {} : null;
      return null;
    },
  };
  const store = new Map();
  let storageAccesses = 0;
  const win = {
    document, location: { origin: "https://t3.chat", href }, URL, DPTabIntegrationRuntime: Runtime,
    localStorage: {
      getItem(key) { storageAccesses++; return store.get(key) ?? null; },
      setItem(key, value) { storageAccesses++; store.set(key, value); },
      removeItem(key) { storageAccesses++; store.delete(key); },
    },
  };
  return { win, store, links, hideLogin() { showLogin = false; }, get storageAccesses() { return storageAccesses; } };
}

{
  const f = fixture({ rows: [
    { id: "a1", title: "Thread title from input" },
    { id: "empty", title: "  " },
    { id: "long", title: "x".repeat(301) },
    { id: "mismatch", title: "Wrong ID", href: "/chat/other" },
    { id: "testid-mismatch", title: "Wrong test id", testId: "thread-link-other" },
    { id: "unsafe", title: "Unsafe URL", href: "https://t3.chat/chat/unsafe?x=1" },
  ] });
  const result = Collector.read(f.win.document);
  assert.equal(result.sourceStatus, "ready");
  assert.deepEqual(result.rows.map(row => [row.id, row.title]), [["a1", "Thread title from input"]]);
  assert.equal(result.rows[0].activity, "unknown");
  assert.equal(result.rows[0].unread, false);
  assert.equal(result.scopeKey, null);
}

for (const id of ["", "../escape", "x/y", "x?y", "雪"]) {
  assert.equal(Collector.conversationURL(id), null);
}
assert.equal(Collector.conversationURL("abc", "https://t3.chat/chat/other"), null);
assert.equal(Collector.conversationURL("abc", "https://t3.chat/chat/abc#fragment"), null);
assert.equal(Collector.conversationURL("abc", "https://user:pass@t3.chat/chat/abc"), null);
assert.equal(Collector.conversationURL("abc", "https://evil.test/chat/abc"), null);
assert.equal(Collector.conversationURL("abc", "https://t3.chat/chat/abc"), "https://t3.chat/chat/abc");
for (const url of [
  "http://t3.chat/", "https://t3.chat.evil.test/", "https://user@t3.chat/",
  "https://t3.chat/settings", "https://t3.chat/login", "https://t3.chat/chat/a?x=1",
  "https://t3.chat/chat/a#x", "https://t3.chat/chat/a/b",
]) assert.equal(Collector.validPageURL(url), false, url);
assert.equal(Collector.validPageURL("https://t3.chat/"), true);
assert.equal(Collector.validPageURL("https://t3.chat/chat/a1"), true);

{
  const missing = fixture({ sidebar: false });
  assert.equal(Collector.read(missing.win.document).sourceStatus, "unavailable");
  const empty = fixture({ rows: [] });
  assert.equal(Collector.read(empty.win.document).sourceStatus, "empty");
  assert.equal(Collector.read(fixture({busy:true}).win.document).sourceStatus, "unavailable");
  assert.equal(Collector.read(fixture({footerLogin:false}).win.document).sourceStatus, "unavailable");
  const malformed = fixture({ rows: [{ id: "broken", title: "" }] });
  assert.equal(Collector.read(malformed.win.document).sourceStatus, "unavailable");
}

{
  const guest = fixture({ rows: [{ id: "local-thread", title: "Guest local conversation" }], footerLogin: true });
  const api = Collector.install(guest.win, Conversations);
  assert.equal(api.snapshot().sourceStatus, "ready");
  assert.equal(api.snapshot().recent[0].title, "Guest local conversation");
  const guestScope = api.snapshot().scopeKey;
  assert.match(guestScope, /^guest-document:/);
  assert.equal(guest.storageAccesses, 0); // No account identity or persistent cache is inferred.
  api.pin("local-thread");
  assert.equal(api.snapshot().pinned.id, "local-thread");
  assert.equal(guest.storageAccesses, 0); // Unknown identity pins stay in this document only.
  assert.equal(api.snapshot().scopeKey, guestScope); // Stable during this guest document.
  guest.hideLogin();
  assert.equal(api.snapshot().scopeKey, null); // A disappeared login marker ends guest-only cache/pin scope.
  assert.equal(api.snapshot().pinned, null);
  api.dispose();
  assert.equal(guest.win.DiaT3Preview, undefined);
  guest.win.location.href = "https://t3.chat/settings";
  assert.equal(Collector.install(guest.win, Conversations), null);
}

{
  const browser = fixture({ rows: [{ id: "browser", title: "Bundled browser adapter" }] });
  const context = vm.createContext(browser.win);
  vm.runInContext(fs.readFileSync(require.resolve("../src/dylib/TabIntegrations/AdapterRuntime.js"), "utf8"), context);
  vm.runInContext(fs.readFileSync(require.resolve("../src/dylib/TabIntegrations/ConversationRuntime.js"), "utf8"), context);
  vm.runInContext(fs.readFileSync(require.resolve("../src/dylib/Patches/T3Preview/Collector.js"), "utf8"), context);
  assert.equal(browser.win.DiaT3Preview.snapshot().recent[0].title, "Bundled browser adapter");
  browser.win.DiaT3Preview.dispose();
}

console.log("t3-preview-collector: minimized title input, URL/ID validation, guest sidebar, pin and lifecycle passed");
