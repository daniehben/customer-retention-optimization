# **Retention Policy Engine — Audit, Leakage Fix, and Streamlined Decision Logic (Baseline V2)**

## Why this document exists

This document captures the *audit trail* of Phase 3 → Phase 5.D, including:

- what the policy engine originally produced,
- why the expected value (EV) equation “collapsed” (became cost-only / negative),
- how that failure revealed **future leakage** in the baseline segmentation,
- how the segmentation was rebuilt using **leakage-safe features** (recency + AOV),
- and how the streamlined system now produces a realistic policy outcome:
  - **default = no_offer**
  - **free_shipping used for a small, defensible subset**

This is the “meta narrative” that ties together the phase docs and explains the business logic drivers behind the final policy.

---

## Executive summary (what changed and why it matters)

The initial Baseline V2 policy engine produced a degenerate outcome: incentives were almost always negative EV, and the system collapsed into selecting `no_offer` (or sometimes a trivial “least bad” option). The root cause was not “bad lift assumptions” or “bad offer costs” — it was a **baseline probability collapse** caused by **future leakage**.

The original Phase 3 segmentation used **days_to_next_order** to define “risk bands.” That variable is an *outcome after the anchor date*, which makes the segmentation leak future information into the baseline. Once that happens, the estimated baseline reorder probability becomes nearly deterministic (0/1), causing the incremental probability uplift (Δp) to collapse toward zero.

When Δp ≈ 0:
- incremental value ≈ 0
- expected incentive cost remains > 0
- therefore **net EV becomes “just negative cost”**

The fix was to rebuild risk segmentation using only anchor-time information:
- **recency bands**
- **AOV tiers**

After the fix:
- baseline reorder probabilities regained variation (not 0/1),
- Δp stopped collapsing,
- EV stopped degenerating into “cost-only” outcomes,
- and the engine produced a policy that looks like a real margin-sensitive retailer strategy:
  - **most customers fall back to `no_offer`**
  - **a small subset receives `free_shipping`**
  - discounts are not broadly selected because they create uncontrolled margin leakage.

---

## Core problem observed: EV collapse

### Symptom
The system’s EV outputs were dominated by:
- `EV = 0` for `no_offer`, and
- negative values for all incentive offers (often just the offer_cost).

This created a decision engine that effectively said:
- “never intervene” (or “intervene only as a tie artifact”)

### Why that was a red flag
This dataset and business context can plausibly support a conservative “mostly no_offer” policy — but a *complete collapse* where incremental value is almost always zero is usually a sign that something upstream has made the probability model degenerate.

That prompted an audit question:

> If incentives always look harmful, is it because incentives are truly harmful — or because Δp is collapsing due to how the baseline is constructed?

---

## Root cause: future leakage in risk segmentation (Phase 3)

### What the original segmentation did
The initial Phase 3 risk bands were defined using:

- **days_to_next_order** (time-to-event after the anchor date)

This was useful for *describing* outcomes, but it is not valid for a decision policy engine that must act at anchor time.

### Why this is leakage
At the moment of making a retention decision (the anchor date), you do not know:

- whether the customer will order again,
- nor how many days until that order happens.

So using days_to_next_order to define risk bands injects future outcome information into the baseline.

### How leakage breaks EV mathematically
The offer EV equation depends on incremental probability:

- **Δp = p(offer) − p(base)**

When leakage makes p(base) nearly deterministic:
- p(base) becomes ~0 or ~1,
- many offers cannot shift it (or the shift becomes trivial),
- **Δp collapses toward 0**.

Then EV becomes:

- **net_EV ≈ (Δp × expected_margin) − expected_offer_cost**
- with Δp ≈ 0 → net_EV ≈ − expected_offer_cost

So the engine stops being a “value creation” evaluator and becomes a “cost penalizer.”

This is exactly the collapse pattern that was observed.

---

## The fix: rebuild segmentation using leakage-safe features

### Design principle
A retention decision system must use only information available **at the moment of decision**.

So segmentation was rebuilt to be feature-based, using:

- **Recency bands** (how recently the customer purchased prior to anchor)
- **AOV tiers** (historical spend prior to anchor)

These features are:
- observable at anchor time,
- stable inputs for a real policy,
- and strong behavioral proxies for risk and value.

### Outcome of the fix
After switching to recency + AOV segmentation:
- baseline probabilities were no longer 0/1 artifacts,
- Δp became non-zero in a meaningful subset,
- EV stopped collapsing,
- and downstream ranking produced stable, realistic recommendations.

---

## Streamlining changes introduced during the fix

Once the leakage issue was identified, the work shifted into *streamlining* — making the policy pipeline deterministic, auditable, and resistant to silent failures (row loss, join holes, null EV artifacts).

Key streamlining principles applied:

1) **Policy spine first**
   - Make a deterministic customer×offer spine and attach economics via joins.
   - Never compute decisions on partially joined data.

2) **Audit flags instead of silent nulls**
   - Track missing join coverage explicitly (e.g., `is_missing_ev_row`).

3) **No-offer fallback is a policy rule**
   - The decision engine must default to `no_offer` whenever EV is not positive.
   - This prevents “least bad spend” decisions.

4) **Bounded-cost incentives are treated differently**
   - Free shipping is capped-ish (bounded by freight).
   - Discounts scale with AOV and can leak margin fast.
   - In a thin-margin retailer context, this distinction matters operationally.

---

## Final pipeline map (views by phase)

This is the final streamlined view stack through Phase 5.D:

### Phase 3 — Risk segmentation
- `churn.v_6_baseline_risk_segment`

### Phase 4 — Offer economics
- `churn.v_6_customer_offer_spine`
- `churn.v_6_p_base_by_risk_segment`
- `churn.v_6_4_offer_spine`
- `churn.v_6_lift_assumption`
- `churn.v_6_offer_ev`

### Phase 5.B — Gates (economic eligibility)
- `churn.v_6_phase5_b_eligibility`

### Phase 5.C — Offer EV spine (customer × offer simulation)
- `churn.v_6_phase_5_c_offer_ev_spine`

### Phase 5.D — Best offer per customer (ranking + fallback)
- `churn.v_6_phase5d_best_offer_per_customer`

---

## Phase 5.C — What it adds (and why it matters)

Phase 5.C creates an auditable decision grid:

- one row per **eligible (customer, anchor_date)** crossed with **all offers**.

Offers simulated:
- `no_offer`
- `free_shipping`
- `discount_5_percent`
- `discount_10_percent`

It then joins in the EV fields from `v_6_offer_ev`.

### Why this is essential
Phase 5.D can only be trusted if:
- every eligible anchor has all 4 offer rows,
- and EV values are populated for each offer,
- with no hidden join holes.

### Sanity checks that validated correctness
From the Phase 5.C outputs:
- **offers_per_anchor = 4**
- **n_null_ev = 0** across offer types

Meaning:
- complete offer coverage,
- complete EV coverage,
- ranking in Phase 5.D is selecting from a full, correct menu.

---

## Phase 5.D — Decision ranking and no-offer fallback

Phase 5.D chooses the best action per customer anchor by ranking offers on:

1) `net_ev_default` (descending)
2) tie-break: `offer_cost` (ascending)
3) tie-break: `offer_type` (deterministic ordering)

Then it applies a strict policy rule:

- if `max_ev_over_anchor <= 0` → force `best_offer_type = 'no_offer'`

### Why this rule is non-negotiable in this business context
For a margin-sensitive retailer:
- spending money on a negative EV intervention is worse than doing nothing,
- and “least bad incentive” logic is how cash leakage happens.

So Phase 5.D encodes:
- **default restraint**
- **intervene only when value is provably positive**

---

## Final result (post-fix): realistic policy shape

After the leakage fix and streamlining, Phase 5.D outputs:

- **734 anchors → `no_offer`**
- **42 anchors → `free_shipping`**

### What this signals
This is the expected shape of a conservative retention policy for a thin-margin retailer:

- most customers do not justify spend under conservative assumptions,
- interventions are reserved for a small subset where EV clears 0,
- and the winning incentive is the bounded-cost option (`free_shipping`),
  not revenue-scaled discounts.

### Why free_shipping appears “dangerous but sometimes worth it”
A key nuance from earlier analysis is that free shipping has:
- a very negative **min EV**
- but still has positive cases.

Interpretation:
- shipping subsidies are risky when freight is structurally high (huge downside),
- but when freight is manageable and lift creates real incremental behavior,
  free_shipping becomes economically defensible.

So the policy is not “free shipping is good.”
It is:
> “Free shipping is only justified in a subset where the economics make it positive EV.”

---

## Key Lessons / Why this matters 

This project demonstrates the difference between analytics that *explains the past* and analytics that can be *trusted to drive spend decisions*. The biggest technical-looking issue ended up being a business-critical one: future leakage made the baseline probability collapse toward 0/1, which collapsed Δp and turned the EV model into a cost-only penalty. Fixing segmentation to use only anchor-time features (recency + AOV) restored probabilistic variation and made the decision engine economically meaningful. The final policy behaves like a real retention system in a margin-constrained retail setting: default to no spend, intervene only when EV is positive, and prefer bounded-cost incentives (shipping) over revenue-scaled leakage (discounts). This is the kind of reasoning that prevents “data-driven” decisions from becoming cash-burning automation.



