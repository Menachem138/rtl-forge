# Payload v2 contract (original)

Product payload for Claude Desktop Official RTL. **Layout-only.**

## Hard rules

1. Idempotent install (`data-claude-rtl` on `<html>`, style id `claude-rtl-style`).
2. No network, no telemetry, no chat storage.
3. **Never mutate text nodes.** No number wrapping, no math rewrites, no bidi control chars (U+200E/U+200F).
4. **Never touch** composers / contenteditable / textarea / input (except `dir=auto` on bare inputs if needed).
5. **Never touch** xterm / terminal surfaces (Claude Code).
6. Prose base direction primarily via CSS `unicode-bidi: plaintext`.
7. Detection fallback is `null`, never forced `'rtl'` on majority-English text.
8. Stamp processed elements with `data-ortl` for idempotency.
9. Works under `window.__CLAUDE_RTL_GENERIC__ === true` for non-Claude Electron apps (broader roots).

## Why layout-only can be better

Upstream-style engines often rewrite DOM (signed-number spans, math reordering). That is powerful and also the source of typing freezes and brittle editor desync.

This engine prioritizes:

- copy/paste byte identity,
- ProseMirror safety,
- terminal safety,
- standard Unicode/CSS bidi.

Trade-off: exotic math display edge cases may be weaker until a dedicated, optional, non-mutating math CSS pass is added.
