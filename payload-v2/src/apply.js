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

  // Prefer constructable stylesheets when available
  try {
    if (typeof CSSStyleSheet !== 'undefined' && doc.adoptedStyleSheets) {
      const sheet = new CSSStyleSheet();
      sheet.replaceSync(cssText);
      doc.adoptedStyleSheets = [...doc.adoptedStyleSheets, sheet];
      doc.__claudeRtlSheet = sheet;
      // also keep a marker element for inject diagnostics that look for style id
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

function shouldSkipElement(el, surfaces) {
  if (!el || el.nodeType !== 1) return true;
  if (surfaces.isNoTouch(el)) return true;
  // already stamped with same dir decision
  return false;
}

function applyDirIfNeeded(el, dir, reason) {
  if (!dir || (dir !== 'rtl' && dir !== 'ltr')) return;
  // do not fight explicit author dir on the element unless we stamped it
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
  // CSS plaintext handles most cases; override only when first-strong LTR + majority RTL
  const override = detect.plaintextOverrideDir(text);
  if (override === 'rtl') {
    applyDirIfNeeded(el, 'rtl', 'plaintext-override');
    return;
  }
  // mark as seen without forcing dir
  if (!el.hasAttribute(STAMP)) el.setAttribute(STAMP, 'prose');
}

function processListOrQuote(el, detect, surfaces) {
  if (shouldSkipElement(el, surfaces)) return;
  if (surfaces.closestMatch(el, surfaces.SELECTORS.editableHost)) return;
  const text = textOf(el);
  const dir = detect.resolvedDir(text);
  // only set rtl when content is actually RTL; ltr decorations default OK
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
  // Only dir=auto for empty-ish chrome; never touch value/text
  if (!el || el.nodeType !== 1) return;
  const tag = (el.tagName || '').toUpperCase();
  if (tag !== 'TEXTAREA' && tag !== 'INPUT') return;
  if (el.closest && el.closest('.xterm, .xterm-helpers, .terminal')) return;
  if (!el.hasAttribute('dir')) {
    el.setAttribute('dir', 'auto');
    el.setAttribute(STAMP, 'input');
  }
}

function processRoot(root, detect, surfaces) {
  if (!root || root.nodeType !== 1) return;
  if (surfaces.isXtermSurface(root)) return;

  // If the observer is scoped into an editor, do nothing but optional input chrome
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

  // bare inputs outside xterm
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

  function scan() {
    const roots = surfaces.getScanRoots(doc, generic);
    for (const r of roots) processRoot(r, detect, surfaces);
    // always process body once as safety net in Claude too
    if (doc.body) processRoot(doc.body, detect, surfaces);
  }

  function schedule() {
    if (scheduled) return;
    scheduled = (doc.defaultView || globalThis).setTimeout(() => {
      scheduled = null;
      scan();
    }, 48);
  }

  function start() {
    installStyles(doc, cssText);
    doc.documentElement.setAttribute(ROOT_ATTR, 'v2');
    doc.documentElement.setAttribute('data-ortl-payload', PAYLOAD_NAME);
    scan();
    if (typeof MutationObserver !== 'undefined') {
      observer = new MutationObserver(() => schedule());
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
  }

  return { start, dispose, scan, processRoot: (r) => processRoot(r, detect, surfaces) };
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
};
