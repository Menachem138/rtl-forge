# Hermes Desktop RTL

## Reality check

Hermes Desktop is **harder** than Claude/Codex for external RTL injection:

1. Multiple installs can run at once (`/Applications/Hermes.app`, old `*.backup*`, `~/.hermes/.../release`).
2. Electron single-instance handoff drops `--remote-debugging-port`.
3. Hermes UI CSS hard-sets `unicode-bidi: isolate` + `direction: ltr` on many text nodes.
4. Force-quitting Hermes mid-session can break the **background agent** → "Repair install" / backend timeout.

**Recommendation:** treat Hermes RTL as best fixed **in Hermes source** (the app already has bidi/RTL pieces). CDP inject is experimental polish only.

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
cd ~/clawd/projects/claude-official-rtl
npm run build
# Fully quit ALL Hermes windows first (Dock → Quit), then:
npm run hermes:apply
```

If the agent backend fails after experiments, open **Terminal.app** (outside Hermes) and repair/restart the Hermes agent service, or use Hermes UI **Repair install**.

## Verify inject stuck

After apply, open a chat with **Hebrew** text. Pure English stays LTR (correct).
