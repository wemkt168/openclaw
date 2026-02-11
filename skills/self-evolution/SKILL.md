---
name: self-evolution
description: Instructions for OpenClaw (Teddy) to autonomously update, modify code, and install dependencies on the host system.
---

# Self-Evolution Skill

This skill empowers OpenClaw (Teddy) to maintain, update, and evolve its own codebase and runtime environment.

## Capabilities

1.  **Self-Update**: Pull latest changes from the repository and rebuild.
2.  **Dependency Management**: Install new npm packages or system tools.
3.  **Code Modification**: Edit source code to add new features or fix bugs.
4.  **Restart**: Restart the Gateway/Daemon to apply changes.

## Security Protocol: The "Scanner First" Rule

> [!IMPORTANT]
> **MANDATORY**: Before installing ANY new skill or running ANY external code, you MUST scan it using `skill-scanner`.

### Scanner Setup
First, ensure the scanner is installed on the host:
```bash
# Check if installed
pip show cisco-ai-skill-scanner

# Install if missing
pip install cisco-ai-skill-scanner
```

### Protocol for New Skills/Capabilities
1.  **Download/Read**: Save the potential skill code to a temporary file (e.g., `temp_skill.md`).
2.  **Scan**: Run the scanner against the file.
    ```bash
    skill-scanner scan ./temp_skill.md --use-llm
    ```
3.  **Evaluate**:
    *   **SAFE**: Proceed to install/move to `skills/` directory.
    *   **WARNING/UNSAFE**: **DELETE IMMEDIATELY**. Do not execute. Report to user.

## Workflows

### 1. Self-Update (Pull & Rebuild)

To update to the latest version of the codebase:

```bash
# 1. Pull latest changes
git pull

# 2. Install dependencies (if package.json changed)
pnpm install

# 3. Rebuild the project
pnpm build

# 4. Verify build runs correctly
pnpm check 

# 5. Restart (if successful)
# WARNING: This stops the current process. Ensure you have a way to restart or runs as a service.
pnpm openclaw gateway restart
```

### 2. Installing New Dependencies

To add a new capability that requires an npm package:

```bash
# 1. Install package
pnpm add <package-name>

# 2. Rebuild
pnpm build

# 3. Restart to load new modules
pnpm openclaw gateway restart
```

### 3. Modifying Source Code

To modify the codebase (e.g., adding a new tool or fixing a bug):

1.  **Locate**: Find the relevant file using `ls` and `grep`.
2.  **Edit**: Use the `edit` or `apply_patch` tool to modify the code.
3.  **Verify**: Run tests or build to ensure no syntax errors.
    ```bash
    pnpm test <related-test-file>
    pnpm build
    ```
4.  **Restart**: If the change affects the Gateway or Agent runtime, restart the service.

### 4. Restarting Teddy

If you need to reload configuration or apply code changes:

-   **Preferred**: `openclaw gateway restart` (if CLI is available and managing the process)
-   **Alternative**: `pkill -f openclaw-gateway` (will require external supervisor to restart it)
-   **Zeabur/Docker**: `exit 0` (container orchestration will restart the pod)

## Environment Context

-   **Project Root**: `/home/node/.openclaw/workspace` or current working directory.
-   **Package Manager**: `pnpm` is preferred, `npm` is fallback.
-   **Service Manager**: Depends on OS (systemd on Linux, launchd on macOS).

## Example: "Teddy, please update yourself"

1.  **Action**: Run `git pull`.
2.  **Check**: If new commits found, run `pnpm install && pnpm build`.
3.  **Result**: If build succeeds, announce "Update successful, restarting..." and run restart command.

## Example: "Teddy, install the 'moment' library for time handling"

1.  **Action**: Run `pnpm add moment`.
2.  **Verify**: creating a small test script to import moment.
3.  **Result**: Announce "Library installed."
