# Claude Official RTL

**Author:** Menachem Samama  
**License:** MIT

Right-to-left Hebrew, Arabic, and Persian for the **official macOS Claude Desktop app** — without copying, patching, unpacking, or re-signing Claude.

This keeps Anthropic’s signed app identity, so subscription state, chat history, Cowork, and Claude Code surfaces keep working.

> Hebrew: [docs/README.he-official-runtime.md](docs/README.he-official-runtime.md)  
> Ownership (for humans + AI agents): [docs/OWNERSHIP.md](docs/OWNERSHIP.md)

## What this project is

| Layer | Path | Notes |
|---|---|---|
| Official runtime | `official-runtime/` | Inject into `/Applications/Claude.app` via Claude’s own Developer debugger |
| Control panel | `manager/` | Menu-bar status / apply / verify / watchdog helpers |
| In-page RTL engine | `payload-v2/` | **Original layout-only** engine (CSS + selective `dir`) |

## What this project is not

- Not a rebrand of someone else’s `engine/` + `dom/` tree  
- Not the classic `Claude-RTL.app` copy + ad-hoc re-sign approach  
- **`dom/` is not part of this repository** and is not Menachem’s product code  

## Quick start

```bash
git clone https://github.com/YOUR_USERNAME/claude-official-rtl.git
cd claude-official-rtl
npm test
npm run build
official-runtime/macos/launch-claude-official-rtl.sh
official-runtime/macos/install-watchdog.sh
```

Grant Accessibility once if macOS blocks the Developer menu click:

```text
System Settings → Privacy & Security → Accessibility
```

## How it works

1. Verify Claude is signed by Anthropic Team ID `Q6L2SF6YDW`
2. Enable Claude’s Developer menu
3. Open `Developer → Enable Main Process Debugger`
4. Connect to local Node inspector `127.0.0.1:9229`
5. Inject `dist/payload.js` (from `payload-v2`) into Claude webContents/frames
6. Close the inspector

Details: [official-runtime/macos/README.md](official-runtime/macos/README.md)

## Why Chrome may open briefly

Chrome can notice Electron’s temporary local inspector and open `chrome://inspect`.  
That is not an extension and not telemetry. The injector closes the inspector after use.

## payload-v2 design

- Primary prose direction: CSS `unicode-bidi: plaintext`
- Selective `dir` for tables / lists / blockquotes / rare plaintext overrides
- **Never mutates text nodes**
- **Never injects** U+200E / U+200F
- Hard no-touch: ProseMirror composers, xterm / Claude Code terminal

Contract: [payload-v2/CONTRACT.md](payload-v2/CONTRACT.md)

## Other apps

Conservative adapter inventory (Claude supported; Hermes/Codex documented carefully):

- [docs/APP_ADAPTERS.md](docs/APP_ADAPTERS.md)
- `manager/core/app-status.sh`

## Development

```bash
npm test
npm run build
npm run official:ensure
```

## License

MIT © Menachem Samama — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
