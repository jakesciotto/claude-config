---
name: causal-critiquer
description: Use when a causal or statistical claim is about to be shipped or shared - a finding that X caused Y, a before/after comparison, an attribution of a usage/revenue/metric change, an experiment readout - or when asked to review, validate, critique, or sanity-check an analysis. Trigger on drafts containing "caused", "drove", "led to", "because of", "resulted in", "X% lift", or a spike/drop attributed to an event.
---

# Causal Critiquer

## Overview

An analyst cannot review their own causal claim. They already believe it, and every check they design is one their claim survives.

This skill separates the roles. Mechanical checks run first with no opinion. A reviewer with a separate context then locks a verdict from the evidence alone, and only afterward reads how the analysis was produced.

**The verdict is locked before the reviewer sees the analyst's reasoning.** Reading the story first grades the story.

## When to Use

- Any claim that an event caused a change in a metric
- Before/after comparisons, with or without a control
- Attribution of a spike, drop, churn signal, or cost change
- Reviewing someone else's analysis on request

**Not for:** descriptive reporting with no causal verb, forecasts, or claims already framed as correlation with no action attached.

## Stage 1 - Mechanical checks

Read the artifact. Answer each yes/no. No interpretation, no scoring.

| # | Check |
|---|---|
| 1 | Estimand named: what quantity, for which units, over what window |
| 2 | Counterfactual stated: what would have happened absent the cause |
| 3 | Comparison basis identified: control group, pre-period, donor pool, or explicitly **none** |
| 4 | Window boundaries stated with the reason they were chosen, and a holdout period named |
| 5 | Post-period runs to the present, not truncated at the effect |
| 6 | Claim verb matches design strength ("caused" vs "coincided with") |
| 7 | Effect size carries uncertainty, not just direction |
| 8 | Headline figure reconciles with the underlying series it is computed from |
| 9 | Denominator stated: rate vs raw count, and what normalizes it |
| 10 | Measurement artifacts ruled out: billing-period boundaries, retries, backfills, cap enforcement, or a change to the instrument itself |

**Any NO makes Approve unavailable.** Record which failed. Do not argue with the result here.

Every check must be satisfiable by a written artifact. A NO that no artifact could ever turn into a YES is a defect in the check, not a finding against the analysis - fix the wording rather than recording the failure. APPROVE has to stay reachable, or the verdict has two states and the reviewer is just a pessimist.

## Stage 2 - Locked verdict (fresh reviewer)

Dispatch one subagent. Give it: the artifact, the stage-1 table, and the relevant pack below. **Do not give it your reasoning, your narrative, or your confidence.**

Dispatch prompt:

> Review this causal claim. Your job is to refute it, not to grade it.
> Review ONLY what the artifact states. Do not consult memory files, account records, CRM, prior notes, or any other source, and do not run searches. If you recall something about this subject from elsewhere, discard it - it is not admissible.
> For each finding: name the specific alternative explanation, state whether the evidence present rules it out, and name the one piece of evidence that would settle it.
> Default to "not ruled out" when the artifact is silent. Silence is not evidence.
> End with exactly one verdict: APPROVE, REVISE, or REJECT.
> Write your verdict and reasoning to `<path>` before doing anything else.

Verdict meanings:

- **APPROVE** - the causal claim is supported at the strength it is stated
- **REVISE** - the finding is probably real but the claim overstates the design, or a named check is missing
- **REJECT** - a live alternative explanation accounts for the observation as well as the claimed cause

## Stage 3 - Process pass (same reviewer, after the lock)

Now hand the reviewer the transcript, notebook, or query history. It hunts only for what evidence cannot show:

- Specification search - several windows, cohorts, or cuts tried, one reported
- Post-hoc window selection - boundaries moved after seeing the effect
- Dropped runs - a query or fit that disagreed and did not make the write-up
- Hypothesis fitted to the result and then presented as prior

**Stage 3 can add findings and can worsen a verdict. It cannot soften one.** An APPROVE that becomes REVISE here is a correct outcome; a REJECT that becomes APPROVE is the failure this ordering exists to prevent.

## Pack: naive before/after

The most common shape and the most often wrong: one series, no control, an event, a change after it.

| Alternative explanation | The question that kills it |
|---|---|
| Regression to the mean | Was the pre-window chosen because it was extreme? |
| Seasonality / period boundary | Does the same shape appear in the prior cycle with no event? |
| Co-occurring change | What else shipped, expired, or was enforced that week? |
| Composition shift | Did the mix of units change, rather than their behavior? |
| Instrument change | Did the measurement change, rather than the thing measured? |
| Anticipation | Did the series move before the event? |
| Denominator drift | Is the base growing or shrinking underneath the rate? |
| Survivorship | Is the cohort defined by something that happened after treatment? |

**Name the cheapest control that was not used.** "No control group available" is almost always false. Peer units over the same window, other segments inside the same unit, the population-wide series, or the same calendar window a year earlier are usually one query away. If a step appears in the population too, the unit-specific cause is dead.

A uniform multiplier across unrelated series, with the base population flat, is a property of the pipeline, not of behavior. Breadth is not corroboration - it is the signature of something that touched every series equally.

A naive before/after can reach APPROVE only when the artifact addresses the alternatives that are live for that series, and the claim is stated at that strength.

## Output

Write the review in this order:

1. **Verdict** - one word, first line, with the single reason for it
2. **Findings** - severity-ranked; each names the alternative explanation, its status (ruled out / not ruled out / fatal), and the evidence that would settle it
3. **Stage-1 failures** - the checks that returned NO
4. **Process findings** - from stage 3, marked as such

## Red flags - you are self-reviewing

- Running the refutation in your own context because "it is a small analysis"
- Writing the reviewer's dispatch prompt with your conclusion in it
- Reading the transcript before the verdict is on disk
- Turning a REJECT into a REVISE after seeing how much work went into it
- Accepting silence in the artifact as a check that passed

| Rationalization | Reality |
|---|---|
| "The finding is obviously right" | Obvious findings are where nobody looks for the confound. |
| "There is no control group available" | Then the claim is descriptive. Restate it, do not upgrade it. |
| "A subagent is overkill here" | The separate context is the mechanism. Without it this is a checklist you grade yourself. |
| "The transcript explains why the window is fine" | Then it goes in the artifact, where the reviewer can see it before locking. |
| "n is small but the direction is clear" | Direction without uncertainty is not an effect size. |
