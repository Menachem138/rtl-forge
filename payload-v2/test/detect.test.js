'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  countStrong,
  firstStrongDir,
  detectBlockDir,
  plaintextOverrideDir,
  resolvedDir,
} = require('../src/detect.js');

test('pure Hebrew → rtl', () => {
  assert.equal(detectBlockDir('שלום עולם'), 'rtl');
  assert.equal(firstStrongDir('שלום'), 'rtl');
});

test('pure English → null (never force rtl)', () => {
  assert.equal(detectBlockDir('Hello world, this is English.'), null);
  assert.equal(firstStrongDir('Hello'), 'ltr');
});

test('majority Hebrew with English product name → rtl', () => {
  assert.equal(detectBlockDir('אני משתמש ב-Claude Desktop כל יום'), 'rtl');
});

test('majority English with one Hebrew word → null', () => {
  // more English letters than Hebrew
  assert.equal(detectBlockDir('The term שלום means peace in documentation'), null);
});

test('empty / digits only → null', () => {
  assert.equal(detectBlockDir(''), null);
  assert.equal(detectBlockDir('42.5 - 3'), null);
});

test('plaintextOverrideDir: Latin opener + majority RTL', () => {
  assert.equal(plaintextOverrideDir('OK — זה המשך בעברית ארוך ומפורט מאוד'), 'rtl');
  assert.equal(plaintextOverrideDir('Hello world only English here'), null);
});

test('resolvedDir for decorations', () => {
  assert.equal(resolvedDir('פריט ראשון'), 'rtl');
  assert.equal(resolvedDir('First item only'), 'ltr');
});

test('countStrong is code-point safe for astral (no throw)', () => {
  const c = countStrong('שלום 😀 hello');
  assert.ok(c.rtl >= 4);
  assert.ok(c.ltr >= 5);
});

test('Arabic detects as rtl', () => {
  assert.equal(detectBlockDir('مرحبا بالعالم'), 'rtl');
});
