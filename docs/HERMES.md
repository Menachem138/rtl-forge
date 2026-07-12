# Hermes Desktop RTL

## Status: supported (one command)

Hermes RTL works reliably at runtime — no source patch, no copy, no re-sign. Verified live:
Hebrew flips RTL across the app including the sidebar conversation titles (hundreds of
`dir="rtl"` / `.ortl-leaf` elements in one apply).

```bash
npm run hermes:apply     # or: Apply on the Hermes card in the RTL Manager menu-bar app
```

Hermes used to be the hard one, and the apply script now handles what made it hard, automatically:

1. **Multiple installs** (`/Applications/Hermes.app`, old `*.backup*`, `~/.hermes/.../release`) —
   the script quits *every* Hermes instance by exact process name and waits for the single-instance
   lock to clear, retrying up to 3× so a stale install can't steal the debug-port handoff.
2. **Single-instance handoff** dropping `--remote-debugging-port` — covered by the quit-all + retry.
3. **Hermes hard-sets `unicode-bidi: isolate` + `direction: ltr`** — the generic payload beats it on
   chat text hosts with a targeted `!important`, without flipping app chrome (English stays LTR).

**One honest caveat remains:** applying relaunches the Hermes window, which briefly restarts the UI.
If the background agent shows "Repair install" / a backend timeout afterwards, restart the Hermes
agent from Terminal or use the app's **Repair install** — the RTL inject itself changes nothing on disk.

## Cleanup if you see two Hermes icons

Quarantine old backups out of `/Applications`:

```bash
mkdir -p ~/Applications/_quarantine
# only if present:
# mv /Applications/Hermes.app.backup-* ~/Applications/_quarantine/
```

Use **one** primary app: `/Applications/Hermes.app`.

## Apply (experimental)

```bash
cd ~/clawd/projects/rtl-forge
npm run build
# Fully quit ALL Hermes windows first (Dock → Quit), then:
npm run hermes:apply
```

If the agent backend fails after experiments, open **Terminal.app** (outside Hermes) and repair/restart the Hermes agent service, or use Hermes UI **Repair install**.

## Verify inject stuck

After apply, open a chat with **Hebrew** text. Pure English stays LTR (correct).
