"use strict";

const assert = require("node:assert/strict");
const { createChatGPTPreviewState, normalizeConversation } = require("../src/dylib/Patches/ChatGPTPreview/State.js");

function conversation(id, updatedAt, overrides) {
  return Object.assign({
    id,
    title: "Conversation " + id,
    url: "https://chatgpt.com/c/" + id,
    updatedAt
  }, overrides || {});
}

function testConversationValidation() {
  assert.equal(normalizeConversation(conversation("abc_123-x", 10), "https://chatgpt.com").id, "abc_123-x");
  for (const row of [
    conversation("../other", 10),
    conversation("ok", 10, { title: "  " }),
    conversation("ok", 10, { title: 12 }),
    conversation("ok", -1),
    conversation("ok", NaN),
    conversation("ok", 10, { url: "https://evil.example/c/ok" }),
    conversation("ok", 10, { url: "https://user:pass@chatgpt.com/c/ok" }),
    conversation("ok", 10, { url: "https://chatgpt.com/c/ok?redirect=evil" }),
    conversation("ok", 10, { url: "https://chatgpt.com/c/other" }),
    conversation("ok", 10, { url: "https://chatgpt.com/c/ok/extra" })
  ]) assert.equal(normalizeConversation(row, "https://chatgpt.com"), null);
}

function testSortAndPinnedDedupe() {
  const model = createChatGPTPreviewState();
  model.syncConversations("profile-a", [
    conversation("old", 1), conversation("two", 2), conversation("pinned", 4),
    conversation("new", 5), conversation("three", 3), conversation("new", 6)
  ]);
  model.setPinnedConversation("profile-a", conversation("pinned", 0));
  const result = model.snapshot("profile-a", 100);
  assert.deepEqual(result.recent.map((row) => row.id), ["new", "three", "two"]);
  assert.equal(result.pinned.id, "pinned");
  assert.equal(model.snapshot("profile-b", 100).recent.length, 0);
  assert.equal(model.snapshot("profile-b", 100).pinned, null);
}

function testNativePerConversationBusyAndUnreadStatus() {
  const model = createChatGPTPreviewState();
  const rows = [conversation("working", 3), conversation("unread", 2), conversation("read", 1), conversation("unknown", 0)];
  model.syncConversations("account", rows, [
    { id: "working", activity: "generating", unread: true, observedAt: 1000 },
    { id: "unread", activity: "idle", unread: true, observedAt: 1000 },
    { id: "read", activity: "idle", unread: false, observedAt: 1000 }
  ]);
  const result = model.snapshot("account", 1000);
  const byId = new Map(result.recent.map((row) => [row.id, row]));
  assert.equal(byId.get("working").activity, "generating");
  assert.equal(byId.get("working").unread, false); // Busy marker wins over the dot.
  assert.equal(byId.get("unread").activity, "idle");
  assert.equal(byId.get("unread").unread, true);
  assert.equal(byId.get("read").unread, false);
  assert.equal(model.conversation("account", "unknown", 1000).activity, "unknown");
  assert.equal(model.conversation("account", "unknown", 1000).unread, null);
}

function testActivityAgesToStaleAndCanBeUnknown() {
  const model = createChatGPTPreviewState({ staleAfterMs: 50 });
  model.syncConversations("account", [conversation("chat", 1), conversation("other", 0)], [
    { id: "chat", activity: "idle", unread: true, observedAt: 100 }
  ]);
  assert.equal(model.snapshot("account", 150).recent.find((row) => row.id === "chat").activity, "idle");
  const stale = model.snapshot("account", 151).recent.find((row) => row.id === "chat");
  assert.equal(stale.activity, "stale");
  assert.equal(stale.unread, null);
  assert.equal(model.snapshot("account", 151).recent.find((row) => row.id === "other").activity, "unknown");
}

testConversationValidation();
testSortAndPinnedDedupe();
testNativePerConversationBusyAndUnreadStatus();
testActivityAgesToStaleAndCanBeUnknown();
console.log("chatgpt-preview-state: all tests passed");
