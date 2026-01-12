#!/bin/bash
# Claude Code Status Line: Basic Example
#
# Shows: Model name, context usage %, git branch
#
# Enable in ~/.claude/settings.json:
# {
#   "statusLine": {
#     "type": "command",
#     "command": "bash ~/.claude/statusline.sh"
#   }
# }

# Read JSON input from stdin
input=$(cat)

# Parse model name
model_name=$(echo "$input" | jq -r '.model.display_name // "Unknown"')

# Calculate context usage percentage
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
usage=$(echo "$input" | jq '.context_window.current_usage // {}')

if [ "$context_size" -gt 0 ]; then
    current_tokens=$(echo "$usage" | jq 'if . then .input_tokens + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) else 0 end')
    context_percent=$((current_tokens * 100 / context_size))
else
    context_percent=0
fi

# Get git branch (if in a git repo)
git_branch=$(git branch --show-current 2>/dev/null)
git_dirty=$(git status --porcelain 2>/dev/null)

# Colors
purple="\033[35m"
gray="\033[90m"
yellow="\033[33m"
orange="\033[38;5;208m"
reset="\033[0m"

# Build output
printf "${purple}%s${reset}" "$model_name"
printf " ${gray}·${reset} %d%%" "$context_percent"

if [ -n "$git_branch" ]; then
    printf " ${gray}·${reset} ${yellow}%s${reset}" "$git_branch"
    [ -n "$git_dirty" ] && printf "${orange}*${reset}"
fi

printf "\n"
