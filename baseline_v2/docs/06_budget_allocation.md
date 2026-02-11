# Phase 6 — Budgeted Allocation

## Objective

Phase 5 identifies the economically best offer per customer (or `no_offer`). Phase 6 answers the operational question the business actually faces:

> **Given a limited retention budget, which customers should receive an incentive this period?**

This phase converts the policy engine from “best decision per customer” into a deployable allocation policy that respects budget constraints and produces an action list.

---

## 6A — Candidate Set (Inputs to Allocation)

### What 6A produces

A single, auditable decision universe where each row represents:

* one customer at one anchor date
* the **best offer** from Phase 5 (or `no_offer`)
* the expected economics needed for budgeting

**Core output view**

* `churn.v_6_phase6a_candidates`

### How 6A is built

6A merges three responsibilities:

1. **Winner selection output (Phase 5D)**

   * Source: `churn.v_6_phase5d_best_offer_per_customer`
   * Supplies: `best_offer_type`, `max_ev_over_anchor`, `risk_segment`, anchor keys.

2. **Eligibility + observable-at-anchor economics (Phase 5B)**

   * Source: `churn.v_6_phase5_b_eligibility`
   * Supplies: `aov_pre_anchor`, `avg_freight_pre_anchor`, `recency_band`, `final_pass`, `ineligibility_reason`.

3. **Winner economics (Phase 5C)**

   * Source: `churn.v_6_phase_5_c_offer_ev_spine`
   * Joined on: `(customer_unique_id, anchor_date, offer_type = best_offer_type)`
   * Supplies: `net_ev_default` and `offer_cost` for the winner.

### Key fields created in 6A

* `candidate_flag`: 1 if `best_offer_type != 'no_offer'`, else 0
* `offer_cost`: expected offer cost used for budgeting
* `worst_case_offer_cost`: conservative redeemed-cost proxy (used later for stress tests)

### Output validity (sanity expectations)

* 6A contains the complete evaluated cohort and preserves eligibility fields for auditability.
* Candidate rate is expected to be low if the EV logic is conservative (as it should be in a business setting).

---

## 6B — Budget Base (Budget Pool Definition)

### Budget definition used in this project

To ensure the budget is anchored to business economics, the retention budget is defined as a **% of expected gross profit** under the baseline (no-offer) behavior.

* Margin assumption: **0.25**
* Baseline reorder probability: **`p_reorder_180d`** (segment-level)

**Budget pool logic**
For each anchor row:

* `expected_gp_no_offer = 0.25 * aov_pre_anchor * p_reorder_180d`

Then aggregated monthly:

* `period_expected_gp = SUM(expected_gp_no_offer)` by `decision_month`
* scenario budgets:

  * 2% / 5% / 10% / 20% of `period_expected_gp`

**Supporting views**

* `churn.v_6_phase6a_gp_pool` (monthly pool computation)
* `churn.v_6_phase6a_budget_base` (joins the pool back to candidates and materializes scenario budgets)

---

## 6C — Budgeted Allocation (Who gets funded)

### Allocation rule

For each `decision_month`:

1. Filter to fundable candidates:

* `final_pass = 1`
* `candidate_flag = 1`
* `net_ev_default > 0`
* `offer_cost > 0`

2. Prioritize:

* Rank by `net_ev_default DESC`
* Tie-break by `offer_cost ASC` (cheaper wins when EV is equal)

3. Allocate within budget:

* Compute cumulative sum of `offer_cost` in rank order
* Select rows while `running_spend <= budget_amount`

**Allocation outputs (scenario views)**

* `churn.v_6_phase6b_budgeted_allocation_2pct`
* `churn.v_6_phase6b_budgeted_allocation_5pct`
* `churn.v_6_phase6b_budgeted_allocation_10pct`
* `churn.v_6_phase6b_budgeted_allocation_20pct`

---

## Phase 6 Results — Scenario Summary

To make the budget decision defensible, the program was evaluated under multiple budget levels. The consolidated export artifact for this phase is:

* **`budget_scenarios_summary.csv`** (Phase 6 scenario export)

This file contains:

* monthly metrics by scenario (selected customers, spend, EV captured)
* a scenario-level total row for each budget tier
* ROI and incremental ROI fields to diagnose diminishing returns

### Key takeaways (from `budget_scenarios_summary.csv`)

**2% (baseline / finance-strict constraint)**

* Program does not launch: **0 customers selected**, **0 spend**, **0 EV captured**.
* Reason: monthly budgets are frequently below the minimum fundable positive-EV incentive cost.

**5% (pilot budget)**

* Funds only a small subset of top winners.
* Strong efficiency but low reach (program activates in only some months).

**10% (recommended operating budget)**

* Activates in most months and captures the majority of attainable EV.
* Maintains healthy ROI while meaningfully increasing coverage versus 5%.

**20% (upper bound / diminishing returns)**

* Near-full funding of the candidate set.
* ROI drops sharply; incremental EV gained per additional spend becomes weak.

### Why 10% is the practical “sweet spot”

The scenario curve shows diminishing returns: moving from 10% to 20% increases spend substantially while adding comparatively little net EV. This suggests that 10% is the most balanced operating point between reach and efficiency.

### Summary 
Using the **scenario totals** in the exported file **`budget_scenarios_summary.csv`**, Phase 6 shows a clear “budget → actionability → diminishing returns” curve. Across the period there are **42** positive-EV candidate winners (total candidate expected cost **811.80**). Under the conservative **2%** budget (total budget **110.19**), the allocator funds **0** customers because the monthly budgets are frequently below the minimum fundable winner cost, so spend and captured value both remain **0**. At **5%**, the program starts as a small pilot: it funds **5/42** customers, spends **97.10**, captures **10.96** net EV, and delivers **~11.29% EV-per-$** ROI (budget utilization **~35.25%**). At **10%**, the program becomes operational: it funds **19/42** customers, spends **338.07**, captures **34.03** net EV, and maintains **~10.07%** ROI while using **~61.36%** of budget. At **20%**, coverage rises to **39/42**, but efficiency drops: spend increases to **764.86** for **41.25** net EV (**~5.39%** ROI). The incremental economics make the recommendation clear: moving **5% → 10%** buys **+23.07 EV** for **+240.97** spend (**~9.57%** incremental ROI), while **10% → 20%** buys only **+7.22 EV** for **+426.79** spend (**~1.69%** incremental ROI). Practically, **10%** is the best operating point (strong coverage + healthy ROI), **2%** is a documented “too tight to deploy” governance baseline, and **20%** is best treated as an upper-bound stress test due to diminishing returns.

---

## Deliverables produced in Phase 6

* `churn.v_6_phase6a_candidates` (candidate universe)
* `churn.v_6_phase6a_gp_pool` (monthly expected GP pool)
* `churn.v_6_phase6a_budget_base` (scenario budgets attached to candidates)
* Budgeted allocation views for 2/5/10/20%
* Export artifact: **`budget_scenarios_summary.csv`** (decision-ready scenario summary)

