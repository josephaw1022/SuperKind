#!/bin/bash
set -euo pipefail

# Update a GitHub issue
# Usage: ./update-issue.sh <number> \"Title\" \"Body\"

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <number> \"Title\" \"Body\""
    exit 1
fi

ISSUE_NUMBER=$1
TITLE=$2
BODY=$3

echo "Updating issue #$ISSUE_NUMBER: $TITLE..."
gh issue edit "$ISSUE_NUMBER" --title "$TITLE" --body "$BODY"
