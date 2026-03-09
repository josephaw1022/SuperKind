#!/bin/bash
set -euo pipefail

# View a GitHub pull request
# Usage: ./view-pr.sh <pr-number>

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <pr-number>"
    exit 1
fi

PR_ID=$1

gh pr view "$PR_ID"
