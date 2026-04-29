---
name: reconcile-tracking
description: Reconcile FOSSE project tracking across Linear (source of truth), GitHub (Automattic/fosse), and the fossep2 P2. Reports drift between surfaces — open PRs missing Linear refs, settled P2 posts without back-link comments, SDD plan tasks marked Done with no merged PR, and similar. --fix walks each item interactively. Read-only by default.
---

# Reconcile Tracking

## Purpose

FOSSE work lives across three surfaces with distinct roles: Linear is the source of truth that stakeholders read (Dotcom team, Radical Month: FOSSE project, `DOTCOM-\d+` IDs), GitHub (`Automattic/fosse`) is where the real work ships, and fossep2 (`fossep2.wordpress.com`) carries the discussion and decision narrative. GitHub issues are treated as a public-facing surface, not a complete project tracker — the skill validates existing GH issues and ensures cross-references when a GH issue and a Linear issue cover the same work, but does not require 1:1 mapping in either direction. By default the skill is read-only and prints a drift report; `--fix` walks each finding interactively, only writing on explicit confirmation.

## Invocation

When invoked, parse the following flags from the user's arguments:

- **`--since <YYYY-MM-DD>`** — sets the lower bound of the activity window. Items with activity on or after this date are included. SDD folders are always included regardless.
- **`--all`** — sets the window to project lifetime (no lower bound). Equivalent to a full historical audit; expect stale findings.
- **`--only <gh|p2|sdd>`** — narrows the scope to one surface: `gh` (GitHub PRs + issues), `p2` (fossep2 posts), or `sdd` (SDD plan files + codebase TODOs). Combinable with `--since`, `--all`, and `--fix`.
- **`--fix`** — after printing the drift report, walk each `[drift]` and `[review]` finding interactively via `AskUserQuestion`. Default mode is read-only (no writes).

### Default behavior (no flags)

- Window: last 30 days (activity cutoff = today minus 30 days).
- Scope: all surfaces (GH PRs, GH issues, P2, SDD).
- Mode: read-only — prints the report, makes no writes.
- SDD folders are always scanned in full regardless of date window.

### Resolution rules

1. **`--since` vs `--all`:** If both are provided, `--all` wins. Briefly warn the user: "Both `--since` and `--all` were given; using `--all` (full project lifetime)."
2. **`--only` with other flags:** `--only` is mutually exclusive only with itself (you can only pass one surface value). It is freely combinable with `--since`, `--all`, and `--fix`.
3. **SDD always reads in full:** SDD plan files (`sdd/<feature>/plan.md`) and codebase TODO scans are always run regardless of the active date window. The multi-PR linkage encoded in SDD plans is the most valuable thing this skill verifies, and its accuracy does not decay with time.
4. **Malformed `--since`:** If `--since` is given without a valid ISO `YYYY-MM-DD` date (or a future date), stop and ask the user to supply a valid date before proceeding. Do not silently coerce.
5. **Unknown `--only` value:** If `--only` is given a value other than `gh`, `p2`, or `sdd`, stop and ask the user to clarify. Do not silently default to all surfaces or pick the closest match.

### Worked example

```
User invocation: /reconcile-tracking --since 2026-01-01 --only p2 --fix
Resolved:
  - Window: 2026-01-01 → today
  - Scope: P2 only
  - Mode: --fix (interactive after report)
```

### First action: echo back resolved scope

Before fetching any data, echo the resolved scope to the user so they can confirm or abort. Format it exactly like the worked example above — `Resolved:` block with Window, Scope, and Mode lines. Output the resolved-scope block, then proceed with data fetching unless the user interrupts. Treat the printed block as a checkpoint the user can read and abort on, not a literal wait. If the user presses `Ctrl-C` or says "stop", exit cleanly.

## Data fetching

Fetch data from all four surfaces before running any drift detection. Respect the `--only` flag: skip surfaces not in scope. Apply the fail-soft rule throughout (see below).

### GitHub

Run these `gh` and `git` commands. Replace `<since>` with the resolved window start date in `YYYY-MM-DD` format (e.g. `2026-03-30` for the default 30-day window).

When `--all` is active:
- For `gh pr list` commands that include a `--search "merged:>=<since>"` or `--search "closed:>=<since> ..."` filter, omit the date portion of the `--search` value entirely (drop the `merged:>=<since>` / `closed:>=<since>` clause; keep any other search qualifiers like `-is:merged`).
- For `git log`, omit the `--since=<since>` flag entirely, producing an unbounded log.

**Open PRs:**
```
gh pr list --state open --json number,title,body,headRefName,author,createdAt --limit 200
```

**Open issues:**
```
gh issue list --state open --json number,title,body,labels,createdAt,updatedAt,comments --limit 200
```

**Merged PRs in window:**
```
gh pr list --state merged --search "merged:>=<since>" --json number,title,body,headRefName,mergedAt --limit 500
```

**Closed-unmerged PRs in window:**
```
gh pr list --state closed --search "closed:>=<since> -is:merged" --json number,title,body,headRefName --limit 200
```

**Recent commits:**
```
git log --since=<since> --pretty=format:'%H %s' --no-merges
```

After fetching, extract `DOTCOM-\d+` references from two places on every PR:
- The `body` field (look for `Closes DOTCOM-\d+`, `See DOTCOM-\d+`, or bare `DOTCOM-\d+`).
- The trailing segment of `headRefName` (branch name), e.g. `feature/foo-bar-DOTCOM-16812` → `DOTCOM-16812`.

Build a map: `{ pr_number → [DOTCOM-ids] }`. Items with no extracted IDs are candidates for `PR-NO-REF`.

### Linear

Load the Linear provider first:

```
mcp__plugin_context-a8c_context-a8c__context-a8c-load-provider
  provider: "linear"
```

Then list FOSSE issues by calling `execute-tool` with the `list_issues` tool, filtering to the *Dotcom* team's *Radical Month: FOSSE* project:

```
mcp__plugin_context-a8c_context-a8c__context-a8c-execute-tool
  provider: "linear"
  tool: "list_issues"
  input: { "project": "Radical Month: FOSSE", "team": "Dotcom" }
```

This gives you the full issue list (IDs, titles, statuses, assignees). Call `get_issue` for any issue whose status is *Done*, *In Progress*, or *In Review*. These are the statuses where drift detection might need full body and comments. Skip `get_issue` for *Backlog*, *Cancelled*, *Triage*, and similar statuses where full content is unlikely to be referenced — **unless** that issue is a target of cross-reference detection (e.g., its description references a fossep2 URL, or it is referenced by a P2 post). Also call `get_issue` for any issue that's a target of cross-reference detection (e.g., its description references a fossep2 URL) regardless of status, to ensure `description_excerpt` is populated.

```
mcp__plugin_context-a8c_context-a8c__context-a8c-execute-tool
  provider: "linear"
  tool: "get_issue"
  input: { "id": "<DOTCOM-id>" }
```

In the comments of each fetched issue, scan for:
- `fossep2.wordpress.com/...` URLs (the P2 back-link signal — their presence means the Linear issue is linked to a P2 post).
- `github.com/Automattic/fosse/(issues|pull)/\d+` URLs (GH cross-link signal).

Also capture each issue's `updatedAt` (the timestamp of the last edit, which Linear updates on status transitions). If `get_issue` exposes a more specific field such as `stateUpdatedAt` or a status-history entry, prefer that — it is a tighter proxy for "time since the current status was set". Fall back to `updatedAt` when no status-specific timestamp is available.

For each issue where `get_issue` is called, extract a `description_excerpt`: take the first ~140 characters of the issue's `description` field, strip Markdown formatting (drop `**bold**`, `*italic*`, link syntax `[text](url)` → `text`, inline code backticks), collapse all whitespace to single spaces, truncate at 140 characters on a word boundary, and append `…` if truncated. If `description` is null or empty, set `description_excerpt` to `""`.

Build a map (referred to throughout this skill as `linear_map`): `{ DOTCOM-id → { title, status, description_excerpt, pr_refs: [...], p2_urls: [...], gh_refs: [...], status_updated_at } }`.

### P2 (fossep2)

**Step 1 — Discovery via mgs:**

Load the `mgs` provider:

```
mcp__plugin_context-a8c_context-a8c__context-a8c-load-provider
  provider: "mgs"
```

Run a search restricted to `fossep2.wordpress.com` for the active date window:

```
mcp__plugin_context-a8c_context-a8c__context-a8c-execute-tool
  provider: "mgs"
  tool: "search"
  input: { "query": "site:fossep2.wordpress.com", "after": "<since>" }
```

The `after` parameter accepts the same `YYYY-MM-DD` string as the resolved window start. When `--all` is active, omit the `after` parameter entirely.

This returns a list of post URLs/slugs within the window.

**Step 2 — Full reads via wpcom:**

Discover the `wpcom` tool names — **do not hardcode tool names**:

```
mcp__plugin_context-a8c_context-a8c__context-a8c-load-provider
  provider: "wpcom"
```

The response from `load-provider` will include the list of available tools and their parameters. From that list, identify the tools for:
- (a) fetching a post by URL or ID.
- (b) fetching comments for a post.

Use those tool names in subsequent `execute-tool` calls.

**Verified tools (last confirmed 2026-04-29):**
- Posts: `posts-text` with `{site, ids: [...]}` (paginated mode also supports `after`/`before`).
- Comments: `content-authoring` with `action: "execute"`, `operation: "comments.list"`, `params: {post: <post_id>, ...}`.

For each post URL discovered in Step 1, fetch the full post body and its comment thread using the verified tools.

**If the wpcom session is dead or comment fetch fails:** do NOT continue running the comment-dependent checks (`P2-LINEAR-MISSING-BACKLINK`, `P2-SETTLED-NO-LINK`) on partial data — back-links may already exist in comments and surfacing missing-back-link drift without checking comments produces false positives. Emit a single `[error]` row in the P2 section noting that comments couldn't be fetched, and suppress those two checks entirely for this run. As a partial fallback before giving up, try MGS search per-DOTCOM-ID restricted by `sites: [254215245]` (fossep2's blog ID) — MGS indexes both posts and comments, so searching for the bare `DOTCOM-NNNN` string reveals whether any P2 post or comment mentions the ID. The same fallback can search for `linear.app radical-month-fosse` to surface project-level back-links. MGS is enough to verify presence/absence but does not return full comment bodies.

**Step 3 — Scanning:**

In each post body and each comment body, scan for:
- `linear.app/a8c/issue/DOTCOM-\d+` URLs.
- Bare `DOTCOM-\d+` mentions.
- `linear.app/a8c/project/[\w-]+` URLs (project-level back-links).

Build a map: `{ post_url → { title, posted_at, last_comment_at, dotcom_refs: [...], project_refs: [...] } }`. The `project_refs` list captures any project-level back-links present anywhere in the post body or comments — `P2-LINEAR-MISSING-BACKLINK` treats these as a valid back-link even when no `DOTCOM-\d+` is present, since one project-level link can cover multiple issues that reference the same post.

### SDD / codebase

This surface is always run in full regardless of the active date window.

**List plan files:**

Use `Glob` to find all SDD plan files. The pattern is relative to the repo root:
```
sdd/*/plan.md
```

**Read and parse each plan:**

For each matched `plan.md`, use `Read` to load the file. Parse two things:
1. The `## Progress` checklist — each task line and its current state.
2. Per-task `**Status**:` fields — specifically values matching `✅ Done (<ref>)`, where `<ref>` is the entire content inside the parentheses.

**Extract individual refs from `<ref>`:**

Real `plan.md` files use varied formats inside the parentheses. Treat `<ref>` as a list — split on commas and parse each token. Recognize these forms:

- **Bare PR ref:** `#27` → PR number `27` in `Automattic/fosse`.
- **Markdown-linked PR ref:** `[#19](https://github.com/Automattic/fosse/pull/19)` → PR number `19` in `Automattic/fosse`. Extract the number from the bracket text.
- **Cross-repo bare ref:** `Automattic/wordpress-atmosphere#33` → PR number `33` in repo `Automattic/wordpress-atmosphere`.
- **Cross-repo Markdown-linked ref:** `[wordpress-activitypub#3210](https://github.com/Automattic/wordpress-activitypub/pull/3210)` → PR number `3210` in the linked repo.
- **Prefixed phrasing:** `part of [#21](url)` or `merged as <sha>` — extract the `#N` or SHA from anywhere in the token; ignore prose like `part of`, `merged as`, `upstream SHA`, dates, etc.
- **7+ char hex SHA:** treat as a commit SHA.
- **Multi-ref entry:** `#27, #34` or `[#19](url), merged as c2900c0` — validate every extracted ref independently. The Status field is "good" only if all refs resolve.

A single `<ref>` may yield multiple validation targets (e.g. one PR number plus one SHA). Validate all of them.

**Resolve each extracted ref:**

- If the ref is a PR number in `Automattic/fosse` (no cross-repo prefix), run:
  ```
  gh pr view <N> --json state,mergedAt
  ```
  A valid ref must have `state: "MERGED"`. If the PR is open or closed-unmerged, flag as `SDD-DONE-BAD-REF`.
- If the ref is a cross-repo PR (e.g. `Automattic/wordpress-atmosphere#33`), **skip validation** for that ref and record it internally as "cross-repo, not validated" so the report-rendering pass can fold it into the plan-level `[info]` row's trailing annotation. Do not run `gh pr view` against other repos.
- If the ref is a 7+ character hex string (a commit SHA), run:
  ```
  git show --no-patch --format=%s <sha>
  ```
  If the command errors (unknown revision), flag as `SDD-DONE-BAD-REF`.

**Per-feature commit recency:**

For each `sdd/<feature>/` folder, run a scoped `git log` to find the most recent commit that touched any file under that folder. This is the signal `SDD-INPROGRESS-COLD` uses to decide whether a task marked *In progress* has actually seen recent work:
```
git log -1 --pretty=format:'%H %cI %s' -- sdd/<feature>/
```

Record the commit timestamp (`%cI`, ISO-8601) per feature folder. If the folder has never been committed against (empty output), record the timestamp as `null`. Build a map: `{ feature_folder → last_commit_at }`. This map is independent of the active date window — `SDD-INPROGRESS-COLD` always compares the recorded timestamp against today, not against `<since>`.

**Scan for TODO references to Linear:**

Use `Grep` across `src/` and `tests/` for lines containing `TODO`, `FIXME`, or `@todo` that also mention `DOTCOM-\d+`:
```
grep -rn 'TODO\|FIXME\|@todo' src/ tests/ | grep -E 'DOTCOM-[0-9]+'
```

For each matched line, record the file path, line number, and the `DOTCOM-\d+` ID(s) mentioned. These are candidates for `CODE-TODO-CLOSED` if the referenced Linear issue is closed.

### Fail-soft rule

If any provider tool errors out — MCP not loaded, network failure, tool not found, timeout — do not abort the entire run. The same rule applies to bash command failures (e.g., `gh` returns non-zero, `git log` errors, `Glob` finds no matches when one was expected): treat them as a partial-data condition, not a fatal error. Instead:

1. Print an `[error]` row in the relevant report section, e.g.:
   ```
   [error] Linear: load-provider failed (MCP not available) — Linear surface skipped.
   [error] P2 (wpcom): get_post timed out for fossep2.wordpress.com/2026/03/foo — post skipped.
   [error] GitHub: `gh pr list --state open` exited non-zero — open PRs skipped.
   ```
2. Continue fetching from the remaining surfaces and proceed to drift detection with whatever data was successfully collected.
3. An `[error]` row is never promoted to `[drift]` or `[review]` — it is informational only, telling the user which data is missing from this run.

## Drift detection

Run all enabled checks after data fetching completes. A check is enabled if its surface is in scope (respects `--only`). Apply the noise reduction rule before emitting any findings (see end of this section).

Throughout this section, the map built in `### Linear` (data fetching) is referred to as `linear_map`. Triggers that read Linear state (status, status timestamps, cross-references) read from `linear_map` directly.

### Threshold defaults

| Threshold | Default |
|---|---|
| Settled-P2 inactivity (days) | 14 |
| SDD in-progress cold (days) | 14 |
| Stale GH issue (days) | 90 |
| Default window (days) | 30 |

These are hardcoded in v1. Do not expose them as flags unless real-world usage shows different values fit better.

### Matching keys

| Edge | Primary key | Fallback |
|---|---|---|
| GH PR → Linear issue | `Closes \|See DOTCOM-\d+` in PR body | branch name suffix `-DOTCOM-\d+` |
| GH issue → Linear issue | `DOTCOM-\d+` in body | Linear issue body/comments referencing `/issues/<N>` |
| P2 post → Linear issue | `DOTCOM-\d+` in post body or comments | Linear issue body/comments referencing the post URL |
| SDD `plan.md` task → PR | `(<ref>)` literal in Status field | — |
| SDD feature folder → Linear | `DOTCOM-\d+` in `requirements.md` or `spec.md` | epic-title heuristic match |

---

### PR-NO-REF
**Severity**: drift
**Trigger**: For each open PR (from data fetched above), if neither the PR body nor the head branch name contains `DOTCOM-\d+`, emit a finding.
**Finding payload**: `{ check: "PR-NO-REF", pr_number, pr_title, suggested_action: "Add \`See DOTCOM-NNNN\` to PR body." }`

---

### PR-CLOSED-OPEN
**Severity**: drift
**Trigger**: For each merged PR, extract every `DOTCOM-\d+` ID matched by the closing-keyword patterns `Closes DOTCOM-\d+`, `Resolves DOTCOM-\d+`, or `Fixes DOTCOM-\d+` in the PR body. For EACH such extracted ID, look it up in `linear_map`. Emit one finding per ID whose Linear issue is not in a terminal state (Done, Cancelled). A single PR can produce multiple findings if it claims to close multiple Linear issues that are still open.
**Finding payload**: `{ check: "PR-CLOSED-OPEN", pr_number, pr_title, dotcom_id, linear_status, suggested_action: "Mark DOTCOM-NNNN Done in Linear." }`

---

### PR-DONE-NO-MERGE
**Severity**: drift
**Trigger**: For each Linear issue with status Done, check whether at least one of its linked PRs (from the `pr_refs` map) is merged. If no merged PR exists — either no PR is linked or all linked PRs are open or closed-unmerged — emit a finding.
**Finding payload**: `{ check: "PR-DONE-NO-MERGE", dotcom_id, dotcom_title, pr_refs, suggested_action: "Verify the correct PR is linked; merge or re-link as needed." }`

---

### PR-PARTIAL-FIXES
**Severity**: drift
**Trigger**: For each open or merged PR, if the body contains the pattern `Fixes DOTCOM-\d+ \(partial\)`, emit a finding. GitHub will auto-close the linked Linear issue when the PR merges, regardless of the `(partial)` qualifier, which creates unintended state.
**Finding payload**: `{ check: "PR-PARTIAL-FIXES", pr_number, pr_title, dotcom_id, suggested_action: "Edit PR body: drop \`(partial)\` and use \`See DOTCOM-NNNN\` instead if the issue is not fully resolved." }`

---

### LINEAR-IN-FLIGHT-NO-PR
**Severity**: review
**Trigger**: For each Linear issue in `linear_map` whose status is *In Progress* or *In Review*, check whether any PR's `headRefName` (across the open, merged, and closed-unmerged PR lists) ends with this issue's `DOTCOM-\d+` ID, or whether any PR body references this `DOTCOM-\d+` ID via the closing keywords. If no such PR is found, emit a finding. Compute `days_in_status` as the integer number of days between today and the issue's `status_updated_at` from `linear_map` (the `updatedAt` or `stateUpdatedAt` field captured during data fetching).
**Finding payload**: `{ check: "LINEAR-IN-FLIGHT-NO-PR", dotcom_id, dotcom_title, linear_status, days_in_status, suggested_action: "Open a PR or branch named *-DOTCOM-NNNN, or update Linear status if work has stalled." }`

---

### GHI-STALE-VALID
**Severity**: review
**Trigger**: For each open GH issue, emit a finding when both conditions hold:
- The issue is older than the *Stale GH issue* threshold (90 days) — measured against `createdAt`.
- The issue has had no comment activity within the last 90 days. Compute `last_comment_at` from `comments`: if `comments` is non-empty, use `comments[-1].createdAt`; if `comments` is empty (zero comments), fall back to `updatedAt`. The issue is "stale" when `last_comment_at` is more than 90 days ago.

**Finding payload**: `{ check: "GHI-STALE-VALID", issue_number, issue_title, age_days, last_comment_at, comment_count, suggested_action: "Confirm issue is still valid; close with a comment if resolved." }`

---

### GHI-LINEAR-NOT-XLINKED
**Severity**: drift (downgrades to review when match confidence is low — see Heuristic detail).
**Trigger**: For each open GH issue, check whether any Linear issue in `linear_map` covers the same work. Two issues are considered to cover the same work if: (a) a non-trivial substring of the GH issue title appears in a Linear issue title (case-insensitive, ignoring filler words such as "the", "a", "an", "of", "and", "for", "in", "on", "with"), OR (b) an explicit comment on either item mentions the other's ID (`DOTCOM-\d+` in the GH issue body/comments, or `/issues/<N>` in the Linear issue body/comments). If a match is found by either criterion and neither item references the other via the primary matching keys, emit a finding.

**Heuristic detail**: The title-substring match is intentionally conservative — require at least 4 consecutive non-filler words to overlap before flagging. The skill flags candidates and shows side-by-side titles for human judgment. Never emit this check as `[drift]` unless there is strong evidence; when confidence is low, show the pair as `[review]` instead and note the match basis.

**Finding payload**: `{ check: "GHI-LINEAR-NOT-XLINKED", issue_number, issue_title, dotcom_id, dotcom_title, match_basis, suggested_action: "Add \`DOTCOM-NNNN\` to the GH issue body and add a GitHub link in the Linear issue." }`

---

### GHI-LINEAR-CLOSED
**Severity**: review
**Trigger**: For each open GH issue whose body references a `DOTCOM-\d+`, look up that ID in `linear_map`. If the Linear issue is in a terminal state (Done, Cancelled), emit a finding asking whether the GH issue was actually resolved.
**Finding payload**: `{ check: "GHI-LINEAR-CLOSED", issue_number, issue_title, dotcom_id, linear_status, suggested_action: "Close the GH issue with a resolution comment if the work is done." }`

---

### P2-SETTLED-NO-LINK
**Severity**: review
**Trigger**: For each P2 post older than the *Settled-P2 inactivity* threshold (14 days) — using `posted_at` — whose `last_comment_at` is also older than the *Settled-P2 inactivity* threshold (14 days) (i.e. no recent activity), check whether the post's `dotcom_refs` list is non-empty. If the post has no `DOTCOM-\d+` references in its body or comments, emit a finding.

Note: inactivity is a heuristic for "settled", not a settlement signal. This check fires on both resolved and abandoned-unresolved discussions; the `--fix` walkthrough disambiguates by asking the user. This is part of why the severity is `[review]`, not `[drift]`.

**Finding payload**: `{ check: "P2-SETTLED-NO-LINK", post_url, post_title, posted_at, last_comment_at, suggested_action: "Confirm whether discussion reached a conclusion. If yes, add a Linear back-link comment with the decision summary. If no, consider resolving the discussion first." }`

---

### P2-LINEAR-MISSING-BACKLINK
**Severity**: drift
**Trigger**: For each Linear issue whose `p2_urls` list is non-empty (i.e. the Linear issue body or comments reference a fossep2 URL), fetch that P2 post from the P2 map. Emit a finding only when BOTH conditions hold: (a) the P2 post has no `DOTCOM-\d+` mention in its body or comments that matches this Linear issue's ID, AND (b) the P2 post has no `project_refs` entry (no `linear.app/a8c/project/...` URL in body or comments). A project-level back-link is the recommended form for kickoff/overview/research posts referenced by multiple issues — if one is present, do not emit drift for any of them.
**Finding payload**: `{ check: "P2-LINEAR-MISSING-BACKLINK", dotcom_id, dotcom_title, post_url, suggested_action: "Post a back-link comment on the P2 post linking to DOTCOM-NNNN." }`

---

### P2-LINK-BROKEN
**Severity**: review
**Trigger**: For each P2 post that contains a `linear.app/a8c/issue/DOTCOM-\d+` URL, look up the referenced DOTCOM ID in `linear_map`. If the referenced issue does not exist in the *Radical Month: FOSSE* project, is archived, or has status Cancelled, emit a finding. Record `reason` as one of `not_in_project`, `archived`, or `cancelled` so the report can show why the link is considered broken.
**Finding payload**: `{ check: "P2-LINK-BROKEN", post_url, post_title, dotcom_id, reason, suggested_action: "Review the P2 post and update or remove the broken Linear link." }`

---

### SDD-DONE-BAD-REF
**Severity**: drift
**Trigger**: For each `plan.md` task marked `✅ Done (<ref>)`, extract and validate every ref as described in the "SDD / codebase" data-fetching section. If any extracted ref fails validation — a PR in `Automattic/fosse` is open or closed-unmerged, or a commit SHA is unknown — emit a finding.

**Cross-repo refs**: If `<ref>` contains a cross-repo reference (e.g. `Automattic/wordpress-atmosphere#33` or `[wordpress-activitypub#3210](https://...)`), skip validation for that ref and record it internally as "cross-repo, not validated" so the report-rendering pass can fold it into the plan-level `[info]` row's trailing annotation. Cross-repo refs are never considered drift — they cannot fail validation since `gh pr view` is not run against other repos. A task whose Status field contains one valid `Automattic/fosse` PR and one cross-repo ref counts as "good" (no `SDD-DONE-BAD-REF` firing) as long as the Automattic/fosse ref resolves to a merged PR.

**Finding payload**: `{ check: "SDD-DONE-BAD-REF", plan_path, task_description, bad_ref, reason, suggested_action: "Update the Status field with the correct merged PR ref." }`

---

### SDD-INPROGRESS-COLD
**Severity**: review
**Trigger**: For each `plan.md` task whose `## Progress` entry is marked `In progress` (or equivalent in-progress wording), look up its feature folder's `last_commit_at` timestamp from the per-feature commit-recency map built during data fetching (`git log -1 -- sdd/<feature>/`). If `last_commit_at` is null (no commits ever touched the folder) or older than the *SDD in-progress cold* threshold (14 days), emit a finding. `days_cold` measures the number of days between today and `last_commit_at` — i.e. days since the most recent commit touching files under `sdd/<feature>/`. When `last_commit_at` is null, set `days_cold` to `null` and note "no commits on folder yet" in the report.
**Finding payload**: `{ check: "SDD-INPROGRESS-COLD", plan_path, task_description, days_cold, suggested_action: "Update plan.md: mark the task Blocked/Abandoned/Done, or push a commit touching files under sdd/<feature>/." }`

---

### SDD-NO-LINEAR
**Severity**: review
**Trigger**: For each `sdd/<feature>/` folder, scan all `.md` files in the folder for any `DOTCOM-\d+` reference. If none is found anywhere in the folder, emit a finding.
**Finding payload**: `{ check: "SDD-NO-LINEAR", feature_folder, suggested_action: "Add a DOTCOM-NNNN reference to requirements.md or spec.md to link the SDD work to its Linear issue." }`

---

### CODE-TODO-CLOSED
**Severity**: drift
**Trigger**: For each `TODO`/`FIXME`/`@todo` line in `src/` or `tests/` that mentions a `DOTCOM-\d+` ID, look up that ID in `linear_map`. If the referenced Linear issue is in a terminal state (Done, Cancelled), emit a finding.
**Finding payload**: `{ check: "CODE-TODO-CLOSED", file_path, line_number, dotcom_id, linear_status, todo_text, suggested_action: "Remove or update the TODO: the referenced Linear issue is closed." }`

---

### Noise reduction rule

Before emitting findings, apply the following deduplication pass:

1. Group all candidate findings by the primary item they concern (a PR number, a GH issue number, a P2 post URL, or an SDD task).
2. Within each group, if a higher-severity check fires on an item, suppress lower-severity checks on the same item.
   - Severity order (highest to lowest): `drift` > `review` > `info`.
3. When two checks of the same severity fire on the same item, emit both ONLY if they require distinct corrective actions. Otherwise suppress the redundant one — keep the check whose `suggested_action` is more specific. Example: `PR-CLOSED-OPEN` (drift) and `PR-NO-REF` (drift) can both fire on the same PR, but `PR-CLOSED-OPEN` already implies the PR has a DOTCOM ref (just one pointing at a still-open Linear issue), so `PR-NO-REF` is suppressed in that case.
4. Cross-repo SDD refs are not standalone findings — they are recorded internally during data fetching and folded into the plan-level `[info]` row at render time (see `### \`[info]\` row rule`). They never participate in suppression.
5. Never suppress a finding that is the sole finding for its item. The rule only fires when two or more checks target the same item in the same run.

## Report rendering

Render the report after all drift detection is complete and the noise-reduction pass has run. The report is chat-only markdown — do not write it to a file.

### Report header

Render the header block exactly as follows (no blank line between the header lines):

```
# FOSSE Tracking Reconciliation — <YYYY-MM-DD>
Window: <since> → <today> (<flag-summary>)
Scope: <surface list>
Findings: <total> (<drift count> drift, <review count> review, <info count> info)
```

Fill in the placeholders:

- `<YYYY-MM-DD>` — today's date (e.g. `2026-04-29`).
- `<since>` — the resolved window start date in `YYYY-MM-DD` format.
- `<today>` — today's date in `YYYY-MM-DD` format.
- `<flag-summary>` — a short human-readable description of which flags were active. Use:
  - `--since default 30d` when no flags were given (default window).
  - `--since <date>` when `--since` was given explicitly.
  - `--all` when `--all` was given.
- `<surface list>` — comma-separated list of surfaces in scope. Full scope: `GH PRs + GH issues + P2 + SDD`. When `--only` was given, show only the active surface (e.g. `P2`).
- `<total>`, `<drift count>`, `<review count>`, `<info count>` — counts after noise reduction. Include `[error]` rows in `<total>` only if any fetch errors occurred; do not count errors in the drift/review/info subtotals.

### Per-section format

Group findings by surface. Render each section only if it has at least one finding (including `[error]` rows). Omit empty sections entirely.

Section headings include per-section counts (omit count categories that are zero):

```
## GitHub PRs ↔ Linear (<drift count> drift, <review count> review)
## GitHub issues ↔ Linear (<drift count> drift, <review count> review)
## P2 ↔ Linear (<drift count> drift, <review count> review)
## SDD / codebase ↔ Linear (<drift count> drift, <review count> review, <info count> info)
```

Render sections in this fixed order: GitHub PRs ↔ Linear, GitHub issues ↔ Linear, P2 ↔ Linear, SDD / codebase ↔ Linear. Within each section, render `[drift]` findings first, then `[review]`, then `[info]`.

### Per-finding line template

Each finding renders on a single line where possible:

```
- [<severity>] <CHECK-ID>: <one-line description with cited identifiers> → <suggested next step>.
```

Map each Finding payload's fields to the line as follows:

- `[<severity>]` — the check's severity: `[drift]`, `[review]`, or `[info]`. Use the bracket-label text, not an emoji.
- `<CHECK-ID>` — the `check` field from the Finding payload (e.g. `PR-NO-REF`, `LINEAR-IN-FLIGHT-NO-PR`).
- `<one-line description with cited identifiers>` — a human-readable sentence constructed from the payload's identifying fields. The example output below is the canonical reference for any check not explicitly called out — match its tone, identifier style, and field ordering exactly. Rules:
  - Cite GH PRs as "PR N" (e.g. "PR 41"), GH issues as "GH issue N" (e.g. "GH issue 12"), Linear issues by their ID string ("DOTCOM-16847"), P2 posts by their title in quotes, SDD plan tasks by their `task_description` field and plan path.
  - Never use `#N` notation (no `#41`, no `#12`). This matches CLAUDE.md: `#N` outside genuine cross-link contexts auto-linkifies incorrectly when pasted.
  - Drift items always cite the literal Linear ID, GH number, or P2 title taken directly from the payload — never invent or paraphrase identifiers.
  - For `PR-DONE-NO-MERGE`: render the `pr_refs` list comma-joined (e.g. `PR 41, PR 47`); if the list is empty, render the literal text `no PR found`.
  - For `LINEAR-IN-FLIGHT-NO-PR`: include the `days_in_status` value in the description, e.g. `is "In Progress" (12d)`. If `status_updated_at` came from an `updatedAt` fallback rather than a more specific field, optionally append `(from updatedAt fallback)` — do this only when it fits on the line without making it unwieldy.
  - **Linear-issue context rendering**: When a finding cites a Linear issue (any check that has `dotcom_id` in its payload), render the finding with `DOTCOM-NNNN "<title>"` followed by the `description_excerpt` (if non-empty) in the format: `DOTCOM-NNNN "<title>" (<status>, <description_excerpt>) → <suggested_action>.` If the total line length would exceed ~200 characters, drop the `description_excerpt` and keep title + status only: `DOTCOM-NNNN "<title>" (<status>) → <suggested_action>.` If `description_excerpt` is empty, use title + status only.
  - For `GHI-LINEAR-NOT-XLINKED`: show both titles side-by-side with a `↔` separator and note the `match_basis`.
  - For `GHI-LINEAR-CLOSED` and `PR-CLOSED-OPEN`: derive `days_since_closed` from `linear_map[dotcom_id].status_updated_at` (today minus that timestamp, in whole days) and render as `(<linear_status> Xd ago)`, e.g. `(Done 30d ago)`. The Finding payload itself does not carry the date — read it from `linear_map` at render time.
  - For `P2-SETTLED-NO-LINK`: render `posted_at` and `last_comment_at` as days-ago integers using the format `(posted Xd ago, last comment Yd ago)`. Use this exact phrasing — do not abbreviate to `(Xd / Yd)` or similar.
  - For `P2-LINK-BROKEN`: render the `reason` enum value as plain English — `not_in_project` → `wrong project`, `archived` → `archived`, `cancelled` → `cancelled`. Format: `links to DOTCOM-NNNN (<reason>)`.
  - For `SDD-DONE-BAD-REF`: include the `bad_ref` and `reason` fields.
  - For `SDD-INPROGRESS-COLD`: include `days_cold` (or `"no commits on folder yet"` when `days_cold` is null).
  - For `CODE-TODO-CLOSED`: include the `file_path`, `line_number`, and the `linear_status` of the closed issue.
  - For `[error]` rows: follow the format `[error] <Surface>: <what failed> — <what was skipped>.`
- `→ <suggested next step>` — the `suggested_action` field from the Finding payload verbatim. The trailing imperative phrase after `→` matches what `--fix` will offer for that check, so the report doubles as a preview of the fix walkthrough.

### `[info]` row rule

Only SDD plans emit `[info]` rows. An `[info]` row is emitted for each `plan.md` that passes all its checks (no `SDD-DONE-BAD-REF`, no `SDD-INPROGRESS-COLD`, no `SDD-NO-LINEAR` findings for that plan). Other surfaces do not emit `[info]` rows, to keep the report short.

The `[info]` line format for a passing SDD plan:

```
- [info] <plan_path>: <done count>/<total count> tasks Done, all refs resolve to merged PRs.
```

**Cross-repo refs are folded into the plan-level `[info]` row, never emitted as standalone rows.** During detection, cross-repo refs (e.g. `Automattic/wordpress-atmosphere#33`) are recorded internally as "not validated" but do not produce their own `[info]` findings. Instead, when rendering a passing plan's `[info]` row, append the annotation `(N cross-repo ref(s) not validated)` — count the cross-repo refs across all of that plan's tasks and substitute `N`. Omit the annotation entirely when `N` is zero.

If a plan has *only* cross-repo refs (no `Automattic/fosse` PRs at all) and otherwise passes its checks, still emit one plan-level `[info]` row with the annotation — the plan counts as passing because no validation failed.

### Formatting rules

1. Keep each finding to one line where possible. When a description cannot fit on one line (e.g. very long PR titles), allow a second line indented by two spaces — but this should be rare.
2. `[error]` rows in the report are informational only; they are never promoted to `[drift]` or `[review]`.

### Example output

The following is the canonical example from the spec. Render output in this exact structure and style:

```
# FOSSE Tracking Reconciliation — 2026-04-29
Window: 2026-03-30 → 2026-04-29 (--since default 30d)
Scope: GH PRs + GH issues + P2 + SDD
Findings: 14 (4 drift, 7 review, 3 info)

## GitHub PRs ↔ Linear (2 drift, 1 review)
- [drift] PR-NO-REF: PR 41 "Add foo widget" → body has no DOTCOM ref. Add `See DOTCOM-NNNN` to body.
- [drift] PR-CLOSED-OPEN: PR 34 (merged) closed DOTCOM-16812; issue still "In Review" → mark Done.
- [review] LINEAR-IN-FLIGHT-NO-PR: DOTCOM-16847 "Implement bar" (In Progress, Implement bar — needed for X feature; blocked on upstream…) is "In Progress" (12d) but no branch/PR found.

## GitHub issues ↔ Linear (1 drift, 2 review)
- [drift] GHI-LINEAR-NOT-XLINKED: GH issue 12 "Plugin breaks on PHP 8.5" ↔ DOTCOM-16910 — neither references the other.
- [review] GHI-STALE-VALID: GH issue 7 (94d, 0 comments) — still real?
- [review] GHI-LINEAR-CLOSED: GH issue 9 references DOTCOM-16500 (Done 30d ago) — was the GH issue resolved?

## P2 ↔ Linear (1 drift, 3 review)
- [drift] P2-LINEAR-MISSING-BACKLINK: DOTCOM-16793 "Onboarding flow redesign" (In Progress, Redesign the onboarding flow to reduce drop-off; covers welcome screen and…) references fossep2.wordpress.com/2026/02/onboarding-retro but post has no back-link → Post a back-link comment on the P2 post linking to DOTCOM-16793.
- [review] P2-SETTLED-NO-LINK: "Bluesky long-form: teaser-thread vs link-card" (posted 18d ago, last comment 16d ago) — no Linear back-link.
- [review] P2-SETTLED-NO-LINK: "Onboarding flow Q1 retro" (posted 22d ago, last comment 21d ago) — no Linear back-link.
- [review] P2-LINK-BROKEN: "FOSSE January planning" links to DOTCOM-16001 (archived).

## SDD / codebase ↔ Linear (0 drift, 1 review, 3 info)
- [review] SDD-INPROGRESS-COLD: sdd/post-type-sync/plan.md task 3 "Wire projector" — In progress 19d, no commits on branch.
- [info] sdd/long-form-bluesky-strategy/plan.md: 7/7 tasks Done, all refs resolve to merged PRs.
- [info] sdd/onboarding-setup-ux/plan.md: 4/9 tasks Done, all refs resolve to merged PRs.
- [info] sdd/bluesky-native-publishing/plan.md: 12/12 tasks Done, all refs resolve to merged PRs.

---
14 findings. Re-run with `--fix` to walk drift and review items interactively.
```

### Trailer line

After all sections, render a horizontal rule and a trailer line:

```
---
<total> findings. Re-run with `--fix` to walk drift and review items interactively.
```

When the run was already invoked with `--fix`, replace the trailer with:

```
---
Starting --fix walkthrough below…
```

This leads directly into the `--fix` walkthrough behavior described in the next section.

## --fix walkthrough

When `--fix` is active, walk findings in this order: drift first, then review; within each severity, surface order is GH PRs → GH issues → P2 → SDD. `[info]` items are always skipped.

For each finding, stop and present an `AskUserQuestion` prompt. Every prompt includes universal choices: `skip` (leave this item alone and continue) and `stop` (exit cleanly; no partial-state warning). Per-check choices are listed in the table below.

### Per-check actions

| Check | Default action offered | Tool |
|---|---|---|
| `PR-NO-REF` | "Which Linear issue?" → free text → `gh pr edit <N>` to append `See DOTCOM-X` | gh |
| `PR-CLOSED-OPEN` | Set Linear DOTCOM-X to *Done* | linear MCP write |
| `PR-DONE-NO-MERGE` | No auto action — flag with context | — |
| `PR-PARTIAL-FIXES` | Edit PR body to drop `(partial)` → confirm before write | gh |
| `LINEAR-IN-FLIGHT-NO-PR` | "Still working / drop status / leave" → if drop, update Linear status | linear MCP write |
| `GHI-STALE-VALID` | "Still valid?" → if no, close GH issue with comment | gh |
| `GHI-LINEAR-NOT-XLINKED` | Add reciprocal links: edit GH issue body + add comment to Linear | gh + linear MCP |
| `GHI-LINEAR-CLOSED` | "GH issue actually resolved?" → if yes, close GH | gh |
| `P2-SETTLED-NO-LINK` | "Tracked in Linear? (paste DOTCOM-id, 'create', or 'no action')" → if id, ask for decision summary and whether to use issue-level or project-level back-link, post back-link comment; if 'create', skill drafts a Linear issue (write still requires confirmation) | wpcom + linear MCP |
| `P2-LINEAR-MISSING-BACKLINK` | Compose back-link comment incl. decision summary; ask whether to use issue-level or project-level back-link form, confirm body, post | wpcom MCP |
| `P2-LINK-BROKEN` | No auto action — flag for human review | — |
| `SDD-DONE-BAD-REF` | Prompt for correct ref → `Edit` `plan.md` | local |
| `SDD-INPROGRESS-COLD` | "Still in progress / abandoned / actually done" → update `plan.md` status | local |
| `SDD-NO-LINEAR` | "Link to existing DOTCOM-X / create new / mark intentional" → update SDD docs and (if create) draft Linear issue | local + linear MCP |
| `CODE-TODO-CLOSED` | "Remove TODO / update reference / leave" → if remove, `Edit` the file | local |

### Prompt body before any state change

Before invoking any write, compose the exact proposed body and show it to the user. Confirmation choices are `yes / edit / skip / stop`. Do not write until the user confirms with `yes`.

**PR-NO-REF** — after the user supplies the DOTCOM-id:

```
Proposed change to PR <N>:
----
<existing PR body>

See DOTCOM-<id>
----
Confirm? (yes / edit / skip / stop)
```

**PR-CLOSED-OPEN** — before setting Linear status:

```
Proposed Linear update:
  DOTCOM-<id> "<title>": <current status> → Done
Confirm? (yes / skip / stop)
```

The status target is fixed (Done) and there is no text body to edit, so `edit` is not offered.

**PR-PARTIAL-FIXES** — before editing the PR body:

```
Proposed change to PR <N>:
----
<existing PR body, with `Fixes DOTCOM-X (partial)` replaced by `See DOTCOM-X`>
----
Confirm? (yes / edit / skip / stop)
```

**LINEAR-IN-FLIGHT-NO-PR** — if the user chooses to drop the status:

```
Proposed Linear update:
  DOTCOM-<id> "<title>": <current status> → <new status chosen by user>
Confirm? (yes / skip / stop)
```

The user already selected the target status in the preceding "Still working / drop status / leave" sub-question, and there is no text body to edit, so `edit` is not offered.

**GHI-STALE-VALID** — if the user says the issue is no longer valid, compose a closing comment, show it, then close:

```
Proposed comment on GH issue <N>:
----
Closing as no longer active. If this is still relevant, please reopen with updated context.
----
Then close the issue. Confirm? (yes / edit / skip / stop)
```

**GHI-LINEAR-NOT-XLINKED** — show both proposed edits before any write:

```
Proposed change to GH issue <N> body:
----
<existing body>

See DOTCOM-<id>
----
Proposed Linear comment on DOTCOM-<id>:
----
See also: github.com/Automattic/fosse/issues/<N>
----
Confirm both? (yes / edit / skip / stop)
```

If the user chooses `edit`, re-prompt for the GH-issue body addition and the Linear comment text independently — each write can be edited separately or accepted as proposed.

**GHI-LINEAR-CLOSED** — if the user confirms the issue is resolved:

```
Proposed comment on GH issue <N>:
----
Closing — resolved by DOTCOM-<id> (<Linear status>).
----
Then close the issue. Confirm? (yes / edit / skip / stop)
```

**P2-LINEAR-MISSING-BACKLINK** — ask for a one-line decision summary and whether the back-link should target the issue or the project page, then show the composed body:

For issue-level (default):

```
Proposed comment on P2 post "<title>":
----
Tracking in [DOTCOM-<id>](https://linear.app/a8c/issue/DOTCOM-<id>). Decision: <user-supplied one-liner>.
----
Confirm? (yes / edit / skip / stop)
```

For project-level (when user selects this option):

```
Proposed comment on P2 post "<title>":
----
Tracking in [<Project Name>](https://linear.app/a8c/project/<project-slug>).
----
Confirm? (yes / edit / skip / stop)
```

The `AskUserQuestion` for this check should include: "Yes, post issue-level back-link" / "Yes, post project-level back-link" / "Edit" / "Skip" / "Stop".

**P2-SETTLED-NO-LINK** — the walkthrough asks two questions in sequence:

1. First: "Was this discussion tracked in Linear? (paste DOTCOM-id, 'create' for a new issue, or 'no action' to skip)"
2. If a DOTCOM-id was supplied: "What was the outcome? (one line, becomes part of the back-link comment)"
3. Ask whether the back-link should target the issue or the project page. The `AskUserQuestion` should include: "Yes, post issue-level back-link" / "Yes, post project-level back-link" / "Edit" / "Skip" / "Stop".
4. Then compose and show the appropriate back-link comment for confirmation:

For issue-level (default):

```
Proposed comment on P2 post "<title>":
----
Tracking in [DOTCOM-<id>](https://linear.app/a8c/issue/DOTCOM-<id>). Decision: <user-supplied one-liner>.
----
Confirm? (yes / edit / skip / stop)
```

For project-level:

```
Proposed comment on P2 post "<title>":
----
Tracking in [<Project Name>](https://linear.app/a8c/project/<project-slug>).
----
Confirm? (yes / edit / skip / stop)
```

If the user chose `'create'` in the first question, follow the `SDD-NO-LINEAR` "Create new" prompt-body pattern below to draft a Linear issue, then return to step 2 with the new DOTCOM-id. If the user chose `'no action'`, skip this finding (counts as `<M>` skipped).

**SDD-DONE-BAD-REF** — after the user supplies the correct ref:

```
Proposed edit to <plan_path>:
----
<task line before>
→
<task line after, with corrected ref>
----
Confirm? (yes / edit / skip / stop)
```

**SDD-INPROGRESS-COLD** — after the user chooses the new status:

```
Proposed edit to <plan_path>:
----
<task line before>
→
<task line after, with new status>
----
Confirm? (yes / edit / skip / stop)
```

**SDD-NO-LINEAR** — three paths depending on the user's choice (Link to existing / Create new / Mark intentional):

*Link to existing DOTCOM-id:*

```
Proposed edit to <sdd/<feature>/requirements.md or spec.md>:
----
Add line: <!-- DOTCOM-<id> -->
----
Confirm? (yes / edit / skip / stop)
```

*Create new:*

```
Draft a new Linear issue under *Radical Month: FOSSE*?
  Title: <feature folder name> (editable)
  Body: stub with link to sdd/<feature>/
Confirm? (yes / edit / skip / stop)
```

On confirm, the skill calls the Linear MCP write tool (which itself prompts), receives the new DOTCOM-id back, and adds it to `sdd/<feature>/requirements.md` using the "Link to existing" prompt body above (still requires confirmation).

*Mark intentional:*

```
Add a sentinel marker to sdd/<feature>/requirements.md so future runs don't re-flag this folder.
Marker: <!-- reconcile-tracking: no-linear-by-design -->
Confirm? (yes / edit / skip / stop)
```

**CODE-TODO-CLOSED** — if the user chooses to remove the TODO:

```
Proposed edit to <file_path> line <line_number>:
----
Remove: <todo_text>
----
Confirm? (yes / edit / skip / stop)
```

### Tool-call confirmation patterns

- **Editing PR body**: compose the new body, show it as above, get `yes/edit/skip/stop` confirmation, then run `gh pr edit <N> --body "..."` (or `--body-file`).
- **Adding GH issue comment**: compose the comment body, show it verbatim, get confirmation, run `gh issue comment <N> --body "..."`.
- **Setting Linear status**: compose the proposed change (e.g. "DOTCOM-X: In Review → Done"), get confirmation, then call the Linear MCP write tool. The MCP `save_*` call itself also prompts — the skill's confirmation is the first gate, the MCP's is the second.
- **Posting a P2 comment**: compose the back-link comment using the decision-summary template (see below), show it, get confirmation, call the wpcom MCP write tool. The MCP write itself may also prompt.
- **Editing local files** (SDD `plan.md`, code TODOs): show the proposed file edit (the new line or block), get confirmation, run `Edit`.

### Hard rules baked into `--fix`

1. **Never post a comment (GH or P2) without showing the exact body and getting explicit confirmation first.** Honors the project-wide rule from CLAUDE.md: never post comments without explicit approval.
2. **Linear status writes still go through the MCP confirmation gate.** The committed `.claude/settings.json` allows Linear read-only calls but prompts for `save_*`. The skill shows the proposed change before invoking the write, so the prompt is informative.
3. **No history-rewriting operations.** No `git push --force`, `--force-with-lease`, `git rebase`, `git reset --hard`, or `--amend`. Per CLAUDE.md, those are never automatic.
4. **`stop` exits cleanly.** No partial-state warning; rerun resumes by re-detecting current drift.
5. **`--fix` is idempotent.** Already-fixed items don't reappear on rerun — idempotency comes from re-running detection against current live state, not from tracking a fixed-item list.

### Decision-summary template (P2 back-link comments)

For `P2-SETTLED-NO-LINK` and `P2-LINEAR-MISSING-BACKLINK`, the back-link comment can take one of two forms. When asking the user for a one-line decision summary, also ask whether the back-link should target the issue (default) or the project page.

**Issue-level back-link** — use when the P2 post discusses a single specific issue's outcome:

```
Tracking in [DOTCOM-NNNN](https://linear.app/a8c/issue/DOTCOM-NNNN). Decision: <user-supplied one-liner>.
```

**Project-level back-link** — use when the P2 post is about the project as a whole (a kickoff post, an overview, a status summary), or when the post is referenced by multiple Linear issues:

```
Tracking in [<Project Name>](https://linear.app/a8c/project/<project-slug>).
```

Use the issue-level form by default. Use the project-level form when the P2 post is a kickoff, overview, or status-summary post, or when it is referenced by multiple Linear issues.

Show the exact composed body and get explicit confirmation before posting.

### After walkthrough

When the loop completes — all items have been applied, skipped, presented as informational, or the user chose `stop` — print:

```
Walkthrough complete. <N> items applied, <M> skipped, <K> unaddressed (stopped early), <L> presented as informational.
```

Bucket semantics:

- `<N>` — items where a write was confirmed and executed.
- `<M>` — items the user explicitly skipped via the `skip` choice.
- `<K>` — items not reached because the user chose `stop` before the loop finished.
- `<L>` — items presented during the walk as informational stops because the check has no auto action available (`PR-DONE-NO-MERGE`, `P2-LINK-BROKEN`). These are surfaced for context but offer no state-changing default.

If `<K>` is zero, omit the `, <K> unaddressed (stopped early)` clause. If `<L>` is zero, omit the `, <L> presented as informational` clause. When both are zero, the line reduces to `Walkthrough complete. <N> items applied, <M> skipped.`

No commit, no push, no further action.
