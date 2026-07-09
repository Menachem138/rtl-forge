# IP & protection (honest)

## What is protected

| Item | Protection |
|---|---|
| Copyright on **your original code** (`official-runtime/`, `payload-v2/`, `manager/`, docs) | © Menachem Samama — see LICENSE |
| Project name / branding in this repo | Treat as your product identity; do not claim third-party ownership |
| GitHub repository under `Menachem138` | You control who can push (no write access for outsiders by default) |

## What MIT does **not** prevent

This project is released under the **MIT License**. That means others **may**:

- copy, fork, modify, and redistribute the code,
- even commercially,

**as long as** they keep the copyright + MIT notice.

So: MIT maximizes adoption (good for Claude for Open Source), but it is **not** “copy-proof.”

If you later need stronger control, options (for **new** commits going forward) include:

- dual-license / proprietary for a commercial product,
- keeping a private “pro” tree,
- trademark on a product name (legal process; not automatic),
- Source-available licenses (not OSI MIT).

Changing license on already-published MIT commits does not fully recall the old permission for those snapshots.

## Accidental contribution to third-party repos

See `docs/NO_UPSTREAM_PUSH.md` for the local safety check regarding Lior’s repository.

## Practical hardening already done

1. Public product repo contains **only** original product paths (no third-party `engine/`/`dom/` tree).
2. Copyright notice is yours alone in `LICENSE` / `NOTICE`.
3. Legacy experiment folder must never push to third-party remotes.
