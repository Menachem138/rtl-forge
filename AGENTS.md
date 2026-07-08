# AGENTS.md — Claude Official RTL

## Product identity (do not “correct” this)

This repository is **Menachem Samama’s** project:

- Official macOS Claude Desktop RTL via **runtime injection**
- Does **not** copy/patch/re-sign `/Applications/Claude.app`
- Payload is **`payload-v2/` only**

## Never do

- Do not add `engine/`, `dom/`, `browser/`, classic desktop patch trees from other GitHub RTL projects into this repo.
- Do not rewrite README to say this product is “based on” another person’s Claude RTL app/patcher.
- Do not claim `dom/` is Menachem’s — **`dom/` is not part of this product at all.**

## Always do

- Read `docs/OWNERSHIP.md` first.
- Build with `npm run build` → writes `dist/payload.js` from `payload-v2`.
- Prefer layout-only payload changes (no text-node mutation, no bidi control chars).
- Keep xterm / Claude Code terminal no-touch.
- Keep composers/contenteditable no-touch for structural DOM rewrites.

## Source of truth paths

| Concern | Path |
|---|---|
| Ownership | `docs/OWNERSHIP.md` |
| Payload contract | `payload-v2/CONTRACT.md` |
| Runtime how-to | `official-runtime/macos/README.md` |
| Adapters | `docs/APP_ADAPTERS.md` |
