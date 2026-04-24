# Dotfiles

Personal dotfiles with manifest-driven symlink management.

License: GPL-2.0-or-later

## Structure

```
.
├── dotfiles/                  # Files to be symlinked (mirrors ~)
│   ├── .gitconfig             # → ~/.gitconfig
│   ├── .zshrc                 # → ~/.zshrc
│   ├── .claude/
│   │   ├── settings.json      # → ~/.claude/settings.json
│   │   ├── CLAUDE.md          # → ~/.claude/CLAUDE.md
│   │   ├── statusline.sh      # Status bar script
│   │   └── hooks/             # Hook scripts
│   ├── .codex/
│   │   └── AGENTS.md          # → ~/.codex/AGENTS.md
│   └── .config/
│       ├── git/ignore         # → ~/.config/git/ignore
│       └── zed/settings.json  # → ~/.config/zed/settings.json
├── bin/                       # Repo management scripts (NOT symlinked)
│   ├── install.sh             # Manifest-driven installer
│   └── add-dotfile.sh         # Add new dotfiles interactively
├── manifest.json              # Defines symlinks + exclusions
├── README.md
└── LICENSE
```

## Installation

```bash
git clone git@github.com:kraftbj/dotfiles.git ~/code/dotfiles
cd ~/code/dotfiles
./bin/install.sh
```

The installer:
1. Shows a dry-run of what would happen
2. Prompts for confirmation before making changes
3. Handles conflicts interactively (backup/skip/abort)

Options:
- `--force` - Skip dry-run and install immediately
- `--help` - Show usage

## Safety Model

The installer uses a strict **allowlist-only** approach:

**Allowed targets:**
- `~/.agents/*` - Codex/agent skill mirrors
- `~/.claude/*` - Claude Code config
- `~/.codex/*` - Codex config
- `~/.config/*` - XDG config directory
- `~/.something` - Single dotfiles directly in home

**Blocked directories:**
- Desktop, Documents, Downloads, Music, Movies, Pictures, Photos, Library, code, Applications, Public, Sites

**Excluded file patterns (hard error):**
- Private keys: `*.pem`, `*.key`, `*_rsa`, `*_ed25519`, `id_*`
- Secrets: `.env`, `*secret*`, `credentials*`
- Sensitive dirs: `.ssh/*`, `.gnupg/*`, `.aws/credentials`

## Adding New Dotfiles

1. Add the file to `dotfiles/` mirroring its home directory path:
   - `~/.gitconfig` → `dotfiles/.gitconfig`
   - `~/.config/git/config` → `dotfiles/.config/git/config`

2. Add entry to `manifest.json`:
   ```json
   {
     "source": "dotfiles/.gitconfig",
     "target": ".gitconfig",
     "description": "Git configuration"
   }
   ```

3. Run `./bin/install.sh` to create the symlink

## What's Included

### Git
- **`.gitconfig`** - User identity, GPG signing, Git LFS, `sync-all` alias (prunes merged branches, fast-forwards others)
- **`.config/git/ignore`** - Global gitignore: `.idea/` (JetBrains), `.claude/settings.local.json` (credentials)

### Shell
- **`.zshrc`** - Oh-my-zsh with plugins (git, nvm, gh), Spaceship prompt, tool configs (nvm, pnpm, bun), `approvemerge` function for PR workflows

### Editors
- **`.config/zed/settings.json`** - JetBrains keymap, font sizes, One Dark/Light theme

### Claude Code

#### Status Line
Shows at bottom of Claude Code: model name, context %, git branch with dirty indicator

#### Hooks

| Hook | Event | What it does |
|------|-------|--------------|
| **notify-waiting.sh** | Stop, Notification | System bell, iTerm2 dock bounce, macOS notification |
| **session-context.sh** | SessionStart | Injects git status + recent 5 commits into context |
| **commit-validator.sh** | PreToolUse (Bash) | Enforces conventional commits, blocks `--force` |
| **save-summary** | SessionEnd | AI-generated session summary saved to `~/.claude/session-logs/` |

## Requirements

- **jq** - JSON processor (required by install.sh and hooks)
- **terminal-notifier** - macOS notifications: `brew install terminal-notifier`
- **Python 3 + Claude Agent SDK** - For AI session summaries (auto-creates venv)

## Customization

### Notification Sound
Edit `dotfiles/.claude/hooks/notify-waiting.sh` and change `-sound Morse` to any of:
Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink

### Disable a Hook
Remove the relevant section in `dotfiles/.claude/settings.json`.

### Switch to Basic Session Logging
Change `save-summary` to `save-summary-basic.sh` in settings.json.

### Codex
- **`.codex/AGENTS.md`** - Global Codex instructions, sharing the Claude style guide at `~/.claude/style-guide.md`
- **`.agents/skills/*`** - Codex skill targets symlinked from the tracked `.claude/skills/*` sources so Claude and Codex share one copy of each custom skill
