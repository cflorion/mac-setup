---
name: commit-to-main
description: Git workflow for this repo — never open a pull request; commit every change directly on main and push at the end of the task, without being asked. Use whenever you change files in cflorion/mac-setup.
---

# Commit to main, no PR

The owner does not want pull requests in this repo.

- Commit every change directly on `main`, in small descriptive commits (`feat(scope): …`, `fix(scope): …`).
- At the end of the task, push: `git push origin main`. Do it without waiting to be asked.
- Never create a feature branch or open a PR. If the work ended up on another branch (for example one imposed by the session), integrate it into `main` (fast-forward or cherry-pick), push `main`, and delete the stray branch.
- If `origin/main` moved meanwhile, `git pull --rebase origin main` before pushing.
