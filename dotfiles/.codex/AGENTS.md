Never add AI credit (commits, PRs, code comments, etc.).

github.com does not accept webfetch; use the gh CLI instead.

wordpress.org URLs (including core.trac.wordpress.org) reject generic user-agents; use curl with a browser user-agent instead of WebFetch.

Never rebuild or restart Docker containers without explicit permission. Other processes may be running.

Prefer JetBrains MCP tools (e.g. search_in_files_by_text, get_file_text_by_path, find_files_by_name_keyword, list_directory_tree) over spawning Task/Explore agents when possible to save context.

When opening PRs, always check for a `.github/PULL_REQUEST_TEMPLATE.md` file (or similar) in the repository and fully comply with its format, including all checkboxes, sections, and changelog requirements.

NEVER use `git commit --amend`, `git push --force`, `git push --force-with-lease`, `git rebase`, or `git reset --hard`. Always create new commits instead. If you believe one of these is truly necessary, you MUST stop and ask the user first using AskUserQuestion — do not infer approval from other instructions like "commit this" or "push this". These operations rewrite history and are disruptive.

NEVER use `--no-verify` on regular commits. Only use it for merge conflict resolution commits as specified in project AGENTS.md files. Always let hooks run on normal commits.

Never make up GitHub repository URLs, contributor identifiers, or author attributions. Only use real, verified identifiers that exist in the current project or have been explicitly provided by the user.

Never post comments (PR comments, issue comments, etc.) without explicit approval. "Approve this PR" means only approve it, not add a comment. Ask before posting any public comments.

Exception: when a review thread is fully resolved by landed work (a commit you or someone else pushed genuinely addresses the comment), you may resolve it without asking — post a brief factual reply naming the fixing commit, then collapse the thread via `resolveReviewThread`. This applies only to threads that are actually, completely resolved; if the fix is partial, the comment is a question, or you are unsure it's addressed, still ask first. Never resolve a thread just to clear it.

When I say "resolve the conversation" (or "resolve the comment/thread") on a GitHub PR, I mean collapse the whole review thread via the GraphQL `resolveReviewThread` mutation — not marking an individual comment as resolved, and not just replying. The flow: (1) fetch the thread ID with a GraphQL query on `repository.pullRequest.reviewThreads.nodes.id`; (2) post the reply via `gh api -X POST repos/OWNER/REPO/pulls/N/comments/COMMENT_ID/replies -f body=...`; (3) resolve with `gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "PRRT_..."}) { thread { isResolved } } }'`. The REST API has no endpoint for this — it's GraphQL-only.

When writing on my behalf (PRs, Linear issues, P2 posts, GitHub comments, documentation, announcements, etc.), follow the style guide in `~/.claude/style-guide.md`.

Never use `@` notation (e.g. `@todo`, `@someone`, `@since`, `@return`, `@param`) in commit messages or in GitHub issues/PRs/comments outside of code blocks. GitHub interprets these as user mentions.

Never use `#` followed by a number (e.g. `#1`, `#123`) unless you intend to cross-link to that exact issue/PR. GitHub, Linear, and P2 auto-linkify `#N` and the link almost always points somewhere wrong (especially when referencing items in a numbered list). Applies everywhere — PRs, issues, comments, commits, P2 posts, Slack, Linear, code review replies. Use "issue 123", "PR 123", "item 3", "the first one", etc. instead. If a literal `#N` is unavoidable in prose, wrap it in an inline code block: `` `#1` ``. This is a hard rule, not a preference — getting it wrong publishes broken cross-references that have to be cleaned up after the fact.

Use "Fixes #123" when the code change completely addresses the issue. Use "See #123" only when more code changes are still needed. Don't downgrade to "See" just because the PR hasn't been tested yet — that's what PR review is for. Never use "Fixes ISSUE-123 (partial)" or similar — Linear/GitHub will still auto-close the issue.

Never frame a change as a security fix in public without my explicit authorization for that specific disclosure. This covers branch names, PR titles and descriptions, commit messages, changelog entries, and issue/PR comments — anything that goes public the moment it is pushed. Do not name the vulnerability class, the attack, the affected versions, or the severity, and do not link a private report or advisory. Describe what the code now does ("validate the redirect URL against an allowlist"), not what it prevents. A branch named `fix-xss-in-comments` discloses an unpatched vulnerability to everyone running the software before a fix has shipped — the push itself is the disclosure, and it cannot be taken back. If the security framing seems necessary, stop and ask. Authorization is per-PR: it does not carry to the next one, and permission to say it in the PR is not permission to say it in the public issue or the changelog.

Never combine merge conflict resolution with other changes (e.g. changelog updates, new code) in the same commit. Resolve conflicts in one commit, then make additional changes in separate commits.

When creating branches for Linear issues, end the branch name with the issue ID (e.g. `-ARC-1476`). Linear auto-associates branches that end with the issue ID.

For `gh` CLI commands, use `@me` instead of looking up the GitHub username (e.g. `--assignee @me`, `--author @me`).

Use `jetpack` for Jetpack monorepo tasks — it is the monorepo's own CLI (`tools/cli`, linked globally via `jetpack cli link`) and runs natively on the host, which is far faster than the Docker-backed `jp` wrapper. `jp` is still installed as a fallback, but prefer `jetpack`. Do not run `npm`, `npx`, or `node` directly in a Jetpack checkout; use `jetpack <command>`, or `jetpack pnpm` / `jetpack composer` to reach the underlying tools.

Ask before running a bare `pnpm install` in a Jetpack checkout. The host and the Docker container share one bind-mounted `node_modules`, so installing for one platform replaces the other's native binaries (darwin-arm64 vs linux-arm64) and breaks its builds until reinstalled. The host install is the current one; `jetpack docker phpunit` is unaffected because Composer packages are platform-independent.

When I mention "Brad" in a GitHub context, I mean gh user `anomiex`. When I mention "Thomas" in a GitHub context, I mean gh user `tbradsha` (Thomas Bradshaw — never call him Tim). When I mention "enej" in a GitHub context, I mean gh user `enejb`. When I mention "Jeremy" in a GitHub context, I mean gh user `jeherve`. Unless I give more detail indicating someone else.

Do not use the `superpowers:using-git-worktrees` skill. Use native EnterWorktree/ExitWorktree tools or Agent `isolation: "worktree"` instead.

For multi-line comment blocks, use a single block comment (`/* ... */` in C-style languages like PHP, JS/TS, and C) instead of stacking multiple single-line `//` comments. Reserve `//` for genuinely single-line comments. Defer to a file's clearly dominant existing style when it differs.

## Reproductions and verification must be faithful

Reproduce the real thing through the real code path. A synthetic stand-in that merely resembles the real output is not a test — it is a restatement of what you already assumed.

Concretely, in WordPress: do NOT hand-write block markup into a static HTML file, apply the CSS, and call the bug fixed. Insert the block the way a user would — through the editor, or via WP-CLI/REST creating a post whose markup WordPress itself renders, on a real install (Playground, Studio, Jurassic Ninja, local Docker, staging). The output you inspect must come out of WordPress, with the real block, real theme, real `theme.json`, real stylesheets, and real enqueue order. Same principle everywhere else: hit the real endpoint instead of a mock shaped the way you expect, run the real build instead of a hand-assembled bundle, exercise the real plugin instead of a snippet that imitates it.

This is a hard rule because a fake reproduction can only ever confirm the assumption that produced it. When that assumption is wrong, the "fix" ships broken, the report gets closed, and I have told colleagues something false. A bug left open is far cheaper than a bug wrongly declared fixed.

So:

- Never say "fixed", "verified", "confirmed", or "works" on the strength of an approximation. State exactly what you ran and exactly what you observed — if the evidence is a hand-built file, say that, and it does not count as verification.
- If you cannot reproduce faithfully — no test site, no local environment, missing credentials, missing data, feature needs a plan or a multisite — STOP and tell me what you need. I will spin up a proper environment. Asking costs minutes; a false "fixed" costs much more.
- Approximations are fine for exploring a hypothesis. Label them plainly as unverified sketches and never let one substitute for the real test before the work is called done.
