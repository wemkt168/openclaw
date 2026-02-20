---
name: github_issue_creator
description: "Automatically creates a timestamped GitHub issue in the wemkt168/openclaw repository when Teddy needs human assistance, a new tool, or permission updates."
---

# GitHub Issue Creator

When you (Teddy) encounter an error, lack a tool, or need a code change in the repository, you can auto-create a tracking issue. This tool creates a local draft to prevent duplicate issues, generates a timestamp-based sequence ID, and submits the issue to GitHub using the `GITHUB_TOKEN`.

## Usage

To create a new GitHub issue, execute the Node.js script located in this folder:

```bash
node ./teddy-core-config/skills/github_issue_creator/create_issue.mjs "Short description of the problem" "Detailed body explaining what happened and what follows."
```

Note:
- The script automatically prepends the `[YYYYMMDD]` or `[YYYYMMDD-X]` tag. Do NOT manually add the timestamp to your title argument.
- Always provide a concise first argument (the title) and a detailed second argument (the body).
