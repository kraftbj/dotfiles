Never add AI credit (commits, PRs, code comments, etc.).

github.com does not accept webfetch; use the gh CLI instead.

wordpress.org URLs (including core.trac.wordpress.org) reject generic user-agents; use curl with a browser user-agent instead of WebFetch.

Never rebuild or restart Docker containers without explicit permission. Other processes may be running.

Prefer JetBrains MCP tools (e.g. search_in_files_by_text, get_file_text_by_path, find_files_by_name_keyword, list_directory_tree) over spawning Task/Explore agents when possible to save context.

When opening PRs, always check for a `.github/PULL_REQUEST_TEMPLATE.md` file (or similar) in the repository and fully comply with its format, including all checkboxes, sections, and changelog requirements.

NEVER use `git commit --amend`, `git push --force`, `git push --force-with-lease`, `git rebase`, or `git reset --hard`. Always create new commits instead. If you believe one of these is truly necessary, you MUST stop and ask the user first using AskUserQuestion — do not infer approval from other instructions like "commit this" or "push this". These operations rewrite history and are disruptive.

NEVER use `--no-verify` on regular commits. Only use it for merge conflict resolution commits as specified in project CLAUDE.md files. Always let hooks run on normal commits.

Never make up GitHub repository URLs, contributor identifiers, or author attributions. Only use real, verified identifiers that exist in the current project or have been explicitly provided by the user.

Never post comments (PR comments, issue comments, etc.) without explicit approval. "Approve this PR" means only approve it, not add a comment. Ask before posting any public comments.

When writing on my behalf (PRs, Linear issues, P2 posts, GitHub comments, documentation, announcements, etc.), follow the style guide in `~/.claude/style-guide.md`.

Never use `@` notation (e.g. `@todo`, `@someone`) in commit messages or in GitHub comments/PR descriptions outside of code blocks. GitHub interprets these as user mentions.

Never use "Fixes ISSUE-123 (partial)" or similar in commits/PRs — Linear will still auto-close the issue. For partial fixes, use "See ISSUE-123" instead. Only use "Fixes" when the issue is fully resolved.

Never combine merge conflict resolution with other changes (e.g. changelog updates, new code) in the same commit. Resolve conflicts in one commit, then make additional changes in separate commits.

When creating branches for Linear issues, end the branch name with the issue ID (e.g. `-ARC-1476`). Linear auto-associates branches that end with the issue ID.

For `gh` CLI commands, use `@me` instead of looking up the GitHub username (e.g. `--assignee @me`, `--author @me`).

NEVER run `pnpm`, `npx`, `npm`, or `node` directly in a Jetpack checkout without explicit permission. Always use `jp` (the Jetpack CLI) which runs commands inside the Docker container. Running package managers directly can destroy the local `node_modules` state.

When I mention "Brad" in a GitHub context, I mean gh user `anomiex`. When I mention "Christopher" in a GitHub context, I mean gh user `ObliviousHarmony`. When I mention "Thomas" in a GitHub context, I mean gh user `tbradsha` (Thomas Bradshaw — never call him Tim). Unless I give more detail indicating someone else.

When a PR fully covers an issue, use "Fixes" (not "See").
