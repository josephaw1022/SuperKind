---
name: github
description: Interact with GitHub for issue and PR management. Use for creating/viewing/listing issues and pull requests.
---

# GitHub Skill

This skill provides procedural guidance and tools for interacting with GitHub repositories using the `gh` CLI.

## Workflow

When a user asks to manage issues or pull requests, use the provided scripts in the `scripts/` directory.

### Issues

- **Create**: `scripts/create-issue.sh "Title" "Body"`
- **Update**: `scripts/update-issue.sh <number> "Title" "Body"`
- **View Details**: `scripts/view-issue.sh <number>`
- **List All**: `scripts/list-issues.sh`

### Pull Requests

- **Create**: `scripts/create-pr.sh "Title" "Body"`
- **Update**: `scripts/update-pr.sh <number> "Title" "Body"`
- **View Details**: `scripts/view-pr.sh <number>`
- **List All**: `scripts/list-prs.sh`

## Guidelines

- **LLM-friendly Output**: All scripts are designed to output clear, concise information.
- **Title and Body**: When creating issues or PRs, ensure the title is concise and the body provides sufficient context.
- **PR Base**: The `create-pr.sh` script defaults to the `main` branch as the base.
