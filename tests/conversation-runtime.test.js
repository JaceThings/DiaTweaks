"use strict";
const assert = require("node:assert/strict");
const Runtime = require("../src/dylib/TabIntegrations/AdapterRuntime.js");
const Conversations = require("../src/dylib/TabIntegrations/ConversationRuntime.js");
const row = (id, extra) => Object.assign({ id, title: "Synthetic " + id, url: "https://example.com/chat/" + id }, extra);
function fixture(initial) {
  let value = initial;
  const store = new Map();
  const win = { document: { documentElement: {} }, location: { origin: "https://example.com" },
    DPTabIntegrationRuntime: Runtime,
    localStorage: { getItem: key => store.get(key) ?? null, setItem: (key, v) => store.set(key, v), removeItem: key => store.delete(key) } };
  function install(extra) {
    const api = Conversations.create({ window: win, namespace: "DiaExample", origin: "https://example.com", read: () => value,
      conversationURL: (id, url) => url === "https://example.com/chat/" + id ? url : null, ...extra });
    win.DiaExample = api;
    return api;
  }
  return { win, store, install, set: next => { value = next; } };
}
{
  const f = fixture({ sourceStatus: "ready", scopeKey: "account:a", rows: [row("a", {activity:"generating",unread:true}),row("b", {unread:true}),row("c"),row("d")] });
  const api = f.install();
  let snap = api.snapshot();
  assert.equal(snap.recent.length, 3);
  assert.equal(snap.recent[0].unread, false);
  assert.equal(snap.recent[1].unread, true);
  assert.equal(snap.recent[2].activity, "unknown");
  api.pin("d");
  assert.equal(api.snapshot().pinned.id, "d");
  assert.deepEqual([...f.store.values()], ["d"]); // No title or message text persisted.
  api.dispose();
  assert.equal(f.win.DiaExample, undefined);
  const restored = f.install();
  assert.equal(restored.snapshot().pinned.id, "d");
  f.set({ sourceStatus:"ready", scopeKey:"account:a", rows:[row("b")] });
  assert.equal(restored.snapshot().pinned.activity,"unknown");
  f.set({ sourceStatus:"ready", scopeKey:"account:b", rows:[row("b")] });
  assert.equal(restored.snapshot().pinned, null);
  f.set({ sourceStatus:"signed-out", rows:[row("a")] });
  snap = restored.snapshot();
  assert.equal(snap.scopeKey, null);
  assert.equal(snap.recent.length, 0);
  restored.pin("a");
  assert.equal(restored.snapshot().pinned, null);
  restored.dispose();
}
{
  const f = fixture({ sourceStatus:"ready", rows:[row("a"),row("a"),row("b",{url:"https://evil.example/chat/b"}),row("c",{title:""}),row("d",{id:{toString:()=>"d"}})] });
  const api=f.install();
  assert.deepEqual(api.snapshot().recent.map(x=>x.id), ["a"]);
  api.pin("a");
  assert.equal(api.snapshot().pinned.id,"a");
  assert.equal(f.store.size,0); // Unknown account identity is never persisted.
  api.pin("unknown");
  assert.equal(api.snapshot().pinned.id,"a");
  api.pin(null);
  assert.equal(api.snapshot().pinned,null);
  f.set({sourceStatus:"ready", rows:[row("a",{url:"https://example.com/chat/a#unsafe"})]});
  assert.equal(api.snapshot().sourceStatus,"unavailable");
  f.set({sourceStatus:"empty", rows:[row("a")]});
  assert.equal(api.snapshot().sourceStatus,"unavailable");
  f.set({sourceStatus:"empty", rows:[]});
  assert.equal(api.snapshot().sourceStatus,"empty");
  assert.deepEqual(api.snapshot().recent,[]);
  api.dispose();
}
{
  const f=fixture({sourceStatus:"ready",scopeKey:"account:blocked",rows:[row("a")]});
  f.win.localStorage.setItem=()=>{throw new Error("blocked");};
  const api=f.install();
  api.pin("a");
  assert.equal(api.snapshot().pinned.id,"a");
  f.set({sourceStatus:"ready",scopeKey:"account:blocked"});
  assert.equal(api.snapshot().sourceStatus,"unavailable");
  api.pin(null); // Unavailable data cannot mutate the previous pin.
  f.set({sourceStatus:"ready",scopeKey:"account:blocked",rows:[row("a")]});
  assert.equal(api.snapshot().pinned.id,"a");
  f.set({sourceStatus:"identity-lost"});
  assert.equal(api.snapshot().pinned,null);
  api.dispose();
}
{
  const f=fixture({sourceStatus:"ready",scopeKey:"guest:fixture",rows:[row("site-pin",{recent:false}),row("a"),row("b"),row("c")]});
  const api=f.install({persistentPins:false});
  assert.deepEqual(api.snapshot().recent.map(x=>x.id),["a","b","c"]);
  api.pin("site-pin");
  assert.equal(api.snapshot().pinned.id,"site-pin");
  assert.equal(f.store.size,0);
  api.dispose();
}
console.log("conversation-runtime: validation, scoped id-only pins, lifecycle and native status precedence passed");
