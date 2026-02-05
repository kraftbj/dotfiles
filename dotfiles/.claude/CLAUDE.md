Never add AI credit (commits, PRs, code comments, etc.).

github.com does not accept webfetch; use the gh CLI instead.

wordpress.org URLs (including core.trac.wordpress.org) reject generic user-agents; use curl with a browser user-agent instead of WebFetch.

Never rebuild or restart Docker containers without explicit permission. Other processes may be running.

Prefer JetBrains MCP tools (e.g. search_in_files_by_text, get_file_text_by_path, find_files_by_name_keyword, list_directory_tree) over spawning Task/Explore agents when possible to save context.

When opening PRs, always check for a `.github/PULL_REQUEST_TEMPLATE.md` file (or similar) in the repository and fully comply with its format, including all checkboxes, sections, and changelog requirements.

NEVER use `git commit --amend`, `git push --force`, `git push --force-with-lease`, `git rebase`, or `git reset --hard`. Always create new commits instead. If you believe one of these is truly necessary, you MUST stop and ask the user first using AskUserQuestion — do not infer approval from other instructions like "commit this" or "push this". These operations rewrite history and are disruptive.

Never make up GitHub repository URLs, contributor identifiers, or author attributions. Only use real, verified identifiers that exist in the current project or have been explicitly provided by the user.

Never post comments (PR comments, issue comments, etc.) without explicit approval. "Approve this PR" means only approve it, not add a comment. Ask before posting any public comments.

When writing on my behalf (PRs, Linear issues, P2 posts, GitHub comments, documentation, announcements, etc.), follow the style guide in `~/.claude/style-guide.md`.
