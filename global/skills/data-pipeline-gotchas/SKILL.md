---
name: data-pipeline-gotchas
description: Mechanism gotchas for PostgREST/Supabase writes and for pipelines whose input is LLM output - upserts resolving on the wrong key, CHECK constraints that fail a whole batch, non-deterministic extraction, salvage and pruning order, and test isolation that covers the socket rather than only the filesystem. Load before writing a PostgREST upsert, adding a constraint to a column an LLM populates, or building anything that parses model output into rows.
when_to_use: Writing a PostgREST or Supabase upsert, choosing between a CHECK constraint and free text, parsing LLM output into a table, debugging duplicate or stale rows from a re-run, or isolating a test that executes a credential-carrying script.
---

# Data pipeline gotchas

Each of these cost a wrong first attempt.

## PostgREST / Supabase

**`Prefer: resolution=merge-duplicates` upserts on the PRIMARY KEY, not on your unique constraint.** If the PK is an auto-generated uuid never present in the payload, a re-run INSERTs duplicates and then trips the unique constraint. You must pass `?on_conflict=<cols>` on the URL. This stops being latent the moment anything re-writes an existing row. `session-summary.sh` carried the bug for months, because every live session_id is new; the first backfill of an existing row hit `23505` on all 34 rows. Fixed 2026-08-27 with `?on_conflict=session_id`.

PostgREST writes only the columns in the payload, so a `created_at` default does not update on re-upsert - it reflects first capture.

**`curl -sS` exits 0 on a 4xx, so `curl ... && echo "wrote row"` logs a success on every rejected write.** That is how the upsert bug above stayed invisible: the log said `wrote <id>` while PostgREST returned `23505` on the same line. Read the status code instead - `-w '\n%{http_code}'`, then branch on `200|201|204`. Use `-f` only if you also want the body discarded.

**An unknown key rejects the WHOLE row, so added columns share fate with the ones that already worked.** PostgREST answers `400 PGRST204 Could not find the '<key>' column ... in the schema cache` and writes nothing - not a partial row. So enriching an existing writer couples the new payload to the old one: if the schema ever lags the code, you lose the original record too, not just the new fields. Verified 2026-08-28 on `claude_sessions`, where the new token columns would otherwise have re-created the `(summary unavailable)` outage. Fix: build the base payload separately, post `base + extra`, and on a `400` retry once with `base` alone, logging which path ran. A schema mismatch then degrades the row instead of dropping it. Apply the migration before the writer ships, and note that `ADD COLUMN IF NOT EXISTS` makes the migration safe to re-run but does nothing for a writer that arrives first.

Prefer an unconstrained text column over a CHECK constraint for any vocabulary an LLM populates. A check rejects an unseen value and fails the whole batch; keep the vocabulary in the prompt so it fails open.

## LLM output handling

**Always validate LLM output against a deterministic vocabulary.** `gpt-oss-120b` returned a token with a **zero-width space inside the word** - invisible in a diff, fatal to a vocab check, and something no human review would catch. Repair deterministically: strip zero-width characters, complete a truncated value only when it uniquely prefixes one vocabulary member, else fall back to the original.

**Extraction is non-deterministic on identical input.** Same transcript, same prompt: 10 items, then 8, then 8. Two consequences:

- An upsert alone leaves the earlier longer run's high-seq rows, mixing two extractions in one record. Prune the tail *after* the upsert - a failed prune leaves a recoverable stale tail, while pruning first risks deleting with nothing to replace it.
- Fence-stripping is not enough salvage. On parse failure, take the outermost `[`..`]` span and revalidate (this recovers an array wrapped in prose), and only then give up - dumping the **entire** raw output to a file. A 500-char log snippet cannot diagnose an intermittent fault.

**Compress, do not explode.** Splitting a dense write-up into atomic rows lost the conclusion, invented vocabulary, and made the rendered context *worse* for 8x the rows. Compressive framing - one headline plus an audit phrase naming what was dropped - hit -91% chars with the conclusion intact. When rewriting typed rows, pass the existing type in and say keep it unless compression genuinely changes it.

**Thresholds must be measured against the real corpora, not chosen from a prompt's target.** A gate set at a prompt's stated target flagged rounding errors and produced an unreviewable queue. A warning that fires on healthy work gets ignored, which is worse than no warning.

## Test isolation

**Isolation must cover the socket, not just the filesystem.** Once a credential is baked in for zero-setup operation, any test that executes a shipped hook egresses to production. A disk-only isolation fixture will not stop it, and the leak is invisible until you query production.

Verify that class of fix **empirically** - re-run the offending test, then query for writes after the cutoff.
