#!/bin/bash

# Safe Branch Management Script for Shigodeki
# Helps prevent outdated branches from causing "fixes not working" issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if branch is up to date with main
check_branch_freshness() {
    local branch_name="$1"
    local main_commit=$(git rev-parse main)
    local merge_base=$(git merge-base main "$branch_name")
    local commits_behind=$(git rev-list --count "$merge_base..main")
    
    if [ "$commits_behind" -gt 10 ]; then
        echo -e "${RED}⚠️  Warning: Branch '$branch_name' is $commits_behind commits behind main${NC}"
        echo -e "${YELLOW}   Consider recreating this branch from current main${NC}"
        return 1
    elif [ "$commits_behind" -gt 5 ]; then
        echo -e "${YELLOW}⚠️  Branch '$branch_name' is $commits_behind commits behind main${NC}"
        return 2
    else
        echo -e "${GREEN}✅ Branch '$branch_name' is up to date (only $commits_behind commits behind)${NC}"
        return 0
    fi
}

# Function to create a fresh branch from main
create_fresh_branch() {
    local issue_number="$1"
    local description="$2"
    
    if [ -z "$issue_number" ]; then
        echo "Usage: create_fresh_branch <issue_number> [description]"
        return 1
    fi
    
    local branch_name="fix/issue-${issue_number}"
    if [ -n "$description" ]; then
        branch_name="fix/issue-${issue_number}-${description}"
    fi
    
    echo -e "${GREEN}Creating fresh branch '$branch_name' from current main...${NC}"
    git checkout main
    git pull origin main
    git checkout -b "$branch_name"
    
    echo -e "${GREEN}✅ Fresh branch '$branch_name' created successfully${NC}"
}

# Function to check all fix branches
check_all_branches() {
    echo -e "${GREEN}Checking all fix branches for freshness...${NC}"
    echo ""
    
    local outdated_branches=()
    
    for branch in $(git branch --list 'fix/*' | sed 's/^[* ] //'); do
        if ! check_branch_freshness "$branch"; then
            if [ $? -eq 1 ]; then  # Severely outdated
                outdated_branches+=("$branch")
            fi
        fi
        echo ""
    done
    
    if [ ${#outdated_branches[@]} -gt 0 ]; then
        echo -e "${RED}🚨 Severely outdated branches detected:${NC}"
        for branch in "${outdated_branches[@]}"; do
            echo -e "${RED}   - $branch${NC}"
        done
        echo ""
        echo -e "${YELLOW}These branches may cause 'fixes not working' issues.${NC}"
        echo -e "${YELLOW}Consider recreating them from current main.${NC}"
        return 1
    else
        echo -e "${GREEN}✅ All branches are reasonably up to date${NC}"
        return 0
    fi
}

# Main command handling
case "$1" in
    "check")
        check_all_branches
        ;;
    "create")
        create_fresh_branch "$2" "$3"
        ;;
    *)
        echo "Safe Branch Management for Shigodeki"
        echo ""
        echo "Usage:"
        echo "  $0 check                    # Check all fix branches for freshness"
        echo "  $0 create <issue> [desc]    # Create fresh branch from main"
        echo ""
        echo "Examples:"
        echo "  $0 check"
        echo "  $0 create 94"
        echo "  $0 create 95 section-picker"
        ;;
esac