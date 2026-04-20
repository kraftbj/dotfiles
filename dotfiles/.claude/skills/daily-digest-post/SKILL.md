---
name: daily-digest-post
description: Use when writing a "Captain's Log" post to kraftcaptainslog.wordpress.com summarizing work since the last captain's log post. Optionally cross-posts an internal-audience draft to a project P2 (currently fossep2). Triggers on "captain's log", "daily digest post", "write up my day", or "/daily-digest".
---

# Daily Digest Post ("Captain's Log")

Publishes a summary post to `kraftcaptainslog.wordpress.com` (PUBLIC) covering work since the last captain's log post. Optionally prepares a DRAFT cross-post on an internal project P2 (currently only `fossep2.wordpress.com`, for FOSSE work).

## Core Principles

- **Public-first privacy.** kraftcaptainslog is on the open web. When in doubt, abstract or omit.
- **Explicit window.** Always show the proposed `[since, until]` range and get user confirmation before gathering.
- **Idempotent writes.** Never double-publish. Never silently overwrite an existing draft — surface it and ask.
- **Direct publish to kraftcaptainslog, draft-only for project P2s.** The public post goes live after user confirms the composed draft. Project P2 cross-posts are always DRAFT.

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

Accept natural-language adjustments. The user may say "cut at 9am today", "include through now", "start from Saturday morning", etc.

## Workflow

### Phase 1 — Confirm Window

1. Query kraftcaptainslog for the most recent published post matching title regex `^Captain's Log` using wpcom content-authoring. Use the post's `date` as `since`.
2. Compute the proposed `until` from the time-of-day rule above.
3. Show the window. Wait for confirmation or adjustment.

### Phase 2 — Check for Existing Posts on the Target Date

Before gathering, check if there's already:

- A **published** captain's log post whose title contains the target date → STOP, tell user, exit.
- A **draft** captain's log post whose title contains the target date → tell user the draft exists, ask: *"Keep drafting on top of it, delete it and start fresh, or abort?"*

Do the same check on fossep2 **only if** the user opted into the FOSSE cross-post.

### Phase 3 — Gather (parallel where possible)

Load providers once at the start:

```
mcp__context-a8c__context-a8c-load-provider(provider: "linear")
mcp__context-a8c__context-a8c-load-provider(provider: "slack")
mcp__context-a8c__context-a8c-load-provider(provider: "wpcom")
mcp__context-a8c__context-a8c-load-provider(provider: "github")
```

Then gather, in parallel where independent:

**A. Git activity (local repos)**

For each top-level repo under `~/code/` that is a git repo:

```bash
git -C "$repo" log --since="$SINCE" --until="$UNTIL" \
  --author="Brandon Kraft" --author="kraftbj" --author="claude@bk9.us" \
  --all --no-merges --pretty=format:'%h %s (%ae)'
```

Group by repo. Record the commit subject lines (not diffs).

**B. GitHub PRs (public github.com)**

Use `gh` CLI — user's global CLAUDE.md notes `webfetch` doesn't work for github.com:

```bash
gh search prs --author=@me --created=">=$SINCE_DATE" --state=all --limit=50 \
  --json=url,title,state,repository,createdAt,closedAt,mergedAt
```

Also fetch reviews:

```bash
gh search prs --reviewed-by=@me --updated=">=$SINCE_DATE" --limit=30 \
  --json=url,title,state,repository,updatedAt
```

Filter results to events whose timestamp falls within `[since, until]`.

**C. Automattic internal GitHub (via context-a8c)**

```
mcp__context-a8c__context-a8c-execute-tool(provider: "github", tool: "my-activity", params: { since: "$SINCE", until: "$UNTIL" })
```

(If that tool name doesn't exist, first call `load-provider` and inspect available tools.)

**D. Linear**

```
mcp__context-a8c__context-a8c-execute-tool(provider: "linear", tool: "my-issues", params: {})
```

Filter returned issues to ones with recent updates inside `[since, until]`. Also:

```
mcp__context-a8c__context-a8c-execute-tool(provider: "linear", tool: "inbox", params: {})
```

**E. Slack**

```
mcp__context-a8c__context-a8c-execute-tool(provider: "slack", tool: "search", params: { query: "from:@kraft after:$SINCE_DATE before:$UNTIL_DATE" })
```

Also pull recent messages from priority channels listed in `~/.claude/context-a8c.json` under `slack.channels`.

**F. P2 activity**

For each priority P2 in `~/.claude/context-a8c.json` (`p2s.priority`):

```
mcp__context-a8c__context-a8c-execute-tool(provider: "wpcom", tool: "posts-search", params: { wpcom_site: "<site>", author: "kraftbj", after: "$SINCE", before: "$UNTIL" })
```

Also pull user notifications:

```
mcp__context-a8c__context-a8c-execute-tool(provider: "wpcom", tool: "user-notifications-inbox", params: {})
```

### Phase 4 — Scrub for Privacy

**This phase is non-negotiable for the kraftcaptainslog (public) version.**

See "Privacy Scrubbing Rules" below. Produce *two* scrubbed datasets:

- `public_dataset` — aggressive scrub for kraftcaptainslog.
- `internal_dataset` — lighter scrub for fossep2 (only if cross-post opted in).

### Phase 5 — Compose

**kraftcaptainslog post (public):**

- Title: `Captain's Log, Stardate YYYY-MM-DD`
- 2–3 sentence lede summarizing the shape of the window.
- Sections (only include if non-empty after scrub): **Code**, **Writing**, **Conversations**, **Reading**, **Misc**.
- Bullets, short. Link to public artifacts only (public GitHub PRs, published blog posts on open sites). No internal URLs.
- Tag: `captains-log`. Category: `Log`.
- Any scrubbed-but-worth-mentioning items become abstracted bullets with `{AGENT NOTE: redacted for privacy — <reason>}` inline so the user can decide during review.

**fossep2 cross-post (internal, DRAFT only):**

- Title: `YYYY-MM-DD · FOSSE log` (or match existing fossep2 title convention if different — check recent posts).
- Internal specifics OK: Linear issue IDs, teammate names, internal repo paths.
- Scope: only include items related to FOSSE work. If the user didn't do anything FOSSE-specific, don't create the draft — tell the user.
- Still NOT customer-identifying info (names, emails, billing numbers).

### Phase 6 — Present for Review

Before any WP.com write:

1. Show the composed kraftcaptainslog post in full.
2. If FOSSE cross-post is being prepared, show it too.
3. Surface a **scrub report** summarizing what was redacted and why, e.g.:
   ```
   Redactions applied to public post:
   - 4 Slack DMs (not publishable)
   - 2 internal-only P2 posts from heartofgoldp2
   - 1 Linear issue from HOG team (marked confidential)
   - 3 customer names abstracted to "a customer"
   ```
4. Ask for explicit go-ahead: *"Publish to kraftcaptainslog now?"* (or "Save fossep2 draft?").

Only proceed to Phase 7 after the user confirms. In `--dry-run` mode, STOP here.

### Phase 7 — Write to WP.com

Use `mcp__claude_ai_WordPress_com__wpcom-mcp-content-authoring`.

- **kraftcaptainslog:** publish directly (`status: "publish"`). Tag `captains-log`, category `Log`.
- **fossep2:** create as DRAFT (`status: "draft"`). Match fossep2's tagging conventions.

Report back the published URL (for kraftcaptainslog) and the edit/preview links (for fossep2).

### Phase 8 — Log

Append a one-line record to `~/.claude/captains-log-history.jsonl`:

```json
{"date":"2026-04-20","window":{"since":"...","until":"..."},"kraftcaptainslog":"<post_url>","fossep2_draft":"<edit_url>|null"}
```

This gives the skill (and the user) a local audit trail that doesn't depend on the WP.com API being reachable.

## Privacy Scrubbing Rules

### Aggressive scrub for kraftcaptainslog (public)

**REMOVE entirely:**
- Any Slack message sourced from a DM or a private channel.
- Any Slack channel whose name isn't a publicly-announced Automattic channel. When unsure, treat as internal.
- Any Linear issue where the project or issue is marked confidential, OR whose team is one of `{security, legal, hr, comms}` (extend this list if in doubt — err toward remove).
- Any P2 post sourced from a P2 that isn't explicitly public. **kraftcaptainslog is PUBLIC; Automattic P2s are internal by default.** Do not quote, link, or summarize internal P2 content.
- Private GitHub repos (a8c org, github.a8c.com) and their URLs.
- Customer names, customer company names, support ticket IDs, billing IDs, email addresses.
- Unreleased product names or internal codenames (treat any codename-looking string as internal unless confirmed public).

**KEEP (with normal editing):**
- Public GitHub PRs (github.com/wordpress/*, github.com/woocommerce/*, github.com/Automattic/jetpack (public side), etc.).
- Published blog posts on the open web (wordpress.org, wordpress.com News, personal blogs).
- Public conference talks, releases, and widely-known product info.
- Generic activity descriptions that don't name internal systems ("reviewed a PR", "paired on a refactor").

**ABSTRACT when in doubt:**
- Use high-level verbs and domain language rather than specific system names ("worked on an auth flow" rather than "fixed [internal-system-X]").
- When abstracting, mark the redaction inline: `{AGENT NOTE: redacted for privacy — <reason>}`. This lets the user decide to restore or leave it abstract during review.

**The rule when unsure:** **OMIT.** Never guess at what's publishable. The cost of being boring is lower than the cost of leaking internal context to the open web.

### Lighter scrub for fossep2 (internal)

- Keep internal specifics (Linear IDs, repo paths, teammate mentions, codenames).
- Still remove: customer-identifying info, credentials, anything marked explicitly confidential.
- Slack DMs still omitted — DMs are not appropriate to republish anywhere without consent.

## Publishing Rules

- kraftcaptainslog post: `status: "publish"`, tag `captains-log`, category `Log`, author = kraftbj.
- fossep2 post: `status: "draft"`, tag matching existing fossep2 conventions (look at recent fossep2 posts before writing).
- Never publish to fossep2 directly, regardless of user instruction — if user insists, they can publish from the WP.com UI after review.
- Never add images in v1.
- Never schedule posts in v1.

## Existing Post/Draft Handling

Before writing:

1. **Published captain's log for target date exists** → exit with: *"A published captain's log for `<date>` already exists: `<url>`. Nothing to do. Run with a different date or delete the post first."*
2. **Draft captain's log for target date exists (created by this skill)** → ask the user: *"There's an existing draft: `<url>`. Options: (a) discard + start fresh, (b) open it for manual edit, (c) abort."*
3. **Manual draft unrelated to this skill** → do not touch. Treat like (2) but note it's not from this skill.

Detect "this skill's posts" by tag = `captains-log` OR by title prefix `Captain's Log`.

## Common Mistakes / Red Flags

- Publishing without showing the scrub report.
- Using MCP `posts-search` or similar without date-range params, then publishing posts older than the window.
- Forgetting the `until` cutoff applies to local git and gh data too — not just MCP data.
- Composing the fossep2 draft from the `public_dataset` (should be `internal_dataset`).
- Calling `wpcom-mcp-content-authoring` with `status: "publish"` on fossep2 (ALWAYS draft).
- Double-publishing because the idempotency check didn't run first.
- Auto-applying natural-language window adjustments without echoing the parsed value back ("Cutting at 09:00 today CDT — correct?").

## Configuration Notes

Reads from `~/.claude/context-a8c.json`:
- `user.wpcom.username` — post author filter on P2s (kraftbj).
- `user.slack.username` — Slack search filter (`@kraft`).
- `p2s.priority` — which P2s to pull activity from.
- `slack.channels` — which channels to inspect for context.
- `teams.linear` — which Linear teams are "mine".

To add another public-audience target (beyond kraftcaptainslog), or another internal cross-post target (beyond fossep2), update this skill — the target list is intentionally not a config knob yet, so privacy policy per target stays reviewable.

## v2 Ideas (out of scope here)

- Featured image picker.
- Scheduled publishing via CronCreate.
- Tracks event ingestion ("product usage" section).
- Calendar integration (meetings attended).
- Auto-detection of more project P2s (not just FOSSE).
