# Codex Desktop RTL (experimental)

## How it works

1. Relaunch `/Applications/Codex.app` with `--remote-debugging-port=<random>` on `127.0.0.1`
2. Inject `dist/payload.js` (payload-v2) with `window.__CLAUDE_RTL_GENERIC__=true`
3. Generic mode:
   - scans from `<body>`
   - CSS `unicode-bidi: plaintext` on `p` / markdown utility classes
   - careful Hebrew **leaf** `span`/`div` stamping (`.ortl-leaf`) — not a blanket span flip

No copy, asar edit, or re-sign of Codex.

## Apply

```bash
cd ~/clawd/projects/claude-official-rtl
npm run build
npm run codex:apply
```

Or:

```bash
manager/core/adapter-control.sh reapply codex-research-macos
manager/core/adapter-control.sh verify codex-research-macos
```

## Status

- Adapter id: `codex-research-macos`
- Status: **research / experimental** (opt-in)
- Verified live: Hebrew sidebar titles get `dir=rtl` + plaintext; chat markdown `<p>` covered by global prose CSS

## Notes

- Debug port stays open for the Codex session (unlike Claude’s transient debugger).
- OpenAI signature/Team ID remain intact.
