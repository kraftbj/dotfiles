#!/bin/bash
# Claude Code Hook: Git Commit Validator (PreToolUse)
#
# This hook validates git commit messages before they're executed.
# Place in ~/.claude/hooks/ and reference in your settings.json
#
# Features:
# - Validates conventional commit prefixes
# - Enforces max length (75 chars)
# - Blocks force commits (-f flag)

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

# Block force commits (-f flag)
if echo "$COMMAND" | grep -qE -- "git commit.*-f"; then
    cat << EOF
{
  "decision": "block",
  "reason": "Force commits (-f) are not allowed! If you really need this, ask your human."
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
    # Check for valid conventional commit prefix
    ALLOWED_PREFIXES="feat fix docs style refactor test chore perf ci build revert add update remove"
    HAS_VALID_PREFIX=false

    for prefix in $ALLOWED_PREFIXES; do
        if echo "$COMMIT_MESSAGE" | grep -q "^$prefix:"; then
            HAS_VALID_PREFIX=true
            break
        fi
    done

    if [ "$HAS_VALID_PREFIX" = "false" ]; then
        cat << EOF
{
  "decision": "block",
  "reason": "Invalid commit format!\n\nMust start with one of: feat:, fix:, docs:, style:, refactor:, test:, chore:, perf:, ci:, build:, revert:, add:, update:, remove:\n\nYour message: '$COMMIT_MESSAGE'"
}
EOF
        exit 0
    fi

    # Check length (max 75 characters)
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

# All checks passed
echo '{"decision": "approve"}'
