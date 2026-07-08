# Claude for Open Source Application Draft

Official program page: https://claude.com/contact-sales/claude-for-oss

## Project

Claude Desktop Official RTL

## Repository URL

Fill in after publishing, e.g. `https://github.com/<your-username>/claude-desktop-official-rtl`.

**Framing for reviewers:** this is an original official-app **runtime injection** product for macOS Claude Desktop, with an original layout-only RTL payload (`payload-v2`). The novel contribution is preserving Anthropic’s signed app identity while applying RTL across chat, Cowork, and Claude Code — without copy/patch/re-sign.

## Tell Us About The Project's Reach And Impact

Claude Desktop Official RTL solves a daily accessibility and usability gap for right-to-left language users of Claude Desktop, especially Hebrew, Arabic, and Persian speakers.

Claude can generate high-quality RTL text, but the official Desktop app can render mixed RTL/LTR content incorrectly: list markers appear on the wrong side, punctuation jumps across the line, tables become hard to scan, and Hebrew/Arabic technical answers are tiring to read.

Existing desktop patch approaches usually create a copied or re-signed Claude app. On macOS that is not equivalent to the official Anthropic-signed app: subscription state, chat history, Cowork, Claude Code, Keychain access, and entitlement-bound behavior can break.

This project keeps the official `/Applications/Claude.app` intact and injects a tested RTL rendering engine at runtime. It verifies Anthropic's Team ID before injection, uses only local loopback access, closes the inspector after injection, and does not copy, patch, unpack, or re-sign Claude.

The project fills a specific ecosystem gap: RTL users need Claude Desktop to be readable without losing the official app identity and account-gated product surfaces. It also contributes a reusable test-backed bidi/DOM engine and regression coverage for sensitive surfaces like ProseMirror composers and Claude Code's xterm terminal.

A menu-bar control panel (`manager/`) makes the project usable by non-technical RTL users: it shows each app adapter's live status, reports an honest per-app RTL state (active / needs-reapply / not-applied / app-not-running), and offers one-click Apply, an auto-reapply-after-update toggle, a live verify, and an Accessibility helper. It is deliberately conservative — it markets only the proven Claude adapter, keeps Hermes and Codex visible but never injects into them, and ships no global "apply to every app" switch — so the safety story stays honest as the project grows.

## How Will You Use The Subscription For Your Project?

I will use Claude Max to maintain and improve the project across Claude Desktop updates:

- test new Claude Desktop versions quickly when DOM or Electron behavior changes,
- improve RTL handling for Hebrew, Arabic, Persian, mixed-language tables, lists, math, and code-adjacent text,
- keep Claude Code and Cowork surfaces working without breaking the official app identity,
- write and maintain documentation for non-technical RTL users,
- triage issues from macOS users and produce reliable fixes with regression tests,
- prepare pull requests upstream where the core RTL engine can benefit the broader project.

Claude Code is especially useful for this project because the work requires careful Electron, macOS, shell, JavaScript, DOM, and bidi-regression debugging.

## Other Info

**Original work:** official macOS runtime path, watchdog, manager/control panel, multi-app adapter research, signed-app preservation policy, and the layout-only in-page payload (`payload-v2`).

The project is intentionally transparent about limitations: it depends on Claude Desktop's Developer menu and Electron inspector behavior, and it is a user-side accessibility workaround rather than an Anthropic-supported integration.
