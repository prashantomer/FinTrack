# FinTrack — Technical Documentation

> Canonical engineering reference. Audience: an engineer joining the codebase
> or returning to a specific subsystem after months away. Assumes working
> familiarity with Rails 8.1 and React 19. No marketing copy, no roadmap
> material — those live one level up in `docs/`.

## How to read this

If you've just cloned the repo, read the documents in order. Each one builds
on terms introduced in the previous. If you're chasing a specific change,
jump straight to the section that names it.

| # | Document | What it covers |
|---|----------|----------------|
| 1 | [`architecture.md`](./architecture.md) | Stack, repo layout, request lifecycle, where the boundaries are |
| 2 | [`domain-model.md`](./domain-model.md) | Core entities (`User`, `Account`, `Transaction`, `Investment`, `Holding`, `ImportBatch`, ...) and how they relate |
| 3 | [`backend.md`](./backend.md) | Controller / service / job patterns. JWT, audited, encryption, pagination, filter machinery |
| 4 | [`imports.md`](./imports.md) | The import pipeline: format adapters, workbook reading, dedupe ladder, reconciliation flow |
| 5 | [`audit-and-balance.md`](./audit-and-balance.md) | Every code path that mutates a balance, the audit-row contract, and how to keep them in sync |
| 6 | [`operations.md`](./operations.md) | Rake tasks (`audits:backfill`, `accounts:recompute_balances`, `cleanup:run`, `users:wipe`, `release`), daily cron, Sidekiq queues |
| 7 | [`frontend.md`](./frontend.md) | React / TanStack Query / base-ui patterns specific to this codebase |

## Conventions used across these docs

- **File paths** are relative to repo root (`backend/app/...`, `frontend/src/...`). Jump to them; they're authoritative — when a doc and the code disagree, fix the doc.
- **Code snippets** are illustrative only. They show *shape* and *invariants*, not the literal bytes on disk. If a snippet contradicts the file, the file wins.
- **"Today" / "currently"** refers to the state of `main` at the time this folder was last updated. Each doc has a "Last reviewed" footer; bump it when you edit.
- **Rake tasks** are written as `bin/rails namespace:task` for clarity, even though Rails accepts them without the prefix.

## What lives outside this folder

- `docs/dev-commands.md` — scenario-grouped command cheatsheet. Less structured than these docs.
- `docs/backend-architecture.md` / `frontend-architecture.md` — older design docs, useful for historical context but partially superseded by this folder.
- `docs/instrument-profile-page.md`, `docs/scaling-daily-snapshot-pipeline.md` — feature-specific design docs, kept as-is.
- `CLAUDE.md` (repo root) — terse guidance for AI agents working in this repo. Not for human reading.

If anything in this folder feels wrong, prefer fixing it over working around it. Stale docs are worse than no docs.

---

Last reviewed: 2026-05-11
