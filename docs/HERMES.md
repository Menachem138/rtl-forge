# Hermes Desktop RTL

## Apply

```bash
cd ~/clawd/projects/claude-official-rtl
npm run build
npm run hermes:apply
```

Requires a clean quit of **every** Hermes process first (Applications, backup apps, release builds under `~/.hermes/...`). Electron single-instance can otherwise swallow `--remote-debugging-port` and the debug endpoint never stays open.

## How it works

Same generic path as Codex:

1. Relaunch Hermes with `--remote-debugging-port`
2. Inject `payload-v2` with `window.__CLAUDE_RTL_GENERIC__=true`
3. Layout-only RTL (CSS plaintext + selective dir / leaf stamps)

## Verify

```bash
manager/core/adapter-control.sh verify hermes-electron-macos
manager/core/adapter-control.sh status hermes-electron-macos
```

## Live check (this machine)

After a full quit + apply:

- `applied=ok` / `inject-electron-cdp: 1/1`
- `data-claude-rtl=v2`, `payload=claude-official-rtl-payload-v2`, style present
- `rtl=active` via adapter-control

Open a Hebrew chat in Hermes to visually confirm paragraphs flip RTL.
