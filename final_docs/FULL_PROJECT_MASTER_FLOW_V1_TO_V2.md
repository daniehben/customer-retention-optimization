# Customer Retention & Incentive Optimization — Full Project Master Flow (Baseline V1 → Baseline V2)

**Purpose of this document**  
This is the **end-to-end master flow** for this project across both baselines:

- **Baseline V1:** the intentionally simple control condition (and what it proved)
- **Baseline V2:** the governed, decision-grade retention policy engine (the final portfolio deliverable)
- **Upgrade Map:** the exact “why” behind each V2 design decision, grounded in V1 symptoms

_Last updated: 2026-02-14_

---

## Table of Contents

1. Executive narrative
2. Baseline V1 — Master Flow (what V1 did)
3. Baseline V1 → V2 Upgrade Map (why V2 exists)
4. Baseline V2 — Master Flow (what V2 built and why it’s “decision-grade”)
5. What is “official” in V2 (policy lock, governance guarantees, final outputs)
6. Activation model + operating cadence
7. Appendix: canonical deliverables and how they connect

---

## 1) Executive narrative 

This project treats retention incentives like **capital allocation**.

This system answers the following question:

> “Given a limited monthly budget, which customers should receive which incentive so that expected incremental profit exceeds cost — while staying safe under redemption uncertainty?”


**Where it ends (V2):**
- a **policy definition** (including `no_offer` as a valid decision)
- a **governance-safe selection rule** (p95 buffered selection)
- a **monthly governance KPI view**
- an **activation-ready customer list**
- and a **scenario-based champion** decision (assumption stress test)

---

## 2) Baseline V1 — Master Flow


**Purpose of this document**  
This is the explanation of **Baseline V1**, built directly from the SQL scripts. It is written to make Baseline V2 more credible by showing:

- what V1 was designed to do (simple, transparent decision engine)
- what assumptions V1 hard-coded (p0 buckets, lift, costs, budget)
- why V1 produced “almost no profitable customers” (structural, not accidental)
- which exact V1 limitations motivated each V2 upgrade

**V1 Script chain included in this review**
- `01_base_tables.sql`
- `02_order_level_aggregation.sql`
- `03_value_and_freight_features.sql`
- `04_baseline_p0.sql`
- `05_customer_value_at_anchor.sql`
- `06_offer_cost_model.sql`
- `07_lift_model.sql`
- `09_expected_value.sql`
- `10_budget_constraint.sql`

---

## 1) What Baseline V1 is (business framing)

Baseline V1 is a **minimal viable retention decision engine**:

> assign a baseline reorder probability (**p0**) using simple buckets, simulate offer uplift and costs, compute expected value per offer, then allocate a fixed budget to the highest value opportunities.

This baseline intentionally tests a key question:

> “If I try to run retention decisioning with **bucket-level probabilities**, do I get a usable, value-creating program?”

The answer (from V1 outputs) was “no” — and that failure becomes the justification for V2’s design.

---

## 2) V1 data preparation flow (what tables/features V1 builds)

### Step 2.1 — Base tables (`01_base_tables.sql`)
This script standardizes the raw sources needed for the V1 pipeline (customers, orders, order_items, deliveries, etc.).  
**Role in flow:** ensures consistent joins and minimal working tables for later phases.

### Step 2.2 — Order-level aggregation (`02_order_level_aggregation.sql`)
Creates an order-level spine by aggregating line items:
- order value (sum of price)
- freight (sum of freight_value)

**Why it matters:** V1 cost and value assumptions are built on these order-level measures.

### Step 2.3 — Value + freight features (`03_value_and_freight_features.sql`)
Builds customer-level features used throughout V1:
- average next order value expectation
- average freight cost
- bucketed freight categories (e.g., 0–10, 10–20, …, 100+)

**Why it matters:** V1’s p0 is bucketed by freight, and free shipping costs are directly tied to freight.

---

## 3) V1 probability model (p0) — the central simplifying assumption

### Step 3.1 — Baseline p0 by bucket (`04_baseline_p0.sql`)
V1 computes p0 as a **bucket-level probability** based on historical behavior:

- p0 is computed for **repeat customers only** (customers with at least one post-anchor order)
- p0 is assigned at the level of **avg_freight_bucket**
- sparse buckets use a **global fallback p0** when the bucket does not have enough customers

**Fallback rule (from SQL):**
- if bucket customer_count < **UNKNOWN**, use overall p0

**Why this matters:**  
This is the root cause of V1’s “probability compression.” Customers within a bucket receive the same p0, which removes the engine’s ability to rank customers meaningfully.

---

## 4) V1 customer value at anchor (`05_customer_value_at_anchor.sql`)

This script attaches “value at decision time” inputs needed for EV:

- expected order value at anchor (safe fallbacks when missing)
- average freight at anchor (safe fallbacks when missing)
- key joins to ensure each customer is decision-ready

**Why it matters:**  
It standardizes the value and cost fields so the offer cost model and EV math can run without null explosions.

---

## 5) V1 offer cost model (`06_offer_cost_model.sql`)

V1 defines deterministic offer costs per customer:

- `no_offer` → cost = 0
- `free_shipping` → cost = `avg_freight_safe`
- `discount_5_percent` → cost = 5% × `expected_order_value_safe`
- `discount_10_percent` → cost = 10% × `expected_order_value_safe`

**Why it matters:**  
This makes the cost side operationally realistic — but it also means expensive freight customers are hard to target unless lift is strong.

---

## 6) V1 lift model (`07_lift_model.sql`)

V1 hard-codes uplift assumptions:

- discount lifts are constants:
  - `discount_5_lift = 0.03`
  - `discount_10_lift = 0.05`
- free shipping lift varies by freight bucket via a CASE rule (bucket-specific uplifts)

V1 then computes:
- `p1 = clamp(p0 + lift, 0, 1)`
- `delta_p = p1 - p0`

**Why it matters:**  
Since p0 is bucket-level, p1 is also bucket-level-with-shift. The model still lacks customer-level separation.

---

## 7) V1 expected value engine (`09_expected_value.sql`)

V1 computes EV per customer-offer:

- **Incremental benefit** is based on expected order value:
  - `incremental_revenue = delta_p * expected_order_value_safe`
- **Expected cost** uses p1 × offer_cost (expected redemption)
- **Net expected value** is:
  - `expected_value = incremental_revenue - expected_cost`

**Important note:**  
V1 computes benefit on **revenue**, not margin. That choice makes V1 optimistic on the upside — meaning the fact that V1 still fails is even *more* convincing.

---

## 8) V1 budget allocator (`10_budget_constraint.sql`)

V1 enforces a fixed budget and selects customers:

- Budget is set as a constant:
  - `total_budget = 10000`
- Filters to **positive EV only**
- Selects the best offer per customer
- Ranks by:
  - `ev_per_cost` first
  - then expected_value
- Allocates until cumulative expected cost exceeds the budget

**Why it matters:**  
This is mechanically correct allocation given the inputs. When the allocation curve turns negative quickly, it’s because the upstream EV ranking is weak (probabilities are too coarse).

---

## 9) Why V1 fails (and why that failure is credible)

Baseline V1’s failure is structural:

1) **Probability compression:** bucket-level p0 means customers within a bucket are nearly indistinguishable.
2) **Fallback dominance:** sparse buckets default to the global p0 → assumptions dominate observed behavior.
3) **EV mass piles near/below 0:** small errors in p0/lift destroy net EV.
4) **Budget allocation amplifies the weakness:** once you move past the first few customers, you quickly allocate into negative EV territory.

This matches the V1 Tableau evidence:
- nearly no customers with positive EV
- budget allocation curve becomes value-destructive quickly

---

## 10) The bridge: how V1 justifies V2 (decision-by-decision)

This is the credibility section: each V2 feature is a direct response to a V1 limitation.

- V1: bucket-level p0 → V2: decision-time-safe segmentation + more granular p_base variation  
- V1: fallback dominates → V2: **eligibility gates** to prevent weak segments from driving spend  
- V1: EV cliff near 0 → V2: “no_offer by default” + strict max-EV rule  
- V1: value destruction as budget scales → V2: Phase 6 budget-rate curve + Phase 7 p95 buffer governance  
- V1: no operational artifact → V2: activation feed + monthly KPI governance + scenario winner selection  

---

# V1 → V2 Upgrade Map (Script → Objects → Replacement → Symptom → Evidence)

**Purpose**  

Each card includes:
- what the V1 script creates
- the V2 view(s) that replace/extend it
- the failure symptom it fixes (or note if it’s shared foundation)
- the evidence artifact you can cite in the Tableau story
---

## Evidence artifacts referenced
These are the Baseline V1 Tableau exports / charts referenced in the table:
- `baseline_p0_distribution.png` — Baseline p0 distribution (probability compression)
- `net_expected_value_distribution.png` — Net expected value distribution (EV cliff)
- `offer_expected_cost_vs_gain.png` — Expected gain vs expected cost (offer economics tension)
- `percentage_customers_positive_expected_value.png` — % customers with positive expected value
- `budget_allocation_curve_basline_v1.png` — Budget allocation curve (value destruction scaling)
- `customers_positive_expectd_value.png` — Customers with positive expected value (who they are / how few)
- `customer_value_freight.png` — Customer value vs freight (cost structure)
- `tableau_offer_economics_202601301658.csv` — Tableau export: offer economics
- `tableau_budget_curve_landscape_202601301735.csv` — Tableau export: budget curve landscape
- `tableau_budget_decisions_202601301513.csv` — Tableau export: budget decisions
- `tableau_budget_summary_202601301513.csv` — Tableau export: budget summary
- `tableau_offer_mix_by_bucket_202601301726.csv` — Tableau export: offer mix by bucket

---

## 01_base_tables.sql

**Creates (V1):** churn.delivered_orders, churn.customer_order_flags, churn.customer_orders, churn.customer_orders_enriched, churn.v2_delivered_order_items  
**Replaced / extended by (V2):** churn.v6_anchor_customers, churn.v6_anchor_behavior_features  
**Fix / rationale:** V1 foundation is order-centric; decision spine not explicitly enforced as a deploy-time anchor contract. V2 formalizes anchor + pre-anchor features as a contract.  
**Evidence:** (structural) Covered by V2 anchor contract; no single V1 chart required.

---

## 02_order_level_aggregation.sql

**Creates (V1):** churn.v2_order_items, churn.v2_order_spine  
**Replaced / extended by (V2):** churn.v2_order_spine, churn.v6_anchor_behavior_features  
**Fix / rationale:** Not a failure — reusable foundation. V2 reuses the spine but tightens anchoring and feature windows.  
**Evidence:** N/A (shared foundation).

---

## 03_value_and_freight_features.sql

**Creates (V1):** churn.v2_avg_order_value, churn.v2_next_order_value, churn.v2_freight_customer_features, churn.v2_freight_bucketed  
**Replaced / extended by (V2):** churn.v6_anchor_behavior_features, churn.v_6_4_offer_spine, churn.v_6_phase5_b_eligibility  
**Fix / rationale:** Value/freight buckets become too influential because p0 is bucket-level → weak ranking resolution and fallback-driven assumptions.  
**Evidence:** customer_value_freight.png + baseline_p0_distribution.png

---

## 04_baseline_p0.sql

**Creates (V1):** churn.v5_p0_anchor_customers, churn.v3_freight_customers, churn.v5_p0_by_bucket, churn.v5_p0_overall, churn.v5_p0_assigned  
**Replaced / extended by (V2):** churn.v6_anchor_customers, churn.v_6_baseline_risk_segment, churn.v_6_p_base_by_risk_segment  
**Fix / rationale:** Bucket-level p0 collapses into few discrete values; sparse buckets fall back to global p0 → probability compression + brittle EV ranking.  
**Evidence:** baseline_p0_distribution.png; percentage_customers_positive_expected_value.png

---

## 05_customer_value_at_anchor.sql

**Creates (V1):** churn.v5_customer_value_at_anchor  
**Replaced / extended by (V2):** churn.v6_anchor_behavior_features, churn.v_6_customer_offer_spine  
**Fix / rationale:** Value inputs are stabilized, but V1 lacks explicit leakage audits and a formal decision-time contract; V2 makes anchoring + feature windows explicit and auditable.  
**Evidence:** (structural) supported by V2 Phase 1–3 documentation.

---

## 06_offer_cost_model.sql

**Creates (V1):** churn.v5_offer_costs  
**Replaced / extended by (V2):** churn.v_6_customer_offer_spine, churn.v_6_4_offer_spine  
**Fix / rationale:** Cost model is realistic, but under compressed probabilities EV becomes extremely sensitive to cost; offer choice becomes brittle.  
**Evidence:** offer_expected_cost_vs_gain.png; tableau_offer_economics_202601301658.csv

---

## 07_lift_model.sql

**Creates (V1):** churn.v5_lift_assumptions, churn.v5_customer_offer_sim  
**Replaced / extended by (V2):** churn.v_6_offer_ev, churn.v_7a_scenario_params, churn.v_7a_offer_ev_by_scenario  
**Fix / rationale:** Single hard-coded lift world; cannot defend assumptions. V2 adds scenario stress testing and winner selection under governance.  
**Evidence:** 7_scenario_leaderboard.csv; 7_final_winner.csv

---

## 09_expected_value.sql

**Creates (V1):** churn.v5_expected_value  
**Replaced / extended by (V2):** churn.v_6_offer_ev, churn.v_6_phase5d_best_offer_per_customer  
**Fix / rationale:** Net EV concentrates at/below zero; almost no profitable customers; program cannot scale.  
**Evidence:** net_expected_value_distribution.png; customers_positive_expectd_value.png; percentage_customers_positive_expected_value.png

---

## 10_budget_constraint.sql

**Creates (V1):** (allocator output query)  
**Replaced / extended by (V2):** churn.v_6_phase6_a_budget_base, churn.v4_7_b_budget_allocator_by_scenarios, churn.v7d_decision_kpis_scenario_month  
**Fix / rationale:** Budget allocation becomes value-destructive as spend increases because ranking resolution is weak; no explicit risk governance. V2 adds Phase 6 budget curves + Phase 7 p95 buffered selection + monitors.  
**Evidence:** budget_allocation_curve_basline_v1.png; tableau_budget_curve_landscape_202601301735.csv; 7_monthly_stability_kpi.csv

---


**End of Baseline V1 master doc.**


---

## 3) Baseline V1 → Baseline V2 Upgrade Map


**Purpose**  
This is the “credibility bridge” document: it shows exactly how Baseline V2 is a direct response to Baseline V1’s observed limitations.

## How to read this map
Each row follows the same pattern:

**V1 limitation → V1 symptom → Why it matters → V2 decision → Where it lives in V2**

---

## 1) Probability modeling & ranking resolution

### V1 limitation
Bucket-level **p0** assigns the same baseline probability to large groups of customers (freight buckets), with global fallback when buckets are sparse.

### V1 symptom (what you saw)
- p0 distribution collapses into a few vertical spikes (very few distinct values)
- customer ranking becomes weak because many customers tie on probability-driven EV

### Why it matters (business impact)
If customers look identical, the optimizer can’t prioritize — you end up spending money “randomly within buckets,” and EV-based allocation quickly becomes value-destructive.

### V2 decision
Move away from “bucket-level probability as the decision signal” toward:
- **decision-time-safe segmentation** (no leakage),
- customer-level variation through a more robust risk framework,
- and policy gates that reduce dependence on unstable probability estimates.

### Where it lives in V2
- Phase 1–3: anchor + outcome framing + time-to-next-order risk
- Phase 5: policy framework + eligibility gates that prevent weak segments from driving spend

---

## 2) Sparse segments and fallback dominance

### V1 limitation
When bucket volumes are low, fallback rules push p0 toward global averages — meaning assumptions dominate observed behavior.

### V1 symptom
- sparse buckets rely on fallback p0 → EV becomes “assumption-driven”
- offer economics looks unstable and brittle across buckets

### Why it matters
Operationally, this creates “phantom confidence”: you deploy to segments where the model is not actually learning from enough data.

### V2 decision
Introduce **economic eligibility** and **policy gating** so sparse/noisy segments don’t get funded just because the math produces a positive number under fallback assumptions.

### Where it lives in V2
- Phase 5B: economic eligibility gates
- Phase 5D: best offer selection with conservative default to `no_offer`

---

## 3) Net EV concentrates at / below zero

### V1 limitation
Compressed probabilities + real offer costs (especially shipping) push most offers below break-even.

### V1 symptom (your Tableau evidence)
- Net EV distribution mass sits just below 0
- tiny share of customers have positive EV (V1 highlight)

### Why it matters
A retention program can’t scale if only a handful of customers are profitable — and if you try to scale, you destroy value.

### V2 decision
Make “restraint” explicit:
- **`no_offer` is the default action**
- enforce: if `max(net_ev) ≤ 0` → `no_offer`
- one offer per customer (no double spend)

### Where it lives in V2
- Phase 5A + 5D (policy framework + best offer selection)

---

## 4) Budget allocation becomes value-destructive as spend increases

### V1 limitation
When ranking resolution is weak, spending more simply moves down a noisy list into negative EV territory.

### V1 symptom (your Tableau evidence)
- budget allocation curve turns negative quickly (“additional spend destroys value”)

### Why it matters
Finance and growth teams need to know: “If I increase budget, do I get more profit or just more spend?”

### V2 decision (two-layer response)
1) **Phase 6:** build a budget-rate landscape (reach vs EV vs diminishing returns)
2) **Phase 7:** add a governance-safe allocator with **p95 buffering** + month-level monitors

### Where it lives in V2
- Phase 6: budget allocation summary and reach curve
- Phase 7B: p95-buffer selection policy + governance monitors

---

## 5) Lack of governance / risk controls

### V1 limitation
V1 allocates on expected values without explicit risk controls (tail risk is not formalized).

### V1 symptom
- decisions feel “mathematically correct” but not finance-safe
- no documented guarantee on budget safety under redemption variability

### Why it matters
Real programs get killed not because expected value is wrong, but because redemption variance causes budget blowups and stakeholder trust collapses.

### V2 decision
Introduce a formal governance stance:
- **Customer-level p95-buffer selection** (official decision policy)
- **Month-level p95 monitors** (must be 0)
- Raw overspend allowed but documented as monitored tail risk

### Where it lives in V2
- Phase 7B: buffer allocator and monitors
- Phase 7D: monthly KPI governance output

---

## 6) Scenario sensitivity (assumptions weren’t stress-tested)

### V1 limitation
V1 uses one “world” (fixed lifts/costs) with no formal scenario stress test.

### V1 symptom
- hard to explain to stakeholders “how sensitive are we to lift/margin assumptions?”

### Why it matters
Retention policies depend on assumptions; without sensitivity, you can’t defend the policy when stakeholders challenge inputs.

### V2 decision
Create a scenario framework and choose a winner under governance gates:
- margin scenarios
- lift scenarios
- shipping cost scenarios
- winner selection under “no p95 overspend” hard constraint

### Where it lives in V2
- Phase 7A: scenarios + recomputed EV
- Phase 7F–7I: scenario comparison and final champion selection
- Phase 7J: exported deliverables

---

## 7) Operationalization (activation-ready output)

### V1 limitation
V1 stops at analysis outputs; there’s no clean operational feed with context.

### V1 symptom
- hard to translate “ranked customers” into a process marketing/ops can run monthly

### Why it matters
A project is “decision-grade” only if it outputs a usable activation contract.

### V2 decision
Produce an operational activation feed + KPIs:
- activation list at customer level
- monthly KPI view with governance context
- documented activation approach: **A now (CRM export), B later (shipping waiver/coupon)**

### Where it lives in V2
- Phase 7E: activation feed
- Phase 7D: monthly KPIs
- Master narrative: activation model section

---

## Quick summary (the recruiter-friendly punchline)

Baseline V1 showed that:
- coarse probabilities and fallback assumptions collapse ranking,
- EV concentrates below zero,
- and budget allocation amplifies weak ranking into value destruction.

Baseline V2 responds like a real business iteration:
- adds policy gates + “no_offer by default”
- introduces budget-rate sensitivity (Phase 6)
- adds governance (p95 buffered selection + monitors)
- stress-tests assumptions (Phase 7 scenarios)
- outputs an activation-ready feed + KPI governance.

---

**End of upgrade map.**

---

## 4) Baseline V2 — Master Flow


**Purpose of this document**  
This is the single source of truth for Baseline V2. It explains:

- **Project flow:** what each phase builds and why it exists  
- **Decision flow:** how a customer moves from “eligible” → “recommended offer” → “selected under budget” → “activation feed”  
- **Governance model:** what the policy guarantees vs what it monitors  
- **Final outputs:** what is considered the canonical truth for reporting and Tableau

---

## 1) What Baseline V2 is (Business framing)

Baseline V2 is a **retention decision engine**, not a churn classifier.

It aims to solve a capital allocation problem:

> With a limited monthly budget, decide **which customers to target** and **which incentive to give** so that expected incremental profit exceeds offer cost, while enforcing governance so the policy is safe to operate.

The engine is designed to end with:
1. A **policy definition** (what you do + what you refuse to do)
2. A **governance-safe selection rule** (**p95-buffer selection**)
3. A **monthly KPI governance view** (budget, utilization, ROI, overspend flags)
4. An **activation-ready customer list** (who gets what)

---

## 2) The “final truth” (Phase 7 deliverables)

These Phase 7 files are the official truth tables for storytelling + Tableau:

- `7_scenario_leaderboard.csv` — scenario rollup leaderboard (12-month horizon)
- `7_monthly_stability_kpi.csv` — scenario-month governance + performance metrics
- `7_activation_list.csv` — customer-level activation list (selected customers only)
- `7_final_winner.csv` — single champion scenario output

---

## 3) Where the story ends (Key outcomes)

### Champion scenario (Phase 7)
- **Champion = LIFT_125**
- Wins **10/12 months** (win rate **0.8333**)
- Governance success: **0 p95 overspend months**
- Raw overspend exists and is explicitly **monitored tail risk** (**10 raw-overspend months**)

### Economic profile of the champion (12-month horizon)
- Total budget: **550.93**
- Total expected spend (selected): **84.78**
- Total p95 buffered spend (selected): **316.87**
- Total net EV (selected): **67.72**
- Expected ROI (profit/spend): **1.80**
- Expected budget utilization (spend/budget): **15.39%**
- Activation volume: **42 customers total**, **1–8 customers/month**
- Utilization range by month (expected): **4.90% to 26.78%**

### What the outputs imply (management interpretation)
- **Lift assumptions dominate**: scenarios that increase incremental response probability tend to win.
- **Budget is not binding under expected spend**: utilization is low → the constraint is not cash, it’s scarcity of **positive-EV eligible customers** under conservative gating.
- **Operational simplicity**: selected customers consistently receive **free_shipping** (observed in activation feed).
- **Governance-first stance**: the policy protects budget with p95 buffering, while documenting raw tail exposure.

---

## 4) Decision flow (How the engine decides)


### Step 0 — Establish the decision moment (Anchor)
Each customer gets an **anchor_date** representing the earliest practical moment the business could act.  
Design goal: prevent leakage by ensuring features are computed **only from data available pre-anchor**.

**Output contract:** one row per customer-anchor with pre-anchor features.

### Step 1 — Define outcome signals (Churn + time-to-event)
Define behavioral outcomes post-anchor to understand repeat behavior:
- a baseline churn framing (short window reorder)
- a **time-to-next-order** framing to preserve signal when churn becomes sparse

Principle: outcome labels are for measurement + evaluation; deploy-time decisions must not depend on future-only information.

### Step 2 — Estimate baseline reorder probability (p_base)
The engine produces a baseline reorder probability per customer.  
This is the foundation for EV:
- If p_base has no variance, EV collapses and “best offer” becomes meaningless.
- Baseline V2 explicitly includes audit work to ensure risk segmentation is **deployable** (no leakage).

### Step 3 — Define offers + cost model
Offers are defined as a finite set of actions (including `no_offer`).  
Each offer must have:
- a redemption probability model (via p_offer)
- an expected cost model
- a raw (worst-case) cost exposure

### Step 4 — Convert uplift into incremental probability (delta_p)
For each customer-offer:
- compute offer-specific uplift (lift)
- compute:
  - `p_offer = clamp(p_base + delta_p, 0, 1)`
  - `delta_p = p_offer - p_base`

### Step 5 — Compute expected benefit and expected cost
Per customer-offer:
- **Expected benefit:** incremental margin value attributable to delta_p
- **Expected cost:** expected redemption × offer cost

### Step 6 — Net EV per customer-offer
Per customer-offer:

> `net_ev = incremental_profit - expected_offer_cost`

Now all offers are comparable in dollars.

### Step 7 — Eligibility gates (policy guardrails)
Before ranking or selection, customers must pass conservative eligibility criteria.  
These gates enforce:
- “Don’t subsidize baseline purchases”
- “Don’t target customers where structural cost dominates”
- “Don’t recommend negative-EV offers”

This is a deliberate business stance: the default is restraint.

### Step 8 — Best offer selection (one offer per customer)
For each customer:
- choose offer with highest net EV
- tie-break on lower cost
- if `max(net_ev) <= 0` → **recommend `no_offer`**

This creates the customer-level recommendation table.

### Step 9 — Budget allocation (who gets funded)
A “best offer” is not automatically funded. Funding happens under monthly budgets.

Baseline V2 has two budget layers:

#### Phase 6 — Expected-spend allocator (budget curve)
Purpose: understand reach vs budget rate trade-offs.  
Example: **10% budget scenario** in Phase 6:
- Candidates: **42**
- Selected: **19**
- Budget amount: **550.93**
- Allocated cost: **338.07**
- Budget utilization: **61.36%**
- Net EV selected: **34.03**

Phase 6 is used to show: too tight budgets underfund the program; too loose budgets hit diminishing returns.

#### Phase 7 — Governed allocator (official policy)
Phase 7 adds the official policy:

- **Customer-level selection policy:** **p95-buffer selection**  
- **Month-level governance monitors:** p95 overspend (must be 0) + raw overspend (monitored)

Mechanics:
- rank customers by `net_ev_scn` within scenario-month
- compute running expected spend + running variance of redemption
- compute p95 buffered spend:
  - `running_spend_p95 = running_spend_expected + z * sqrt(running_var)`
  - **z = 1.645** (one-sided p95)
- select until `running_spend_p95 <= budget_amount`

This is the “finance-safe” layer that makes the engine deployable.

---

## 5) Project flow (What each phase contributes)

### Phase 1 — Anchor Definition
**Goal:** build the decision spine.  
**Output:** customer-anchor view with pre-anchor features.

### Phase 2 — Outcome Definition
**Goal:** define reorder outcome windows for evaluation.  
**Output:** baseline churn outcome view.

### Phase 3 — Time-to-Next-Order Risk
**Goal:** preserve signal and avoid “weak churn label” pitfalls.  
**Output:** time-to-event risk framing view.

### Phase 4 — Offer Economics
**Goal:** define EV math and compute EV components.  
**Output:** economic measures (expected margin value, expected cost, net EV components).

### Phase 5 — Policy Engine (Framework → Eligibility → EV Simulation → Best Offer)
**Goal:** convert economics into a conservative, auditable decision policy:
- define the policy stance (`no_offer` default)
- apply eligibility gates
- simulate EV across offers
- select one best offer per customer

**Output:** customer-level “best offer” recommendation table.

### Phase 6 — Budget Allocation
**Goal:** turn best-offer recommendations into a funded program under budget-rate scenarios.  
**Output:** budget curve summary (reach, spend, EV under 2% / 10% / 20% etc.).

### Phase 7 — Scenarios + Governance + Final Outputs
**Goal:** stress test assumptions and freeze the official outputs.
- recompute EV under scenarios (margin/lift/shipping)
- allocate under p95-buffer governance
- freeze decision output + monthly KPIs
- produce activation feed
- compare scenarios and select a champion

**Output:** the final deliverables (leaderboard, monthly KPIs, activation list, final winner).

---

## 6) Governance model (What you guarantee vs what you monitor)

### What the policy guarantees
- With **p95-buffer selection**, monthly selection is designed so the portfolio does not exceed budget at p95 confidence (monthly monitor should stay clean).

### What is allowed but monitored
- **Raw overspend** (worst-case all-redeem exposure) can exceed budget.  
  This is explicitly treated as tail risk and documented via monitors.


---

## 7) Activation model (How this becomes real)

The documented activation assumption is:

**A:** monthly export to CRM/campaign tool  
- The engine outputs the selected list and ops executes campaigns.

**B (later):** automate free shipping via coupon/shipping waiver  
- After validation, the offer is delivered automatically at checkout for selected customers.

This aligns with the operational simplicity of free shipping and the low monthly selection volume.

---


## 5) What is “official” in V2 (policy lock + deliverables)

### Official decision policy (locked)
- **Customer-level selection policy:** **p95 buffer selection**
- **Month-level governance monitors:** p95 monitors at month level
- p95 test validation: p95 overspend should be 0 under buffered selection
- raw overspend may remain and is documented as monitored tail risk

### Canonical deliverables (the truth tables for reporting + Tableau)
- Scenario leaderboard (horizon rollup)
- Monthly stability KPI (scenario-month governance + performance)
- Activation feed (customer-level selected list)
- Final winner (single champion scenario)

These outputs are the “source of truth” for storytelling and dashboards.

---

## 6) Activation model + operating cadence (A now, B later)

**A (now): CRM / campaign export**
- Each month: export the activation list and run outreach via CRM/campaign tooling.

**B (later): automate free shipping via waiver/coupon**
- After validation: apply free-shipping waiver (or coupon logic) automatically at checkout for selected customers.

**Operating cadence (what a real business would do)**
1. Monthly: run policy → produce activation feed
2. Execute campaign
3. Track redemption + incremental reorder uplift
4. Monthly: review governance KPIs (budget utilization, ROI, overspend monitors)
5. Quarterly: recalibrate lift assumptions and re-run scenario selection if needed

---

## Appendix A — Data contracts (Phase 7 file expectations)

### `7_scenario_leaderboard.csv`
Scenario rollup across the horizon:
- total budget, expected spend, p95 spend, raw exposure
- incremental profit, net EV, ROI, utilization
- overspend month counts and business-winner rank

### `7_monthly_stability_kpi.csv`
Scenario-month governance table:
- budget amount
- selected customers
- expected spend vs p95 buffered spend vs raw spend
- ROI, utilization
- flags: p95 overspend (must be 0), raw overspend (monitored)
- data quality monitor: missing p_offer rows

### `7_activation_list.csv`
Customer-level activation feed (selected only):
- scenario_id, decision_month, customer_id, anchor_date
- recommended_offer_type
- policy name (`p95_buffer`)
- economics columns + governance context

### `7_final_winner.csv`
Single champion scenario output (executive decision)


