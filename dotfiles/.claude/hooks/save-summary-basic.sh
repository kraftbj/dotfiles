#!/bin/bash
# Claude Code Hook: Save Session Summary (SessionEnd)
#
# Logs session info when a session ends.
# Place in ~/.claude/hooks/ and reference in your settings.json
#
# Configure in settings.json:
#   "SessionEnd": [
#     {
#       "hooks": [{"type": "command", "command": "~/.claude/hooks/save-summary.sh"}]
#     }
#   ]

# Read JSON input from stdin
JSON_DATA=$(cat)

# Extract session info
SESSION_ID=$(echo "$JSON_DATA" | jq -r '.session_id // "unknown"')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get working directory if available
WORK_DIR=$(echo "$JSON_DATA" | jq -r '.workspace.current_dir // "unknown"')

# Log to file
LOG_FILE="$HOME/.claude/session-log.txt"
echo "[$TIMESTAMP] Session $SESSION_ID ended (dir: $WORK_DIR)" >> "$LOG_FILE"

# SessionEnd hooks don't return JSON - they're fire-and-forget
exit 0
