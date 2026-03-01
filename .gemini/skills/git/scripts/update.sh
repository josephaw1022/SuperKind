#!/bin/bash
set -euo pipefail

# Pull latest changes for the current branch
# Usage: ./update.sh

echo "Pulling latest changes..."
git pull
