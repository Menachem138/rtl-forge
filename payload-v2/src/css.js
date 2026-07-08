'use strict';

/**
 * Core stylesheet for layout-only RTL.
 * Prefer unicode-bidi: plaintext so the first strong character drives each leaf.
 *
 * Claude path: semantic tags under html[data-claude-rtl].
 * Generic Electron apps (Codex/Hermes via CDP): same rules + markdown utility classes
 * and .ortl-leaf (JS-stamped text leaves such as sidebar spans).
 */

const APPLY_CSS = `
/* Claude Official RTL — original layout-only payload (v2) */
html[data-claude-rtl] .ortl-prose,
html[data-claude-rtl] .ortl-leaf,
html[data-claude-rtl] p,
html[data-claude-rtl] li,
html[data-claude-rtl] h1,
html[data-claude-rtl] h2,
html[data-claude-rtl] h3,
html[data-claude-rtl] h4,
html[data-claude-rtl] h5,
html[data-claude-rtl] h6,
html[data-claude-rtl] figcaption,
html[data-claude-rtl] label,
html[data-claude-rtl] dt,
html[data-claude-rtl] dd,
html[data-claude-rtl] td,
html[data-claude-rtl] th,
html[data-claude-rtl] [class*="markdownText"],
html[data-claude-rtl] [class*="paragraph"],
html[data-claude-rtl] [class*="listItem"] {
  unicode-bidi: plaintext !important;
  text-align: start !important;
}

/* Long mixed tokens in RTL bubbles */
html[data-claude-rtl] p,
html[data-claude-rtl] li,
html[data-claude-rtl] .ortl-leaf {
  overflow-wrap: anywhere;
}

/* Inline code / paths stay visually LTR islands inside RTL prose */
html[data-claude-rtl] :not(pre) > code,
html[data-claude-rtl] kbd,
html[data-claude-rtl] samp {
  unicode-bidi: isolate;
  direction: ltr;
}

/* Fenced code & terminals: force LTR host */
html[data-claude-rtl] pre,
html[data-claude-rtl] pre code,
html[data-claude-rtl] .xterm,
html[data-claude-rtl] .xterm-screen,
html[data-claude-rtl] .xterm-rows,
html[data-claude-rtl] .terminal {
  direction: ltr !important;
  unicode-bidi: embed;
  text-align: left;
}

/* dir=rtl decorations (lists / quotes / tables) when JS sets dir */
html[data-claude-rtl] [dir="rtl"] {
  text-align: start;
}

html[data-claude-rtl] ul[dir="rtl"],
html[data-claude-rtl] ol[dir="rtl"] {
  padding-inline-start: 1.5em;
  padding-inline-end: 0;
}

html[data-claude-rtl] blockquote[dir="rtl"] {
  border-inline-start-width: 3px;
  border-inline-end-width: 0;
  padding-inline-start: 1em;
  padding-inline-end: 0;
}

html[data-claude-rtl] table[dir="rtl"] {
  direction: rtl;
}

/* Composer / inputs: never break typing; auto is enough for empty field chrome */
html[data-claude-rtl] [contenteditable="true"],
html[data-claude-rtl] [contenteditable=""],
html[data-claude-rtl] textarea,
html[data-claude-rtl] input[type="text"],
html[data-claude-rtl] input:not([type]),
html[data-claude-rtl] [role="textbox"] {
  unicode-bidi: plaintext;
}
`;

// __EXPORTS__
module.exports = { APPLY_CSS };
