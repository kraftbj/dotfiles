# Project Instructions

## Security Review Required

This is a dotfiles repository. Before ANY commit or push:

1. **Review all changes for sensitive data** - passwords, API keys, tokens, private keys, credentials
2. **Check new files thoroughly** - especially settings.json, any config files, or files with "env", "secret", "key", "credential", "password", or "token" in the name or content
3. **Never auto-push** - always require explicit user confirmation before pushing to remote

## Sensitive Patterns to Block

These should NEVER be committed:
- Passwords or API keys (even application passwords)
- Private keys (*.pem, *_rsa, *_ed25519, id_*)
- Environment files (.env, .env.*)
- Credential files (credentials*, *secret*, *.secret)
- Auth tokens or session data

## Adding New Dotfiles

Use `./bin/add-dotfile.sh <path>` which will:
1. Validate the file against exclusion patterns
2. Show file contents for review
3. Add to manifest.json
4. Create the symlink

Always review the file contents before confirming.

## Local-Only Config

Machine-specific or sensitive config belongs in `~/.claude/settings.local.json` for Claude or `~/.codex/settings.local.json` for Codex (not tracked).
