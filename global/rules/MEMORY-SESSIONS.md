# MEMORY-SESSIONS.md

Rolling summary of the last 10 substantive sessions. Older entries are removed when new ones are added. One-offs and trivial tasks are not logged.

Format: `### YYYY-MM-DD — Topic` followed by a 2–4 sentence summary of what was done and what was learned.

---

<!-- Add entries below as sessions complete -->
### 2026-05-29 — Tools for Humanity stickiness analysis
Evaluated PostHog stickiness entry points for TFH (World/Worldcoin, org 017f9d36...) as they churn off Feature Flags (~$14k/mo) but keep Product Analytics (~$14.6k, ~1.9B events/mo) per their Head of DS. Forecast MRR collapses ~$29k→$16.9k, near mono-product. Core finding: account is sliding toward "PostHog = collection pipe" (batch-exporting 2.3B events/mo OUT + CDP 100M+/mo into their own warehouse) — pipe-only relationships churn next; stickiness = win the analyze-and-act layer on events they keep, plus a commercial commit + exec sponsor above the (adversarial) Head of DS. Ran 22-agent workflow; top plays = Analysis Home (zero-instrumentation) + Experiments re-anchored on residual flag tail. CSM is Ryan McCrary, not Jake.
