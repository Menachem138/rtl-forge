# Launch checklist — Claude Official RTL

## 0) Product truth (for the public story)

**Supported flagship:** official Claude Desktop (macOS) runtime RTL.  
**Experimental:** Codex.  
**Hermes:** later (not blocking launch).

Repo path:

```text
~/clawd/projects/claude-official-rtl
```

## 1) Pre-flight (local)

```bash
cd ~/clawd/projects/claude-official-rtl
npm test
npm run build
```

Optional visual: Claude still works with `npm run official:ensure` **from Terminal**, not from experiments that kill Hermes.

## 2) GitHub login (one-time)

`gh` is not logged in yet. In **Terminal.app**:

```bash
gh auth login
# GitHub.com → HTTPS → login with browser → select account menachemsamama
gh auth status
```

## 3) Create + push public repo

```bash
cd ~/clawd/projects/claude-official-rtl
gh repo create menachemsamama/claude-official-rtl \
  --public \
  --source=. \
  --remote=origin \
  --description "RTL for official macOS Claude Desktop without copy/patch/re-sign" \
  --push
```

If the repo already exists empty on GitHub:

```bash
git remote add origin https://github.com/menachemsamama/claude-official-rtl.git
git push -u origin main
```

## 4) Post-push polish on GitHub

- About: “Official Claude Desktop RTL (macOS) — no re-sign”
- Topics: `claude`, `rtl`, `hebrew`, `arabic`, `macos`, `accessibility`, `electron`
- Enable Issues
- Optional: Discussions later

## 5) Claude for Open Source

1. Open https://claude.com/contact-sales/claude-for-oss  
2. Use answers in `docs/CLAUDE_FOR_OPEN_SOURCE_APPLICATION_DRAFT.md`  
3. Paste the real repo URL after push  
4. Submit even if not a “classic” OSS maintainer — the form allows important gap-filling projects  

## 6) First 48h growth (maximize OSS odds)

- Share with 5–10 Hebrew/Arabic Claude Desktop users  
- Ask for 1–2 real issues (“list markers still wrong on X”)  
- Keep README honest (limitations section)  
- Do **not** over-claim Hermes  

## 7) Do not ship

- Legacy tree `~/clawd/projects/claude-desktop-official-rtl`  
- `storage/sources/claude-desktop-rtl`  
- Any Lior engine/dom tree  
- Hermes kill/relaunch scripts as “required install”  

## Done when

- [ ] Public GitHub URL live  
- [ ] `npm test` green on clean clone  
- [ ] README clone instructions work  
- [ ] OSS form submitted with repo URL  
