---
name: git
description: Common Git operations for branch management, syncing with main, and viewing differences. Use when you need to checkout branches, create new ones, pull latest changes, or check git status and diffs.
---

# Git Skill

This skill provides a set of scripts for common Git workflows.

## Workflows

### Syncing with Main
To checkout the `main` branch and pull the latest changes, use:
```bash
.agents/skills/git/scripts/sync-main.sh
```

### Updating the Current Branch
To pull the latest changes for the current branch:
```bash
.agents/skills/git/scripts/update.sh
```

### Creating a New Branch
To create and checkout a new branch:
```bash
.agents/skills/git/scripts/create-branch.sh <branch-name>
```

### Checking Out a Branch
To checkout an existing branch:
```bash
.agents/skills/git/scripts/checkout.sh <branch-name>
```

### Viewing Differences
To see the changes in the current branch:
```bash
.agents/skills/git/scripts/diff.sh
```

### Checking Status
To see the current status of the repository:
```bash
.agents/skills/git/scripts/status.sh
```
