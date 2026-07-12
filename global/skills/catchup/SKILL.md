---
name: catchup
description: Use when returning from PTO/OOO or otherwise behind on Slack, and you need to reconstruct what happened on your accounts while away - "what did I miss", "go through slack from last week", "pull out tasks/followups/events". For a Customer Success book (per-account posthog-<slug> channels + support tickets + billing spikes).
---

# Catch-up

## Overview

Reconstruct everything a CSM missed while out: what needs action, what a standby teammate already handled, new accounts, and billing spikes. Ends by landing action items in the Obsidian Inbox. Signal over noise: most inbound gets covered while you're out, so the job is separating still-open from already-handled.

## When to use

- Returning from PTO/OOO, or catching up after days away from Slack.
- "What did I miss", "go through Slack from last week", "pull tasks / followups / events".

Not for: a live single-account question (answer from hogpilot + live surfaces directly).

## Inputs — ask once, then run

Two things gate every search, so pin them before spending tool calls:
1. **Date range** — default to the OOO week; confirm exact dates (today's weekday matters).
2. **Scope** — `things touching me` (DMs + @mentions + my threads) / `+ my account & CS channels` (default for a real catch-up) / `everything`.

Convert the range to `after:YYYY-MM-DD before:YYYY-MM-DD` with one day of padding each side (Slack date modifiers are edge-sensitive).

## Identity + book

- Slack user id: `slack_search_users` output header states `Current logged in user's Slack user_id is <id>`. Grab it. Email: jake.s@posthog.com.
- Account book + org_ids: hogpilot (`hp` CLI). Customer channels are `posthog-<slug>`. Channel names drift from slugs (tools-for-humanity = `posthog-toolsforhumanity`, luxury-presence may differ) — confirm with `slack_search_channels` when a guess returns nothing.

## Passes (order matters; parallelize within a pass)

1. **Mentions** — `slack_search_public_and_private` q=`<@USERID> after:D before:D`, sort=timestamp asc. Page the whole window (20/page; the tail days get cut off if you stop at page 1).
2. **DMs** — q=`to:me after:D before:D`.
3. **Classify open vs handled** — for each customer thread that has replies, `slack_read_thread`. If a standby teammate already resolved it, it's FYI, not your task.
4. **Coverage & new accounts** — find your OOO post in `#team-customer-success` and any "account movement" / reassignment posts. Accounts newly assigned to you are the highest-value output.
5. **Support tickets** — read `#support-managed-customers` (C05MUMZLC13) across the window; keep rows where `CSM: <you>`. The alert bot's text is in blocks — read the channel, don't trust the search snippet (it comes back empty). Tickets with no visible teammate response = verify they were picked up.
6. **Stakeholder changes** — same channel logs `joined`/`left` for `posthog-<account>` channels. A champion leaving a big account is a churn signal; a new stakeholder joining tracks with expansion/meetings.
7. **Customer-channel sweep** — fan out ONE read-only subagent (general-purpose) across the whole book to return only: customer messages with no reply / no teammate tagged, or notable signals (blocker, frustration, expansion, pricing, renewal, churn/migration). Keeps main context clean. Give it the account list, your user id, the window, and the accounts you already have full context on so it only reports NEW items.
8. **Billing spikes** — not in Slack; query the warehouse (below).

## Billing spikes query

Table `prod_postgres_billing_spike` (Postgres source), joined to `billing_customers_with_owner` to filter to your book. Run via PostHog MCP `execute-sql` (project 2).

```sql
SELECT o.name AS account, s.date AS spike_date, s.usage_key AS product,
       round(s.z_score, 1) AS z_score, s.spike_value
FROM prod_postgres_billing_spike s
INNER JOIN (
  SELECT DISTINCT id, name, current_owner_email
  FROM billing_customers_with_owner
  WHERE current_owner_email = 'jake.s@posthog.com'
) o ON s.customer_id = o.id
WHERE s.date >= 'START' AND s.date <= 'END'
ORDER BY abs(s.z_score) DESC
LIMIT 100
```

`z_score` = deviation magnitude; a high z on a low-baseline account is a sharp relative jump but small absolute (note both). Spike is bidirectional (down = churn/outage). `billing_customers_with_owner` also carries `current_owner_slack_id`, `vitally_segment`, `organization_id` if you need another filter.

## Output

Chat digest, grouped and ordered by what needs action:
- **On you now** — open action items.
- **New accounts** — additions to your book + any context/intel (flag "keep quiet" items).
- **Weigh in** — strategic threads where you're co-owner.
- **Handled while out (FYI)** — covered, no action.
- **Personal** — comp/HR etc. Keep out of the Inbox unless asked (sensitive).

Then, on request, append to Obsidian `Inbox.md` under `## Untriaged` (mode: append, never overwrite):
- action items → `- [ ] <text> [tier:: now|next]`
- FYI/handled + billing spikes → `- [ ] <text> [label:: follow-up]`

The vault's Obsidian agent triages `Untriaged` into PARA from there.

## Common mistakes

- Treating a replied-to thread as still yours — a coverage teammate likely closed it. Read the thread.
- Trusting search snippets for bot alerts — they render empty; read the channel/blocks.
- Stopping at mention-search page 1 — the last days of the window get truncated.
- Guessing customer channel names — confirm with `slack_search_channels`.
- Looking for billing spikes in Slack — they live in the warehouse table.
- Never cross-reference one customer's data into another's output; keep internal CS tables out of customer-scoped artifacts.
