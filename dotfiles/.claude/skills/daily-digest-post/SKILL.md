---
name: daily-digest-post
description: Use when writing a "Captain's Log" post to kraftcaptainslog.wordpress.com summarizing work since the last captain's log post. Optionally prepares a FOSSE-scoped draft for fossep2.wordpress.com. Triggers on "captain's log", "daily digest post", "write up my day", or "/daily-digest".
---

# Daily Digest Post ("Captain's Log")

Publishes a summary post to `kraftcaptainslog.wordpress.com` (an **internal** Automattic site) covering work since the last captain's log post. Optionally prepares a DRAFT cross-post on `fossep2.wordpress.com` scoped to FOSSE-related work.

**Both destinations are internal to Automattic.** Internal context is fine: Linear IDs, teammate names, internal repo paths, codenames, internal P2 content, github.a8c.com PRs. No public-audience scrub is needed.

## Core Principles

- **Explicit window.** Always show the proposed `[since, until]` range and get user confirmation before gathering.
- **Present before writing.** Show the composed post and wait for go-ahead before any WP.com write.
- **Idempotent.** Never double-publish. Never silently overwrite an existing draft — surface and ask.
- **Minimal scrub.** Drop Slack DM contents and abstract customer-identifying info; otherwise include internal specifics.
- **Publish to kraftcaptainslog, draft-only for fossep2.** The primary post goes live after user confirms. The FOSSE cross-post is always DRAFT — let the user publish it from the WP.com UI after review.

## Activation

Triggers: user asks to post their captain's log, types `/daily-digest`, etc.

### Arguments

| Arg | Meaning | Default |
|-----|---------|---------|
| `YYYY-MM-DD` | Date shown in post title | Today (Austin/US-Central) |
| `--since=<ts>` | Window start override | Last published captain's log's timestamp |
| `--until=<ts>` | Window end override | See "Window Model" |
| `--dry-run` | Compose + display locally, no MCP writes | off |
| `--fosse` | Also prepare a fossep2 cross-post draft | off (offered at end instead) |

## Window Model

Each post covers `[since, until]` where:

- **since** = timestamp of the most recent *published* post on `kraftcaptainslog.wordpress.com` whose title starts with "Captain's Log". If none exists, default to 7 days ago and warn.
- **until** = a proposed cutoff based on the time of invocation:
  - If **now < 15:00** local → propose **`today 07:00` local** (morning mode: captures yesterday + gap, excludes anything already done today).
  - If **now >= 15:00** local → propose **`now`** (end-of-day mode: includes today's work).

**ALWAYS confirm the window with the user before gathering.** Display:

```
Proposed window:
  since: Fri 2026-04-17 17:42 CDT   (last captain's log)
  until: Mon 2026-04-20 07:00 CDT   (morning cutoff, today pre-work)

OK to proceed, or adjust? (say "until now" / "until yesterday 18:00" / etc.)
```

Accept natural-language adjustments. Echo the parsed window back before proceeding ("Cutting at 09:00 today CDT — correct?").

## Workflow

### Phase 1 — Confirm Window

1. Query kraftcaptainslog via wpcom content-authoring for the most recent published post matching title regex `^Captain's Log`. Use the post's `date` as `since`.
2. Compute the proposed `until` from the time-of-day rule.
3. Show the window. Wait for confirmation or adjustment.

### Phase 2 — Check for Existing Posts on the Target Date

Before gathering, check if there's already:

- A **published** captain's log post whose title contains the target date → STOP, tell user, exit.
- A **draft** captain's log post whose title contains the target date → tell user the draft exists, ask: *"Keep drafting on top of it, delete it and start fresh, or abort?"*

Do the same check on fossep2 **only if** the user opted into the FOSSE cross-post.

Detect "this skill's posts" by tag = `captains-log` OR title prefix `Captain's Log`.

### Phase 3 — Gather (parallel where possible)

Load providers once:

```
mcp__context-a8c__context-a8c-load-provider(provider: "linear")
mcp__context-a8c__context-a8c-load-provider(provider: "slack")
mcp__context-a8c__context-a8c-load-provider(provider: "wpcom")
mcp__context-a8c__context-a8c-load-provider(provider: "github")
```

Then gather, in parallel where independent:

**A. Git activity (local repos)**

For each top-level git repo under `~/code/`:

```bash
git -C "$repo" log --since="$SINCE" --until="$UNTIL" \
  --author="Brandon Kraft" --author="kraftbj" --author="claude@bk9.us" \
  --all --no-merges --pretty=format:'%h %s (%ae)'
```

Group by repo. Record commit subject lines.

**B. GitHub PRs — github.com**

Use `gh` CLI (user's global CLAUDE.md notes `webfetch` doesn't work for github.com):

```bash
gh search prs --author=@me --created=">=$SINCE_DATE" --state=all --limit=50 \
  --json=url,title,state,repository,createdAt,closedAt,mergedAt
gh search prs --reviewed-by=@me --updated=">=$SINCE_DATE" --limit=30 \
  --json=url,title,state,repository,updatedAt
```

Filter results whose timestamps fall within `[since, until]`.

**C. GitHub PRs — github.a8c.com (internal GHE)**

Prefer `gh` CLI if it's authenticated for the GHE host (run `gh auth status` to check). Otherwise use the context-a8c github provider:

```
mcp__context-a8c__context-a8c-execute-tool(provider: "github", tool: "<list available tools and pick the my-activity / my-prs equivalent>", params: { since: "$SINCE", until: "$UNTIL" })
```

If the exact tool name isn't known, `load-provider` returns the provider's tool list — inspect and pick.

**D. Linear**

```
mcp__context-a8c__context-a8c-execute-tool(provider: "linear", tool: "my-issues", params: {})
mcp__context-a8c__context-a8c-execute-tool(provider: "linear", tool: "inbox", params: {})
```

Filter to issues with updates in `[since, until]`.

**E. Slack**

```
mcp__context-a8c__context-a8c-execute-tool(provider: "slack", tool: "search", params: { query: "from:@kraft after:$SINCE_DATE before:$UNTIL_DATE" })
```

Also pull recent messages from priority channels in `~/.claude/context-a8c.json` (`slack.channels`). **For DMs**, keep only metadata ("replied to 3 DM threads") — do not include message contents.

**F. P2 activity**

For each priority P2 in `~/.claude/context-a8c.json` (`p2s.priority`):

```
mcp__context-a8c__context-a8c-execute-tool(provider: "wpcom", tool: "posts-search", params: { wpcom_site: "<site>", author: "kraftbj", after: "$SINCE", before: "$UNTIL" })
```

Also:

```
mcp__context-a8c__context-a8c-execute-tool(provider: "wpcom", tool: "user-notifications-inbox", params: {})
```

### Phase 4 — Light Scrub

Apply only these scrubs to gathered data:

- **Slack DM contents** — omit. Summarize as metadata only ("replied to a DM thread with <teammate> about <topic>" at high level is OK, but no verbatim quotes).
- **Customer-identifying info** — abstract. Customer names, company names, email addresses, support ticket IDs, billing IDs → use "a customer" / "a store owner" / "an internal report" / etc.
- **Credentials** — if anything that looks like a key, token, or password slipped into commit messages / Linear titles / Slack text, remove it entirely.

Everything else stays as-is, including: Linear issue IDs and titles, teammate @-mentions, codenames, internal repo paths, github.a8c.com PR URLs, internal P2 post URLs.

### Phase 5 — Compose

**kraftcaptainslog post:**

- Title: `Captain's Log, Stardate YYYY-MM-DD`
- 2–3 sentence lede summarizing the shape of the window.
- Sections (only include if non-empty): **Code**, **Writing**, **Conversations**, **Reading**, **Misc**. Use sensible judgment; skip sections that would feel like filler.
- Bullets, short. Link every mentioned artifact: Linear issues, PRs (both hosts), P2 posts, Slack threads.
- Tag: `captains-log`. Category: `Log`.

**fossep2 cross-post (optional, DRAFT only):**

- Title: match existing fossep2 convention — fetch the 3 most recent fossep2 posts first and mirror their title format. Fallback: `YYYY-MM-DD · FOSSE log`.
- Scope: only FOSSE-related items. If no FOSSE work in the window, don't create the draft — tell the user.
- Tags: match existing fossep2 conventions (look at recent posts).

### Phase 6 — Present for Review

Before any WP.com write:

1. Show the composed kraftcaptainslog post in full.
2. If the FOSSE cross-post is being prepared, show it too.
3. Note anything dropped in the scrub (e.g., *"Omitted 2 DM contents, abstracted 1 customer name."*) — short, one line.
4. Ask: *"Publish to kraftcaptainslog?"* and *"Save fossep2 draft?"* if applicable.

Only proceed to Phase 7 after the user confirms. In `--dry-run` mode, STOP here.

### Phase 7 — Write to WP.com

Use `mcp__claude_ai_WordPress_com__wpcom-mcp-content-authoring`.

- **kraftcaptainslog:** publish (`status: "publish"`). Tag `captains-log`, category `Log`.
- **fossep2:** DRAFT (`status: "draft"`). Match fossep2's tagging conventions.

Report back the published URL (for kraftcaptainslog) and the edit/preview links (for fossep2).

### Phase 8 — Log

Append a one-line record to `~/.claude/captains-log-history.jsonl`:

```json
{"date":"2026-04-20","window":{"since":"...","until":"..."},"kraftcaptainslog":"<post_url>","fossep2_draft":"<edit_url>|null"}
```

Local audit trail, independent of the WP.com API.

## Publishing Rules

- kraftcaptainslog: `status: "publish"`, tag `captains-log`, category `Log`, author = kraftbj.
- fossep2: `status: "draft"`, tags matching existing fossep2 conventions.
- Never publish to fossep2 directly, regardless of user instruction — if the user insists, they can publish from the WP.com UI after review.
- No images in v1.
- No scheduling in v1.

## Existing Post/Draft Handling

Before writing:

1. **Published captain's log for target date exists** → exit: *"A published captain's log for `<date>` already exists: `<url>`. Nothing to do."*
2. **Draft captain's log for target date exists (this skill's)** → ask: *"There's an existing draft: `<url>`. Options: (a) discard + start fresh, (b) open it for manual edit, (c) abort."*
3. **Manual draft unrelated to this skill** → do not touch. Tell the user and abort.

## Common Mistakes / Red Flags

- Publishing without showing the composed post for confirmation.
- Calling MCP `posts-search` without date-range params, then including posts from outside the window.
- Forgetting the `until` cutoff applies to local git and `gh` data too — not just MCP data.
- Composing the fossep2 draft from items unrelated to FOSSE.
- Calling `wpcom-mcp-content-authoring` with `status: "publish"` on fossep2 (ALWAYS draft).
- Double-publishing because the idempotency check didn't run first.
- Applying natural-language window adjustments without echoing the parsed value back.
- Including verbatim Slack DM text (even internally, DMs are personal — metadata only).

## Configuration Notes

Reads from `~/.claude/context-a8c.json`:
- `user.wpcom.username` — post-author filter on P2s (`kraftbj`).
- `user.slack.username` — Slack search filter (`@kraft`).
- `p2s.priority` — which P2s to pull activity from (includes `fossep2.wordpress.com`).
- `slack.channels` — which channels to inspect for context.
- `teams.linear` — which Linear teams are "mine".

To add another cross-post target (beyond fossep2), update this skill — the target list is intentionally not a config knob yet so it stays reviewable.

## v2 Ideas (out of scope here)

- Featured image picker.
- Scheduled publishing via CronCreate.
- Tracks event ingestion ("product usage" section).
- Calendar integration (meetings attended).
- Auto-detection of additional project P2s (not just FOSSE).
