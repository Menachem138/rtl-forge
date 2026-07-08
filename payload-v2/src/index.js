'use strict';

/**
 * Browser entry (bundled into IIFE). In Node tests, modules are required separately.
 */

function boot(globalScope) {
  const g = globalScope || (typeof globalThis !== 'undefined' ? globalThis : {});
  const doc = g.document;
  if (!doc || !doc.documentElement) return { skipped: true, reason: 'no-dom' };

  // Idempotent: already running v2
  if (g.__CLAUDE_OFFICIAL_RTL_V2__ && typeof g.__CLAUDE_OFFICIAL_RTL_V2__.dispose === 'function') {
    try {
      g.__CLAUDE_OFFICIAL_RTL_V2__.dispose();
    } catch {
      /* ignore */
    }
  }

  const detect = g.__ORTL_DETECT__;
  const surfaces = g.__ORTL_SURFACES__;
  const cssText = g.__ORTL_CSS__;
  const apply = g.__ORTL_APPLY__;
  if (!detect || !surfaces || !cssText || !apply) {
    return { skipped: true, reason: 'missing-modules' };
  }

  const controller = apply.createController(doc, {
    detect,
    surfaces,
    cssText,
  });
  controller.start();
  g.__CLAUDE_OFFICIAL_RTL_V2__ = controller;
  return { ok: true, payload: apply.PAYLOAD_NAME };
}

// __EXPORTS__
module.exports = { boot };
