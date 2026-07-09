# Codex Desktop RTL — supported (opt-in)

## Breakthrough

Codex Desktop is OpenAI-signed / hardened. There is no Claude-style “Developer → Main Process Debugger” menu.

Verified approach:

1. Relaunch `/Applications/Codex.app` with `--remote-debugging-port=<random>` on `127.0.0.1`
2. Inject `payload-v2` with `window.__CLAUDE_RTL_GENERIC__=true`
3. Generic mode:
   - scan from `<body>`
   - plaintext CSS on markdown paragraphs
   - careful Hebrew leaf `span` stamping for sidebar titles

**No copy, asar edit, or re-sign.** OpenAI signature stays.

## Apply

```bash
cd ~/clawd/projects/claude-official-rtl   # or desktop-rtl-runtime after rename
npm run build
npm run codex:apply
```

Or:

```bash
manager/core/adapter-control.sh reapply codex-research-macos
manager/core/adapter-control.sh verify codex-research-macos
```

## Live verification (author machine)

- `applied=ok`
- Hebrew sidebar titles: `dir=rtl`, `unicode-bidi: plaintext`
- Chat markdown `<p class="_markdownText…">` covered by prose CSS
- Adapter state: `rtl=active`

## User expectations

- Apply **relaunches** Codex (save work first)
- A **local** debug port stays open for that session
- Prefer this over any “patch Codex.app” guide
