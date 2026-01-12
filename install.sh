#!/bin/bash
# Install script for my-claude-tools
# Run this on a new machine after cloning the repo

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "Installing my-claude-tools..."

# Ensure ~/.claude directory exists
mkdir -p "$CLAUDE_DIR"

# Backup existing files if they exist and aren't symlinks
for file in settings.json CLAUDE.md; do
    target="$CLAUDE_DIR/$file"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "Backing up existing $file to $file.bak"
        mv "$target" "$target.bak"
    elif [ -L "$target" ]; then
        echo "Removing existing symlink $file"
        rm "$target"
    fi
done

# Create symlinks
echo "Creating symlinks..."
ln -s "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
ln -s "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"

# Make hooks executable
chmod +x "$SCRIPT_DIR/hooks/"*.sh 2>/dev/null || true

echo "Done! Your Claude config is now linked to: $SCRIPT_DIR"
echo ""
echo "Symlinks created:"
ls -la "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/CLAUDE.md"
