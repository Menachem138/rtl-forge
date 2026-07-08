# RTL Manager (menu-bar control panel)

A menu-bar app that shows every RTL adapter, its live status, and — for the supported
Claude runtime — one-click **Apply RTL**, a **Keep RTL after updates** watchdog toggle, a live
**Verify**, and quick access to logs and the Accessibility permission.

It is deliberately conservative: it markets only the **supported** adapter. Candidate (Hermes)
and research (Codex) adapters are visible for transparency but are never presented as working,
and this app never injects into them.

```
manager/
  adapters/        # static per-app metadata (one JSON each) — read by both the scanner and the GUI
    claude-official-macos.json    # supported
    hermes-source-macos.json      # candidate (source-level fix, not shipped here)
    codex-research-macos.json     # research only
  core/
    app-status.sh        # read-only inventory: bundle id, version, signer, Gatekeeper, running
    adapter-control.sh   # the command surface the GUI wraps (status/verify/watch/reapply/logs)
  gui/
    Sources/RTLManager/  # SwiftUI MenuBarExtra app
    build.sh             # assembles a self-contained "RTL Manager.app"
```

## Design

The GUI holds no policy of its own. Static facts come straight from `adapters/*.json`; live
facts come from `core/adapter-control.sh`, which emits plain `key=value` lines (trivial to emit
in bash, trivial to parse in Swift). The only mutating verbs — `reapply` and `watch on|off` —
only ever touch the Claude adapter, whose runtime path never modifies `/Applications/Claude.app`.

`adapter-control.sh verify claude-official-macos` reports an **honest** RTL state by comparing the
running Claude's process key with the one recorded at the last successful injection:

| state        | meaning                                                        |
|--------------|---------------------------------------------------------------|
| `active`     | Claude is running and it is the exact instance we injected into |
| `stale`      | Claude is running but relaunched/updated since — reapply needed  |
| `inactive`   | Claude is running, never injected this session                  |
| `notRunning` | Claude is not running                                           |

## Run it

Dev (from a checkout — the app walks up to find the repo):

```bash
cd manager/gui
swift run            # menu-bar icon appears; ⌘-drag not needed
```

Build the self-contained app:

```bash
manager/gui/build.sh          # -> manager/gui/dist/RTL Manager.app
open "manager/gui/dist/RTL Manager.app"
```

Grant **Accessibility** once (System Settings → Privacy & Security → Accessibility) so the
app can click Claude's `Developer → Enable Main Process Debugger` when it applies RTL.

## Read-only scanner

```bash
manager/core/app-status.sh
```

Reports bundle IDs, versions, signature Team IDs, Gatekeeper status, running state, and adapter
policy for Claude/Hermes/Codex. It never injects, patches, or modifies any app.
