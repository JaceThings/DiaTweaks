"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const Runtime = require("../src/dylib/TabIntegrations/AdapterRuntime.js");

class EventTarget {
  constructor() { this.listeners = new Map(); }
  addEventListener(type, fn) {
    if (!this.listeners.has(type)) this.listeners.set(type, new Set());
    this.listeners.get(type).add(fn);
  }
  removeEventListener(type, fn) { this.listeners.get(type)?.delete(fn); }
  dispatch(type) { for (const fn of this.listeners.get(type) || []) fn(); }
}

function harness() {
  const win = new EventTarget();
  const doc = { documentElement: new EventTarget(), querySelector: () => null };
  win.document = doc;
  win.timers = new Map();
  win.intervals = new Map();
  win.nextTimer = 1;
  win.setTimeout = (fn) => { const id = win.nextTimer++; win.timers.set(id, fn); return id; };
  win.clearTimeout = (id) => win.timers.delete(id);
  win.setInterval = (fn) => { const id = win.intervals.size + 1; win.intervals.set(id, fn); return id; };
  win.clearInterval = (id) => win.intervals.delete(id);
  win.flushTimers = () => { const callbacks = [...win.timers.values()]; win.timers.clear(); callbacks.forEach((fn) => fn()); };
  win.MutationObserver = class {
    constructor(callback) { this.callback = callback; harness.observers.push(this); }
    observe(target, options) { this.target = target; this.options = options; }
    disconnect() { this.disconnected = true; }
    mutate() { this.callback([]); }
  };
  harness.observers = [];
  return win;
}

const fixtureDir = path.join(__dirname, "fixtures/tab-integrations/runtime");
for (const filename of fs.readdirSync(fixtureDir).sort()) {
  if (!filename.endsWith(".json")) continue;
  const fixture = JSON.parse(fs.readFileSync(path.join(fixtureDir, filename), "utf8"));
  const win = harness();
  let current = fixture.initial;
  let collections = 0;
  let commands = 0;
  const api = Runtime.create({
    window: win,
    version: 1,
    collectPolicy: "dirty",
    observeMutations: false,
    collect() { collections += 1; return current; },
    commands: { [fixture.command]() { commands += 1; current = fixture.afterCommand; } }
  });

  // The same native JSON transport contract accepts each unrelated provider schema.
  assert.deepEqual(JSON.parse(JSON.stringify(api.snapshot())), fixture.initial, filename);
  assert.deepEqual(JSON.parse(JSON.stringify(api.snapshot())), fixture.initial, filename);
  assert.equal(collections, 1, filename);
  api[fixture.command]();
  assert.deepEqual(JSON.parse(JSON.stringify(api.snapshot())), fixture.afterCommand, filename);
  assert.equal(collections, 2, filename);
  api.dispose();
  assert.equal(api.disposed, true, filename);
  assert.deepEqual(JSON.parse(JSON.stringify(api.snapshot())), fixture.afterCommand, filename);
  api[fixture.command]();
  assert.equal(commands, 1, filename);
}

{
  const win = harness();
  const root = new EventTarget();
  let reads = 0;
  const api = Runtime.create({ window: win, version: 2, root, debounceMs: 5, events: ["focus"], collectPolicy: "dirty",
    collect() { return { read: ++reads }; } });
  assert.deepEqual(api.snapshot(), { read: 1 });
  win.dispatch("focus");
  win.flushTimers();
  assert.deepEqual(api.snapshot(), { read: 2 });
  harness.observers.at(-1).mutate();
  assert.deepEqual(harness.observers.at(-1).options, { childList: true, subtree: true, attributes: true, characterData: true });
  win.flushTimers();
  assert.deepEqual(api.snapshot(), { read: 3 });
  api.dispose();
  assert.equal(win.listeners.get("focus").size, 0);
  assert.equal(harness.observers.at(-1).disconnected, true);
  assert.equal(win.timers.size, 0);
}

{
  const win = harness();
  harness.observers = [];
  assert.throws(() => Runtime.create({ window: win, version: 1, collectPolicy: "interval", events: ["focus"],
    collect() { return {}; }, commands: { snapshot() {} } }), /invalid adapter command/);
  assert.equal(harness.observers.length, 0);
  assert.equal(win.listeners.get("focus"), undefined);
  assert.equal(win.intervals.size, 0);
}

{
  const win = harness();
  let time = 100;
  let reads = 0;
  const api = Runtime.create({ window: win, version: 1, collectPolicy: "dirty", maxAgeMs: 50, now: () => time,
    observeMutations: false, collect() { return { read: ++reads }; } });
  assert.deepEqual(api.snapshot(), { read: 1 });
  time = 149;
  assert.deepEqual(api.snapshot(), { read: 1 });
  time = 150;
  assert.deepEqual(api.snapshot(), { read: 2 });
  api.dispose();
}

{
  const win = harness();
  let reads = 0;
  const api = Runtime.create({ window: win, version: 1, collectPolicy: "dirty", observeMutations: false,
    collect() { reads += 1; if (reads === 1) throw new Error("temporary read error"); return { read: reads }; } });
  assert.throws(() => api.snapshot(), /temporary read error/);
  assert.deepEqual(api.snapshot(), { read: 2 });
  api.dispose();
}

{
  const win = harness();
  let reads = 0;
  const api = Runtime.create({ window: win, version: 1, collectPolicy: "dirty", debounceMs: 5,
    collect() { return { read: ++reads }; } });
  api.snapshot();
  harness.observers.at(-1).mutate();
  assert.equal(win.timers.size, 1);
  assert.deepEqual(api.snapshot(), { read: 2 });
  assert.equal(win.timers.size, 0);
  win.flushTimers();
  assert.equal(reads, 2);
  api.dispose();
}

{
  const win = harness();
  let reads = 0;
  const api = Runtime.create({ window: win, version: 1, collectPolicy: "interval", pollMs: 100,
    collect() { return { read: ++reads }; } });
  assert.deepEqual(api.snapshot(), { read: 1 });
  win.intervals.values().next().value();
  win.flushTimers();
  assert.deepEqual(api.snapshot(), { read: 2 });
  api.dispose();
  assert.equal(win.intervals.size, 0);
}

{
  const win = harness();
  let reads = 0;
  const api = Runtime.create({ window: win, version: 1, collectPolicy: "dirty", debounceMs: 5,
    collect() { return { read: ++reads }; } });
  api.snapshot();
  harness.observers.at(-1).mutate();
  assert.equal(win.timers.size, 1);
  api.dispose();
  assert.equal(win.timers.size, 0);
  win.flushTimers();
  assert.equal(reads, 1);
}

assert.throws(() => Runtime.create({ window: harness(), version: 1, collect() {}, collectPolicy: "guess" }), /collectPolicy/);
