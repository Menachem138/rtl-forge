# Security Policy

## What this project does

- Injects a **local** JavaScript payload into Claude Desktop / optional Electron targets on your machine.
- Uses **loopback only** (`127.0.0.1`) for temporary debug endpoints.
- Does **not** send chat contents to the network as part of the RTL feature.

## What this project does not do

- Does not modify Anthropic’s `/Applications/Claude.app` bundle.
- Does not re-sign Claude.
- Does not require your Claude password/token to be pasted into this repo.

## Reporting issues

Open a GitHub issue for non-sensitive bugs.  
For sensitive findings, contact the author via GitHub profile without posting exploit details publicly.

## User responsibilities

- Grant Accessibility only to runners you trust (Terminal / official launch helpers).
- Prefer the Claude official-runtime path over experimental multi-app injectors.
- Close debug ports if an experimental session is left open (`lsof -nP -iTCP -sTCP:LISTEN`).
