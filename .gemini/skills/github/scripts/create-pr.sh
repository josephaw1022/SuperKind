#!/bin/bash
set -euo pipefail

# Create a GitHub pull request
# Usage: ./create-pr.sh "Title" "Body"

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 "Title" "Body""
    exit 1
fi

TITLE=$1
BODY=$2

echo "Creating PR: $TITLE..."
gh pr create --title "$TITLE" --body "$BODY" --base main
