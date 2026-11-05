"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const Runtime = require("../src/dylib/TabIntegrations/AdapterRuntime.js");
const Conversations = require("../src/dylib/TabIntegrations/ConversationRuntime.js");
const Collector = require("../src/dylib/Patches/GeminiPreview/Collector.js");
function fixture() {
  const state = { account: "Google Account: Synthetic User (person@example.com)", present:true, loading:false,
    rows:[{id:"pinned",title:"Synthetic site pin",pin:true},{id:"a",title:"Synthetic first"},{id:"b",title:"Synthetic second"},{id:"c",title:"Synthetic third"}] };
  const anchors = () => state.rows.map(row => ({
    getAttribute: name => name === "href" ? row.url || "/app/" + row.id : null,
    querySelector: selector => selector === ".title-text" ? { textContent:row.title } : null,
    closest: selector => selector === "gem-nav-list-item" ? {querySelector: selector => selector === ".conversation-pin-icon" && row.pin ? {} : null} : null
  }));
  const store = new Map();
  const win = { URL, location:{origin:"https://gemini.google.com"}, DPTabIntegrationRuntime:Runtime, DPConversationRuntime:Conversations,
    localStorage:{getItem:k=>store.get(k)??null,setItem:(k,v)=>store.set(k,v),removeItem:k=>store.delete(k)},
    document:{documentElement:{},querySelector: selector => selector === 'a.mavatar-footer-left[aria-label]'
      ? state.account ? {getAttribute:()=>state.account} : null
      : selector === 'conversations-list[data-test-id="all-conversations"]' && state.present
        ? {querySelectorAll:()=>anchors(),querySelector:()=>state.loading?{}:null} : null} };
  return {win,state,store};
}
{
  const {win,state,store}=fixture();const api=Collector.install(win);
  assert.deepEqual(api.snapshot().recent.map(x=>x.id),["a","b","c"]);
  assert.equal(api.snapshot().scopeKey,"account:person@example.com");
  api.pin("pinned");assert.equal(api.snapshot().pinned.id,"pinned");
  assert.deepEqual([...store.values()],["pinned"]);
  state.account="Google Account: Another User (other@example.com)";
  assert.equal(api.snapshot().pinned,null);
  state.account=null;assert.equal(api.snapshot().scopeKey,null);
  state.present=false;assert.equal(api.snapshot().sourceStatus,"unavailable");
  state.present=true;state.rows=[];state.loading=true;
  assert.equal(api.snapshot().sourceStatus,"unavailable");
  state.loading=false;assert.equal(api.snapshot().sourceStatus,"unavailable");
  state.rows=[{id:"bad",title:"bad",url:"https://evil.example/app/bad"}];
  assert.equal(api.snapshot().recent.length,0);
  api.dispose();
}
for(const url of ["https://evil.example/app/a","https://gemini.google.com/app/a?authuser=1","https://u:p@gemini.google.com/app/a","/app/a#fragment","/share/a","/app/b"])
  assert.equal(Collector.conversationURL("a",url),null);
assert.equal(Collector.conversationURL("a","/u/1/app/a"),"https://gemini.google.com/u/1/app/a");
{
  const {win}=fixture();win.globalThis=win;
  vm.runInNewContext(fs.readFileSync("src/dylib/Patches/GeminiPreview/Collector.js","utf8"),win);
  assert.equal(win.DiaGeminiPreview.snapshot().recent.length,3);win.DiaGeminiPreview.dispose();
}
console.log("gemini-preview-collector: observed sidebar/title markup, native pins, identity, loading and URL boundaries passed");
