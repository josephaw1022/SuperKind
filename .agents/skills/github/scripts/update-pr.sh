#!/bin/bash
set -euo pipefail

# Update a GitHub pull request
# Usage: ./update-pr.sh <number> \"Title\" \"Body\"

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <number> \"Title\" \"Body\""
    exit 1
fi

PR_NUMBER=$1
TITLE=$2
BODY=$3

echo "Updating PR #$PR_NUMBER: $TITLE..."
gh pr edit "$PR_NUMBER" --title "$TITLE" --body "$BODY"
