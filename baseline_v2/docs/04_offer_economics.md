# Phase 4 — Offer Economics & Decision Rationale

## Purpose of Offer Economics

The purpose of Phase 4 is **not** to maximize incentive usage, but to evaluate whether **monetary retention incentives are economically justified at all** under realistic business constraints.

Given the business context:

* thin contribution margins
* sensitivity to cash leakage
* high baseline reorder behavior

the objective is to determine **when incentives should be avoided**, and under what conditions (if any) they can be justified as last-resort actions.

---

## Modeling Framework (Summary)

Each customer anchor is evaluated across multiple hypothetical actions:

* No intervention
* Free shipping
* 5% discount
* 10% discount

For each customer × offer combination, the model computes:

* Baseline reorder probability (empirical, by risk band)
* Incremental lift (policy assumptions)
* Incremental expected margin
* Expected incentive cost (conversion-conditional)
* Net expected value (EV)

The default evaluation horizon is **180 days**, chosen to align with observed customer reorder behavior and avoid artificial zero-probability bias.

All calculations use **conservative, cash-realistic assumptions**, reflecting how costs are incurred in practice.

---

## Key Finding 1 — No Incentive Produces Positive Expected Value

### Evidence

Across all customers and all offer types:

* **0% of customer-offer combinations have positive EV**
* This holds across:

  * all risk bands (low, medium, high, dormant)
  * all monetary incentives tested
  * all customers in the dataset

This result is unanimous and stable.

### Interpretation

This indicates that **monetary incentives do not generate sufficient incremental behavior** to offset their cost under current business economics.

This is not a targeting failure — the result persists even when analyzed by risk segment.

---

## Key Finding 2 — Incentives Generate Cost Without Incremental Value

### Evidence

Decomposing EV into value and cost components shows:

* **Average incremental profit ≈ 0** for all incentives
* **Expected incentive costs remain strictly positive**
* Net EV is therefore negative across the board

This pattern holds consistently across:

* discount-based incentives
* free shipping
* all customer risk segments

### Interpretation

The model shows that incentives primarily **discount existing behavior** rather than creating new behavior.

In practical terms:

* customers who would have reordered anyway receive incentives
* incentives do not meaningfully change reorder probability
* margin is reduced without corresponding value creation

This is the most dangerous scenario for a low-margin business.

---

## Key Finding 3 — Revenue-Based Incentives Are Structurally Harmful

### Evidence

Percentage-based discounts perform worse as order value increases:

* incentive cost scales with AOV
* high-value customers are penalized most
* expected costs rise faster than incremental value

Even modest discounts (5%) remain negative EV across all segments.

### Interpretation

Revenue-based incentives are **structurally misaligned** with thin-margin businesses.

They:

* scale with order size
* apply to baseline conversions
* create uncontrolled margin leakage

This is not a parameter-tuning issue — it is a strategic constraint.

---

## Key Finding 4 — Free Shipping Does Not Solve the Problem

### Evidence

Free shipping:

* has bounded cost
* performs better than percentage discounts
* but still produces **negative EV in all segments**

### Interpretation

While shipping friction may be relevant, **subsidizing shipping alone is insufficient** to justify intervention under current margins and observed lift.

This suggests that:

* friction reduction alone does not create enough incremental behavior
* non-price experience improvements may be more effective than monetary subsidies

---

## Key Finding 5 — “No Offer” Is the Dominant Action

### Evidence

For all customers:

* “no_offer” has EV = 0
* all incentives have EV < 0

### Interpretation

From a financial perspective, **non-intervention strictly dominates intervention** under current assumptions.

This is not an absence of recommendation — it is a **clear recommendation to preserve capital**.

---

## Strategic Implications

### 1. Incentives Should Not Be Default Retention Tools

The analysis shows that incentives:

* do not improve outcomes
* consistently reduce expected value
* increase financial risk

Therefore, incentives should be treated as **exceptional actions**, not standard policy.

---

### 2. Retention Decisions Should Prioritize Harm Avoidance

The primary value of this model is in answering:

> “Who should explicitly *not* receive incentives?”

Avoiding unprofitable actions produces more value than attempting marginal gains through discounts.

---

### 3. Monetary Incentives Are Last-Resort Winbacks

If incentives are ever used, they should be:

* limited to extreme risk cases
* justified by unusually high lifetime value
* deployed only when the alternative (losing the customer) is demonstrably worse

Under current data and assumptions, **no such cases exist**.

---

## What This Phase Does *Not* Claim

* It does not claim incentives never work in general
* It does not rule out non-monetary interventions
* It does not assume lift is zero — it demonstrates lift is insufficient relative to cost

This phase evaluates incentives **under conservative, realistic assumptions**, which is appropriate for a financially constrained business.

---

## Phase 4 Conclusion

> **Under current unit economics and observed customer behavior, monetary retention incentives produce negative expected value across all customer segments.
> The optimal policy is to minimize incentive usage and reserve intervention only for exceptional, high-risk cases where inaction would be more damaging.**

This conclusion is supported directly by:

* empirical baseline behavior
* transparent cost modeling
* conservative lift assumptions
* customer-level expected value analysis

---

## Transition to Final Policy Layer

With the economic viability of incentives evaluated and found lacking, the next step is **not further optimization**, but **formalizing a decision policy** that:

* encodes non-intervention as the default
* restricts incentives to exceptional scenarios
* protects the business from margin erosion


