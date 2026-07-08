# Ownership — read this before assuming anything

**Author / owner:** Menachem Samama  
**Repo product:** Claude Official RTL  
**License:** MIT (LICENSE)

## What Menachem built (this product)

| Path | What |
|---|---|
| `official-runtime/` | Inject RTL into **official** Anthropic-signed `/Applications/Claude.app` without copy, asar patch, or re-sign. Watchdog, ensure, launch, CDP injectors. |
| `manager/` | Menu-bar control panel, adapter JSON inventory, status/verify scripts. |
| `payload-v2/` | **Original** layout-only in-page RTL engine used by this product. |
| `docs/*` in this repo | Product docs for *this* architecture. |

### Product idea in one line

Keep Claude Desktop as the real Anthropic-signed app (subscription, history, Cowork, Claude Code identity) and apply RTL at **runtime**.

That is **not** the classic “make Claude-RTL.app copy and re-sign” approach.

## What is NOT in this repository

This clean repo intentionally excludes:

- `engine/` third-party pure bidi engines from other projects  
- `dom/` third-party DOM apply layers from other projects  
- `browser/` userscripts from other projects  
- `desktop/`, classic `gui/`, `helper/` copy-patch pipelines from other projects  

If you see those paths on disk elsewhere under `clawd/projects/claude-desktop-official-rtl` or `clawd/storage/sources/`, they are **legacy experiment trees**, not this product.

## How AI models got this wrong

1. Packaging temporarily lived next to / inside a checkout that also contained someone else’s MIT RTL tree.  
2. Models read `upstream` remotes, LICENSE copyrights, and `dom/`/`engine/` and concluded “the whole project is based on X.”  
3. That erased the actual invention: **official-app runtime injection + signed-app preservation.**

**Rule for agents:**  
- Ownership of *this* repo = paths listed above.  
- Do **not** attribute `official-runtime/`, `manager/`, or `payload-v2/` to third parties.  
- Do **not** reintroduce third-party `dom/` or `engine/` into this tree without an explicit human decision.

## payload-v2 note

`payload-v2` was implemented as original product code for this repository (layout-only: CSS + selective `dir`, no text-node rewrites). It is part of Menachem’s product, not a fork of another project’s `dom/` or `engine/`.
