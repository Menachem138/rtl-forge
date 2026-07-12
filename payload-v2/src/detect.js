'use strict';

/**
 * Pure script / direction detection (no DOM).
 * Layout-only engine — decisions only, never rewrites text.
 */

function isRtlCodePoint(cp) {
  // Hebrew
  if (cp >= 0x0590 && cp <= 0x05ff) return true;
  // Arabic + presentation forms
  if (cp >= 0x0600 && cp <= 0x06ff) return true;
  if (cp >= 0x0750 && cp <= 0x077f) return true;
  if (cp >= 0x08a0 && cp <= 0x08ff) return true;
  if (cp >= 0xfb50 && cp <= 0xfdff) return true;
  if (cp >= 0xfe70 && cp <= 0xfeff) return true;
  // Syriac, Thaana, N'Ko, Samaritan, Mandaic
  if (cp >= 0x0700 && cp <= 0x074f) return true;
  if (cp >= 0x0780 && cp <= 0x07bf) return true;
  if (cp >= 0x07c0 && cp <= 0x07ff) return true;
  if (cp >= 0x0800 && cp <= 0x083f) return true;
  if (cp >= 0x0840 && cp <= 0x085f) return true;
  return false;
}

function isLtrLetterCodePoint(cp) {
  // Basic Latin letters
  if ((cp >= 0x41 && cp <= 0x5a) || (cp >= 0x61 && cp <= 0x7a)) return true;
  // Latin-1 supplement letters (rough)
  if (cp >= 0xc0 && cp <= 0x24f && !isRtlCodePoint(cp)) {
    // exclude multiply/divide signs etc. — treat letter-ish as LTR if not RTL
    if ((cp >= 0xc0 && cp <= 0xd6) || (cp >= 0xd8 && cp <= 0xf6) || (cp >= 0xf8 && cp <= 0x24f)) {
      return true;
    }
  }
  // Greek, Cyrillic (common in technical mixed content)
  if (cp >= 0x0370 && cp <= 0x03ff) return true;
  if (cp >= 0x0400 && cp <= 0x04ff) return true;
  return false;
}

/**
 * Count strong LTR vs RTL letters in a string (code-point safe).
 */
function countStrong(text) {
  let ltr = 0;
  let rtl = 0;
  if (!text) return { ltr, rtl };
  for (let i = 0; i < text.length; ) {
    const cp = text.codePointAt(i);
    i += cp > 0xffff ? 2 : 1;
    if (isRtlCodePoint(cp)) rtl += 1;
    else if (isLtrLetterCodePoint(cp)) ltr += 1;
  }
  return { ltr, rtl };
}

/**
 * First strong direction in the string (Unicode-ish first-strong).
 * Digits/neutrals skipped. Returns 'ltr' | 'rtl' | null.
 */
function firstStrongDir(text) {
  if (!text) return null;
  for (let i = 0; i < text.length; ) {
    const cp = text.codePointAt(i);
    i += cp > 0xffff ? 2 : 1;
    if (isRtlCodePoint(cp)) return 'rtl';
    if (isLtrLetterCodePoint(cp)) return 'ltr';
  }
  return null;
}

/**
 * Block base direction decision for optional dir= attributes.
 * Returns 'rtl' | 'ltr' | null.
 * null = leave to CSS plaintext / parent (never force RTL on English).
 */
function detectBlockDir(text) {
  const { ltr, rtl } = countStrong(text);
  if (rtl === 0 && ltr === 0) return null;
  if (rtl === 0) return null; // pure LTR / English — do not set dir
  if (ltr === 0) return 'rtl';
  // mixed: majority wins; ties fall back to first-strong if RTL, else null
  if (rtl > ltr) return 'rtl';
  if (ltr > rtl) return null;
  return firstStrongDir(text) === 'rtl' ? 'rtl' : null;
}

/**
 * When CSS plaintext misfires: first-strong LTR opener but majority RTL content.
 * Returns 'rtl' or null.
 */
function plaintextOverrideDir(text) {
  const { ltr, rtl } = countStrong(text);
  if (rtl === 0) return null;
  if (rtl <= ltr) return null;
  if (firstStrongDir(text) === 'ltr') return 'rtl';
  return null;
}

/**
 * Side the content "wants" for list markers / blockquote bars.
 * Prefer resolved majority; never invent rtl for empty/english.
 */
function resolvedDir(text) {
  const d = detectBlockDir(text);
  if (d) return d;
  // majority LTR or empty → ltr for decorations
  const { ltr, rtl } = countStrong(text);
  if (rtl > ltr) return 'rtl';
  return 'ltr';
}

// __EXPORTS__
module.exports = {
  isRtlCodePoint,
  isLtrLetterCodePoint,
  countStrong,
  firstStrongDir,
  detectBlockDir,
  plaintextOverrideDir,
  resolvedDir,
};
