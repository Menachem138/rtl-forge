# Claude for Open Source Application Draft

Official program page: https://claude.com/contact-sales/claude-for-oss

## Project

Claude Official RTL

## Repository URL

`https://github.com/Menachem138/claude-official-rtl`  
*(fill exact URL after first push)*

**Framing for reviewers:** original macOS **runtime injection** product for the official Anthropic-signed Claude Desktop app, with an original layout-only RTL payload (`payload-v2`). The novel contribution is preserving signed-app identity (subscription, Cowork, Claude Code) while making Hebrew/Arabic/Persian readable — without copy/patch/re-sign.

## Tell Us About The Project's Reach And Impact

Claude Official RTL solves a daily accessibility gap for RTL users of Claude Desktop (Hebrew, Arabic, Persian).

Claude can generate high-quality RTL text, but the Desktop app often renders mixed RTL/LTR content poorly: wrong-side list markers, jumped punctuation, hard-to-scan tables, tiring mixed technical answers.

Existing desktop patch approaches usually create a copied or re-signed Claude app. On macOS that is not equivalent to the official Anthropic-signed app: subscription state, history, Cowork, Claude Code, Keychain, and entitlement-bound behavior can break.

This project keeps `/Applications/Claude.app` intact and injects a local RTL payload at runtime. It:

- verifies Anthropic Team ID before injection,
- uses only local loopback,
- closes the inspector after injection,
- never copies, patches, unpacks, or re-signs Claude,
- keeps ProseMirror composers and Claude Code’s xterm terminal safe (no text-node rewrites; terminal stays LTR).

The project fills a specific ecosystem gap: RTL users need Claude Desktop to be readable **without losing official app identity**.

Optional experimental path for other Electron apps (e.g. Codex) exists and is documented as opt-in/research — Claude remains the supported flagship.

## How Will You Use The Subscription For Your Project?

I will use Claude Max to maintain the project across Claude Desktop updates:

- re-test quickly when Claude Desktop DOM / Electron behavior changes,
- improve Hebrew/Arabic/Persian + mixed-language edge cases,
- keep Cowork + Claude Code safe,
- expand docs for non-technical RTL users,
- triage macOS issues with regression tests,
- grow adoption (issues/stars) and keep the safety story honest.

Claude Code is especially useful here: Electron, macOS automation, shell, JS, DOM, and bidi debugging.

## Other Info

**Original work:** official macOS runtime path, watchdog, manager/adapters, signed-app preservation policy, and the layout-only payload (`payload-v2`).

Transparent limitations: depends on Claude Desktop’s Developer menu / inspector behavior; user-side accessibility workaround, not an Anthropic-supported integration.
