'use strict';

// Schema guard for the adapter descriptors the menu-bar manager reads. Runs under the repo's
// existing `node --test` (see package.json "test"). Keeps the JSON honest: no typo'd status,
// no missing path, and the safety invariants the README/APP_ADAPTERS promise.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const ADAPTER_DIR = path.join(__dirname, '..', 'adapters');
const VALID_STATUS = new Set(['supported', 'candidate', 'research']);
const VALID_APPLY = new Set(['official-debugger', 'electron-cdp', 'electron-cdp-experimental']);
const files = fs.readdirSync(ADAPTER_DIR).filter((f) => f.endsWith('.json'));
const allAdapters = () => files.map((f) => JSON.parse(fs.readFileSync(path.join(ADAPTER_DIR, f), 'utf8')));

test('adapters: at least Claude, Hermes, and Codex are described', () => {
  assert.ok(files.length >= 3, `expected >= 3 adapters, found ${files.length}`);
});

for (const file of files) {
  const full = path.join(ADAPTER_DIR, file);
  const a = JSON.parse(fs.readFileSync(full, 'utf8'));

  test(`adapter ${file}: required fields + valid shape`, () => {
    for (const key of ['id', 'name', 'platform', 'bundleId', 'defaultPath', 'status', 'safeRoute']) {
      assert.ok(typeof a[key] === 'string' && a[key].length > 0, `${file}: "${key}" must be a non-empty string`);
    }
    assert.strictEqual(a.id, path.basename(file, '.json'), `${file}: id must match the file name`);
    assert.ok(VALID_STATUS.has(a.status), `${file}: status "${a.status}" not in ${[...VALID_STATUS].join('/')}`);
    if ('notes' in a) assert.ok(Array.isArray(a.notes), `${file}: notes must be an array`);
    if ('teamId' in a) assert.ok(typeof a.teamId === 'string' && a.teamId.length > 0, `${file}: teamId must be a non-empty string`);
    if ('apply' in a) assert.ok(VALID_APPLY.has(a.apply), `${file}: apply "${a.apply}" not in ${[...VALID_APPLY].join('/')}`);
  });
}

test('adapters: Claude is supported, pins the Anthropic Team ID, and uses its own debugger route', () => {
  const claude = allAdapters().find((a) => a.id === 'claude-official-macos');
  assert.ok(claude, 'the Claude adapter must exist');
  assert.strictEqual(claude.status, 'supported');
  assert.strictEqual(claude.teamId, 'Q6L2SF6YDW', 'Claude adapter must pin the Anthropic Team ID');
  assert.strictEqual(claude.apply, 'official-debugger');
});

test('adapters: every supported adapter has a non-experimental apply route', () => {
  for (const a of allAdapters().filter((a) => a.status === 'supported')) {
    assert.ok(a.apply, `${a.id}: a "supported" adapter must declare an apply route`);
    assert.notStrictEqual(a.apply, 'electron-cdp-experimental',
      `${a.id}: the experimental route must never ship as "supported"`);
  }
});

test('adapters: Codex stays research-only and its apply route is gated experimental', () => {
  const codex = allAdapters().find((a) => a.id === 'codex-research-macos');
  assert.strictEqual(codex.status, 'research', 'Codex must not be marketed as supported');
  assert.strictEqual(codex.apply, 'electron-cdp-experimental',
    'if Codex is injectable at all, it must be through the gated experimental route');
});
