# Official Claude Desktop RTL Runtime for macOS

This mode injects the RTL payload into the official macOS Claude Desktop app at runtime.

It does **not** copy, patch, unpack, or re-sign `/Applications/Claude.app`.

**Ownership:** scripts in this directory and the injected `dist/payload.js` (from `payload-v2/`) are **original product work**. See [NOTICE](../../NOTICE) and [payload-v2/CONTRACT.md](../../payload-v2/CONTRACT.md).

That matters because Claude Desktop features such as subscription state, chat history, Cowork, and Claude Code can depend on the official app identity, Team ID, entitlements, and Keychain access. A copied or ad-hoc-signed app can look like Claude but no longer behave like the Anthropic-signed app.

## What It Does

1. Verifies `/Applications/Claude.app` is signed by Anthropic Team ID `Q6L2SF6YDW`.
2. Enables Claude's built-in Developer menu by writing `developer_settings.json`.
3. Starts or uses the official Claude process.
4. Opens Claude's official `Developer -> Enable Main Process Debugger` menu item.
5. Connects locally to the Node inspector on `127.0.0.1:9229`.
6. Injects `dist/payload.js` into Claude `claude.ai` / `claude.com` webContents and frames.
7. Installs in-process hooks so later navigations and frames get the same RTL payload.
8. Closes the Node inspector after injection.

The RTL payload is built from this repo's original `payload-v2/` tree (`npm run build` → `dist/payload.js`).

## Install

From the repository root:

```bash
npm install
npm run build
official-runtime/macos/launch-rtl-forge.sh
official-runtime/macos/install-watchdog.sh
```

If macOS blocks the menu click, grant Accessibility access once:

```text
System Settings -> Privacy & Security -> Accessibility
```

Enable the thing that is running the script:

- `Terminal`, if you launch manually from Terminal.
- `bash`, if the LaunchAgent watchdog is running it.
- Your IDE/agent app, if you launch from an automation tool.

## Watchdog Behavior

The LaunchAgent runs every minute, but normally exits immediately.

It reinjects only when one of these is true:

- Claude was restarted.
- Claude was updated.
- The current Claude process has not been confirmed recently.
- You run `ensure-rtl-forge.sh --force`.

The default periodic confirmation interval is 24 hours:

```bash
CLAUDE_RTL_PERIODIC_SECONDS=86400
```

You can override it in the environment if you want a shorter or longer interval.

## Why Chrome May Open

When Claude's main-process debugger is enabled, Electron exposes a local Node inspector endpoint on:

```text
127.0.0.1:9229
```

Chrome may notice that inspector and briefly open `chrome://inspect`.

This is not a Chrome extension, not telemetry, and not a remote server. It is a temporary local debugging endpoint used to reach Claude's Electron main process. After the payload is injected, the injector calls `node:inspector.close()`, and the watchdog also tries to close any Chrome `chrome://inspect` tabs that appeared.

You can verify the inspector is closed:

```bash
lsof -nP -iTCP:9229 -sTCP:LISTEN
```

No output means nothing is listening on the inspector port.

## Claude Code

Claude Code inside Desktop uses xterm.js for its terminal surface.

The RTL payload deliberately leaves xterm alone:

- no `dir="auto"` on the hidden xterm textarea,
- no span injection inside the terminal screen,
- no list/table/prose direction stamps inside the terminal DOM.

The surrounding Claude messages can still render RTL. The terminal itself stays LTR because shell prompts, commands, paths, and code-like output break if forced RTL.

## Uninstall

```bash
official-runtime/macos/uninstall-watchdog.sh
```

This removes the LaunchAgent only. It does not modify Claude.

To remove the local state/logs:

```bash
rm -rf "$HOME/Library/Application Support/Claude/official-rtl"
rm -f "$HOME/Library/Logs/Claude/official-rtl-"*.log
```

## Limitations

- macOS only.
- Depends on Claude Desktop exposing the official Developer menu.
- Depends on Electron's Node inspector behavior.
- Can break if Anthropic removes or renames `Enable Main Process Debugger`.
- Requires local Accessibility permission for the runner that clicks the Developer menu.
- Offered as a user-side accessibility/runtime workaround, not as an Anthropic-supported integration.

## Security Notes

- Verifies Anthropic Team ID before injection.
- Does not modify `/Applications/Claude.app`.
- Does not copy or re-sign Claude.
- Does not read or send conversation content.
- Uses only local loopback `127.0.0.1`.
- Closes the inspector after injection by default.
