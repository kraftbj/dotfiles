#!/bin/bash
# Claude Code Hook: Inject context at session start (SessionStart)
#
# This hook injects git status and recent commits when a session starts.
# Place in ~/.claude/hooks/ and reference in your settings.json
#
# Triggers on: startup, resume, clear, compact
# Note: Use separate matcher entries for each event (pipe syntax not supported)

# Read JSON input from stdin
JSON_DATA=$(cat)

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    # Not a git repo, skip context injection
    exit 0
fi

# Build context content
CONTENT="## Git Context\n\n"

# Add git status
GIT_STATUS=$(git status --short 2>/dev/null)
if [ -n "$GIT_STATUS" ]; then
    CONTENT+="### Uncommitted Changes\n\n\`\`\`\n$GIT_STATUS\n\`\`\`\n\n"
else
    CONTENT+="### Working Directory Clean\n\n"
fi

# Add current branch
BRANCH=$(git branch --show-current 2>/dev/null)
if [ -n "$BRANCH" ]; then
    CONTENT+="**Current Branch:** \`$BRANCH\`\n\n"
fi

# Add recent commits
RECENT_COMMITS=$(git log --oneline -5 2>/dev/null)
if [ -n "$RECENT_COMMITS" ]; then
    CONTENT+="### Recent Commits\n\n\`\`\`\n$RECENT_COMMITS\n\`\`\`\n"
fi

# Escape content for JSON
ESCAPED=$(echo -e "$CONTENT" | jq -Rs .)

# Output hook response with additionalContext
cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $ESCAPED
  }
}
EOF
