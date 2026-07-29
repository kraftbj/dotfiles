---
name: ce-review-challenge
description: Reconcile findings from prior /ce-code-review and /codex (and optionally /codex:adversarial-review) passes through a single structured challenge round. Mechanically dedups across providers, flags cross-model consensus as the strongest signal, runs one Claude subagent to challenge singleton findings with concrete diff evidence, and returns only defensible post-worthy comments. Use when prior review outputs are already in the conversation (pasted or saved to files) and the goal is filtering to evidence-backed comments. Do NOT use to run reviews from scratch — use /ce-code-review for that.
---

# ce-review-challenge

## Purpose

`/ce-code-review` and `/codex` (plus `/codex:adversarial-review` when warranted) already cover the same ground a 4-agent panel would. What they don't do is reconcile each other's output: deduping across providers, flagging which findings have cross-model agreement, and challenging singletons that only one source raised. This skill is that reconciliation pass — one round, no re-review.

The skill assumes the upstream reviews already happened. It does not invoke `/ce-code-review`, `/codex`, or `/codex:adversarial-review` itself. If those have not run, stop and tell the user to run them first.

## When to use

Use when:
- The user has run `/ce-code-review` plus at least one of `/codex` or `/codex:adversarial-review` on the same PR or working tree, and
- The combined output is in the conversation or available at file paths the user provides.

Do not use when:
- No prior reviews have run (point the user at `/ce-code-review` and `/codex`).
- The upstream reviews already agreed on the same small set of findings with concrete evidence (the reconciliation will be a no-op; just post the findings).
- The user is asking for review *from scratch* — that is what `/ce-code-review` is for.

## Inputs

Accept either:
1. **Pasted output** already in the conversation. Identify each provider block by its leading marker (`/ce-code-review` typically prints persona names like "security", "correctness", "testing"; `/codex:review` prints a Codex-attributed block; `/codex:adversarial-review` prints an adversarial-framed block).
2. **File paths** the user provides (e.g., saved transcripts).

If neither is present, ask once. Do not try to re-run the reviewers.

## Workflow

### 1. Normalize findings

Parse every finding into:

```
{
  provider,           // "ce-correctness" | "ce-security" | "ce-testing" | "codex" | "codex-adversarial" | etc.
  severity,           // blocker | high | medium | low | note
  confidence,         // high | medium | low (default medium if absent)
  file,               // path relative to repo root
  line_start,         // integer
  line_end,           // integer (== line_start if single line)
  category,           // short tag: "security", "regression", "test-gap", "perf", "ux", etc.
  claim,              // one-sentence summary
  evidence            // the specific code / diff lines / behavior the finding cites
}
```

Codex output is prose with file:line anchors; extract the file path, leading line number, the leading claim sentence, and any cited code block as evidence. If a finding is missing `file` or a numeric `line_start`, drop it. This is the mechanical generic-best-practice filter — do not negotiate.

### 2. Classify by consensus

Compute dedup key: `(file, floor(line_start/5)*5, category)`.

For each dedup-key bucket:

- **Cross-model consensus** = at least one finding from a `ce-*` provider AND at least one from a `codex*` provider in the same bucket. Mark these as the strongest signal.
- **Same-provider consensus** = multiple findings in the bucket but all from the same side (e.g., two `ce-*` personas). Mark as moderate signal.
- **Singleton** = exactly one source raised the finding. Sends it to the challenge round.

Collapse buckets to one entry, preserving the union of raising providers in a `raised_by` list.

### 3. Single challenge round

Spawn one Claude subagent (general-purpose). Hand it:

- The PR diff (or working-tree diff if no PR).
- The full list of singleton findings.
- An explicit instruction set:

  > For each singleton finding below, read the cited file and line range in the diff and decide:
  > - `valid` — the cited code actually has the problem; produce a one-line concrete failure path.
  > - `overstated` — the issue is real but the severity or impact is exaggerated; explain what it actually is.
  > - `invalid` — the cited code does not have the claimed problem; cite the counter-evidence from the diff.
  > - `needs-verification` — cannot decide without running the code or checking external behavior; say exactly what would resolve it.
  >
  > Reject findings whose only evidence is "best practice", "might cause issues", "could be improved", or similar — without a specific failure path, mark as `invalid`.

Consensus findings (cross-model or same-provider) are NOT challenged. They are already corroborated.

### 4. Arbitrate

Build the final lists:

- **Post-worthy:** cross-model consensus + same-provider consensus + singletons marked `valid` by the challenge round. Sort by severity (`blocker` → `high` → `medium` → `low`). Drop `note`-only items into Merge-readiness notes.
- **Downgraded / withdrawn:** singletons marked `overstated`, `invalid`, or `needs-verification`. For each, record which provider raised it and the counter-evidence from the challenge round.
- **Cross-model consensus callout:** the subset of post-worthy findings with cross-model agreement. Surface these first — they are the strongest signal.
- **Validated non-issues:** none, unless the challenge round explicitly cleared a category.

### 5. Output

Return a compact report:

```
## Cross-model consensus (strongest signal)
- [severity] file:line — claim. Raised by: ce-security + codex.
  Suggested comment: <one-paragraph PR comment ready to post>

## Other post-worthy findings
- [severity] file:line — claim. Raised by: <providers>.
  Suggested comment: <…>

## Downgraded / withdrawn
- file:line — claim. Raised by: <provider>. Verdict: <overstated|invalid|needs-verification>. Reason: <counter-evidence>.

## Merge-readiness notes
- <CI status, missing manual verification, etc., if mentioned in input>

## Provenance
- ce-code-review: <which personas ran>
- codex: <ran | not provided>
- codex-adversarial: <ran | not provided>
```

Do not post anything to GitHub. If the user asks to post after seeing the report, that is a separate explicit step.

## Severity rubric

Same scale the upstream tools use; preserve their severity unless the challenge round produced concrete counter-evidence:

- `blocker` — likely incorrect behavior, data loss, security issue, or merge-breaking failure.
- `high` — serious regression or contract violation with concrete evidence.
- `medium` — real issue with limited scope or clear workaround.
- `low` — maintainability, edge case, or test gap with plausible impact.
- `note` — merge-readiness or process observation, not a review finding.

When a challenge round marks something `overstated`, drop the severity by exactly one level and record the change.

## What this skill explicitly does not do

- Does not invoke `/ce-code-review`, `/codex`, or `/codex:adversarial-review`. Those are upstream.
- Does not preflight `gh`, `git`, or `codex` (the upstream tools already did this).
- Does not pin the review SHA (the upstream tools already pinned their own).
- Does not post comments to GitHub.
- Does not run multiple rounds. One challenge pass over singletons is enough — if the upstream reviews disagreed at a level one challenge round cannot resolve, that is a signal to escalate manually, not to spin more agents.
- Does not adjudicate consensus findings. If both providers agreed, the skill trusts them.

## Honest caveat

This skill is a no-op on small PRs where the upstream tools already agreed on a short list of concrete findings. That is the correct behavior — just post the findings. The skill earns its keep when the combined output is long enough that filtering and consensus marking actually saves a human read-through, or when the two providers disagreed.
