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
| `YYYY-MM-DD` | Date shown in post title (overrides the default title-date rule) | See "Title Date" in Window Model |
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

### Title Date

Separate from the window. The title date signals *what day the post is about*, not the day it was posted.

- **Morning mode** → title date = **yesterday** (today − 1 day). Makes clear the post is about prior work, not today's in-progress work.
- **End-of-day mode** → title date = **today**.
- **Explicit `YYYY-MM-DD` arg** → overrides either default.

**Title / window conflict handling.** If the user passes a title-arg that contradicts the window (e.g. arg `today` while morning-mode window excludes today), DO NOT silently keep the override. Resurface the specific mismatch before gathering: *"Window excludes today's work. Options: title = `YYYY-MM-DD` [yesterday], title = `YYYY-MM-DD` [today] + switch window to end-of-day, or keep the override as-is."* Treat a bare "proceed" as "accept the defaults", not "keep the conflicting arg".

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

**MCP tool names (exact):**

- context-a8c: `mcp__plugin_context-a8c_context-a8c__context-a8c-load-provider` and `mcp__plugin_context-a8c_context-a8c__context-a8c-execute-tool`
- Linear: `mcp__linear__list_issues`, `mcp__linear__get_issue`, `mcp__linear__list_comments`, etc. — **Linear is a separate MCP, not a context-a8c provider.**
- WP.com (for reading/writing kraftcaptainslog and fossep2 posts directly): `mcp__claude_ai_WordPress_com__wpcom-mcp-content-authoring`

**Available context-a8c providers:** `slack`, `wpcom`, `github`, `github-a8c` (internal GHE), `mgs`, `matticspace`, `teamcity`, `jetpack`, `fieldguide`, `opengrok`, `team-activity`, `datadog`, `anonymattic`. No `linear` provider.

Load what you need at the start of the phase:

```
mcp__plugin_context-a8c_context-a8c__context-a8c-load-provider(provider: "slack")
mcp__plugin_context-a8c_context-a8c__context-a8c-load-provider(provider: "wpcom")
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

Use `gh` CLI. Use the `YYYY-MM-DD..YYYY-MM-DD` range syntax on `--created` / `--updated` (do NOT pass two separate `--created` flags — the second silently overrides the first):

Notes on `gh search prs` flags:

- `--state` only accepts `open` or `closed` (there is no `all` value — omit the flag for both).
- JSON fields `createdAt`, `closedAt` exist; `mergedAt` does **not** (use `closedAt` + `state=="merged"`).

```bash
gh search prs --author=@me --created="$SINCE_DATE..$UNTIL_DATE" --limit=50 \
  --json=url,title,state,repository,createdAt,closedAt
gh search prs --reviewed-by=@me --updated="$SINCE_DATE..$UNTIL_DATE" --limit=30 \
  --json=url,title,state,repository,updatedAt
```

**Also gather merged-by-me PRs** (catches Dependabot / bot-authored PRs that the user merged without formal review — `gh search prs` has no `--merged-by` flag, so iterate per repo):

```bash
# For each repo with activity in the window (discover via git commits / author search first):
gh pr list --repo OWNER/REPO --state merged --search "merged:$SINCE_DATE..$UNTIL_DATE" --limit 50 \
  --json number,title,author,mergedBy,mergedAt,url
# Keep results where mergedBy.login == the user's GH login and author != the user (dedup — already in author search).
```

**C. GitHub PRs — github.a8c.com (internal GHE)**

`gh` on this machine is typically auth'd for both hosts — confirm with `gh auth status`. To target the GHE host, set **`GH_HOST`** env var on the command (there is NO `--hostname` flag):

```bash
GH_HOST=github.a8c.com gh search prs --author=@me --created="$SINCE_DATE..$UNTIL_DATE" --limit=30 \
  --json=url,title,state,repository,createdAt
GH_HOST=github.a8c.com gh search prs --reviewed-by=@me --updated="$SINCE_DATE..$UNTIL_DATE" --limit=20 \
  --json=url,title,state,repository,updatedAt
# Same per-repo merged-by-me sweep for internal repos with activity in the window.
```

Fallback (if `gh` isn't auth'd for GHE): load the context-a8c `github-a8c` provider and run `load-provider` to inspect available tools.

**D. Linear (standalone MCP)**

```
mcp__linear__list_issues(assignee: "me", updatedAt: "<ISO-8601 duration, e.g. -P7D>", limit: 50)
```

`updatedAt` accepts an ISO-8601 duration (e.g. `-P7D` = last 7 days). If the skill's window isn't a round number of days, pass the wider duration and then filter the results by comparing each issue's `updatedAt` to `[since, until]` locally.

For deeper context on any specific issue:

```
mcp__linear__get_issue(id: "<ISSUE-ID>")
mcp__linear__list_comments(issueId: "<ISSUE-ID>")
```

**E. Slack**

```
mcp__plugin_context-a8c_context-a8c__context-a8c-execute-tool(provider: "slack", tool: "search", params: { query: "from:@kraft after:$SINCE_DATE before:$UNTIL_DATE" })
```

Also pull recent messages from priority channels in `~/.claude/context-a8c.json` (`slack.channels`). **For DMs**, keep only metadata ("replied to 3 DM threads") — do not include message contents.

**F. P2 activity**

For each priority P2 in `~/.claude/context-a8c.json` (`p2s.priority`):

```
mcp__plugin_context-a8c_context-a8c__context-a8c-execute-tool(provider: "wpcom", tool: "posts-search", params: { wpcom_site: "<site>", author: "kraftbj", after: "$SINCE", before: "$UNTIL" })
```

Also:

```
mcp__plugin_context-a8c_context-a8c__context-a8c-execute-tool(provider: "wpcom", tool: "user-notifications-inbox", params: {})
```

**G. Team activity (optional, often adds context)**

The context-a8c `team-activity` provider aggregates cross-source activity signals. Load it and inspect its tools — it may surface work that didn't land in git/Linear/Slack directly (e.g., reviews, mentions, comment-level engagement):

```
mcp__plugin_context-a8c_context-a8c__context-a8c-load-provider(provider: "team-activity")
```

Then call the provider's tools with window bounds. If the result largely overlaps with what B/C/D/E/F already gave us, skip the overlap in the compose rather than duplicating.

**H. Matts Global Search (opportunistic)**

When an item needs more context (a P2 post teaser that's worth expanding, a codename that needs disambiguation), `mgs` gives Elasticsearch-backed search across internal content:

```
mcp__plugin_context-a8c_context-a8c__context-a8c-load-provider(provider: "mgs")
```

Don't use it as a primary source — just as a lookup when something's unclear.

### Phase 4 — Light Scrub

Apply only these scrubs to gathered data:

- **Slack DM contents** — omit. Summarize as metadata only ("replied to a DM thread with <teammate> about <topic>" at high level is OK, but no verbatim quotes).
- **Customer-identifying info** — abstract. Customer names, company names, email addresses, billing IDs → use "a customer" / "a store owner" / "an internal report" / etc. (Support ticket IDs are fine to keep — both destinations are internal.)
- **Credentials** — if anything that looks like a key, token, or password slipped into commit messages / Linear titles / Slack text, STOP and flag it to the user: show the suspect item in context and ask whether it's actually a credential, whether upstream cleanup is needed (e.g. commit history rewrite, key rotation), and only then continue. Do not silently scrub and publish — the fact that it surfaced may indicate a leak that needs follow-up outside this skill.

Everything else stays as-is, including: Linear issue IDs and titles, teammate @-mentions, codenames, internal repo paths, github.a8c.com PR URLs, internal P2 post URLs.

### Phase 5 — Compose

**Merged-to-trunk vs. in-flight.** Across all posts, do not conflate work that has landed with work that is only on a PR branch. If a section draws heavily from an open PR, name the PR in the section header (e.g. "Bundled backends (PR #11, open)") and add a one-line note that nothing in the section has landed on trunk. Don't phrase open-PR work as if it already shipped (e.g. *avoid* "went from empty repo to a working plugin with X" when X is in an open PR).

**kraftcaptainslog post:**

- Title: `Captain's Log, Stardate YYYY-MM-DD` — use the **title date** per the Window Model (yesterday for morning mode, today for end-of-day mode, or the explicit `YYYY-MM-DD` arg if provided).
- 2–3 sentence lede summarizing the shape of the window.
- Sections (only include if non-empty): **Code**, **Writing**, **Conversations**, **Reading**, **Misc**. Use sensible judgment; skip sections that would feel like filler.
- Bullets, short. Link every mentioned artifact: Linear issues, PRs (both hosts), P2 posts, Slack threads.
- Tag: `captains-log`. Category: `Log`.

**Project-P2 cross-post drafts (optional, DRAFT only):**

Applies to any project P2 (currently only `fossep2.wordpress.com`, but the same rules apply if more are added).

- **It's Kraft's personal daily digest, sliced to the project's scope** — not a team-wide recap or a formal project report. A team-wide weekly would be a separate skill.
- Title: `Kraft's Daily Digest — YYYY-MM-DD (<project> slice)` (date = title date from the Window Model). Do NOT use "Week N" or team-weekly framing.
- Lede: one sentence making the personal-log scope explicit, with a link back to the parent kraftcaptainslog post.
- Body: project-scoped subset of Kraft's work only. Structure as **Merged to trunk** / **In flight — not yet merged** / **Writing** / **Conversations** / **Reading**. Skip "What's next" and other forward-planning — that's the team's job, not a personal log's.
- Tags: match existing P2 conventions (look at recent posts) + `dailylog` (personal daily-log tag — create it on the target P2 if it doesn't exist yet).
- If no project-scoped work in the window, don't create the draft — tell the user.

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
- Framing a project-P2 draft (fossep2, etc.) as a team weekly ("Week N: …") or formal project report instead of Kraft's personal daily digest sliced to the project's scope.
- Conflating merged-to-trunk work with in-flight PR work — especially when summarizing a PR's branch commits as if they already landed.
- Missing merged-by-me / Dependabot PRs because only `--author=@me` + `--reviewed-by=@me` searches ran.
- Keeping an explicit `today` title arg when the window is morning-mode (excludes today's work) — surface the conflict and ask.
- Calling `wpcom-mcp-content-authoring` with `status: "publish"` on fossep2 (ALWAYS draft).
- Double-publishing because the idempotency check didn't run first.
- Applying natural-language window adjustments without echoing the parsed value back.
- Including verbatim Slack DM text (even internally, DMs are personal — metadata only).
- Using `gh search prs --state=all` (invalid — omit the flag) or requesting JSON field `mergedAt` (doesn't exist on `gh search prs`; use `closedAt` + `state=="merged"`).

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
