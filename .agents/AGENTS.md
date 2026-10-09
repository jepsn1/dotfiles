- In all interactions and commit messages, be extremely concise and sacrifice grammer for the sake of concision.
- Concise ≠ cryptic: I don't have your context (files read, commands run, your reasoning). Explain from the top — what the thing is, what you found/did, why it matters — so it makes sense to someone who wasn't watching.

## Plans

- At the end of each plan, give me a list of unresolved questions to answer, if any. Make the questions extremely concise. Sacrifice grammer for the sake of concision.

## PRs

- When creating a PR, check conversation context for related GitHub issues and link them with `Closes #N` in the PR body.

## Parallel work

- A GitHub issue labelled `agent-ready` = parallel work. Invoke the `parallel-work` skill (Worker role): claim the issue atomically BEFORE reading/editing code, build it in your OWN worktree, open a PR. Never work an issue you didn't win the claim on; never touch a worktree you didn't create.

## Agent config (this machine)

- Shared for all users (marcus, work1, work2): ONE checkout at `/srv/dotfiles` (`~/dotfiles` = symlink). This file, skills, statusline live in `.agents/`; shared Claude settings in `.agents/managed-settings.json` (→ `/etc/claude-code/managed-settings.json`).
- Change shared config there, once — never per-user copies, jq edits of `~/.claude/settings.json`, or per-worker pull/install steps.
- Only marcus can write it. As a worker: don't try; propose the change to the user instead.
