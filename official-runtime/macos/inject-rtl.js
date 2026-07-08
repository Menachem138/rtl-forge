#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');

const DEBUG_URL = process.env.CLAUDE_RTL_DEBUG_URL || 'http://127.0.0.1:9229/json/list';
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const PAYLOAD_PATH = process.env.CLAUDE_RTL_PAYLOAD || path.join(REPO_ROOT, 'dist', 'payload.js');

async function getTarget() {
  const res = await fetch(DEBUG_URL);
  if (!res.ok) throw new Error(`Inspector target list failed: HTTP ${res.status}`);
  const targets = await res.json();
  const target = targets.find((t) => t.webSocketDebuggerUrl && t.type === 'node') || targets[0];
  if (!target || !target.webSocketDebuggerUrl) {
    throw new Error('No Node inspector target found for Claude');
  }
  return target;
}

async function evaluateInClaude(expression) {
  const target = await getTarget();
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  let id = 0;
  const pending = new Map();

  ws.addEventListener('message', (event) => {
    const msg = JSON.parse(event.data);
    if (msg.id && pending.has(msg.id)) {
      pending.get(msg.id)(msg);
      pending.delete(msg.id);
    }
  });

  await new Promise((resolve, reject) => {
    ws.addEventListener('open', resolve, { once: true });
    ws.addEventListener('error', reject, { once: true });
  });

  const call = (method, params = {}) => {
    const msg = { id: ++id, method, params };
    ws.send(JSON.stringify(msg));
    return new Promise((resolve) => pending.set(msg.id, resolve));
  };

  try {
    let response = await call('Runtime.evaluate', {
      expression,
      awaitPromise: false,
      returnByValue: false,
      replMode: true,
      timeout: 15000,
    });

    if (response.error) throw new Error(JSON.stringify(response.error));
    let result = response.result && response.result.result;

    if (result && result.subtype === 'promise' && result.objectId) {
      response = await call('Runtime.awaitPromise', {
        promiseObjectId: result.objectId,
        returnByValue: true,
        timeout: 15000,
      });
      if (response.error) throw new Error(JSON.stringify(response.error));
      result = response.result && response.result.result;
    }

    if (!result) return null;
    if (result.type === 'string') return result.value;
    if ('value' in result) return result.value;
    return JSON.stringify(result);
  } finally {
    ws.close();
  }
}

function mainExpression() {
  if (!fs.existsSync(PAYLOAD_PATH)) {
    throw new Error(`Payload not found at ${PAYLOAD_PATH}. Run: npm run build`);
  }
  const closeInspector = process.env.CLAUDE_RTL_KEEP_INSPECTOR !== '1';
  return `
(async () => {
  const require = process.getBuiltinModule('module').createRequire('file:///');
  const fs = require('node:fs');
  const crypto = require('node:crypto');
  const electron = require('electron');
  const payloadPath = ${JSON.stringify(PAYLOAD_PATH)};
  const payload = fs.readFileSync(payloadPath, 'utf8');
  const payloadHash = crypto.createHash('sha256').update(payload).digest('hex').slice(0, 16);
  const hookKey = '__CLAUDE_OFFICIAL_RTL_INJECTOR__';
  const hosts = new Set(['claude.ai', 'claude.com']);
  const closeInspector = ${JSON.stringify(closeInspector)};

  function hostMatches(url) {
    try {
      const u = new URL(url || 'about:blank');
      if (u.protocol === 'app:') return true;
      return hosts.has(u.hostname) || [...hosts].some((h) => u.hostname.endsWith('.' + h));
    } catch {
      return false;
    }
  }

  function collectFrames(frame, out = []) {
    if (!frame) return out;
    out.push(frame);
    const children = Array.isArray(frame.frames) ? frame.frames : [];
    for (const child of children) collectFrames(child, out);
    return out;
  }

  function safeFrameUrl(frame) {
    try { return frame.url || ''; } catch { return ''; }
  }

  async function injectFrame(frame, reason) {
    const url = safeFrameUrl(frame);
    if (!hostMatches(url)) return { skipped: true, url, reason: 'host' };
    try {
      const code =
        ';window.__CLAUDE_OFFICIAL_RTL_PAYLOAD_HASH__=' + JSON.stringify(payloadHash) + ';\\n' +
        payload +
        '\\n;({rtl:!!document.documentElement.getAttribute("data-claude-rtl"), style:!!document.getElementById("claude-rtl-style") || !!(document.__claudeRtlSheet && document.adoptedStyleSheets && document.adoptedStyleSheets.includes(document.__claudeRtlSheet)), href:location.href, reason:' + JSON.stringify(reason) + '});';
      const value = await frame.executeJavaScript(code, true);
      return { ok: true, url, value };
    } catch (error) {
      return { ok: false, url, error: String(error && error.stack || error) };
    }
  }

  async function injectWebContents(wc, reason) {
    if (!wc || wc.isDestroyed()) return [];
    const frames = collectFrames(wc.mainFrame);
    if (frames.length === 0 && hostMatches(wc.getURL())) {
      try {
        const value = await wc.executeJavaScript(payload, true);
        return [{ ok: true, url: wc.getURL(), value, via: 'webContents' }];
      } catch (error) {
        return [{ ok: false, url: wc.getURL(), error: String(error && error.stack || error), via: 'webContents' }];
      }
    }
    const results = [];
    for (const frame of frames) results.push(await injectFrame(frame, reason));
    return results;
  }

  if (globalThis[hookKey] && typeof globalThis[hookKey].dispose === 'function') {
    globalThis[hookKey].dispose();
  }

  const attached = new Map();
  const disposers = [];

  function attach(wc) {
    if (!wc || wc.isDestroyed() || attached.has(wc.id)) return;
    attached.set(wc.id, wc);
    const run = (reason) => setTimeout(() => injectWebContents(wc, reason).catch(() => {}), 50);
    const onReady = () => run('dom-ready');
    const onFinish = () => run('did-finish-load');
    const onNav = () => run('navigate');
    wc.on('dom-ready', onReady);
    wc.on('did-finish-load', onFinish);
    wc.on('did-navigate', onNav);
    wc.on('did-navigate-in-page', onNav);
    wc.once('destroyed', () => attached.delete(wc.id));
    disposers.push(() => {
      try { wc.off('dom-ready', onReady); } catch {}
      try { wc.off('did-finish-load', onFinish); } catch {}
      try { wc.off('did-navigate', onNav); } catch {}
      try { wc.off('did-navigate-in-page', onNav); } catch {}
    });
    run('attach');
  }

  const onCreated = (_event, wc) => attach(wc);
  electron.app.on('web-contents-created', onCreated);
  disposers.push(() => {
    try { electron.app.off('web-contents-created', onCreated); } catch {}
  });

  for (const wc of electron.webContents.getAllWebContents()) attach(wc);

  async function injectAll() {
    const all = electron.webContents.getAllWebContents();
    for (const wc of all) attach(wc);
    const results = [];
    for (const wc of all) {
      results.push({
        id: wc.id,
        type: typeof wc.getType === 'function' ? wc.getType() : null,
        url: typeof wc.getURL === 'function' ? wc.getURL() : '',
        frames: await injectWebContents(wc, 'manual'),
      });
    }
    return results;
  }

  globalThis[hookKey] = {
    payloadHash,
    payloadPath,
    attached,
    dispose() {
      for (const dispose of disposers.splice(0)) dispose();
      attached.clear();
    },
    injectAll,
  };

  const results = await injectAll();
  const injectedFrames = results.flatMap((r) => r.frames).filter((f) => f && f.ok);
  if (closeInspector) {
    setTimeout(() => {
      try { require('node:inspector').close(); } catch {}
    }, 500);
  }
  return JSON.stringify({
    ok: injectedFrames.length > 0,
    payloadHash,
    webContents: results.length,
    injectedFrames: injectedFrames.length,
    inspectorClosing: closeInspector,
    results,
  });
})()
`;
}

async function run() {
  const raw = await evaluateInClaude(mainExpression());
  const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw;
  console.log(JSON.stringify(parsed, null, 2));
  if (!parsed || !parsed.ok) process.exit(2);
}

run().catch((error) => {
  console.error(`[claude-official-rtl] ${error.stack || error.message || error}`);
  process.exit(1);
});
