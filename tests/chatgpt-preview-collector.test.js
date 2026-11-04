"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const State = require("../src/dylib/Patches/ChatGPTPreview/State.js");
const Collector = require("../src/dylib/Patches/ChatGPTPreview/Collector.js");
const integrationDir = path.join(__dirname, "../src/dylib/Patches/ChatGPTPreview");

class Target {
  constructor() { this.listeners = new Map(); }
  addEventListener(type, fn) {
    if (!this.listeners.has(type)) this.listeners.set(type, new Set());
    this.listeners.get(type).add(fn);
  }
  removeEventListener(type, fn) { if (this.listeners.has(type)) this.listeners.get(type).delete(fn); }
  dispatch(type, event) { for (const fn of this.listeners.get(type) || []) fn(event || {}); }
}

function element(attrs, text, rect) {
  return {
    attrs,
    textContent: text || "",
    href: attrs.href,
    getAttribute(name) { return attrs[name] == null ? null : attrs[name]; },
    getBoundingClientRect() { return rect || { top: 0, left: 0, bottom: 40, right: 300, width: 300, height: 40 }; }
  };
}

function fixture(options) {
  options = options || {};
  const win = new Target();
  const doc = new Target();
  const store = options.sharedStore || new Map();
  const linkStates = options.links || [];
  const anchorRows = linkStates.map((row) => {
    const wrapper = {
      getAttribute(name) { return name === "role" ? "group" : name === "aria-label" ? row.title : null; },
      hasAttribute(name) { return name === "data-sidebar-cycle-item"; },
      querySelector(selector) {
        if (row.sitePinned && selector === 'button[aria-label="Unpin chat"]') return {};
        if (selector === 'span[role="status"][aria-label="Working"]') return row.working ? {} : null;
        if (selector === ".block.size-2.shrink-0.rounded-full.bg-info-solid") return row.unreadDot ? {} : null;
        return null;
      }
    };
    const anchor = element({ href: row.href || (row.project ? "/g/g-p-project_1/c/" + row.id : "/c/" + row.id), "aria-label": row.label }, row.anchorText || row.title);
    let parent = anchor;
    for (let i = 0; i < 4; i += 1) { parent.parentElement = {}; parent = parent.parentElement; }
    parent.parentElement = wrapper;
    return anchor;
  });
  const sidebar = options.sidebar === false ? null : { querySelectorAll: () => anchorRows };
  doc.documentElement = {};
  doc.visibilityState = options.visible === false ? "hidden" : "visible";
  doc.querySelector = (selector) => {
    if (selector === 'nav[aria-label="Chat history"]') return sidebar;
    if (selector.startsWith("main h1")) return options.heading ? { textContent: options.heading } : null;
    return null;
  };
  doc.querySelectorAll = () => [];
  win.document = doc;
  win.location = { origin: "https://chatgpt.com", href: options.href || "https://chatgpt.com/" };
  win.innerHeight = 800;
  win.innerWidth = 1200;
  win.localStorage = {
    getItem(key) { fixture.readKeys.push(key); return store.has(key) ? store.get(key) : null; },
    setItem(key, value) { store.set(key, value); },
    removeItem(key) { store.delete(key); }
  };
  win.setInterval = () => 1;
  win.clearInterval = () => {};
  win.setTimeout = (fn) => { fixture.scheduled.push(fn); return fixture.scheduled.length; };
  win.clearTimeout = () => {};
  win.MutationObserver = class { observe() {} disconnect() {} };
  win.__reactRouterContext = options.accountId ? { state: { loaderData: { root: { user: { id: options.accountId } } } } } : undefined;
  fixture.stores.push(store);
  return { win, doc, store, anchorRows, linkStates };
}
fixture.stores = [];
fixture.readKeys = [];
fixture.scheduled = [];

function testSidebarMetadataAndSourceStatus() {
  const f = fixture({ links: [{ id: "a", title: "A" }, { id: "b", title: "B" }, { id: "c", title: "C" }, { id: "d", title: "D" }] });
  const api = Collector.install(f.win, State);
  const view = api.snapshot();
  assert.equal(view.sourceLoaded, true);
  assert.equal(view.sourceStatus, "ready");
  assert.equal(view.recent.length, 3);
  assert.deepEqual(view.recent.map((row) => row.id), ["a", "b", "c"]);
  assert.equal(view.scopeStatus, "transient");
  assert.equal(view.sourceLabel, "sidebar recent chats");
  assert.match(view.scopeKey, /^transient:/);
  assert.equal(view.currentConversationId, null);
  api.dispose();

  const empty = fixture({ sidebar: false });
  const emptyView = Collector.install(empty.win, State).snapshot();
  assert.equal(emptyView.sourceLoaded, false);
  assert.equal(emptyView.sourceStatus, "no-sidebar-data");
}

function testDeclaredBrowserModuleOrderInstallsTheSameAdapter() {
  const manifest = JSON.parse(fs.readFileSync(path.join(integrationDir, "integration.json"), "utf8"));
  assert.deepEqual(manifest.scripts, ["State.js", "Pins.js", "Sidebar.js", "Lifecycle.js", "Collector.js"]);
  const f = fixture({ links: [{ id: "browser", title: "Browser build" }] });
  for (const script of manifest.scripts) {
    vm.runInNewContext(fs.readFileSync(path.join(integrationDir, script), "utf8"), f.win, { filename: script });
  }
  assert.equal(f.win.DiaChatGPTPreview.version, 3);
  assert.ok(f.win.DiaChatGPTPreview.snapshot());
  f.win.DiaChatGPTPreview.dispose();
}

function testProjectAndWebsitePinnedRowsAreNotRecent() {
  const f = fixture({ links: [
    { id: "project-chat", title: "Project conversation", project: true },
    { id: "same-chat", title: "Project duplicate", project: true },
    { id: "same-chat", title: "Recent canonical" },
    { id: "recent-1", title: "Recent one" },
    { id: "site-pinned", title: "Website pinned", sitePinned: true },
    { id: "recent-2", title: "Recent two" }
  ] });
  const api = Collector.install(f.win, State);
  const view = api.snapshot();
  assert.deepEqual(view.recent.map((row) => row.id), ["same-chat", "recent-1", "recent-2"]);
  api.pin("project-chat");
  assert.equal(api.snapshot().pinned.id, "project-chat");
  assert.equal(api.snapshot().pinned.url, "https://chatgpt.com/c/project-chat");
  api.dispose();
}

function testNativeSidebarMarkersDriveBusyUnreadAndReadState() {
  const f = fixture({ links: [
    { id: "working", title: "Working", working: true, unreadDot: true },
    { id: "unread", title: "Unread", unreadDot: true },
    { id: "read", title: "Read" }
  ] });
  const api = Collector.install(f.win, State);
  assert.equal(api.version, 3);
  let byId = new Map(api.snapshot().recent.map((row) => [row.id, row]));
  assert.equal(byId.get("working").activity, "generating");
  assert.equal(byId.get("working").unread, false); // Working wins over an overlapping dot.
  assert.equal(byId.get("unread").activity, "idle");
  assert.equal(byId.get("unread").unread, true);
  assert.equal(byId.get("read").activity, "idle");
  assert.equal(byId.get("read").unread, false);

  f.linkStates[0].working = false;
  byId = new Map(api.snapshot().recent.map((row) => [row.id, row]));
  assert.equal(byId.get("working").activity, "idle");
  assert.equal(byId.get("working").unread, true);

  f.linkStates[0].unreadDot = false;
  byId = new Map(api.snapshot().recent.map((row) => [row.id, row]));
  assert.equal(byId.get("working").activity, "idle");
  assert.equal(byId.get("working").unread, false);
  api.dispose();
}

function testCurrentOlderConversationExposesStatusOutsideRecentThree() {
  const f = fixture({
    href: "https://chatgpt.com/c/older",
    links: [
      { id: "latest-1", title: "Latest 1" },
      { id: "latest-2", title: "Latest 2" },
      { id: "latest-3", title: "Latest 3" },
      { id: "older", title: "Older conversation", working: true }
    ],
  });
  const api = Collector.install(f.win, State);
  const view = api.snapshot();
  assert.deepEqual(view.recent.map((row) => row.id), ["latest-1", "latest-2", "latest-3"]);
  assert.equal(view.currentConversationId, "older");
  assert.equal(view.current.id, "older");
  assert.equal(view.current.title, "Older conversation");
  assert.equal(view.current.activity, "generating");
  assert.equal(view.current.activityObservedAt, view.observedAt);
  assert.equal(view.current.unread, false);
  api.dispose();
}

function testMissingSidebarRowRemainsUnknownWithoutUnreadDot() {
  const f = fixture({
    href: "https://chatgpt.com/c/not-in-sidebar",
    heading: "Open conversation",
    links: [{ id: "recent", title: "Sidebar conversation" }]
  });
  const api = Collector.install(f.win, State);
  const view = api.snapshot();
  assert.equal(view.currentConversationId, "not-in-sidebar");
  assert.equal(view.current, null); // No sidebar title/status row is available; never read page headings.
  api.dispose();
}

function testPinsPersistOnlyForStrongAccountAndSyncViaStorage() {
  const readOffset = fixture.readKeys.length;
  const first = fixture({ accountId: "user_123", links: [{ id: "chat", title: "Pinned title" }] });
  const firstApi = Collector.install(first.win, State);
  assert.equal(firstApi.scopeStatus, "account");
  firstApi.pin("chat");
  const key = "__dia_chatgpt_preview_pin_v1__:user_123";
  assert.equal(first.store.has(key), true);
  assert.equal(fixture.readKeys.slice(readOffset).every((readKey) => readKey.startsWith("__dia_chatgpt_preview_pin_v1__:")), true);

  const second = fixture({ accountId: "user_123", sharedStore: first.store, links: [{ id: "chat", title: "Pinned title" }] });
  const secondApi = Collector.install(second.win, State);
  assert.equal(secondApi.snapshot().pinned.id, "chat");
  second.store.delete(key); // The browser updates shared storage before delivering the event.
  second.win.dispatch("storage", { key, newValue: null });
  assert.equal(secondApi.snapshot().pinned, null);
  firstApi.dispose();
  secondApi.dispose();

  const transient = fixture({ links: [{ id: "chat", title: "Chat" }] });
  const transientApi = Collector.install(transient.win, State);
  transientApi.pin("chat");
  const fallbackKey = "__dia_chatgpt_preview_transient_pin_v1__";
  assert.deepEqual(JSON.parse(transient.store.get(fallbackKey)), { id: "chat" });
  assert.equal(transient.store.get(fallbackKey).includes("Chat"), false);
  transientApi.dispose();
}

function testTransientPinSurvivesDocumentsButResolvesOnlyFromCurrentSidebar() {
  const shared = new Map([["unrelated", "leave this alone"]]);
  const first = fixture({ links: [{ id: "chat", title: "Old page title" }], sharedStore: shared });
  const firstApi = Collector.install(first.win, State);
  firstApi.pin("chat");
  const key = "__dia_chatgpt_preview_transient_pin_v1__";
  assert.deepEqual(JSON.parse(shared.get(key)), { id: "chat" });
  const firstScope = firstApi.scopeKey;
  firstApi.dispose();

  const next = fixture({ links: [{ id: "chat", title: "Fresh page title" }], sharedStore: shared });
  const nextApi = Collector.install(next.win, State);
  let view = nextApi.snapshot();
  assert.notEqual(nextApi.scopeKey, firstScope); // Pin crosses documents; observation state does not.
  assert.equal(view.pinned.title, "Fresh page title");

  const otherAccount = fixture({ links: [{ id: "different-chat", title: "Other account" }], sharedStore: shared });
  const otherApi = Collector.install(otherAccount.win, State);
  view = otherApi.snapshot();
  assert.equal(view.pinned, null); // Id is hidden unless this page's sidebar resolves it.

  shared.set(key, JSON.stringify({ id: "different-chat" }));
  otherAccount.win.dispatch("storage", { key, newValue: shared.get(key) });
  assert.equal(otherApi.snapshot().pinned.title, "Other account");
  otherApi.pin(null);
  assert.equal(shared.has(key), false);
  assert.equal(shared.get("unrelated"), "leave this alone");
  nextApi.dispose();
  otherApi.dispose();
}

function testMalformedTransientPinIdsAreIgnored() {
  const key = "__dia_chatgpt_preview_transient_pin_v1__";
  const shared = new Map([[key, JSON.stringify({ id: "../bad", title: "Should never appear" })]]);
  const f = fixture({ links: [{ id: "good", title: "Good" }], sharedStore: shared });
  const api = Collector.install(f.win, State);
  assert.equal(api.snapshot().pinned, null);
  api.dispose();
}

function testSameOriginAndIdValidationAndDispose() {
  const f = fixture({ links: [
    { id: "good", title: "Good" },
    { id: "evil", title: "Evil", href: "https://evil.example/c/evil" },
    { id: "bad", title: "Bad", href: "/c/bad?x=1" },
    { id: "../x", title: "Traversal" }
  ] });
  const api = Collector.install(f.win, State);
  assert.deepEqual(api.snapshot().recent.map((row) => row.id), ["good"]);
  const before = f.win.listeners.get("storage").size;
  f.win.DiaChatGPTPreview = api;
  api.dispose();
  assert.equal(f.win.listeners.get("storage").size, before - 1);
  assert.equal(Object.hasOwn(f.win, "DiaChatGPTPreview"), false);
  assert.equal(api.snapshot(), null);

  const replacement = Collector.install(f.win, State);
  f.win.DiaChatGPTPreview = replacement;
  assert.notEqual(f.win.DiaChatGPTPreview, api);
  assert.equal(replacement.snapshot().sourceStatus, "ready");
  replacement.dispose();
}

function testAccountChangesAndLogoutDiscardPriorScope() {
  const f = fixture({ accountId: "account_a", links: [{ id: "a-chat", title: "A chat" }] });
  const api = Collector.install(f.win, State);
  const originalScope = api.scopeKey;
  api.pin("a-chat");
  assert.equal(api.snapshot().pinned.id, "a-chat");

  f.win.__reactRouterContext = { state: { loaderData: { root: { user: { id: "account_b" } } } } };
  let view = api.snapshot();
  assert.equal(api.scopeKey, "account:account_b");
  assert.notEqual(api.scopeKey, originalScope);
  assert.equal(view.scopeStatus, "account");
  assert.equal(view.pinned, null); // Account A's dedicated pin is not carried into B.

  delete f.win.__reactRouterContext;
  view = api.snapshot();
  assert.equal(api.scopeStatus, "transient");
  assert.match(api.scopeKey, /^transient:/);
  assert.notEqual(api.scopeKey, "account:account_b");
  assert.equal(view.pinned, null);
  assert.equal(f.store.has("__dia_chatgpt_preview_pin_v1__:account_a"), true); // Kept under A only.
  assert.equal(f.store.has("__dia_chatgpt_preview_pin_v1__:account_b"), false);
  api.dispose();
}

testSidebarMetadataAndSourceStatus();
testDeclaredBrowserModuleOrderInstallsTheSameAdapter();
testProjectAndWebsitePinnedRowsAreNotRecent();
testNativeSidebarMarkersDriveBusyUnreadAndReadState();
testCurrentOlderConversationExposesStatusOutsideRecentThree();
testMissingSidebarRowRemainsUnknownWithoutUnreadDot();
testPinsPersistOnlyForStrongAccountAndSyncViaStorage();
testTransientPinSurvivesDocumentsButResolvesOnlyFromCurrentSidebar();
testMalformedTransientPinIdsAreIgnored();
testSameOriginAndIdValidationAndDispose();
testAccountChangesAndLogoutDiscardPriorScope();
console.log("chatgpt-preview-collector: all tests passed");
