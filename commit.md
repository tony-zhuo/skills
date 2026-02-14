# Git Commit Skill

## Description
Commit current changes with a clean commit message (no Claude attribution).

## Instructions

When invoked, follow these steps:

1. **Check for changes:**
   ```bash
   git status
   git diff --staged
   git diff
   ```

2. **Stage all changes (if not already staged):**
    - Ask user if they want to stage all changes, or let them specify files

3. **Generate commit message:**
    - Analyze the changes and create a concise, meaningful commit message
    - Follow conventional commit format if the project uses it (e.g., `feat:`, `fix:`, `refactor:`, `docs:`, `test:`)
    - Focus on the "why" rather than the "what"
    - Keep it to 1-2 sentences maximum

4. **Commit format:**
    - **DO NOT** add any Claude attribution
    - **DO NOT** add "Generated with Claude Code" footer
    - **DO NOT** add "Co-Authored-By: Claude"
    - Just a clean, simple commit message

5. **Execute commit:**
   ```bash
   git add . && git commit -m "your message here"
   ```

6. **Confirm success:**
    - Show the commit hash and message
    - Run `git status` to confirm working directory is clean

## Example Output

```
feat: implement invitation code registration feature

✓ Committed: abc1234
```