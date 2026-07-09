# Claude Official RTL

**Author:** Menachem Samama  
**License:** MIT  
**Platform:** macOS

Right-to-left Hebrew, Arabic, and Persian for the **official macOS Claude Desktop app** — without copying, patching, unpacking, or re-signing Claude.

That preserves Anthropic’s signed app identity: subscription, chat history, Cowork, and Claude Code keep working.

> עברית: [docs/README.he-official-runtime.md](docs/README.he-official-runtime.md)

## Why this exists

Claude writes excellent Hebrew/Arabic, but Claude Desktop often renders RTL poorly (punctuation, lists, tables, mixed text).

Common workarounds build a **copied** `Claude-RTL.app` and re-sign it. On macOS that can break Keychain / Team-ID-bound features (subscription, Cowork, Claude Code).

**This project takes the runtime route:** keep `/Applications/Claude.app` intact and inject a local RTL payload.

## Status

| Surface | Status |
|---|---|
| Claude Desktop (macOS, official signed app) | **Supported** |
| Claude chat + history + subscription | **Supported** |
| Cowork | **Supported** |
| Claude Code terminal | **Supported with care** (terminal stays LTR) |
| Codex Desktop | **Experimental** (opt-in CDP relaunch) |
| Hermes Desktop | **Later / research** (prefer source-level fix) |

## Quick start (Claude)

```bash
git clone https://github.com/menachemsamama/claude-official-rtl.git
cd claude-official-rtl
npm test
npm run build
npm run official:launch
npm run official:watch   # optional: re-apply after Claude relaunch/update
```

Grant **Accessibility** once if macOS blocks the Developer menu click:

```text
System Settings → Privacy & Security → Accessibility
```

Enable Terminal / your runner / `bash` (for the watchdog).

## How it works

1. Verify Claude is signed by Anthropic Team ID `Q6L2SF6YDW`
2. Enable Claude’s Developer menu
3. Open `Developer → Enable Main Process Debugger`
4. Connect to local Node inspector `127.0.0.1:9229`
5. Inject `dist/payload.js` (built from `payload-v2/`) into Claude frames
6. Close the inspector

Details: [official-runtime/macos/README.md](official-runtime/macos/README.md)

## Why Chrome may open briefly

Chrome can notice Electron’s temporary local inspector and open `chrome://inspect`.  
Not an extension, not telemetry. Loopback only; closed after inject.

## Security model

- Verifies Anthropic Team ID before inject  
- Does **not** modify `/Applications/Claude.app`  
- Does **not** copy or re-sign Claude  
- No network exfiltration of chat content  
- Local loopback only  
- Inspector closed after injection by default  

## payload-v2 (original engine)

- CSS `unicode-bidi: plaintext` as primary prose direction  
- Selective `dir` for tables / lists / blockquotes / overrides  
- **Never mutates text nodes**  
- **Never injects** U+200E / U+200F  
- Hard no-touch: composers + xterm / Claude Code terminal  

Contract: [payload-v2/CONTRACT.md](payload-v2/CONTRACT.md)

## Project layout

```text
official-runtime/   # Claude signed-app runtime inject + watchdog
payload-v2/         # original layout-only RTL payload
manager/            # menu-bar helpers + adapter inventory
docs/               # architecture notes, Hebrew guide, OSS draft
```

## Other apps

- Codex: [docs/CODEX.md](docs/CODEX.md) — `npm run codex:apply` (experimental)  
- Hermes: [docs/HERMES.md](docs/HERMES.md) — deferred; multi-install + CSS conflicts  
- Adapters overview: [docs/APP_ADAPTERS.md](docs/APP_ADAPTERS.md)

## Development

```bash
npm test
npm run build
npm run official:ensure
```

## Claude for Open Source

Draft application answers: [docs/CLAUDE_FOR_OPEN_SOURCE_APPLICATION_DRAFT.md](docs/CLAUDE_FOR_OPEN_SOURCE_APPLICATION_DRAFT.md)

## License

MIT © Menachem Samama — [LICENSE](LICENSE) · [NOTICE](NOTICE)
