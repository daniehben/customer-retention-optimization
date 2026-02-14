# Business Memo

## Customer Retention Optimization: Incentive Decision Engine (SQL-first, governance-ready)

### Executive summary

Retention incentives are often treated as “marketing spend,” but the real question is a **capital allocation** decision:

> Given a limited monthly retention budget, which customers should receive which offer so that **incremental value exceeds cost**, while remaining **safe under redemption uncertainty**?

This project builds a **decision engine** (not just a predictive model) that outputs:

* a customer-level **activation list** (who gets what)
* a monthly **governance KPI pack** (budget safety + ROI)
* a **scenario-tested** champion policy under different business assumptions

It’s built SQL-first for transparency and auditability, and designed for Tableau reporting.

---

## Business problem and why it matters

Incentives can easily become value-destructive when:

* uplift assumptions are too coarse
* customer ranking has weak signal resolution
* budget allocation scales down a noisy ranked list
* redemption variability creates budget blow-ups (stakeholder trust killer)

This engine makes those risks explicit and gives a defensible policy that can be monitored.

---

## What the system decides

At each “anchor date” (decision point), the system decides:

1. **Should we intervene or not?** (no_offer is an explicit option)
2. If yes, **which offer** should we give?
3. Under a fixed budget, **how far down the ranked list** can we go before value turns negative or risk becomes unacceptable?

Decision metric is **Expected Value (EV)**:

**EV = (Δ purchase probability × expected incremental value) − incentive cost**

The system then allocates budget to the highest-value actions first, under governance controls.

---

## Why two baselines 

### Baseline V1 (diagnostic control condition)

V1 intentionally uses **bucket-level baseline probabilities (p0)** with fallbacks. It answers:

> What happens if we try retention optimization with coarse probability assumptions?

**Observed outcome:** almost no customers are economically viable; ranking collapses; budget allocation becomes value-destructive quickly.
This is not a “bad result.” It’s a **business signal failure** demonstration: coarse probability resolution can’t support optimization.

### Baseline V2 (final policy engine)

V2 is the credible, decision-grade upgrade:

* stricter decision framing (`no_offer` default)
* economic eligibility gating
* one best offer per customer
* budget allocation landscape (Phase 6)
* governance-safe allocation with **p95 buffering** (Phase 7)
* scenario sensitivity testing + final champion selection

---

## What makes V2 “business-safe”

### Governance policy 

**Customer-level selection uses p95-buffered spend.**
This means we don’t just allocate based on expected spend — we add a statistical buffer to control tail risk.

**Month-level governance monitors** validate:

* p95 overspend flags (should be 0 under policy)
* raw overspend flags (allowed but monitored as tail exposure)

This is the core stakeholder trust feature: the policy is not only value-seeking, it’s **risk-governed**.

---

## Scenario sensitivity testing (Phase 7)

Because retention depends on assumptions, V2 runs multiple “worlds”:

* margin scenarios
* lift scenarios
* shipping-cost scenarios

Each scenario recomputes EV and runs the allocator, then selects a winner under hard governance constraints.

**Result:** a single champion scenario is chosen based on:

* governance pass (no p95 overspend)
* total net EV
* ROI / utilization tradeoffs
* tail risk exposure

This is how you defend the policy in a real org when stakeholders challenge assumptions.

---

## Operational outputs (what a team can actually run)

V2 ends with decision-grade deliverables:

* **Activation feed:** customer_id + recommended offer + decision month + economics context
* **Monthly KPI governance view:** budget utilization, ROI, expected vs p95 spend, overspend monitors
* **Scenario leaderboard:** total net EV and other ranking criteria
* **Final winner table:** single champion scenario for the operating policy

These outputs are Tableau-ready and can be used as a recurring monthly operating pack.

---

## Key insight from the numbers

A major strategic insight surfaced in V2:

* budget utilization is typically low → the limiting factor isn’t budget, it’s **how many customers are actually positive-EV under conservative assumptions and gating**
* operationally, the chosen offer type tends to collapse to the simplest high-signal lever (in your runs: free shipping dominates)

This is exactly the kind of insight product/marketing teams need: it tells them whether they should invest in **better targeting**, **better economics**, **new offer types**, or **uplift calibration** via experiments.

---

## Tech stack and why it’s structured this way

* **PostgreSQL**: end-to-end logic in views for auditability
* **VS Code Postgres extension**: import raw tables and quick iteration
* **DBeaver**: consistent execution + exporting CSV deliverables
* **Tableau Desktop**: decision narrative + governance dashboards

SQL-first is intentional: it makes the decision engine transparent, reviewable, and business-friendly.

---

## What be the next step in a real team

If this were moving toward production:

1. calibrate lift assumptions via A/B testing and backtesting
2. expand offer set (bundled offers, threshold shipping, time-limited coupons)
3. improve probability resolution and segment stability
4. integrate campaign execution and redemption tracking loop
5. automate monthly run + monitoring pack distribution





