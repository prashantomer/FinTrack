# Claude PR Review — Custom GitHub App Setup

This repo runs **two** automated reviewers on every PR (see `.github/workflows/pr-review.yml`):

- **Copilot** — uses the built-in `copilot-pull-request-review[bot]`. Zero setup beyond enabling Copilot at the GitHub org level.
- **Claude** — uses `anthropics/claude-code-action@v1`. Authenticates to GitHub via a **custom GitHub App we own** (not the third-party `claude` App), and to Anthropic via the `ANTHROPIC_API_KEY` repo secret.

The custom-App route keeps the auth surface fully under our control — no third-party app installation, no shared identity. This doc walks through the one-time setup.

---

## Required repo secrets

| Name | What it is | How to set |
|---|---|---|
| `ANTHROPIC_API_KEY` | Anthropic API key (sk-ant-…). Bills your Anthropic account. | `gh secret set ANTHROPIC_API_KEY` |
| `FINTRACK_REVIEW_APP_ID` | Numeric ID of the GitHub App you create below. | `gh secret set FINTRACK_REVIEW_APP_ID` |
| `FINTRACK_REVIEW_APP_PRIVATE_KEY` | Contents of the App's `.pem` private key (full file, including the `BEGIN RSA PRIVATE KEY` line). | `gh secret set FINTRACK_REVIEW_APP_PRIVATE_KEY < /path/to/key.pem` |

Without all three, the `claude` job in the workflow will fail at the App-token step. The `copilot` job is unaffected.

---

## Creating the custom App (one-time)

1. **Open** https://github.com/settings/apps/new (personal) or your org's **Settings → Developer settings → GitHub Apps → New GitHub App**.
2. **Fill in:**
   - **Name**: `FinTrack PR Reviewer` (or anything; this is what shows up as the comment author).
   - **Homepage URL**: your repo URL (required field, value doesn't matter).
   - **Webhook**: uncheck "Active" — this App only needs API access, not webhook delivery.
3. **Repository permissions** — set exactly these:
   - **Contents**: Read
   - **Pull requests**: Read & Write
   - **Issues**: Read & Write *(needed for inline comments — they're issue comments under the hood)*
   - **Metadata**: Read (auto-set)
4. **Where can this App be installed?** — pick "Only on this account" (or "Any account" if you'll reuse it across orgs).
5. **Create GitHub App.**

After creation:

6. **Copy the App ID** from the top of the App settings page → save it as `FINTRACK_REVIEW_APP_ID`.
7. Scroll to **Private keys** → **Generate a private key** → download the `.pem` → save its full contents as `FINTRACK_REVIEW_APP_PRIVATE_KEY`.
8. **Install App** (button on the left sidebar) → choose the `FinTrack` repo → confirm.

---

## Verify

After secrets are in place and the App is installed, trigger a workflow run:

```bash
# Re-run the failed run on the open PR
gh run list --branch feature/ai-assistant --workflow "PR Review" --limit 1
gh run rerun <run-id>
```

Watch the run in `gh run watch <id>` or the Actions tab. Expected output:

- `Generate GitHub App token` step → succeeds (mints an installation token).
- `Run anthropics/claude-code-action@v1` step → no 401, no "Claude Code is not installed" error.
- A "Claude is reviewing…" tracking comment appears on the PR within ~30s.
- Final review (top-level summary + inline comments) lands a few minutes later.

The comment author will be your custom App's name (e.g., `fintrack-pr-reviewer[bot]`), not `claude[bot]`.

---

## Rotating the key

Generate a new `.pem` from the App settings, delete the old one, and update the secret:

```bash
gh secret set FINTRACK_REVIEW_APP_PRIVATE_KEY < new-key.pem
```

No workflow change needed.

---

## Why a custom App over the official Claude App

| | Official `claude` App | Custom App (this repo) |
|---|---|---|
| Setup time | 30 seconds | ~5 minutes |
| Third-party dependency | Yes (Anthropic-controlled) | No |
| Posts comments as | `claude[bot]` | Your App's name |
| Permissions controllable | Fixed by Anthropic | Granular, owned by you |
| Permission scope creep risk | Whatever Anthropic ships | Locked to what you grant |

For personal/learning projects, the official App is fine. For anything where you want auditable, repo-scoped review automation, custom App wins.
