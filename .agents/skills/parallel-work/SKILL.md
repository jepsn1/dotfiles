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
- **Claiming means committing to build it.** Once you win the claim, run the
  whole flow — worktree → implement → verify → PR — without pausing to ask
  "should I start?". Work happens in an isolated worktree, so it's reversible;
  don't treat it as a hard-to-reverse action needing confirmation.
- **NEVER touch a worktree you did not create this session.** No
  `git worktree remove/prune`, `rm -rf`, `git checkout` over it, `git reset`,
  `git stash`, or `git add -A` that sweeps one in. Uncommitted work in a
  worktree is unrecoverable — git never stored it. If another worktree is in
  your way, scope your command around it; never delete it to "tidy up".
- **Claim before you read or edit code.** Lose the claim race → pick another
  issue. Never work an issue you didn't win.
- **Branch from the integration branch** (`$BASE`, see below) and PR back to
  it. Never branch from or PR into `main` unless it's an explicit release.

## Setup (every worker, once per shell)
```bash
# Integration branch: override, else develop if it exists, else the default branch
BASE="${AGENT_BASE_BRANCH:-$(git ls-remote --exit-code --heads origin develop >/dev/null 2>&1 \
  && echo develop || git symbolic-ref --short refs/remotes/origin/HEAD | sed 's@^origin/@@')}"
AGENT_ID="${AGENT_ID:-$(whoami)-$(basename "$PWD")}"   # stable, unique per agent
# Claim locks: explicit dir > shared root + owner-repo (agents as different Linux users) > this clone
CLAIMS="${AGENT_CLAIMS_DIR:-}"
if [ -z "$CLAIMS" ] && [ -n "${AGENT_CLAIMS_ROOT:-}" ]; then
  CLAIMS="$AGENT_CLAIMS_ROOT/$(git remote get-url origin | sed -E 's#\.git$##; s#.*[:/]([^/]+/[^/]+)$#\1#; s#/#-#' | tr '[:upper:]' '[:lower:]')"
fi
: "${CLAIMS:=$(cd "$(git rev-parse --git-common-dir)" && pwd)/agent-claims}"
(umask 002; mkdir -p "$CLAIMS")   # group-writable, so other users can clear stale claims
```

## Part A — Orchestrator: split a backlog into grabbable issues

**Scope: only Marcus's Jira tickets.** When slicing from a Jira board/column,
filter `assignee = marcus.klausen` — never slice other people's tickets, even
if they sit in the same column.

**Read the ticket's COMMENTS, not just the description.** Acceptance criteria
are routinely refined or superseded in Jira comments (BA/QA/backend chime in
after the description was written). Before slicing, fetch
`GET /rest/api/2/issue/<KEY>/comment` and fold every AC-bearing comment into
the issue body. Also diff the AC against what's already merged on the
integration branch — never slice from a PR description or a stale ticket
state; check the actual code.

Each issue must be finishable by one worker alone. Make them so:

- **Vertical slice, self-contained.** One issue = one deliverable, no
  cross-issue coordination to finish it.
- **Body carries everything:** link the source ticket (e.g. `LOG-1234`),
  scope + acceptance criteria, key file hints, and any dependency stated
  explicitly (`Blocked by #N`).
- **Label the queue** `agent-ready` so workers can find pickable work. Add a
  `blocked` label (and the `Blocked by #N` line) to any issue that isn't yet
  pickable; drop it when the blocker merges.
- **Label human-in-the-loop issues `HITL`.** Any issue needing a human
  decision, design review, credentials, or manual verification gets the `HITL`
  label (on top of `agent-ready` if an agent can still build it), and the body
  says exactly what the human must decide/do. Everything else is AFK. Prefer
  AFK slices — split the human part out where possible.
- **Flag file overlap.** If two issues touch the same files, say so in both —
  workers serialize those or coordinate, rather than racing conflicting PRs.

```bash
gh issue create --repo OWNER/REPO --title "LOG-1234: <summary>" \
  --label agent-ready \
  --body "$(printf 'Source: LOG-1234\n\nScope: ...\nAC: ...\nFiles: ...\nDeps: none')"
```

## Part B — Worker: find → claim → worktree → PR

**Read everything before building:** the GitHub issue body AND its comments,
and the linked Jira ticket's description AND comments
(`GET /rest/api/2/issue/<KEY>/comment`) — AC corrections often live only in a
late Jira comment. If ticket comments contradict the issue body, the comments
win; note the discrepancy on the issue.

### 1. Find unclaimed work
```bash
gh issue list --repo OWNER/REPO --label agent-ready --state open \
  --json number,title,labels
```
Skip anything labelled `blocked` or `agent:claimed`. Running unattended →
also skip `HITL`. If you do take a `HITL` issue: build up to the human step,
then stop and ask (issue comment + tell the user) — never guess the decision.
Keep the `HITL` label on the issue and mention it in the PR body.

### 2. Claim it — atomically
The claim lock lives in `$CLAIMS` (Setup) — by default the repo's **shared git
common dir**, so every worktree of this clone sees the same locks. `mkdir`
either creates the dir or fails — atomically. First agent wins; everyone else
fails and moves on. This is the source of truth for who-owns-what.

```bash
ISSUE=1234
if (umask 002; mkdir "$CLAIMS/$ISSUE") 2>/dev/null; then
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
git worktree add ../wt-log-$ISSUE -b fix/log-1234-slug "origin/$BASE"
cd ../wt-log-$ISSUE
ln -s "$OLDPWD/node_modules" node_modules   # deps are branch-independent
```

### 4. Build, verify, PR
- Implement; run typecheck, lint, tests.
- `git push -u origin fix/log-1234-slug`
- `gh pr create --repo OWNER/REPO --base "$BASE" --title "…" --body "… refs the issue"`
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
Defaults to `<user>-<cwd basename>`; override with a short fixed tag if you
like. It goes in the claim record so others can see who holds what.

## Multi-clone / multi-user note
The default lock is shared across **worktrees of one clone** (they share the
git common dir). If agents use separate clones, set `AGENT_CLAIMS_DIR` to one
fixed path per repo that every agent can write. Agents running as different
Linux users each have their own clone and home, so give them a shared group
dir, e.g. `/srv/agent-claims/OWNER-REPO` owned by group `agents`, mode 2770.
Or set `AGENT_CLAIMS_ROOT=/srv/agent-claims` once (worker users get it from
`worker/new-worker.sh`) and the `owner-repo` subdir is derived from `origin`.
