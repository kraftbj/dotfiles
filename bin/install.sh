#!/bin/bash
# Dotfiles installer - manifest-driven with strict safety validation
# Default: dry-run mode. Use --force to skip confirmation.

set -euo pipefail

# Script is in bin/, repo root is parent directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$REPO_DIR/manifest.json"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Options
FORCE=false
RUN_BREW=false

# Arrays to track actions
declare -a NEW_SYMLINKS=()
declare -a UPDATE_SYMLINKS=()
declare -a CONFLICTS=()
declare -a DIRS_TO_CREATE=()
declare -a EXCLUDE_PATTERNS=()

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Install dotfiles from manifest.json by creating symlinks."
    echo ""
    echo "Options:"
    echo "  --force    Skip dry-run and install immediately"
    echo "  --brew     Also run 'brew bundle' to install Homebrew dependencies"
    echo "  --help     Show this help message"
    echo ""
    echo "Default behavior: show what would happen (dry-run), then prompt to proceed."
}

# Load exclusion patterns from manifest
load_exclusions() {
    if jq -e '.exclude.patterns' "$MANIFEST" > /dev/null 2>&1; then
        while IFS= read -r pattern; do
            EXCLUDE_PATTERNS+=("$pattern")
        done < <(jq -r '.exclude.patterns[]' "$MANIFEST")
    fi
}

# Check if a path matches any exclusion pattern
check_exclusions() {
    local path="$1"
    local basename
    basename=$(basename "$path")

    for pattern in "${EXCLUDE_PATTERNS[@]:-}"; do
        # Handle glob patterns
        # shellcheck disable=SC2254
        case "$basename" in
            $pattern)
                echo -e "${RED}BLOCKED: '$path' matches exclusion pattern '$pattern'${NC}"
                echo -e "${RED}This file type is not allowed for security reasons.${NC}"
                return 1
                ;;
        esac
        # Also check full path for patterns like .ssh/*
        # shellcheck disable=SC2254
        case "$path" in
            $pattern)
                echo -e "${RED}BLOCKED: '$path' matches exclusion pattern '$pattern'${NC}"
                echo -e "${RED}This file type is not allowed for security reasons.${NC}"
                return 1
                ;;
        esac
    done
    return 0
}

# SAFETY: Validate target path is allowed
# Only dotfiles directly under ~ or in ~/.config/ or ~/.claude/
validate_target() {
    local target="$1"

    # Must start with a dot
    if [[ ! "$target" =~ ^\. ]]; then
        echo "BLOCKED: Target must start with '.' (dotfile): $target"
        return 1
    fi

    # Block path traversal
    if [[ "$target" == *".."* ]]; then
        echo "BLOCKED: Path traversal not allowed: $target"
        return 1
    fi

    # Block absolute paths
    if [[ "$target" == /* ]]; then
        echo "BLOCKED: Absolute paths not allowed: $target"
        return 1
    fi

    # Blocked directories - NEVER touch these
    local blocked_dirs=("Desktop" "Documents" "Downloads" "Music" "Movies"
                        "Pictures" "Photos" "Library" "code" "Applications"
                        "Public" "Sites")
    for blocked in "${blocked_dirs[@]}"; do
        if [[ "$target" == *"$blocked"* ]]; then
            echo "BLOCKED: Cannot touch protected directory '$blocked': $target"
            return 1
        fi
    done

    # Check against exclusion patterns
    if ! check_exclusions "$target"; then
        return 1
    fi

    # Allowed patterns (allowlist approach)
    # Pattern 1: ~/.claude/*
    if [[ "$target" =~ ^\.claude/ ]]; then
        return 0
    fi

    # Pattern 2: ~/.config/*
    if [[ "$target" =~ ^\.config/ ]]; then
        return 0
    fi

    # Pattern 3: Single dotfile directly in ~ (e.g., .gitconfig, .zshrc)
    # Must be just a filename starting with dot, no subdirectories
    if [[ "$target" =~ ^\.[a-zA-Z0-9_-]+$ ]]; then
        return 0
    fi

    echo "BLOCKED: Target does not match allowed patterns: $target"
    echo "         Allowed: .claude/*, .config/*, or .<filename>"
    return 1
}

# Check current state of a target
get_target_state() {
    local target="$HOME/$1"
    local source="$2"

    if [[ ! -e "$target" && ! -L "$target" ]]; then
        echo "none"
    elif [[ -L "$target" ]]; then
        local link_target
        link_target=$(readlink "$target")
        local expected="$REPO_DIR/$source"
        if [[ "$link_target" == "$expected" ]]; then
            echo "symlink-correct"
        else
            echo "symlink-wrong"
        fi
    elif [[ -d "$target" ]]; then
        echo "directory"
    elif [[ -f "$target" ]]; then
        echo "file"
    else
        echo "unknown"
    fi
}

# Check if jq is available
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required but not installed.${NC}"
        echo "Install with: brew install jq"
        exit 1
    fi
}

# Process manifest and determine actions
process_manifest() {
    if [[ ! -f "$MANIFEST" ]]; then
        echo -e "${RED}Error: manifest.json not found at $MANIFEST${NC}"
        exit 1
    fi

    # Load exclusion patterns first
    load_exclusions

    local entry_count
    entry_count=$(jq '.entries | length' "$MANIFEST")

    for ((i=0; i<entry_count; i++)); do
        local source target description
        source=$(jq -r ".entries[$i].source" "$MANIFEST")
        target=$(jq -r ".entries[$i].target" "$MANIFEST")
        description=$(jq -r ".entries[$i].description" "$MANIFEST")

        # Validate source exists
        if [[ ! -e "$REPO_DIR/$source" ]]; then
            echo -e "${RED}Error: Source file not found: $source${NC}"
            exit 1
        fi

        # Check source against exclusion patterns
        if ! check_exclusions "$source"; then
            echo -e "${RED}Aborting due to exclusion pattern match.${NC}"
            exit 1
        fi

        # Validate target path (SAFETY CHECK)
        if ! validate_target "$target"; then
            echo -e "${RED}Aborting due to safety validation failure.${NC}"
            exit 1
        fi

        # Check parent directory
        local parent_dir
        parent_dir=$(dirname "$HOME/$target")
        if [[ ! -d "$parent_dir" ]]; then
            # Check if we need to add to dirs to create
            local already_listed=false
            for d in "${DIRS_TO_CREATE[@]:-}"; do
                if [[ "$d" == "$parent_dir" ]]; then
                    already_listed=true
                    break
                fi
            done
            if [[ "$already_listed" == false ]]; then
                DIRS_TO_CREATE+=("$parent_dir")
            fi
        fi

        # Check current state
        local state
        state=$(get_target_state "$target" "$source")

        case "$state" in
            none)
                NEW_SYMLINKS+=("$source|$target|$description")
                ;;
            symlink-correct)
                # Already correctly linked, skip
                ;;
            symlink-wrong)
                UPDATE_SYMLINKS+=("$source|$target|$description")
                ;;
            file|directory)
                CONFLICTS+=("$source|$target|$description|$state")
                ;;
            *)
                echo -e "${YELLOW}Warning: Unknown state for $target: $state${NC}"
                ;;
        esac
    done
}

# Display dry-run summary
show_dry_run() {
    echo -e "${BOLD}Dotfiles Installation - Dry Run${NC}"
    echo "================================"
    echo ""
    echo -e "Repository: ${CYAN}$REPO_DIR${NC}"
    echo ""

    # Directories to create
    if [[ ${#DIRS_TO_CREATE[@]} -gt 0 ]]; then
        echo -e "${BLUE}Directories to create:${NC}"
        for dir in "${DIRS_TO_CREATE[@]}"; do
            echo -e "  ${BLUE}[MKDIR]${NC} $dir"
        done
        echo ""
    fi

    # New symlinks
    if [[ ${#NEW_SYMLINKS[@]} -gt 0 ]]; then
        echo -e "${GREEN}Would create symlinks:${NC}"
        for entry in "${NEW_SYMLINKS[@]}"; do
            IFS='|' read -r source target description <<< "$entry"
            echo -e "  ${GREEN}[NEW]${NC}    ~/$target"
            echo -e "           ${CYAN}$description${NC}"
            echo ""
        done
    fi

    # Updates
    if [[ ${#UPDATE_SYMLINKS[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Would update symlinks:${NC}"
        for entry in "${UPDATE_SYMLINKS[@]}"; do
            IFS='|' read -r source target description <<< "$entry"
            local current_target
            current_target=$(readlink "$HOME/$target" 2>/dev/null || echo "unknown")
            echo -e "  ${YELLOW}[UPDATE]${NC} ~/$target"
            echo -e "           Currently: $current_target"
            echo -e "           Will point to: $REPO_DIR/$source"
            echo -e "           ${CYAN}$description${NC}"
            echo ""
        done
    fi

    # Conflicts
    if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
        echo -e "${RED}Conflicts detected:${NC}"
        for entry in "${CONFLICTS[@]}"; do
            IFS='|' read -r source target description state <<< "$entry"
            echo -e "  ${RED}[CONFLICT]${NC} ~/$target"
            echo -e "             Existing $state (not a symlink)"
            echo -e "             Will need: backup or skip"
            echo -e "             ${CYAN}$description${NC}"
            echo ""
        done
    fi

    # Summary
    local total=$((${#NEW_SYMLINKS[@]} + ${#UPDATE_SYMLINKS[@]} + ${#CONFLICTS[@]}))
    echo "─────────────────────────────────"
    echo -e "Summary: ${GREEN}${#NEW_SYMLINKS[@]} new${NC}, ${YELLOW}${#UPDATE_SYMLINKS[@]} updates${NC}, ${RED}${#CONFLICTS[@]} conflicts${NC}"

    if [[ $total -eq 0 ]]; then
        echo -e "${GREEN}Everything is already up to date!${NC}"
        return 1
    fi

    return 0
}

# Create backup of a file
create_backup() {
    local file="$1"
    mkdir -p "$BACKUP_DIR"
    local basename
    basename=$(basename "$file")
    cp -a "$file" "$BACKUP_DIR/$basename"
    echo -e "  Backed up to: ${CYAN}$BACKUP_DIR/$basename${NC}"
}

# Handle conflict interactively
handle_conflict() {
    local source="$1"
    local target="$2"
    local description="$3"

    echo ""
    echo -e "${YELLOW}Conflict: ~/$target already exists${NC}"
    echo -e "  $description"
    echo ""
    echo "Options:"
    echo "  [B] Backup existing file and replace with symlink"
    echo "  [S] Skip this file"
    echo "  [A] Abort installation"
    echo ""

    while true; do
        read -rp "Choice [B/S/A]: " choice
        case "$choice" in
            [bB])
                create_backup "$HOME/$target"
                rm -rf "$HOME/$target"
                ln -s "$REPO_DIR/$source" "$HOME/$target"
                echo -e "  ${GREEN}Created symlink${NC}"
                return 0
                ;;
            [sS])
                echo -e "  ${YELLOW}Skipped${NC}"
                return 0
                ;;
            [aA])
                echo -e "${RED}Aborted.${NC}"
                exit 1
                ;;
            *)
                echo "Invalid choice. Please enter B, S, or A."
                ;;
        esac
    done
}

# Execute the installation
execute_install() {
    echo ""
    echo -e "${BOLD}Installing...${NC}"
    echo ""

    # Create directories
    for dir in "${DIRS_TO_CREATE[@]:-}"; do
        [[ -z "$dir" ]] && continue
        echo -e "Creating directory: $dir"
        mkdir -p "$dir"
    done

    # Create new symlinks
    for entry in "${NEW_SYMLINKS[@]:-}"; do
        [[ -z "$entry" ]] && continue
        IFS='|' read -r source target description <<< "$entry"
        echo -e "Creating symlink: ~/$target"
        ln -s "$REPO_DIR/$source" "$HOME/$target"
    done

    # Update existing symlinks
    for entry in "${UPDATE_SYMLINKS[@]:-}"; do
        [[ -z "$entry" ]] && continue
        IFS='|' read -r source target description <<< "$entry"
        echo -e "Updating symlink: ~/$target"
        rm "$HOME/$target"
        ln -s "$REPO_DIR/$source" "$HOME/$target"
    done

    # Handle conflicts interactively
    for entry in "${CONFLICTS[@]:-}"; do
        [[ -z "$entry" ]] && continue
        IFS='|' read -r source target description state <<< "$entry"
        handle_conflict "$source" "$target" "$description"
    done

    # Make hook scripts executable
    if [[ -d "$REPO_DIR/dotfiles/.claude/hooks" ]]; then
        chmod +x "$REPO_DIR/dotfiles/.claude/hooks/"*.sh 2>/dev/null || true
        chmod +x "$REPO_DIR/dotfiles/.claude/hooks/save-summary" 2>/dev/null || true
    fi

    echo ""
    echo -e "${GREEN}${BOLD}Installation complete!${NC}"

    # Handle Brewfile
    if [[ -f "$REPO_DIR/Brewfile" ]]; then
        if [[ "$RUN_BREW" == true ]]; then
            echo ""
            echo -e "${BLUE}Installing Homebrew dependencies...${NC}"
            brew bundle --file="$REPO_DIR/Brewfile"
        else
            echo ""
            echo -e "${CYAN}Tip: Install Homebrew dependencies with:${NC}"
            echo "  brew bundle --file=$REPO_DIR/Brewfile"
            echo -e "${CYAN}Or run this script with --brew${NC}"
        fi
    fi

    # Kiro CLI installation
    if [[ ! -x "$HOME/.local/bin/kiro-cli" ]]; then
        echo ""
        echo -e "${CYAN}Kiro CLI is not installed.${NC}"
        echo -e "The .zprofile includes Kiro shell integration (provides autosuggestions)."
        echo ""
        read -rp "Would you like to install Kiro CLI now? [y/N]: " install_kiro
        case "$install_kiro" in
            [yY]|[yY][eE][sS])
                echo -e "${BLUE}Installing Kiro CLI...${NC}"
                curl -fsSL https://kiro.dev/install.sh | bash
                echo -e "${GREEN}Kiro CLI installed.${NC}"
                ;;
            *)
                echo -e "${YELLOW}Skipped Kiro CLI installation.${NC}"
                echo "  Install later: curl -fsSL https://kiro.dev/install.sh | bash"
                ;;
        esac
    fi

    echo ""
    echo "Symlinks created:"
    for entry in "${NEW_SYMLINKS[@]:-}" "${UPDATE_SYMLINKS[@]:-}"; do
        [[ -z "$entry" ]] && continue
        IFS='|' read -r source target description <<< "$entry"
        ls -la "$HOME/$target" 2>/dev/null || true
    done
}

# Main
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                FORCE=true
                shift
                ;;
            --brew)
                RUN_BREW=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    check_dependencies
    process_manifest

    if ! show_dry_run; then
        exit 0
    fi

    echo ""

    if [[ "$FORCE" == true ]]; then
        execute_install
    else
        read -rp "Proceed with installation? [y/N]: " confirm
        case "$confirm" in
            [yY]|[yY][eE][sS])
                execute_install
                ;;
            *)
                echo "Installation cancelled."
                exit 0
                ;;
        esac
    fi
}

main "$@"
