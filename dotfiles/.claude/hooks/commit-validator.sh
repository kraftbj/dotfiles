#!/bin/bash
# Claude Code Hook: Git Commit Validator (PreToolUse)
#
# This hook validates git commit messages before they're executed.
# Place in ~/.claude/hooks/ and reference in your settings.json
#
# Features:
# - Validates conventional commit prefixes
# - Enforces max length (75 chars)
# - Blocks force commits (-f, --force, --force-with-lease) as standalone args
#   (substrings like "upstream-first" or a "-form" in a branch name are fine;
#   --no-verify is intentionally allowed for merge-conflict commits)

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

# Block force commits. Match the flag only when it's a standalone argument
# (preceded by whitespace or line-start, followed by whitespace, '=', or
# line-end) so substrings like "short-form" in a commit subject or "-form" in
# a branch name don't trigger a false positive. --no-verify is deliberately
# NOT blocked here — it's the expected tool for merge-conflict commits.
if echo "$COMMAND" | grep -qE -- "(^|[[:space:]])(-f|--force|--force-with-lease)([[:space:]]|=|$)"; then
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
        # Extract message from -m flag
        COMMIT_MESSAGE=$(echo "$COMMAND" | sed -n 's/.*-m[[:space:]]*"\([^"]*\)".*/\1/p')
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

    # Check for valid conventional commit prefix
    ALLOWED_PREFIXES="feat fix docs style refactor test chore perf ci build revert add update remove"
    HAS_VALID_PREFIX=false
    IS_GIT_NATIVE=false

    # Allow git's native merge/revert messages (e.g. `Merge branch 'foo' into bar`,
    # `Merge pull request #123 from owner/branch`, `Revert "original subject"`).
    # Git generates these, so we exempt them from both the prefix and length rules.
    if echo "$COMMIT_MESSAGE" | grep -qE "^(Merge|Revert) "; then
        HAS_VALID_PREFIX=true
        IS_GIT_NATIVE=true
    fi

    if [ "$HAS_VALID_PREFIX" = "false" ]; then
        for prefix in $ALLOWED_PREFIXES; do
            if echo "$COMMIT_MESSAGE" | grep -q "^$prefix:"; then
                HAS_VALID_PREFIX=true
                break
            fi
        done
    fi

    if [ "$HAS_VALID_PREFIX" = "false" ]; then
        cat << EOF
{
  "decision": "block",
  "reason": "Invalid commit format!\n\nMust start with one of: feat:, fix:, docs:, style:, refactor:, test:, chore:, perf:, ci:, build:, revert:, add:, update:, remove:, or git's native 'Merge ' / 'Revert ' prefixes\n\nYour message: '$COMMIT_MESSAGE'"
}
EOF
        exit 0
    fi

    # Check length (max 75 characters). Skip for git-native merge/revert messages,
    # whose default format routinely exceeds 75 chars and is not ours to control.
    if [ "$IS_GIT_NATIVE" = "false" ]; then
        MESSAGE_LENGTH=${#COMMIT_MESSAGE}
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
