# My Claude Tools

Personal dotfiles and configuration for [Claude Code](https://claude.ai/code).

## Structure

```
.
├── CLAUDE.md              # Global instructions for Claude
├── settings.json          # Claude Code settings with hooks + status line
├── statusline.sh          # Status bar showing model, context %, git branch
├── hooks/
│   ├── notify-waiting.sh  # Bell + iTerm bounce + macOS notification
│   ├── session-context.sh # Injects git status/commits at session start
│   ├── commit-validator.sh# Enforces conventional commits, blocks force push
│   ├── save-summary       # AI session summary (wrapper script)
│   ├── save-summary.py    # AI summary using Claude Agent SDK
│   └── save-summary-basic.sh # Simple logging without AI
└── install.sh             # Setup script for new machines
```

## What's Included

### Status Line
Shows at bottom of Claude Code:
- Model name (purple)
- Context usage %
- Git branch (yellow) with dirty indicator (orange *)

### Hooks

| Hook | Event | What it does |
|------|-------|--------------|
| **notify-waiting.sh** | Stop, Notification | System bell, iTerm2 dock bounce, macOS notification (Morse sound) |
| **session-context.sh** | SessionStart | Injects git status + recent 5 commits into context |
| **commit-validator.sh** | PreToolUse (Bash) | Enforces conventional commits, max 72 chars, blocks `--force` |
| **save-summary** | SessionEnd | AI-generated session summary saved to `~/.claude/session-logs/` |

### Plugins

Run these after installing:
```bash
/plugin marketplace add emdashcodes/claude-code-plugins
/plugin install google-calendar@emdashcodes-claude-code-plugins
/google-calendar:setup
```

## Installation

### New Machine Setup
```bash
git clone <this-repo> ~/code/my-claude-tools
cd ~/code/my-claude-tools
./install.sh
```

### Manual Setup
```bash
# Backup existing config
mv ~/.claude/settings.json ~/.claude/settings.json.bak
mv ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak

# Symlink from this repo
ln -s ~/code/my-claude-tools/settings.json ~/.claude/settings.json
ln -s ~/code/my-claude-tools/CLAUDE.md ~/.claude/CLAUDE.md
```

## Requirements

- **jq** - JSON processor (all hooks use this)
- **terminal-notifier** - macOS notifications: `brew install terminal-notifier`
- **Python 3 + Claude Agent SDK** - For AI session summaries (auto-creates venv)

## Customization

### Notification Sound
Edit `hooks/notify-waiting.sh` and change `-sound Morse` to any of:
Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink

### Disable a Hook
Remove or comment out the relevant section in `settings.json`.

### Switch to Basic Session Logging
Change `save-summary` to `save-summary-basic.sh` in settings.json to skip AI summaries.

## Hook Events Reference

| Event | When it fires |
|-------|---------------|
| SessionStart | startup, resume, clear, compact |
| SessionEnd | /exit or session ends |
| PreToolUse | Before tool execution (can block) |
| PostToolUse | After tool execution |
| Stop | When Claude finishes responding |
| Notification | idle_prompt (60s wait), permission_prompt |
