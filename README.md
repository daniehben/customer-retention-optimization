# Customer Retention Optimization

*A decision-focused analytics project for allocating retention incentives under budget constraints (SQL-first).*

---

## 1) Project Overview (Business Context)

This project addresses a common but poorly specified business problem:

> **Given a limited retention budget, which customers should receive incentives — and which incentives — so retained value exceeds cost (and stays within governance)?**

Rather than starting with machine learning, this repository treats retention as a **decision optimization problem**, not a prediction exercise.

The objective is to:
- quantify the **economic value** of retention actions
- make tradeoffs between **cost, uplift, and budget**
- produce **decision-ready outputs** (activation list + governance KPIs), not just scores

The repository evolves through two baselines so stakeholders can see **why V1 fails** and **what V2 fixes**.

---

## 2) What This System Decides

At each decision point (“anchor date”), the system evaluates:

- Should we intervene or not?
- If yes, **which incentive** should we offer?
- Under a fixed monthly budget, **how far do we go down the ranked list** before spending becomes unsafe or value-destructive?

Decision logic is expressed as **Expected Value (EV)**:

EV = (Δ purchase probability × expected incremental profit) − incentive cost

---

## 3) How This Repo Is Structured (Decision Pipeline)

This repository is organized as a **decision flow**, not a one-off analysis:

**A) Data & customer history**
- delivered orders only
- customer/order spines + pre-anchor features

**B) Probability + value inputs**
- baseline purchase probability
- uplift assumptions by offer
- expected value components (profit + cost)

**C) Economics & optimization**
- net EV per customer-offer
- best-offer selection (one offer per customer)
- budget allocation with governance controls

**D) Operational outputs**
- customer-level decision output
- monthly KPI governance view
- activation feed (who gets what)
- Tableau-ready exports

---

## 4) Baseline V1 (Why it exists)

Baseline V1 is intentionally simple. It uses:
- bucket-level probability assumptions (freight buckets + fallback)
- fixed uplift assumptions by offer type
- EV ranking + budget allocation

It exists to answer:

> *What happens if we allocate retention budget using coarse, bucket-level probabilities?*

**Key outcome (V1):**
- only ~0.14% of customers show positive EV
- budget allocation becomes value-destructive almost immediately
- offer recommendations collapse into edge-case behavior due to weak ranking resolution

📄 V1 documentation:
- `baseline_v1/docs/`

---

## 5) Baseline V2 (Final engine)

Baseline V2 upgrades V1 into a **governed policy engine**:

- **anchor contract + spines** (decision-time integrity)
- **policy framework** (`no_offer` is a valid choice)
- **economic eligibility** (gates for sparse/noisy segments)
- **offer EV simulation** (transparent unit economics)
- **best-offer selection** (one offer per customer)
- **budget allocation (Phase 6)** reach/value landscape
- **governance (Phase 7)** p95-buffered selection + monthly monitors
- **scenario sensitivity testing (Phase 7)** margin/lift/shipping worlds + champion selection
- **operational outputs** activation feed + KPI audit + exports

### Official Baseline V2 policy (locked)
- **Customer-level decision rule:** **p95-buffer selection**
- **Month-level governance:** p95 monitors (overspend must be 0 under policy)
- Raw overspend can exist and is documented as monitored tail risk

---

## 6) End-to-end Decision Flow 

1) Build delivered-order foundation  
2) Build decision spines + pre-anchor features  
3) Define outcome + baseline risk framework  
4) Simulate offers + compute EV per customer-offer  
5) Apply eligibility + select best offer per customer  
6) Allocate budget (and enforce governance policy)  
7) Produce operational outputs + scenario winner

---
## 7) How to Run 

### Environment
- PostgreSQL
- VS Code (Postgres extension for CSV import)
- DBeaver (recommended for running the SQL pipeline + exporting CSVs)
- Tableau Desktop (visualization)

### Database / schema setup

This project assumes:

- Database: `customers_churn`
- Schema: `churn` (raw tables + all views are created here)

Create them if needed:

```sql
CREATE DATABASE customers_churn;

-- connect to customers_churn first, then:
CREATE SCHEMA IF NOT EXISTS churn;
``` 

### Tooling workflow (how this repo is actually run)

1. **Download data**

* Pull the Olist dataset via Kaggle API into:
  `data/raw/`

2. **Load into Postgres (VS Code Postgres extension)**

* Use the VS Code Postgres extension to import CSVs into:

  * Database: `customers_churn`
  * Schema: `churn`

3. **Build the decision engine (DBeaver)**

* Connect DBeaver to the same Postgres database to:

  * run SQL scripts in order
  * inspect intermediate views
  * export final deliverables (CSV)

### Data

Raw data is stored under:
`data/raw/`

### CSV → table mapping (raw inputs)

* `data/raw/olist_orders_dataset.csv` → `churn.orders`
* `data/raw/olist_customers_dataset.csv` → `churn.customers`
* `data/raw/olist_order_items_dataset.csv` → `churn.order_items`

### Required raw tables (must exist before running SQL)

The SQL scripts assume these tables exist in `customers_churn.churn`:

* `churn.orders`
* `churn.customers`
* `churn.order_items`

### Where outputs land

All raw tables, intermediate views, and final decision outputs are created under:

* Database: `customers_churn`
* Schema: `churn`


---

## 8) Execution Order (SQL)

### A) Baseline V1
Run V1 scripts in order from: `baseline_v1/sql/`

(V1 scripts create `churn.delivered_orders` and the V1 allocator outputs.)


### B) Baseline V2 (execution order)
Run V2 scripts in order from: `baseline_v2/sql/`

**Phase 1–4 (foundation + economics)**
1. `01_anchor_behavior_features.sql`
2. `02_churn_outcome_definition.sql`
3. `03_baseline_time_to_next_order_risk.sql`
4. `04_offer_economics.sql`

**Phase 5 (policy engine)**
5. `05.B_intervention_rules.sql`
6. `05.C_offer_ev_simulation.sql`
7. `05.D_decision_ranking_engine.sql`

**Phase 6 (budget allocation)**
8. `06.A_candidate_table.sql`
9. `06.B_budget_allocator.sql`

**Phase 7 (scenarios + governance + outputs)**
10. `07.A_sensitivity_scenarios.sql`
11. `07.B_scenarios_budget_allocator.sql`
12. `07.C_outputs.sql`
13. `07.D_kpis.sql`
14. `07.E_packaged_dataset.sql`
15. `07.F_scenario_comparison.sql`
16. `07.G_scenario_winner.sql`
17. `07.H_score_board.sql`
18. `07.I_final_winner.sql`
19. `07.J_final_exports.sql`

---

## 9) Final Deliverables (Baseline V2)

The final outputs are exported into: `baseline_v2/deliverables/`


Key files:
- `6_budget_scenarios_summary.csv` (Phase 6 summary)
- `7_scenario_leaderboard.csv`
- `7_monthly_stability_kpi.csv`
- `7_activation_list.csv`
- `7_2_scenario_winner_rollup_h.csv`
- `7_final_winner.csv`

These are the “truth tables” for Tableau and the final narrative.

---

## 10) Documentation

All Baseline V2 phase writeups live in: `baseline_v2/docs/`


A full project-level master narrative lives in: `final_docs/FULL_PROJECT_MASTER_FLOW_V1_TO_V2.md`


---

## 11) Dataset & Attribution
This project uses the publicly available **Olist Brazilian E-Commerce Dataset** for demonstration purposes.


---
## Contact
If you’re reviewing this for a role in Business Analytics / Data Science / Product Analytics and want the “1-page business memo” version, see the docs folder.














