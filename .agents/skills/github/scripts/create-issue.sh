#!/bin/bash
set -euo pipefail

# Create a GitHub issue
# Usage: ./create-issue.sh "Title" "Body"

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 \"Title\" \"Body\""
    exit 1
fi

TITLE=$1
BODY=$2

echo "Creating issue: $TITLE..."
gh issue create --title "$TITLE" --body "$BODY"
