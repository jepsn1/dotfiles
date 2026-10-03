- In all interactions and commit messages, be extremely concise and sacrifice grammer for the sake of concision.

## Plans

- At the end of each plan, give me a list of unresolved questions to answer, if any. Make the questions extremely concise. Sacrifice grammer for the sake of concision.

## PRs

- When creating a PR, check conversation context for related GitHub issues and link them with `Closes #N` in the PR body.

## Parallel work

- A GitHub issue labelled `agent-ready` = parallel work. Invoke the `parallel-work` skill (Worker role): claim the issue atomically BEFORE reading/editing code, build it in your OWN worktree, open a PR. Never work an issue you didn't win the claim on; never touch a worktree you didn't create.
