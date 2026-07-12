'use strict';

/**
 * DOM application layer — layout attributes + observer only.
 * Never rewrites text nodes or injects wrapper spans into content.
 */

const STAMP = 'data-ortl';
const STAMP_DIR = 'data-ortl-dir';
const ROOT_ATTR = 'data-claude-rtl';
const STYLE_ID = 'claude-rtl-style';
const PAYLOAD_NAME = 'claude-official-rtl-payload-v2';

function installStyles(doc, cssText) {
  if (!doc || !doc.documentElement) return false;
  if (doc.getElementById(STYLE_ID)) return true;

  try {
    if (typeof CSSStyleSheet !== 'undefined' && doc.adoptedStyleSheets) {
      const sheet = new CSSStyleSheet();
      sheet.replaceSync(cssText);
      doc.adoptedStyleSheets = [...doc.adoptedStyleSheets, sheet];
      doc.__claudeRtlSheet = sheet;
      const mark = doc.createElement('style');
      mark.id = STYLE_ID;
      mark.setAttribute('data-ortl-sheet', 'adopted');
      mark.textContent = '/* ' + PAYLOAD_NAME + ' adoptedStyleSheet */';
      (doc.head || doc.documentElement).appendChild(mark);
      return true;
    }
  } catch {
    // fall through
  }

  const style = doc.createElement('style');
  style.id = STYLE_ID;
  style.textContent = cssText;
  (doc.head || doc.documentElement).appendChild(style);
  return true;
}

function textOf(el) {
  try {
    return (el && el.textContent) || '';
  } catch {
    return '';
  }
}

/** Own text only (not descendants) — for leaf span detection in generic apps. */
function ownText(el) {
  if (!el || !el.childNodes) return '';
  let s = '';
  for (let i = 0; i < el.childNodes.length; i++) {
    const n = el.childNodes[i];
    if (n.nodeType === 3) s += n.nodeValue || n.textContent || n.data || '';
  }
  // Fallback: pure text host with no element children may only expose textContent
  if (!s && !hasElementChild(el)) {
    try { s = el.textContent || ''; } catch { s = ''; }
  }
  return s;
}

function hasElementChild(el) {
  if (!el || !el.childNodes) return false;
  for (let i = 0; i < el.childNodes.length; i++) {
    const n = el.childNodes[i];
    if (n.nodeType !== 1) continue;
    const tag = (n.tagName || '').toUpperCase();
    if (tag === 'BR' || tag === 'WBR') continue;
    return true;
  }
  return false;
}

function shouldSkipElement(el, surfaces) {
  if (!el || el.nodeType !== 1) return true;
  if (surfaces.isNoTouch(el)) return true;
  return false;
}

function applyDirIfNeeded(el, dir, reason) {
  if (!dir || (dir !== 'rtl' && dir !== 'ltr')) return;
  const prev = el.getAttribute('dir');
  const stamped = el.getAttribute(STAMP_DIR);
  if (prev && !stamped && prev !== dir) return;
  el.setAttribute('dir', dir);
  el.setAttribute(STAMP_DIR, dir);
  el.setAttribute(STAMP, reason || '1');
}

function processProseLeaf(el, detect, surfaces) {
  if (shouldSkipElement(el, surfaces)) return;
  if (surfaces.isEditableHost(el) || surfaces.closestMatch(el, surfaces.SELECTORS.editableHost)) return;
  if (surfaces.isXtermSurface(el)) return;

  const text = textOf(el);
  const override = detect.plaintextOverrideDir(text);
  if (override === 'rtl') {
    applyDirIfNeeded(el, 'rtl', 'plaintext-override');
    return;
  }
  if (!el.hasAttribute(STAMP)) el.setAttribute(STAMP, 'prose');
}

function processListOrQuote(el, detect, surfaces) {
  if (shouldSkipElement(el, surfaces)) return;
  if (surfaces.closestMatch(el, surfaces.SELECTORS.editableHost)) return;
  const text = textOf(el);
  const dir = detect.resolvedDir(text);
  if (dir === 'rtl') applyDirIfNeeded(el, 'rtl', 'decorated');
  else if (!el.hasAttribute(STAMP)) el.setAttribute(STAMP, 'decorated-ltr');
}

function processTable(el, detect, surfaces) {
  if (shouldSkipElement(el, surfaces)) return;
  if (surfaces.closestMatch(el, surfaces.SELECTORS.editableHost)) return;
  const text = textOf(el);
  const dir = detect.detectBlockDir(text);
  if (dir === 'rtl') applyDirIfNeeded(el, 'rtl', 'table');
  else if (!el.hasAttribute(STAMP)) el.setAttribute(STAMP, 'table');
}

function processInputChrome(el) {
  if (!el || el.nodeType !== 1) return;
  const tag = (el.tagName || '').toUpperCase();
  if (tag !== 'TEXTAREA' && tag !== 'INPUT') return;
  if (el.closest && el.closest('.xterm, .xterm-helpers, .terminal')) return;
  if (!el.hasAttribute('dir')) {
    el.setAttribute('dir', 'auto');
    el.setAttribute(STAMP, 'input');
  }
}

/**
 * Generic-mode only: stamp pure text leaves (span/div with own Hebrew text, no element kids).
 * Used for Codex sidebar titles and similar Tailwind text leaves — NOT a blanket span flip.
 */
function processGenericTextLeaves(root, detect, surfaces) {
  if (!root || !root.querySelectorAll) return;
  const nodes = root.querySelectorAll('span, div');
  for (let i = 0; i < nodes.length; i++) {
    const el = nodes[i];
    if (shouldSkipElement(el, surfaces)) continue;
    if (surfaces.closestMatch(el, surfaces.SELECTORS.editableHost)) continue;
    if (surfaces.isXtermSurface(el)) continue;
    if (hasElementChild(el)) continue;
    const own = ownText(el).trim();
    if (own.length < 2) continue;
    // Leaf UI text (sidebar titles, etc.): first-strong RTL is enough — English product
    // names must not cancel a Hebrew sentence (majority letter count alone is too weak).
    const first = detect.firstStrongDir(own);
    const majority = detect.detectBlockDir(own);
    const override = detect.plaintextOverrideDir(own);
    const rtl = first === 'rtl' || majority === 'rtl' || override === 'rtl';
    if (!rtl) continue;
    try {
      if (el.classList) el.classList.add('ortl-leaf');
      else el.setAttribute('class', ((el.getAttribute('class') || '') + ' ortl-leaf').trim());
    } catch {
      /* ignore */
    }
    el.setAttribute(STAMP, 'leaf-text');
    applyDirIfNeeded(el, 'rtl', 'leaf-text');
  }
}

function processRoot(root, detect, surfaces, generic) {
  if (!root || root.nodeType !== 1) return;
  if (surfaces.isXtermSurface(root)) return;

  if (surfaces.isEditableHost(root)) {
    processInputChrome(root);
    return;
  }

  const tables = root.querySelectorAll ? root.querySelectorAll('table') : [];
  for (const t of tables) processTable(t, detect, surfaces);

  const decorated = root.querySelectorAll ? root.querySelectorAll('ul, ol, blockquote') : [];
  for (const d of decorated) processListOrQuote(d, detect, surfaces);

  const leaves = root.querySelectorAll
    ? root.querySelectorAll(surfaces.SELECTORS.proseLeaf)
    : [];
  for (const leaf of leaves) {
    if (surfaces.closestMatch(leaf, surfaces.SELECTORS.editableHost)) continue;
    if (surfaces.isXtermSurface(leaf)) continue;
    processProseLeaf(leaf, detect, surfaces);
  }

  if (generic) processGenericTextLeaves(root, detect, surfaces);

  const inputs = root.querySelectorAll ? root.querySelectorAll('textarea, input') : [];
  for (const inp of inputs) {
    if (surfaces.isXtermSurface(inp)) continue;
    processInputChrome(inp);
  }
}

function createController(doc, deps) {
  const { detect, surfaces, cssText } = deps;
  let observer = null;
  let scheduled = null;
  const generic =
    typeof globalThis !== 'undefined' &&
    (globalThis.__CLAUDE_RTL_GENERIC__ === true ||
      (typeof window !== 'undefined' && window.__CLAUDE_RTL_GENERIC__ === true));

  let pending = new Set(); // changed subtrees to reprocess on the next tick
  let fullPending = false; // fall back to a whole-document sweep this tick

  // Full sweep — de-duped so <body> isn't processed twice when it is already a scan root.
  function scan() {
    const roots = surfaces.getScanRoots(doc, generic);
    const seen = new Set();
    for (const r of roots) {
      if (r && r.nodeType === 1 && !seen.has(r)) {
        seen.add(r);
        processRoot(r, detect, surfaces, generic);
      }
    }
    if (doc.body && !seen.has(doc.body)) processRoot(doc.body, detect, surfaces, generic);
  }

  // Reduce a mutation to the element whose querySelectorAll covers the change, so streaming
  // (which reflows one leaf at a time) reprocesses that small subtree instead of the whole doc.
  function enqueue(m) {
    if (m.type === 'characterData') {
      const leaf = m.target && m.target.parentNode; // element holding the changed text
      const container = (leaf && leaf.parentNode) || leaf; // its parent → querySelectorAll finds the leaf
      if (container && container.nodeType === 1) pending.add(container);
      else fullPending = true;
    } else if (m.target && m.target.nodeType === 1) {
      pending.add(m.target); // childList: added nodes are descendants of the target
    } else {
      fullPending = true;
    }
  }

  function flush() {
    scheduled = null;
    const targets = pending;
    const full = fullPending;
    pending = new Set();
    fullPending = false;
    // Safety valve: a whole-body change or a huge burst is cheaper as one full sweep.
    if (full || (doc.body && targets.has(doc.body)) || targets.size > 40) {
      scan();
      return;
    }
    for (const el of targets) {
      if (el && el.nodeType === 1) processRoot(el, detect, surfaces, generic);
    }
  }

  function schedule() {
    if (scheduled) return;
    scheduled = (doc.defaultView || globalThis).setTimeout(flush, 48);
  }

  function start() {
    installStyles(doc, cssText);
    doc.documentElement.setAttribute(ROOT_ATTR, 'v2');
    doc.documentElement.setAttribute('data-ortl-payload', PAYLOAD_NAME);
    if (generic) doc.documentElement.setAttribute('data-ortl-generic', '1');
    scan(); // initial pass stays a full sweep
    if (typeof MutationObserver !== 'undefined') {
      observer = new MutationObserver((mutations) => {
        for (const m of mutations) enqueue(m);
        schedule();
      });
      observer.observe(doc.documentElement, {
        subtree: true,
        childList: true,
        characterData: true,
      });
    }
  }

  function dispose() {
    if (observer) observer.disconnect();
    observer = null;
    if (scheduled) {
      try {
        (doc.defaultView || globalThis).clearTimeout(scheduled);
      } catch {
        /* ignore */
      }
      scheduled = null;
    }
    pending = new Set();
    fullPending = false;
  }

  return { start, dispose, scan, processRoot: (r) => processRoot(r, detect, surfaces, generic) };
}

// __EXPORTS__
module.exports = {
  STAMP,
  STAMP_DIR,
  ROOT_ATTR,
  STYLE_ID,
  PAYLOAD_NAME,
  installStyles,
  processRoot,
  createController,
  processProseLeaf,
  processListOrQuote,
  processTable,
  processInputChrome,
  processGenericTextLeaves,
  ownText,
  hasElementChild,
};
