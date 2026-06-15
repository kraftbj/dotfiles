---
description: Post a "Captain's Log" summary to kraftcaptainslog.wordpress.com covering work since the last captain's log post
argument-hint: [date] [--since=<ts>] [--until=<ts>] [--dry-run] [--xpost]
---

# Daily Digest Post

Invoke the `daily-digest-post` skill to compose and publish a captain's log post.

**Arguments:** `$ARGUMENTS`

Use the `daily-digest-post` skill directly via the `Skill` tool and pass `$ARGUMENTS` through verbatim. Follow the skill's workflow exactly — including the window-confirmation and privacy-scrub-report steps. Do not skip those steps even if the arguments look unambiguous.

If `$ARGUMENTS` is empty, the skill defaults to today's date with the time-of-day window heuristic (see the skill for details).
