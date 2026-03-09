#!/bin/bash
set -euo pipefail

# View a GitHub issue
# Usage: ./view-issue.sh <issue-number>

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <issue-number>"
    exit 1
fi

ISSUE_ID=$1

gh issue view "$ISSUE_ID"
