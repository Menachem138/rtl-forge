# App Adapters and Multi-App RTL

This project ships two runtime adapters that inject RTL without touching the app on disk: the
Claude-specific main-process-debugger route, and a **generic Electron CDP adapter** that works for
any Electron app which will relaunch with a Chromium remote-debugging port.

The RTL engine can be reused elsewhere, but the injection is always **runtime-only** — no copy, no
asar edit, no re-sign. A global "inject into every open app" mode is still not safe as a default:
signed apps, terminals, editors, and login-gated surfaces have different failure modes, so every app
is an explicit, opt-in adapter.

## Support Matrix

| App | Status | Safe Route | Notes |
|---|---:|---|---|
| Claude Desktop for macOS | Supported | Claude's built-in main-process debugger | Proven on the official Anthropic-signed app. Transient inspector (closed after injection). Keeps subscription, history, Cowork, and Claude Code identity intact. |
| Hermes Desktop | Supported | Generic Electron CDP (relaunch with `--remote-debugging-port`) | Ad-hoc signed, fuses open. Verified: injection flips real content (59 blocks got `dir="rtl"` in one snapshot). Runtime-only; no source change. |
| Codex Desktop | Research / experimental opt-in | Generic Electron CDP (experimental) | OpenAI-signed + hardened, but Electron with node-inspect fuse ON. Verified: the direct `--remote-debugging-port` flag DOES open a CDP endpoint and the payload injects. Kept opt-in because it relaunches a signed app and the payload needs Codex DOM polish. |
| Other Electron apps | Experimental only | Per-app allowlisted CDP adapters | Same generic route, but opt-in, app-scoped, and easy to disable. |

Trade-off between the two routes: Claude's route opens a **transient** inspector and closes it after
injection. The generic CDP route keeps a **localhost debug port open for the app's session** (bound
to `127.0.0.1`, on a random high port). Prefer the bespoke route where an app exposes one.

## Claude Adapter

Claude works because the official app exposes a menu item:

```text
Developer -> Enable Main Process Debugger
```

The macOS runtime adapter uses that official path to open a temporary local Node inspector, injects the RTL payload into Claude webContents/frames, then closes the inspector.

Safety boundaries:

- verifies Anthropic Team ID `Q6L2SF6YDW`,
- does not modify `/Applications/Claude.app`,
- does not copy or re-sign Claude,
- uses only `127.0.0.1`,
- closes the inspector after injection,
- leaves Claude Code xterm terminal surfaces untouched.

## Generic Electron CDP Adapter

The "one mechanism for every Electron app" path. It relaunches the target app with
`--remote-debugging-port` (random high port, `127.0.0.1`, `--remote-allow-origins=*`), connects over
the Chrome DevTools Protocol, and injects the **same** `dist/payload.js` into every page/webview via
`Page.addScriptToEvaluateOnNewDocument` (persists across in-app navigations) plus `Runtime.evaluate`
(applies to the current document). It touches nothing on disk — no copy, asar edit, re-sign, or
source change — so the RTL comes purely from the control panel at runtime, for any user.

Scripts: `official-runtime/macos/apply-electron-rtl.sh` (relaunch + orchestrate) and
`official-runtime/macos/inject-electron-cdp.js` (the CDP client; needs Node 22+ for global `WebSocket`).

## Hermes Adapter (supported, generic CDP)

Hermes is the clean case, and it is verified working:

- Electron; the installed macOS app is **ad-hoc signed** (no hardened runtime, no Team ID).
- Electron fuses are open (`RunAsNode` on, `EnableNodeCliInspectArguments` on, asar integrity off).
- The stock installed `/Applications/Hermes.app` has **no** bidi CSS of its own (0 `unicode-bidi`
  strings in its asar) — so any RTL that appears is unambiguously from our runtime injection.
- Verified: `apply-electron-rtl.sh /Applications/Hermes.app` relaunches Hermes with the debug port
  and injects the payload; in one snapshot 59 elements gained `dir="rtl"` and 19 gained `dir="auto"`.

The earlier local source patch (markdown-table `dir="auto"` under `~/.hermes/.../apps/desktop`) is
**not** used or required: it only ever helps one machine's build. The shipped path is the runtime
CDP adapter, so it works for everyone through the control panel.

## Codex Adapter (research / experimental opt-in)

An earlier assessment concluded Codex "does not expose a debugger path." That was incomplete —
re-checked against the installed app:

- Bundle ID `com.openai.codex`, Team ID `2DC432GLL2`, version `26.623.141536`.
- Hardened runtime + notarized Developer ID signature — **but** it is Electron (Chromium 149), and
  its `EnableNodeCliInspectArguments` fuse is **ON**, asar integrity **OFF**.
- The env-var route (`CODEX_ELECTRON_CHROMIUM_SWITCHES`) is dev-only, which is what the earlier note
  caught. But the **direct** `--remote-debugging-port` command-line flag is a different mechanism —
  and it is **not** stripped: relaunching Codex with it opens a CDP endpoint (`Chrome/149…`), and the
  payload injects successfully.

So the same generic CDP adapter works on Codex. It is kept **research / experimental opt-in** — never
marketed as supported — because:

- it relaunches OpenAI's signed app with a debug port (intrusive for a work tool, port stays open),
- the Claude-tuned payload needs Codex DOM polish before RTL quality is good,
- runtime injection preserves the signature/notarization (no on-disk change), but the conservative
  default is to require an explicit, clearly-warned click in the control panel.

The manager exposes it as `apply: electron-cdp-experimental` behind a warning, not as a default.

## Generic Electron Mode

A generic mode should be opt-in and visibly experimental.

Minimum rules:

- never enable for all apps by default,
- require an allowlist entry per app bundle ID,
- show app name, bundle ID, path, signature Team ID, and current adapter status before injection,
- skip terminal/editor surfaces such as xterm, Monaco, CodeMirror, and native shell panes,
- provide a one-click disable and log view,
- avoid touching signed official apps unless the adapter preserves their official identity,
- never read or persist conversation text.

The generic mode can start as an inventory scanner:

```text
Open apps -> Electron/Chromium? -> signed? -> known adapter? -> status only
```

Injection should come later, app by app.

Current scanner:

```bash
manager/core/app-status.sh
```

It is read-only: bundle metadata, signature Team ID, Gatekeeper status, running state, and adapter policy only.

## Menu-Bar Control Panel

The existing SwiftUI menu-bar app in `gui/` was built for the older copied-app patch path. The
multi-app control panel is a separate, adapter-oriented manager under `manager/` — shipped.

Controls (built):

- app list from `manager/adapters/*.json`: Claude, Hermes, Codex (detected-Electron scan is present, read-only),
- per-app status pill: supported / candidate / research, plus live installed/version/signer/running,
- per-app RTL state for Claude — **active / stale / inactive / notRunning** (honest, from the process key),
- one-click **Apply / Reapply RTL** for the supported adapter,
- **Keep RTL after updates** watchdog toggle (installs/removes the LaunchAgent),
- live **Verify** via Refresh,
- **Logs** shortcut,
- **Accessibility** permission helper (`AXIsProcessTrusted` + a jump to the settings pane),
- experimental read-only **Scan installed apps** section,
- no global injection toggle.

Internal layout (as built):

```text
manager/
  adapters/
    claude-official-macos.json   # supported
    hermes-source-macos.json     # candidate
    codex-research-macos.json    # research
  core/
    app-status.sh                # read-only inventory scanner
    adapter-control.sh           # status / verify / watch-status / logs-path / reapply / watch
  gui/
    Package.swift
    build.sh                     # -> "RTL Manager.app" (runtime bundled into Resources)
    Sources/RTLManager/          # MenuBarExtra app (Models / Manager / ContentView / App)
  __tests__/
    adapters.test.js             # schema + safety guards, runs under `npm test`
```

The public promise stays conservative: the manager markets only the supported adapter. Candidate
and research adapters are visible for transparency, but the manager never injects into them.
