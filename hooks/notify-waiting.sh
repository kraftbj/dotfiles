#!/bin/bash
# Notification script for when Claude is waiting for user input
# Triggers: system bell, iTerm2 bounce, and macOS notification

# 1. System bell (terminal beep)
printf '\a'

# 2. iTerm2: Request attention (bounces dock icon if not focused)
# Uses iTerm2 proprietary escape sequence
printf '\033]1337;RequestAttention=yes\a'

# 3. macOS notification - try terminal-notifier first (more reliable), fall back to osascript
if command -v terminal-notifier &>/dev/null; then
    terminal-notifier -title "Claude Code" -message "Waiting for your input" -sound Morse &
else
    osascript -e 'display notification "Claude is waiting for your input" with title "Claude Code" sound name "Ping"' 2>/dev/null &
fi

exit 0
