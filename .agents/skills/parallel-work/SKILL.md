---
name: parallel-work
description: Coordinate several agents working the same repo at once — split a backlog into independently-grabbable GitHub issues, then have each worker atomically claim one issue, build it in its own git worktree, and open a PR, without ever colliding on the same task or touching another agent's worktree. Use when delegating a backlog across multiple agents, fanning work out, or when an agent must pick up unclaimed work safely.
---

# Parallel agent work — issues + worktrees + a claim lock

Two roles:
- **Orchestrator** splits work into issues and hands the queue to workers.
- **Worker** claims ONE issue, builds it in its OWN worktree, opens a PR.

The hard problem is collisions: two agents grabbing the same task, or one
agent stomping another's uncommitted work. Both are solved below — an atomic
filesystem claim lock, and an absolute worktree-isolation rule.

## Golden rules (violating these corrupts other agents' work)

- **One agent = one issue = one worktree = one branch = one PR.**
- **NEVER touch a worktree you did not create this session.** No
  `git worktree remove/prune`, `rm -rf`, `git checkout` over it, `git reset`,
  `git stash`, or `git add -A` that sweeps one in. Uncommitted work in a
  worktree is unrecoverable — git never stored it. If another worktree is in
  your way, scope your command around it; never delete it to "tidy up".
- **Claim before you read or edit code.** Lose the claim race → pick another
  issue. Never work an issue you didn't win.
- **Branch from the integration branch** (here: `develop`) and PR back to it.
  Never branch from or PR into `main` unless it's an explicit release.

## Part A — Orchestrator: split a backlog into grabbable issues

Each issue must be finishable by one worker alone. Make them so:

- **Vertical slice, self-contained.** One issue = one deliverable, no
  cross-issue coordination to finish it.
- **Body carries everything:** link the source ticket (e.g. `LOG-1234`),
  scope + acceptance criteria, key file hints, and any dependency stated
  explicitly (`Blocked by #N`).
- **Label the queue** `agent-ready` so workers can find pickable work. Add a
  `blocked` label (and the `Blocked by #N` line) to any issue that isn't yet
  pickable; drop it when the blocker merges.
- **Flag file overlap.** If two issues touch the same files, say so in both —
  workers serialize those or coordinate, rather than racing conflicting PRs.

```bash
gh issue create --repo OWNER/REPO --title "LOG-1234: <summary>" \
  --label agent-ready \
  --body "$(printf 'Source: LOG-1234\n\nScope: ...\nAC: ...\nFiles: ...\nDeps: none')"
```

## Part B — Worker: find → claim → worktree → PR

### 1. Find unclaimed work
```bash
gh issue list --repo OWNER/REPO --label agent-ready --state open \
  --json number,title,labels
```
Skip anything labelled `blocked` or `agent:claimed`.

### 2. Claim it — atomically
The claim lock lives in the repo's **shared git common dir**, so every worktree
of this clone sees the same locks. `mkdir` either creates the dir or fails —
atomically. First agent wins; everyone else fails and moves on. This is the
source of truth for who-owns-what.

```bash
ISSUE=1234
AGENT_ID="${AGENT_ID:-agent-$$}"            # stable, unique per agent
CLAIMS="$(cd "$(git rev-parse --git-common-dir)" && pwd)/agent-claims"
mkdir -p "$CLAIMS"

if mkdir "$CLAIMS/$ISSUE" 2>/dev/null; then
  printf 'owner=%s\nbranch=fix/log-1234-slug\nat=%s\n' \
    "$AGENT_ID" "$(date -u +%FT%TZ)" > "$CLAIMS/$ISSUE/claim"
  echo "claimed $ISSUE"
else
  echo "already claimed — pick another"; exit 0
fi
```
Then mirror it for humans / other machines (best-effort — the lock, not the
label, is authoritative):
```bash
gh issue edit $ISSUE --repo OWNER/REPO --add-label "agent:claimed"
gh issue comment $ISSUE --repo OWNER/REPO --body "Claimed by $AGENT_ID."
```

### 3. Make YOUR worktree (never reuse another agent's)
```bash
git worktree add ../wt-log-$ISSUE -b fix/log-1234-slug origin/develop
cd ../wt-log-$ISSUE
ln -s "$OLDPWD/node_modules" node_modules   # deps are branch-independent
```

### 4. Build, verify, PR
- Implement; run typecheck, lint, tests.
- `git push -u origin fix/log-1234-slug`
- `gh pr create --repo OWNER/REPO --base develop --title "…" --body "… refs the issue"`
- On the issue: `gh issue edit $ISSUE --remove-label agent:claimed --add-label agent:in-review`
  and comment the PR link.

### 5. Done / abandon
- **Done:** leave the claim dir in place — it marks the issue handled; the PR +
  `agent:in-review` label carry the state.
- **Abandon:** `rm -rf "$CLAIMS/$ISSUE"`, remove your `agent:claimed`
  label/comment, and if you created a throwaway worktree with **no commits**,
  remove **only your own** worktree.

## Stale claims
A claim with `at=` older than ~2h, no open PR for its branch, and the issue
still open may be reclaimed. Check `gh pr list --search <branch>` first. When
unsure, ask a human — never stomp a live claim.

## AGENT_ID
Pick something stable and unique for your session (worktree basename, or a
short fixed tag). It goes in the claim record so others can see who holds what.

## Multi-clone note
The lock is shared across **worktrees of one clone** (they share the git common
dir). If agents use separate clones on the same machine, point `CLAIMS` at a
fixed shared path instead, e.g. `~/.cache/agent-claims/OWNER-REPO`.
