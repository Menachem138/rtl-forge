'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const detect = require('../src/detect.js');
const surfaces = require('../src/surfaces.js');
const { processRoot, installStyles, ROOT_ATTR, STYLE_ID } = require('../src/apply.js');
const { APPLY_CSS } = require('../src/css.js');

/** Minimal DOM mock sufficient for querySelectorAll / attributes / textContent */
function el(tag, attrs = {}, children = []) {
  const node = {
    nodeType: 1,
    tagName: tag.toUpperCase(),
    attrs: { ...attrs },
    children: [],
    childNodes: [],
    parentNode: null,
    textContent: '',
    getAttribute(k) {
      return this.attrs[k] ?? null;
    },
    setAttribute(k, v) {
      this.attrs[k] = String(v);
    },
    hasAttribute(k) {
      return Object.prototype.hasOwnProperty.call(this.attrs, k);
    },
    matches(sel) {
      // tiny subset used by tests
      if (sel.includes('contenteditable')) {
        const ce = this.attrs.contenteditable;
        return ce === '' || ce === 'true' || ce === true;
      }
      if (sel.includes('xterm')) {
        const cls = this.attrs.class || '';
        return cls.includes('xterm') || cls.includes('terminal');
      }
      if (sel.includes('textarea') && this.tagName === 'TEXTAREA') return true;
      if (sel.includes('input') && this.tagName === 'INPUT') return true;
      return false;
    },
    closest(sel) {
      let cur = this;
      while (cur) {
        if (cur.matches && cur.matches(sel)) return cur;
        // also check multi-part selectors roughly for contenteditable / xterm
        if (sel.includes('contenteditable') && cur.attrs && (cur.attrs.contenteditable === '' || cur.attrs.contenteditable === 'true')) {
          return cur;
        }
        if (sel.includes('xterm') && cur.attrs && String(cur.attrs.class || '').includes('xterm')) {
          return cur;
        }
        cur = cur.parentNode;
      }
      return null;
    },
    querySelectorAll(sel) {
      const out = [];
      const walk = (n) => {
        if (n.nodeType !== 1) return;
        const tags = sel.split(',').map((s) => s.trim().toLowerCase());
        for (const t of tags) {
          if (t === n.tagName.toLowerCase()) out.push(n);
          if (t.startsWith('.') && (n.attrs.class || '').includes(t.slice(1))) out.push(n);
          if (t.includes('contenteditable') && n.matches(t)) out.push(n);
        }
        // proseLeaf multi
        if (sel.includes('p') && n.tagName === 'P') {
          /* already handled by tag */
        }
        for (const c of n.children) walk(c);
      };
      walk(this);
      // de-dupe
      return [...new Set(out)];
    },
    appendChild(c) {
      c.parentNode = this;
      this.children.push(c);
      this.childNodes.push(c);
      return c;
    },
  };
  for (const c of children) {
    if (typeof c === 'string') {
      node.textContent += c;
      node.childNodes.push({ nodeType: 3, textContent: c, data: c });
    } else {
      node.appendChild(c);
      node.textContent += c.textContent || '';
    }
  }
  return node;
}

function recomputeText(node) {
  if (!node.children.length && node.childNodes.some((c) => c.nodeType === 3)) {
    node.textContent = node.childNodes.filter((c) => c.nodeType === 3).map((c) => c.textContent).join('');
    return;
  }
  let t = '';
  for (const c of node.children) {
    recomputeText(c);
    t += c.textContent || '';
  }
  if (t) node.textContent = t;
}

test('composer paragraph is not given forced dir stamps that rewrite text', () => {
  const p = el('p', {}, ['המחיר -5 שקל']);
  const composer = el('div', { contenteditable: 'true', class: 'ProseMirror' }, [p]);
  recomputeText(composer);
  processRoot(composer, detect, surfaces);
  // text nodes untouched
  assert.equal(p.textContent, 'המחיר -5 שקל');
  assert.equal(p.childNodes.filter((c) => c.nodeType === 1).length, 0);
});

test('rendered Hebrew paragraph can receive plaintext-override dir', () => {
  const p = el('p', {}, ['OK — זה משפט בעברית ארוך מאוד עם הרבה מילים']);
  const root = el('div', { class: 'standard-markdown' }, [p]);
  recomputeText(root);
  processRoot(root, detect, surfaces);
  assert.equal(p.getAttribute('dir'), 'rtl');
  assert.equal(p.textContent.includes('עברית'), true);
});

test('English paragraph does not get dir=rtl', () => {
  const p = el('p', {}, ['Hello world, this is a long English paragraph about APIs.']);
  const root = el('div', { class: 'standard-markdown' }, [p]);
  recomputeText(root);
  processRoot(root, detect, surfaces);
  assert.notEqual(p.getAttribute('dir'), 'rtl');
});

test('xterm surface skipped', () => {
  const row = el('div', { class: 'xterm-rows' }, [el('p', {}, ['שלום'])]);
  const term = el('div', { class: 'xterm' }, [row]);
  recomputeText(term);
  processRoot(term, detect, surfaces);
  assert.equal(row.children[0].getAttribute('dir'), null);
});

test('RTL table gets dir=rtl', () => {
  const td = el('td', {}, ['עמודה בעברית']);
  const tr = el('tr', {}, [td]);
  const table = el('table', {}, [tr]);
  const root = el('div', { class: 'markdown' }, [table]);
  recomputeText(root);
  processRoot(root, detect, surfaces);
  assert.equal(table.getAttribute('dir'), 'rtl');
});

test('installStyles sets style marker', () => {
  const kids = [];
  const doc = {
    adoptedStyleSheets: undefined,
    getElementById(id) {
      return kids.find((k) => k.id === id) || null;
    },
    createElement(tag) {
      const n = { tagName: tag.toUpperCase(), id: '', textContent: '', attrs: {}, setAttribute() {}, getAttribute() { return null; } };
      return n;
    },
    documentElement: { setAttribute() {} },
    head: {
      appendChild(n) {
        kids.push(n);
      },
    },
  };
  assert.equal(installStyles(doc, APPLY_CSS), true);
  assert.ok(kids.some((k) => k.id === STYLE_ID));
});

test('ROOT_ATTR constant is data-claude-rtl (injector diagnostics)', () => {
  assert.equal(ROOT_ATTR, 'data-claude-rtl');
  assert.equal(STYLE_ID, 'claude-rtl-style');
});
