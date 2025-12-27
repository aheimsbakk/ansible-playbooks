#!/bin/bash

# ==============================================================================
# Script Name: git-touch.sh
# Description: Updates multiple git repositories with a "README.touched" file.
# Version:     0.7
# Author:      Arnulf Heimsbakk (w/Gemini)
# ==============================================================================

VERSION="0.7"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Defaults
OPT_GIT_NAME=""
OPT_GIT_EMAIL=""
DRY_RUN=false

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERR]${NC}  $1" >&2; }
log_dry() { echo -e "${PURPLE}[DRY]${NC}  $1"; }

show_usage() {
    echo "Usage: $(basename "$0") [OPTIONS] [PATH...]"
    echo "Try '$(basename "$0") --help' for more information."
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [PATH...]

Updates git repositories with a 'README.touched' file (ISO date).
Commits and pushes changes using provided or detected git identity.

Arguments:
  PATH              Relative or absolute paths to git repositories.

Options:
  -n, --dry-run     Simulate the process without making any changes.
  -u, --name NAME   Set the Git user.name for this operation.
  -e, --email EMAIL Set the Git user.email for this operation.
  -h, --help        Show this help message.
  -V                Show version.

Example:
  $(basename "$0") -n ./my-repo
EOF
}

show_version() {
    echo "$(basename "$0") version $VERSION"
}

ensure_git_identity() {
    local repo_path="$1"

    # In Dry Run, we just announce what we would do
    if [[ "$DRY_RUN" == "true" ]]; then
        if [[ -n "$OPT_GIT_NAME" ]]; then
            log_dry "Would set local user.name to: '$OPT_GIT_NAME'"
        fi
        if [[ -n "$OPT_GIT_EMAIL" ]]; then
            log_dry "Would set local user.email to: '$OPT_GIT_EMAIL'"
        fi
        return 0
    fi

    # 1. Apply CLI overrides
    if [[ -n "$OPT_GIT_NAME" ]]; then
        git -C "$repo_path" config user.name "$OPT_GIT_NAME"
    fi
    if [[ -n "$OPT_GIT_EMAIL" ]]; then
        git -C "$repo_path" config user.email "$OPT_GIT_EMAIL"
    fi

    # 2. Fallback check
    if ! git -C "$repo_path" config user.email > /dev/null; then
        log_warn "No git identity found. Using fallback 'Git Touch Bot'."
        git -C "$repo_path" config user.name "Git Touch Bot"
        git -C "$repo_path" config user.email "automation@bot.local"
    fi
}

process_repo() {
    local repo_path="$1"
    local file_name="README.touched"
    local current_date
    current_date=$(date +%F)

    # 1. Validation
    if [[ ! -d "$repo_path" ]]; then
        log_error "Directory not found: '$repo_path'"
        return 1
    fi

    if ! git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_error "Not a valid git repository: '$repo_path'"
        return 1
    fi

    log_info "Processing: $repo_path"

    # 2. Detached HEAD Check
    local branch_name
    branch_name=$(git -C "$repo_path" rev-parse --abbrev-ref HEAD)
    if [[ "$branch_name" == "HEAD" ]]; then
        log_error "Repo is in 'Detached HEAD' state. Skipping."
        return 1
    fi

    # 3. Pull Latest
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry "Would execute: git pull (Branch: $branch_name)"
    else
        if git -C "$repo_path" pull >/dev/null 2>&1; then
            log_success "Synced with upstream ($branch_name)."
        else
            log_error "Git pull failed. Manual intervention required."
            return 1
        fi
    fi

    # 4. Identity Configuration
    ensure_git_identity "$repo_path"

    # 5. Update File
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry "Would write '$current_date' to $file_name"
    else
        echo "$current_date" > "${repo_path}/${file_name}"
    fi

    # 6. Git Commit & Push
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry "Would stage $file_name"
        log_dry "Would commit changes if diff exists"
        log_dry "Would push to $branch_name"
    else
        git -C "$repo_path" add "$file_name"

        if git -C "$repo_path" diff-index --quiet HEAD; then
            log_warn "No changes to commit."
        else
            if git -C "$repo_path" commit -m "docs: touch update $current_date" >/dev/null; then
                log_success "Committed changes."
            else
                log_error "Failed to commit."
                return 1
            fi
        fi

        if git -C "$repo_path" push >/dev/null 2>&1; then
            log_success "Pushed to $branch_name."
        else
            log_error "Push failed."
            return 1
        fi
    fi
}

# ------------------------------------------------------------------------------
# Main Execution
# ------------------------------------------------------------------------------

# Immediate check for zero arguments
if [[ $# -eq 0 ]]; then
    show_usage
    exit 1
fi

repos=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help; exit 0 ;;
        -V)
            show_version; exit 0 ;;
        -n|--dry-run)
            DRY_RUN=true; shift ;;
        -u|--name)
            if [[ -n "$2" && "$2" != -* ]]; then
                OPT_GIT_NAME="$2"; shift 2
            else
                log_error "Error: --name (-u) requires a non-empty argument."; exit 1
            fi ;;
        -e|--email)
            if [[ -n "$2" && "$2" != -* ]]; then
                OPT_GIT_EMAIL="$2"; shift 2
            else
                log_error "Error: --email (-e) requires a non-empty argument."; exit 1
            fi ;;
        -*)
            log_error "Unknown option: $1"; show_usage; exit 1 ;;
        *)
            repos+=("$1"); shift ;;
    esac
done

# If arguments were provided but they were all flags (no paths)
if [[ ${#repos[@]} -eq 0 ]]; then
    log_error "No repositories specified."
    show_usage
    exit 1
fi

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${PURPLE}--- DRY RUN MODE ACTIVATED ---${NC}"
fi

errors=0
for repo in "${repos[@]}"; do
    echo "---------------------------------------------------"
    process_repo "$repo" || ((errors++))
done

echo "---------------------------------------------------"
if [[ $errors -eq 0 ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "Dry run completed. No changes were made."
    else
        log_success "All done."
    fi
else
    log_warn "Completed with $errors error(s)."
    exit 1
fi
