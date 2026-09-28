---
name: exec-update
description: Draft the short monthly Danish status email about LogBuy Portalen (and the LogBuy app) for the manager and CEO — turns git history and release notes into business outcomes (member activity, client onboarding/retention, partner value, cost saved, risk removed), with placeholders for missing numbers and an "Udeladt og hvorfor" list. Use when asked for a monthly update, exec update, status mail to the CEO/manager, "månedsopdatering", or "what did we ship this month" in business terms.
---

# Exec update — monthly status email (Danish)

Readers: a manager and a non-technical CEO. They care about client retention,
member activity, onboarding time, partner value, customer wins, cost saved and
risk removed. The mail must be readable in 30 seconds by someone who has never
seen the codebase.

LogBuy context: companies/organisations buy access for their members, who use
the portal to find discounts at partner merchants. Purchases happen at the
partner, so our value shows as member usage, clicks to partners, client
onboarding/retention and partner data — not direct revenue.

## Output

Return exactly three blocks, in this order:

1. The email (Danish, format below)
2. `Pladsholdere` — every `[TAL: …]` / `[BEKRÆFT: …]` from the mail, one per line, with where the number could come from if known
3. `Udeladt og hvorfor` — one line per dropped theme: what it was (in plain words) + why dropped. Keeps the user able to override the judgement.

Don't send anything. It's a draft.

## Email format (strict)

Max ~120 words total, Danish, plain text.

```
Emne: LogBuy Portalen – opdatering [måned år]

[Én linje: hvad der er leveret eller ændret denne måned, i forretningstermer.]

- [Effekt, med tal hvor det findes]
- [Effekt]
- [Evt. tredje effekt]

[Én linje: hvad der kommer næste gang, og hvorfor det betyder noget.]

[Kun i første mail:] Sig til, hvis I gerne vil have sådan en kort status hver måned.
```

- Greeting/sign-off: a bare "Hej [navn]," and the user's first name are fine; nothing else.
- No headings, no technical terms, no links to Jira/GitHub, no PR/ticket numbers, never "vi har refaktoreret X".
- Tone: plain, confident, no hype, no superlatives, no exclamation marks.
- No anglicisms where a Danish word exists: udgivelse (not release), funktion (not feature), måling (not tracking), fejl (not bug), lanceret/sat i drift (not deployed/shipped). "App", "onboarding", "support", "login" are accepted Danish usage.
- **Portal + app:** when the mobile app repo (or app work in the portal repo) is in scope, add it as a second short part of the *same* mail — one lead-in line ("Appen: …") plus at most two bullets. Never a second email. Both parts share the ~120-word cap; cut the portal part to make room.

## Translation rules — technical → business

For every theme, ask in order:

1. **Who can now do what they couldn't before?** — a member, a client admin, a partner, a salesperson, support.
2. **What stopped going wrong?** — incidents, manual work, support tickets, lost logins, duplicate payments, security exposure.
3. **What does this enable next?** — e.g. groundwork for the mobile app, data we can now sell/show to partners.

If none of the three has a business-visible answer, drop it (→ Udeladt). That
includes refactors, dependency bumps, CI, test coverage, dev tooling, docs,
pure visual polish — **unless** it removed a concrete risk or cost; then say
the risk/cost, not the work ("sikkerhedshuller lukket", not "opdaterede Next.js").

Honesty rules:

- **Never invent metrics.** If a number would strengthen a claim but isn't in the code, commits or PR bodies, insert a placeholder: `[TAL: aktive medlemmer siden marts]`. Use `[BEKRÆFT: …]` for facts you couldn't verify (rollout state, dates).
- **Never claim visibility that doesn't exist.** Internal analytics ≠ "partnere kan se". If we can now *measure* something, say "vi kan nu måle …", not that a partner/client can see it.
- **Delivered = live for users.** Only work that reached production in the period counts as "leveret". Merged-but-unreleased work, and anything behind a feature flag that's off, goes in the "næste gang" line or Udeladt — never as delivered. Same for app work not yet in users' hands (TestFlight, CI, signing): groundwork, not an outcome.
- Group by theme, not by commit/PR. Five PRs about one feature = one line.

Typical LogBuy metrics to placeholder: aktive medlemmer, klik videre til
partnere, indløste rabatter, onboarding-tid pr. kunde, supporthenvendelser,
antal kunder/organisationer på portalen, partnere med adgang til data,
login-fejl, sidehastighed.

## Examples

| Dårligt | Godt |
|---|---|
| Migreret auth-service til nyt token-flow | Medlemmer forbliver logget ind på tværs af enheder – den hyppigste supporthenvendelse er væk |
| Ny partner-API endpoint | Partnere kan nu selv se, hvor mange medlemmer der har set deres tilbud – det gør det lettere for salg at forhandle bedre rabatter |
| Tilføjet Idempotency-Key på beginPayment | Medlemmer kan ikke længere komme til at betale to gange for det samme gavekort |
| Konverteringstracking med surface-attribution | Vi kan nu måle, hvilke dele af portalen der sender medlemmer videre til partnerne – [TAL: klik videre til partnere i september] |
| Error ID i alle fejlbeskeder, søgbart i Sentry | Når et medlem skriver til support om en fejl, kan vi nu finde præcis den fejl med det samme |
| Bumpede sårbare pakker, SSRF-guard | Kendte sikkerhedshuller er lukket |
| Capacitor-shell med native tab bar | Den nye app bygger direkte på portalen, så nye funktioner kommer i appen og på nettet samtidig |

## Process

1. **Period.** If the user gave a range (`2026-09`, `v2026.08.13..HEAD`, two dates), use it. Otherwise: since the last release tag (`git tag --sort=-creatordate | head`), or the last 30 days if there are no tags. **If the last tag is younger than ~3 weeks** (weekly releases), a tag-based range is too short for a monthly mail — use the calendar month (or the previous month if we're in its first days). State the chosen period in one line above the draft.
2. **Sources, best first:**
   - Release PR bodies merged to the production branch in the period (e.g. `gh pr list --base main --state merged --search "Release in:title merged:YYYY-MM-DD..YYYY-MM-DD" --json number,title,mergedAt,body`). They're already grouped into Features/Fixes/Chore and often carry QA notes explaining user impact.
   - Otherwise `git log <range> --no-merges --format='%h %ad %s' --date=short` plus PR titles/bodies (`gh pr list --state merged --search "merged:…" --json number,title,body`).
   - Merged-but-unreleased work on the integration branch (e.g. `git log <last-tag>..origin/develop --no-merges`) → candidates for "næste gang" only.
   - Mobile app repo (e.g. `~/dev/logbuy-mobile`) if present: `git log --since … --no-merges`.
3. **Understand, don't summarise diffs.** Read changed files only when a title/body doesn't make clear what a member/admin/partner experiences. Check feature-flag state before calling something live.
4. **Group by theme**, apply the translation rules, pick the 2–3 strongest effects for the bullets. Prefer effects the CEO's list names: retention, member activity, onboarding time, partner value, customer wins, cost saved, risk removed.
5. **Draft** the email in the format above; count words.
6. Add `Pladsholdere` and `Udeladt og hvorfor` below it.
7. Ask whether this is the first mail (for the optional closing line) only if unclear — default to including it and note that in Udeladt.
