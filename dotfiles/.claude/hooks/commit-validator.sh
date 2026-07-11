#!/bin/bash
# Claude Code Hook: Git Commit Validator (PreToolUse)
#
# This hook validates git commit messages before they're executed.
# Place in ~/.claude/hooks/ and reference in your settings.json
#
# Features:
# - Enforces max subject length (75 chars)
# - Blocks force commits/pushes (-f, --force, --force-with-lease) as standalone
#   args, checked only within the git segment(s) of the command (substrings like
#   "upstream-first" or a "-form" in a branch name are fine, and an unrelated
#   `rm -f`/`grep -f` chained after the commit doesn't trip it; --no-verify is
#   intentionally allowed for merge-conflict commits)

# Read JSON input from stdin
JSON_DATA=$(cat)

# Extract tool name and command
TOOL_NAME=$(echo "$JSON_DATA" | jq -r '.tool_name // ""')
COMMAND=$(echo "$JSON_DATA" | jq -r '.tool_input.command // ""')

# Only process Bash tool
if [ "$TOOL_NAME" != "Bash" ]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Only check commands containing git commit (handles "cd ... && git commit" patterns)
if ! echo "$COMMAND" | grep -q "git commit"; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Block force commits/pushes. Only inspect the segment(s) that actually invoke
# git: split the command on shell separators (; && || | newline) and keep the
# pieces whose command word is `git`. This way an unrelated `rm -f`, `grep -f`,
# or similar chained alongside the commit (e.g. `git commit ... ; rm -f tmp`)
# doesn't trip the guard. Within those git segments, match the force flag only
# as a standalone argument so substrings like "short-form" in a commit subject
# or "-form" in a branch name don't false-positive. --no-verify is deliberately
# NOT blocked here — it's the expected tool for merge-conflict commits.
GIT_SEGMENTS=$(printf '%s' "$COMMAND" | tr ';|&\n' '\n\n\n\n' | grep -E "(^|[[:space:]/])git[[:space:]]")
if printf '%s' "$GIT_SEGMENTS" | grep -qE -- "(^|[[:space:]])(-f|--force|--force-with-lease)([[:space:]]|=|$)"; then
    cat << EOF
{
  "decision": "block",
  "reason": "Force commit/push flag detected (-f / --force / --force-with-lease). Not allowed without explicit human approval — ask first."
}
EOF
    exit 0
fi

# Extract commit message
COMMIT_MESSAGE=""
if echo "$COMMAND" | grep -q -- "-m"; then
    # Handle heredoc format: git commit -m "$(cat <<'EOF'...EOF)"
    if echo "$COMMAND" | grep -q "cat <<'EOF'"; then
        COMMIT_MESSAGE=$(echo "$COMMAND" | sed -n "/cat <<'EOF'/,/EOF/p" | sed "1d;\$d")
    else
        # Extract the -m message with a multi-line-aware slurp. A line-oriented
        # sed only matches when the closing quote is on the same line as -m, so
        # a subject+body message (-m "subject<newline><newline>body") extracted
        # as empty and silently skipped every check below, including the
        # @-mention check. perl -0777 slurps the whole command so multi-line
        # quoted messages are captured. Tries double-quoted first, then single.
        COMMIT_MESSAGE=$(printf '%s' "$COMMAND" | perl -0777 -ne 'if (/-m\s*"((?:[^"\\]|\\.)*)"/s){print $1} elsif (/-m\s*'\''((?:[^'\''\\]|\\.)*)'\''/s){print $1}' 2>/dev/null)
        # Fall back to the original line-oriented sed if perl is unavailable.
        if [ -z "$COMMIT_MESSAGE" ]; then
            COMMIT_MESSAGE=$(echo "$COMMAND" | sed -n 's/.*-m[[:space:]]*"\([^"]*\)".*/\1/p')
        fi
        if [ -z "$COMMIT_MESSAGE" ]; then
            COMMIT_MESSAGE=$(echo "$COMMAND" | sed -n "s/.*-m[[:space:]]*'\([^']*\)'.*/\1/p")
        fi
    fi
fi

# Validate commit message if found
if [ -n "$COMMIT_MESSAGE" ]; then
    # Check for @ notation (GitHub interprets as user mentions).
    # Strip email addresses first, then check for remaining @word patterns.
    STRIPPED=$(echo "$COMMIT_MESSAGE" | sed 's/[a-zA-Z0-9._%+-]*@[a-zA-Z0-9.-]*\.[a-zA-Z]*//g')
    AT_MATCH=$(echo "$STRIPPED" | grep -oE '@[a-zA-Z][a-zA-Z0-9_]*' | head -1)
    if [ -n "$AT_MATCH" ]; then
        cat << EOF
{
  "decision": "block",
  "reason": "Commit message contains @ notation ('$AT_MATCH') which GitHub interprets as a user mention. Use the term without the @ prefix (e.g. 'since' instead of '@since')."
}
EOF
        exit 0
    fi

    # The length rule applies to the subject line only (first line); the body
    # may legitimately be long and span multiple lines.
    SUBJECT_LINE=$(printf '%s\n' "$COMMIT_MESSAGE" | head -n1)

    # Git's native merge/revert messages (e.g. `Merge branch 'foo' into bar`,
    # `Merge pull request #123 from owner/branch`, `Revert "original subject"`)
    # routinely exceed 75 chars and are not ours to control, so exempt them from
    # the length rule below.
    IS_GIT_NATIVE=false
    if echo "$SUBJECT_LINE" | grep -qE "^(Merge|Revert) "; then
        IS_GIT_NATIVE=true
    fi

    # Check length (max 75 characters). Skip for git-native merge/revert messages.
    if [ "$IS_GIT_NATIVE" = "false" ]; then
        MESSAGE_LENGTH=${#SUBJECT_LINE}
        if [ "$MESSAGE_LENGTH" -gt 75 ]; then
            cat << EOF
{
  "decision": "block",
  "reason": "Commit message too long: $MESSAGE_LENGTH characters (max: 75)"
}
EOF
            exit 0
        fi
    fi
fi

# All checks passed
echo '{"decision": "approve"}'
