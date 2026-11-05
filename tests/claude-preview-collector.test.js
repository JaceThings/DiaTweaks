"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const Collector = require("../src/dylib/Patches/ClaudePreview/Collector.js");
const Runtime = require("../src/dylib/TabIntegrations/AdapterRuntime.js");
const integrationDir = path.join(__dirname, "../src/dylib/Patches/ClaudePreview");

function labelNode(title, status) {
  const copy = {
    textContent: title + status,
    querySelectorAll() {
      const srOnly = { remove: () => { copy.textContent = title; } };
      return [srOnly];
    }
  };
  return { cloneNode: () => copy };
}

function conversation(id, title, href, working = false) {
  const label = labelNode(title, "Working");
  const row = {
    querySelector(selector) {
      if (selector === "[data-row-label] .dframe-fade-label") return label;
      return selector === '[data-attention="working"]' && working ? {} : null;
    }
  };
  return {
    getAttribute(name) { return name === "href" ? (href || "/chat/" + id) : null; },
    closest(selector) { return selector === "[data-row]" ? row : null; }
  };
}

function container(anchors) { return { querySelectorAll: () => anchors }; }

function fixture(options = {}) {
  const recents = options.recents === false ? null : container(options.links || []);
  const pinned = options.pinned ? container(options.pinned) : null;
  const sidebar = options.sidebar === false ? null : {
    querySelector(selector) {
      if (selector === '[data-testid="sidebar-recents"]') return recents;
      if (selector === '[data-testid="sidebar-pinned"]') return pinned;
      return null;
    }
  };
  const doc = { querySelector: selector => selector === "aside.dframe-sidebar" ? sidebar : null, documentElement: {} };
  const win = {
    document: doc,
    location: { origin: "https://claude.ai", pathname: options.pathname || "/", href: "https://claude.ai/" },
    DPTabIntegrationRuntime: Runtime,
    URL,
    localStorage: {
      getItem() { throw new Error("no identity-scoped storage should be read"); },
      setItem() { throw new Error("no identity-scoped storage should be written"); },
      removeItem() { throw new Error("no identity-scoped storage should be changed"); }
    },
    setTimeout: () => 1,
    clearTimeout() {},
    addEventListener() {},
    removeEventListener() {}
  };
  return { win, doc };
}

function testReaderExtractsLabelWithoutStatusAndBoundsRecents() {
  const f = fixture({ links: [conversation("one", "First"), conversation("two", "Second"), conversation("three", "Third"), conversation("four", "Fourth")] });
  const result = Collector.read(f.win);
  assert.equal(result.scopeKey, null);
  assert.equal(result.sourceStatus, "ready");
  assert.deepEqual(result.rows.map(row => row.id), ["one", "two", "three", "four"]);
  assert.deepEqual(result.rows.map(row => row.title), ["First", "Second", "Third", "Fourth"]);
  assert.ok(result.rows.every(row => row.activity === "unknown" && row.unread === false && row.recent === true));
}

function testPinnedCandidatesAreCataloguedButDoNotTakeRecentSlots() {
  const f = fixture({
    links: [conversation("r1", "Recent 1"), conversation("r2", "Recent 2"), conversation("r3", "Recent 3"), conversation("r4", "Recent 4")],
    pinned: [conversation("p1", "Site pinned")]
  });
  const result = Collector.read(f.win);
  assert.equal(result.rows.at(-1).id, "p1");
  assert.equal(result.rows.at(-1).recent, false);
  const api = Collector.install(f.win);
  const snapshot = api.snapshot();
  assert.deepEqual(snapshot.recent.map(row => row.id), ["r1", "r2", "r3"]);
  api.pin("p1");
  assert.equal(api.snapshot().pinned.id, "p1");
  assert.equal(api.snapshot().pinned.title, "Site pinned");
  api.dispose();
}

function testConfirmedWorkingMarkerDrivesGeneratingState() {
  const f = fixture({ links: [conversation("busy", "Working conversation", undefined, true), conversation("quiet", "No marker")] });
  const rows = Collector.read(f.win).rows;
  assert.equal(rows[0].activity, "generating");
  assert.equal(rows[0].unread, false);
  assert.equal(rows[1].activity, "unknown");
  assert.equal(rows[1].unread, false);
}

function testInvalidURLsDuplicatesAndLongTitlesAreRejected() {
  const f = fixture({ links: [
    conversation("good", "Good"),
    conversation("good", "Duplicate"),
    conversation("query", "Query", "/chat/query?x=1"),
    conversation("share", "Share", "/share/share"),
    conversation("evil", "Evil", "https://evil.example/chat/evil"),
    conversation("bad", "Bad", "/chat/bad#fragment"),
    conversation("long", "x".repeat(301))
  ] });
  assert.deepEqual(Collector.read(f.win).rows.map(row => row.id), ["good"]);
  for (const [id, url] of [
    ["good", "https://claude.ai/chat/good?x=1"],
    ["good", "https://claude.ai/chat/other"],
    ["good", "https://user:pass@claude.ai/chat/good"],
    ["../x", "https://claude.ai/chat/../x"]
  ]) assert.equal(Collector.conversationURL(id, url), null);
  assert.equal(Collector.conversationURL("good", "/chat/good"), "https://claude.ai/chat/good");
}

function testMissingSidebarAndSignedOutState() {
  assert.equal(Collector.read(fixture({ sidebar: false }).win).sourceStatus, "unavailable");
  assert.equal(Collector.read(fixture({ recents: false }).win).sourceStatus, "unavailable");
  const empty = Collector.read(fixture().win);
  assert.equal(empty.sourceStatus, "unavailable");
  assert.equal(empty.rows.length, 0);
  const signedOut = Collector.read(fixture({ pathname: "/login" }).win);
  assert.equal(signedOut.sourceStatus, "signed-out");
  assert.equal(signedOut.scopeKey, null);
}

function testNativeBuildLoadsManifestAndInstallsSharedRuntime() {
  const manifest = JSON.parse(fs.readFileSync(path.join(integrationDir, "integration.json"), "utf8"));
  assert.deepEqual(manifest, { runtime: true, conversations: true, scripts: ["Collector.js"] });
  const f = fixture({ links: [conversation("browser", "Browser build")] });
  f.win.DPConversationRuntime = require("../src/dylib/TabIntegrations/ConversationRuntime.js");
  const context = vm.createContext(f.win);
  vm.runInContext(fs.readFileSync(path.join(integrationDir, "Collector.js"), "utf8"), context, { filename: "Collector.js" });
  assert.equal(f.win.DiaClaudePreview.version, 1);
  const browserSnapshot = f.win.DiaClaudePreview.snapshot();
  assert.equal(browserSnapshot.sourceStatus, "ready");
  assert.equal(browserSnapshot.recent[0].title, "Browser build");
  f.win.DiaClaudePreview.dispose();
  assert.equal(Object.hasOwn(f.win, "DiaClaudePreview"), false);
}

testReaderExtractsLabelWithoutStatusAndBoundsRecents();
testPinnedCandidatesAreCataloguedButDoNotTakeRecentSlots();
testConfirmedWorkingMarkerDrivesGeneratingState();
testInvalidURLsDuplicatesAndLongTitlesAreRejected();
testMissingSidebarAndSignedOutState();
testNativeBuildLoadsManifestAndInstallsSharedRuntime();
console.log("claude-preview-collector: all tests passed");
