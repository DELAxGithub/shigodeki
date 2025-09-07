#!/bin/bash

# Safe Branch Management Script
# Prevents "修正したのに治らない" problem by ensuring branches are fresh

set -e

SCRIPT_NAME=$(basename "$0")
MAIN_BRANCH="main"
MAX_COMMITS_BEHIND=10

usage() {
    echo "Usage: $SCRIPT_NAME <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  check                    - Check all branches for freshness"
    echo "  create <issue> <name>    - Create new branch from main"
    echo "  cleanup                  - Delete stale branches"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME check"
    echo "  $SCRIPT_NAME create 95 section-picker"
    echo "  $SCRIPT_NAME cleanup"
}

# Get the number of commits a branch is behind main
get_commits_behind() {
    local branch=$1
    if [[ "$branch" == "$MAIN_BRANCH" ]]; then
        echo 0
        return
    fi
    
    git rev-list --count "origin/$MAIN_BRANCH".."$branch" 2>/dev/null || echo "unknown"
}

# Check branch freshness
check_branches() {
    echo "🔍 Checking branch freshness (max $MAX_COMMITS_BEHIND commits behind main)..."
    echo ""
    
    # Fetch latest changes
    git fetch origin "$MAIN_BRANCH" --quiet
    
    local has_stale=false
    
    # Check all local branches
    while IFS= read -r branch; do
        # Skip main branch
        if [[ "$branch" == "$MAIN_BRANCH" ]]; then
            continue
        fi
        
        local commits_behind
        commits_behind=$(git rev-list --count "$branch"..origin/"$MAIN_BRANCH" 2>/dev/null || echo "unknown")
        
        if [[ "$commits_behind" == "unknown" ]]; then
            echo "⚠️  $branch: Cannot determine status (may not exist on remote)"
            has_stale=true
        elif [[ "$commits_behind" -gt "$MAX_COMMITS_BEHIND" ]]; then
            echo "❌ $branch: $commits_behind commits behind main (STALE)"
            has_stale=true
        elif [[ "$commits_behind" -gt 5 ]]; then
            echo "⚠️  $branch: $commits_behind commits behind main (consider updating)"
        else
            echo "✅ $branch: $commits_behind commits behind main (fresh)"
        fi
    done < <(git branch --format='%(refname:short)')
    
    echo ""
    
    if [[ "$has_stale" == true ]]; then
        echo "🚨 STALE BRANCHES DETECTED!"
        echo "Working on stale branches causes '修正したのに治らない' problems."
        echo "Run: $SCRIPT_NAME cleanup"
        echo ""
        return 1
    else
        echo "✅ All branches are fresh!"
        return 0
    fi
}

# Create new branch from main
create_branch() {
    local issue_number=$1
    local branch_suffix=$2
    
    if [[ -z "$issue_number" || -z "$branch_suffix" ]]; then
        echo "Error: Both issue number and branch name suffix are required"
        echo "Usage: $SCRIPT_NAME create <issue> <name>"
        exit 1
    fi
    
    local branch_name="feature/$issue_number-$branch_suffix"
    
    echo "🌟 Creating fresh branch: $branch_name"
    
    # Ensure we're on main and it's up to date
    git checkout "$MAIN_BRANCH"
    git fetch origin "$MAIN_BRANCH"
    git pull origin "$MAIN_BRANCH"
    
    # Create and checkout new branch
    git checkout -b "$branch_name"
    
    echo "✅ Created and switched to: $branch_name"
    echo "📍 Based on latest main commit: $(git rev-parse --short HEAD)"
}

# Clean up stale branches
cleanup_branches() {
    echo "🧹 Cleaning up stale branches..."
    echo ""
    
    # Fetch latest changes
    git fetch origin "$MAIN_BRANCH" --quiet
    
    local current_branch
    current_branch=$(git branch --show-current)
    
    local branches_to_delete=()
    
    # Identify stale branches
    while IFS= read -r branch; do
        # Skip main branch and current branch
        if [[ "$branch" == "$MAIN_BRANCH" || "$branch" == "$current_branch" ]]; then
            continue
        fi
        
        local commits_behind
        commits_behind=$(git rev-list --count "$branch"..origin/"$MAIN_BRANCH" 2>/dev/null || echo "unknown")
        
        if [[ "$commits_behind" == "unknown" ]]; then
            echo "⚠️  Skipping $branch (cannot determine status)"
        elif [[ "$commits_behind" -gt "$MAX_COMMITS_BEHIND" ]]; then
            echo "🗑️  Marking $branch for deletion ($commits_behind commits behind)"
            branches_to_delete+=("$branch")
        fi
    done < <(git branch --format='%(refname:short)')
    
    if [[ ${#branches_to_delete[@]} -eq 0 ]]; then
        echo "✅ No stale branches found"
        return 0
    fi
    
    echo ""
    echo "The following branches will be deleted:"
    printf '  - %s\n' "${branches_to_delete[@]}"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for branch in "${branches_to_delete[@]}"; do
            echo "Deleting $branch..."
            git branch -D "$branch"
        done
        echo "✅ Cleanup complete"
    else
        echo "❌ Cleanup cancelled"
    fi
}

# Main command dispatch
case "${1:-}" in
    check)
        check_branches
        ;;
    create)
        create_branch "$2" "$3"
        ;;
    cleanup)
        cleanup_branches
        ;;
    *)
        usage
        exit 1
        ;;
esac