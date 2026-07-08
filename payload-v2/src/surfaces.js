'use strict';

/**
 * Surface policy: where we may style, and hard no-touch zones.
 * Original product policy for Claude Desktop Official RTL.
 */

const SELECTORS = {
  // ProseMirror / edit boxes / form fields — never mutate children
  editableHost:
    '[contenteditable=""],[contenteditable="true"],[contenteditable=true],textarea,input, [role="textbox"]',
  // Claude Code / xterm — terminal must stay LTR
  xterm:
    '.xterm, .xterm-screen, .xterm-rows, .xterm-helpers, .xterm-helper-textarea, .terminal, [class*="xterm"]',
  // code blocks (still allow plaintext on outer pre? we skip mutating inside)
  code: 'pre, code, .hljs, [class*="language-"]',
  // leaf-ish prose targets
  proseLeaf: 'p, li, h1, h2, h3, h4, h5, h6, blockquote, td, th, figcaption, label, dt, dd',
};

function closestMatch(el, selector) {
  if (!el || el.nodeType !== 1) return null;
  if (typeof el.closest === 'function') {
    try {
      return el.closest(selector);
    } catch {
      return null;
    }
  }
  return null;
}

function isEditableHost(el) {
  return !!closestMatch(el, SELECTORS.editableHost);
}

function isXtermSurface(el) {
  return !!closestMatch(el, SELECTORS.xterm);
}

function isCodeSurface(el) {
  // code inside messages: we still allow parent dir, but skip deep rewrites (we never rewrite text anyway)
  return !!closestMatch(el, SELECTORS.code);
}

/**
 * Hard no-touch: no dir stamps that break carets, no child processing.
 */
function isNoTouch(el) {
  if (!el || el.nodeType !== 1) return true;
  if (isXtermSurface(el)) return true;
  if (isEditableHost(el)) return true;
  // skip script/style/svg/math internals
  const tag = (el.tagName || '').toUpperCase();
  if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'SVG' || tag === 'PATH' || tag === 'NOSCRIPT') {
    return true;
  }
  return false;
}

/**
 * Roots to scan. Generic mode widens beyond Claude markdown wrappers.
 */
function getScanRoots(doc, generic) {
  if (!doc) return [];
  if (generic) {
    return [doc.body || doc.documentElement].filter(Boolean);
  }
  const preferred = doc.querySelectorAll(
    [
      '[class*="standard-markdown"]',
      '[class*="markdown"]',
      '[class*="prose"]',
      '[data-testid*="conversation"]',
      'main',
      'article',
      '[role="log"]',
      '[role="article"]',
    ].join(',')
  );
  if (preferred && preferred.length) return Array.from(preferred);
  return [doc.body || doc.documentElement].filter(Boolean);
}

// __EXPORTS__
module.exports = {
  SELECTORS,
  isEditableHost,
  isXtermSurface,
  isCodeSurface,
  isNoTouch,
  getScanRoots,
  closestMatch,
};
