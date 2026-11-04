const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const scripts = JSON.parse(fs.readFileSync('build/integration-protocol-scripts.json', 'utf8'));
const namespace = 'Fixture-A"';
function context(origin = 'https://a.example') {
  const value = { window: {}, location: { origin } };
  vm.createContext(value);
  return value;
}
function run(source, value) { return vm.runInContext(source, value); }
const page = context();
let reads = 0, pins = 0, disposed = 0, foreignCalls = 0;
page.window[namespace] = { version: 1, snapshot() { reads++; return { owner: 'A' }; }, pin(value) { pins++; page.pin = value; }, dispose() { disposed++; } };
page.window.FixtureB = { snapshot() { foreignCalls++; }, dispose() { foreignCalls++; } };
assert.equal(JSON.parse(run(scripts.poll, page)).owner, 'A');
run(scripts.command, page);
assert.equal(pins, 1);
assert.equal(page.pin, scripts.payload);
assert.equal(page.injected, undefined, 'command arguments remain data');
run(scripts.dispose, page);
assert.equal(disposed, 1);
assert.equal(page.window[namespace], undefined);
assert.equal(foreignCalls, 0, 'another provider namespace is untouched');
const install = context();
let oldDisposed = 0;
install.window[namespace] = { version: 0, dispose() { oldDisposed++; } };
assert.equal(JSON.parse(run(scripts.install, install)).loaded, 'A');
assert.equal(oldDisposed, 1, 'old adapter is disposed on version replacement');
assert.equal(install.window[namespace].version, 1);
for (const source of [scripts.poll, scripts.install, scripts.command, scripts.dispose]) {
  const foreign = context('https://b.example');
  foreign.window[namespace] = { version: 1, snapshot() { throw Error('foreign snapshot'); }, pin() { throw Error('foreign command'); }, dispose() { throw Error('foreign dispose'); } };
  assert.equal(run(source, foreign), '{}', 'origin is checked again inside the page');
}
assert.ok(reads >= 2);
console.log('tab-integrations-protocol: namespace/origin isolation and JSON arguments passed');
