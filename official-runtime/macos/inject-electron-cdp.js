'use strict';

// Generic Electron RTL injector — the "one mechanism for every Electron app" path.
//
// It connects to a Chromium remote-debugging endpoint (opened by relaunching the target app with
// --remote-debugging-port) and injects the SAME dist/payload.js into every page/webview target via
// the Chrome DevTools Protocol. It touches nothing on disk: no copy, no asar edit, no re-sign, no
// source change. The RTL comes purely from this runtime injection — so it works for any user who
// runs the control panel, not because of any local build.
//
// Requires Node 22+ (global WebSocket). Env:
//   RTL_CDP_PORT   remote-debugging port to attach to (default 9333)
//   RTL_PAYLOAD    path to payload.js (required)
//   RTL_CDP_HOST   default 127.0.0.1

const http = require('http');
const fs = require('fs');

const HOST = process.env.RTL_CDP_HOST || '127.0.0.1';
const PORT = process.env.RTL_CDP_PORT || '9333';
const PAYLOAD_PATH = process.env.RTL_PAYLOAD;

if (!PAYLOAD_PATH || !fs.existsSync(PAYLOAD_PATH)) {
  console.error('inject-electron-cdp: RTL_PAYLOAD not found:', PAYLOAD_PATH);
  process.exit(2);
}
if (typeof WebSocket === 'undefined') {
  console.error('inject-electron-cdp: need Node 22+ (global WebSocket). Set RTL_NODE to a newer node.');
  process.exit(3);
}

const httpGetJSON = (path) =>
  new Promise((resolve, reject) => {
    http
      .get({ host: HOST, port: PORT, path }, (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          try { resolve(JSON.parse(data)); } catch (e) { reject(e); }
        });
      })
      .on('error', reject);
  });

// Chromium's debug endpoint rejects WS connections carrying a browser Origin that isn't allowed,
// but accepts originless clients (Node sends no Origin). We also launch with --remote-allow-origins=*.
function injectInto(target, payload) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(target.webSocketDebuggerUrl);
    let seq = 0;
    const pending = new Map();
    const call = (method, params) =>
      new Promise((res) => {
        const id = ++seq;
        pending.set(id, res);
        ws.send(JSON.stringify({ id, method, params: params || {} }));
      });

    ws.addEventListener('message', (ev) => {
      let msg;
      try { msg = JSON.parse(ev.data); } catch { return; }
      if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
    });
    ws.addEventListener('error', (e) => reject(e.message || e));
    ws.addEventListener('open', async () => {
      try {
        await call('Page.enable');
        // Persist across reloads/navigations within this target…
        await call('Page.addScriptToEvaluateOnNewDocument', { source: payload });
        // …and apply to whatever is on screen right now.
        const r = await call('Runtime.evaluate', { expression: payload, awaitPromise: false });
        ws.close();
        if (r.result && r.result.exceptionDetails) reject(r.result.exceptionDetails.text || 'payload threw');
        else resolve();
      } catch (e) { reject(e); }
    });
  });
}

(async () => {
  // Flip on generic mode BEFORE the payload runs: the target app has none of Claude's message-root
  // classes, so the engine treats <body> as one prose root and applies the tested per-leaf-block
  // path. Claude's own injector never sets this, so Claude is unaffected.
  const payload = 'try{window.__CLAUDE_RTL_GENERIC__=true;}catch(e){}\n' + fs.readFileSync(PAYLOAD_PATH, 'utf8');

  // The window may not be ready the instant the port opens — retry the target list briefly.
  let pages = [];
  for (let i = 0; i < 40; i++) {
    try {
      const targets = await httpGetJSON('/json/list');
      pages = targets.filter((t) => (t.type === 'page' || t.type === 'webview') && t.webSocketDebuggerUrl);
      if (pages.length) break;
    } catch { /* endpoint still coming up */ }
    await new Promise((r) => setTimeout(r, 250));
  }

  if (!pages.length) {
    console.error('inject-electron-cdp: no page targets on', `${HOST}:${PORT}`);
    process.exit(1);
  }

  let ok = 0;
  for (const p of pages) {
    try { await injectInto(p, payload); ok++; console.log('injected ->', p.url || p.title || p.id); }
    catch (e) { console.error('inject failed for', p.url || p.id, '::', e); }
  }
  console.log(`inject-electron-cdp: ${ok}/${pages.length} target(s) done`);
  process.exit(ok > 0 ? 0 : 1);
})();
