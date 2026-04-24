#!/bin/bash
# Add a new dotfile to the repo and manifest
# Usage: ./bin/add-dotfile.sh [path-to-file]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$REPO_DIR/manifest.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

usage() {
    echo "Usage: $0 [OPTIONS] <file-path>"
    echo ""
    echo "Add a dotfile to the repo and manifest."
    echo ""
    echo "Arguments:"
    echo "  file-path    Path to the file (e.g., ~/.gitconfig or .gitconfig)"
    echo ""
    echo "Options:"
    echo "  --help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 ~/.gitconfig"
    echo "  $0 ~/.config/git/config"
}

# Check dependencies
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required but not installed.${NC}"
        echo "Install with: brew install jq"
        exit 1
    fi
}

# Validate the file path matches allowed patterns
validate_target() {
    local target="$1"

    # Must start with a dot
    if [[ ! "$target" =~ ^\. ]]; then
        echo -e "${RED}Error: Target must be a dotfile (start with '.')${NC}"
        return 1
    fi

    # Block path traversal
    if [[ "$target" == *".."* ]]; then
        echo -e "${RED}Error: Path traversal not allowed${NC}"
        return 1
    fi

    # Allowed patterns
    if [[ "$target" =~ ^\.(agents|claude|codex)/ ]] || [[ "$target" =~ ^\.config/ ]] || [[ "$target" =~ ^\.[a-zA-Z0-9_-]+$ ]]; then
        return 0
    fi

    echo -e "${RED}Error: Target does not match allowed patterns${NC}"
    echo "Allowed: .agents/*, .claude/*, .codex/*, .config/*, or .<filename>"
    return 1
}

# Check against exclusion patterns from manifest
check_exclusions() {
    local file="$1"
    local basename
    basename=$(basename "$file")

    # Read exclusion patterns from manifest
    local patterns
    patterns=$(jq -r '.exclude.patterns[]' "$MANIFEST" 2>/dev/null)

    while IFS= read -r pattern; do
        # shellcheck disable=SC2254
        case "$basename" in
            $pattern)
                echo -e "${RED}BLOCKED: '$basename' matches exclusion pattern '$pattern'${NC}"
                echo -e "${RED}This file type is not allowed for security reasons.${NC}"
                return 1
                ;;
        esac
    done <<< "$patterns"

    return 0
}

# Main
main() {
    check_dependencies

    # Parse arguments
    if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        usage
        exit 0
    fi

    local source_file="$1"

    # Expand ~ if present
    source_file="${source_file/#\~/$HOME}"

    # Make path absolute if needed
    if [[ ! "$source_file" = /* ]]; then
        source_file="$HOME/$source_file"
    fi

    # Check file exists
    if [[ ! -e "$source_file" ]]; then
        echo -e "${RED}Error: File not found: $source_file${NC}"
        exit 1
    fi

    # Calculate target (relative to ~)
    local target
    target="${source_file#$HOME/}"

    if [[ "$target" == "$source_file" ]]; then
        echo -e "${RED}Error: File must be under home directory${NC}"
        exit 1
    fi

    # Validate target path
    if ! validate_target "$target"; then
        exit 1
    fi

    # Check exclusions
    if ! check_exclusions "$source_file"; then
        exit 1
    fi

    # Calculate source path in repo
    local repo_source="dotfiles/$target"
    local repo_source_full="$REPO_DIR/$repo_source"

    # Check if already in manifest
    if jq -e ".entries[] | select(.target == \"$target\")" "$MANIFEST" > /dev/null 2>&1; then
        echo -e "${YELLOW}Warning: '$target' is already in the manifest${NC}"
        exit 1
    fi

    echo -e "${BOLD}Adding dotfile:${NC}"
    echo -e "  Source: ${CYAN}$source_file${NC}"
    echo -e "  Target: ${CYAN}~/$target${NC}"
    echo -e "  Repo:   ${CYAN}$repo_source${NC}"
    echo ""

    # Ask for description
    read -rp "Description for manifest: " description
    if [[ -z "$description" ]]; then
        description="$target configuration"
    fi

    # Show file contents for review
    echo ""
    echo -e "${BOLD}File contents:${NC}"
    echo "─────────────────────────────────"
    cat "$source_file"
    echo ""
    echo "─────────────────────────────────"
    echo ""

    echo -e "${YELLOW}Review the file above for sensitive data (passwords, keys, tokens).${NC}"
    echo -e "${YELLOW}Consider running: claude 'review this file for sensitive data before I commit it'${NC}"
    echo ""

    read -rp "Proceed with adding this file? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[yY] ]]; then
        echo "Cancelled."
        exit 0
    fi

    # Create directory structure if needed
    local repo_dir
    repo_dir=$(dirname "$repo_source_full")
    mkdir -p "$repo_dir"

    # Copy file to repo
    cp "$source_file" "$repo_source_full"

    # Add to manifest
    local tmp_manifest
    tmp_manifest=$(mktemp)
    jq ".entries += [{\"source\": \"$repo_source\", \"target\": \"$target\", \"description\": \"$description\"}]" "$MANIFEST" > "$tmp_manifest"
    mv "$tmp_manifest" "$MANIFEST"

    # Remove original and create symlink
    rm "$source_file"
    ln -s "$repo_source_full" "$source_file"

    echo ""
    echo -e "${GREEN}Done!${NC}"
    echo -e "  Copied to: $repo_source"
    echo -e "  Added to manifest"
    echo -e "  Created symlink: ~/$target -> $repo_source_full"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Review with: git diff"
    echo "  2. Ask Claude to verify: claude 'review the staged changes for sensitive data'"
    echo "  3. Commit: git add -A && git commit -m 'add: $target'"
    echo "  4. Push (after review): git push"
}

main "$@"
