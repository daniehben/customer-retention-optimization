# Phase 4 — Offer Economics & Why the EV Engine Collapsed (and How it was Fixed)

## Purpose of Phase 4

Phase 4 builds a **transparent unit-economics decision engine** that answers:

> If we spend money on retention (discounts / free shipping), do we get enough incremental profit to justify the cost?

This phase is not about “maximizing incentives.” It is about **economic justification** under thin margins and cash constraints.

The output of Phase 4 is a customer × offer table with:

* baseline reorder probability (`p_base_default`)
* assumed uplift (`lift_default`)
* expected incremental profit
* expected incentive cost (conversion-conditional)
* **net expected value** (`net_ev_default`)

Default horizon used: **180 days** (kept for comparability and to avoid short-window artifacts).

---

## Modeling Framework (What We Compute)

For each anchor (customer, anchor_date), four actions were evaluated:

* `no_offer`
* `free_shipping`
* `discount_5_percent`
* `discount_10_percent`

For each customer × offer:

1. **Baseline probability**
   `p_base_default` = empirical reorder probability by segment (default horizon = 180d).

2. **Lift assumption**
   `lift_default` = `p_base_default × lift_pct` (policy matrix).

3. **Offer probability**
   `p_offer_default = min(1, p_base_default + lift_default)`

4. **Incremental probability**
   `delta_p_default = p_offer_default - p_base_default`

5. **Incremental profit (expected)**
   `incremental_profit = delta_p_default × expected_margin_value`
   where `expected_margin_value = margin_rate × AOV`

6. **Expected offer cost (conversion conditional)**
   `expected_offer_cost = p_offer_default × offer_cost`

7. **Net EV**
   `net_ev_default = incremental_profit - expected_offer_cost`

---

## The critical failure discovered: EV collapse due to baseline collapse

### What was observed (symptom)

In the initial Phase 4 run, EV behaved like this:

* **most EV values were ~0**
* the remaining values were negative (essentially “just the cost”)
* best-offer logic defaulted to `no_offer` for everyone

### Why that happens (mechanism)

The EV formula depends on incremental value:

* If `delta_p_default ≈ 0`, then:

  * `incremental_profit ≈ 0`
  * `net_ev_default ≈ - expected_offer_cost` (negative for any paid offer)

So the EV engine collapses when **delta collapses**.

### The real root cause (not SQL, but logic validity)

Delta collapsed because baseline probabilities (`p_base_default`) were collapsing toward extremes due to **future leakage** in segmentation:

* risk bands were built using `days_to_next_order`
* that is **future information**, not available at decision time
* outcome-based bands can make baselines behave like hindsight labels
* which kills meaningful incremental movement in probability

In plain business terms:

> If you segment customers using future outcomes, your “baseline probability” stops behaving like a real forecast and starts behaving like a label — and EV becomes “cost-only.”

This was the key insight of Phase 4.

---

## The Phase 4 fix: make the baseline decision-time valid

To fix EV collapse, the segmentation key used for baselines had to be:

✅ based on **pre-anchor features** (what the business knows at the moment of decision)
❌ not based on the future (`days_to_next_order`)

So instead of outcome-based risk bands, **feature-based risk segments** (recency band + AOV tier) were created in Phase 3:

* segmentation uses **recency_days** and **aov_pre_anchor**
* `days_to_next_order` remains as the *evaluation target* used only to compute reorder probabilities by segment

Once segmentation became decision-time valid:

* `p_base_default` became realistic (not degenerate)
* `delta_p_default` became non-zero
* incremental_profit became meaningful again
* EV no longer collapsed into cost-only recommendations

---

## What Phase 4 ultimately concludes (correct version)

### Key Finding 1 — The EV engine is highly sensitive to baseline validity

**Evidence:** when segmentation leaks future outcomes, baseline probabilities become unstable and delta collapses. EV becomes dominated by incentive cost.

**Interpretation:** EV engines are not “plug-and-play.” If the baseline is not decision-time valid, the whole recommendation system becomes logically invalid.

---

### Key Finding 2 — Under realistic retailer economics, most customers should receive no offer

A realistic business outcome was confirmed after fixes:

* `no_offer` becomes the dominant action for most anchors
* incentives win only when incremental profit truly exceeds expected cost

**Interpretation:** For thin-margin retailers, a healthy policy is selective, not generous.

---

### Key Finding 3 — Free shipping can be rational, but only for a small subset

After leakage fixes and streamlining:

* free_shipping showed **very negative worst-case EV** (danger if applied broadly)
* but a **small subset** produced positive EV (targetable)

**Interpretation:** free shipping is not a blanket retention lever. It is a targeted tactic for cases where:

* shipping friction is meaningful, and
* margin × uplift is high enough, and
* freight burden is not structurally catastrophic

---

### Key Finding 4 — Percentage discounts are structurally risky when the retailer absorbs them

Under the standard assumption it was confirmed that:

> “We’re a retailer absorbing discounts ourselves.”

Discount cost scales with AOV, so it can easily exceed incremental margin effects, especially with thin contribution margin assumptions.

**Interpretation:** discounts should be treated as high-risk tools unless there is strong evidence of incremental lift — and even then should be constrained by policy gates (Phase 5).

---

## What Phase 4 does *not* claim (updated)

* It does **not** claim incentives never work.
* It does **not** claim EV must be positive frequently.
* It does **not** treat assumptions as truth — it shows how assumptions interact and where failure modes appear.
* It does **not** recommend blanket incentives; it recommends a controlled policy architecture.

---

## Phase 4 Deliverables (views)

Phase 4 consists of:

* `churn.v_6_customer_offer_spine`
* `churn.v_6_p_base_by_risk_segment`
* `churn.v_6_4_offer_spine`
* `churn.v_6_lift_assumption`
* `churn.v_6_offer_ev`

---

## Phase 4 Conclusion (correct)

> Phase 4 produced a deployable offer-economics framework and revealed a critical validity requirement: baseline segmentation must be decision-time feature-based (not outcome-based), otherwise the EV engine collapses into cost-only logic. After removing leakage and rebuilding baselines using feature-based risk segments, the system behaves realistically: most customers correctly receive no offer, while a small subset can justify targeted interventions (most commonly free shipping) under strict economic constraints.

---

## Transition to Phase 5

With the EV engine stable, Phase 5 formalizes the policy layer:

* **Phase 5B:** eligibility gates (who is even allowed to be considered)
* **Phase 5C:** EV spine for eligible customers
* **Phase 5D:** choose best offer per anchor with no-offer fallback when EV ≤ 0

This ensures incentives are used only when justified and prevents margin leakage.

