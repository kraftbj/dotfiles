# My Claude Tools

Personal dotfiles and configuration for [Claude Code](https://claude.ai/code).

## Structure

```
.
├── CLAUDE.md           # Global instructions for Claude
├── settings.json       # Claude Code settings with hooks
├── hooks/
│   └── notify-waiting.sh  # Notification when Claude waits for input
└── install.sh          # Setup script for new machines
```

## What It Does

### Notifications (`hooks/notify-waiting.sh`)
When Claude finishes responding or needs your attention, you'll get:
- **System bell** - terminal beep
- **iTerm2 dock bounce** - if you're using iTerm2 and it's not focused
- **macOS notification** - with the "Ping" sound

Triggers on:
- `Stop` - when Claude finishes a response
- `Notification:idle_prompt` - when Claude has been waiting 60+ seconds
- `Notification:permission_prompt` - when Claude needs permission to proceed

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
ln -s /path/to/my-claude-tools/settings.json ~/.claude/settings.json
ln -s /path/to/my-claude-tools/CLAUDE.md ~/.claude/CLAUDE.md
```

## Customization

### Adding More Hooks
Edit `settings.json` and add to the `hooks` section. Available events:
- `PreToolUse` / `PostToolUse` - before/after tool calls
- `Stop` - when Claude finishes responding
- `Notification` - with matchers: `idle_prompt`, `permission_prompt`
- `UserPromptSubmit` - when you submit a prompt
- `SessionStart` / `SessionEnd` - session lifecycle

### Disabling Notifications
Comment out or remove the hooks in `settings.json`, or make the script exit early.

## Future Ideas
- [ ] Push notifications to phone (Telegram/Signal/Pushover)
- [ ] Different sounds for different events
- [ ] Slack/Discord webhook notifications
