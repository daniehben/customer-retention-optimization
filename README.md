# Customer Retention Optimization — Baseline V1 (SQL-first)

A reproducible, SQL-first decisioning baseline for retention incentives.

This project treats retention as a **budget allocation problem**:

> With a limited incentive budget, which customers should receive which offer so that the **expected incremental retained value** exceeds the **incentive cost**?

**Baseline V1 intentionally uses coarse, bucket-level churn probabilities** (instead of ML) to demonstrate why naive probability assumptions fail to create actionable customer ranking — and to establish a clean benchmark for future modeling upgrades.

---

## ⦿ What you get from this repo

### Outputs (decision artifacts)
- **Customer × Offer expected value table** (EV, cost, uplift, profitability flag)
- **Budget-constrained selected set** (who gets an offer under a fixed budget)
- **Tableau-ready extracts** + a dashboard that visualizes:
  - Baseline churn probability distribution (p0)
  - Offer economics (expected gain vs expected cost)
  - Net EV distribution
  - Budget allocation curve + “optimal stop point”
  - Offer mix under budget

### Baseline V1 headline result (diagnostic)
- Only **4 / 2,784 customers (~0.14%)** appear positive EV under this baseline.
- That’s not “business reality” — it’s a **signal resolution failure** caused by coarse probability assumptions.

---

## ⦿ Repository Structure

| baseline_v1/
|
├── docs/      
│   ├── baseline_v1.md # write-up of baseline findings + narrative
│   ├── slides/
│       ├── baseline_v1_slides.md # optional slide narrative (if used)
│       ├── images/
│   
│ 
├── sql/
│   ├── baseline_truth/  
│       ├── baseline_truth_v1.sql
|
│   ├── checks/
│       ├── 07_sanity_checks.sql
│       ├── 09_sanity_checks.sql
│       ├── 10_sanity_checks.sql
|
│   ├── exploration/
│       ├── 10.sql
|
│   ├── 00_setup.sql
│   ├── 01_base_tables.sql
│   ├── 02_order_level_aggregation.sql
│   ├── 03_value_and_freight_features.sql
│   ├── 04_baseline_p0.sql
│   ├── 05_customer_value_at_anchor.sql
│   ├── 06_offer_cost_models.sql
│   ├── 07_lift_model.sql
│   ├── 08_materialization_and_indexes.sql
│   ├── 09_expected_value.sql
│   ├── 10_budget_constraints.sql
│   ├── 11_exports.sql
|
│   ├── tableau/
│       ├── Baseline_V1.twb
│       ├── .csv # exported Tableau inputs
│                  
│   
├── data/       
|
│   ├── extra/ # extra Olist tables (optional)
|
│   ├── raw/ # main CSVs used (3 core tables)
│       ├── olist_customers_dataset.csv
│       ├── olist_order_items_dataset.csv
│       ├── olist_orders_dataset.csv
|         
│     
└── README.md

---

## ⦿ Requirements

- **PostgreSQL** (any recent version is fine)
- A SQL client (recommended: **DBeaver**)
- **Tableau Public** or Tableau Desktop (to open the workbook)

---

## ⦿ Data

This baseline uses the Olist Brazilian e-commerce dataset.

### Minimum required CSVs (used in the SQL pipeline)
Place these in `data/raw/`:
- `olist_orders_dataset.csv`
- `olist_customers_dataset.csv`
- `olist_order_items_dataset.csv`

You also have additional Olist tables in `data/extra/` (not required for Baseline V1).

---

## ⦿ How to run the project (end-to-end)

### 1) Create a database + load raw tables
In PostgreSQL, create a database (example name: `customers_churn`).

Load the three CSVs into tables:
- `churn.orders`
- `churn.customers`
- `churn.order_items`

> Tip: In **DBeaver**, you can import CSV → create table, then set column types.
> The SQL scripts expect:
> - `orders.order_status`
> - `orders.order_delivered_customer_date`
> - `orders.customer_id`
> - `customers.customer_unique_id`, `customers.customer_id`
> - `order_items.order_id`, `order_items.price`, `order_items.freight_value`

### 2) Run SQL scripts in order
Run the scripts below in sequence:

1. `sql/exploration/00_setup.sql`  
2. `sql/exploration/01_base_tables.sql`  
3. `sql/exploration/02_order_level_aggregation.sql`  
4. `sql/exploration/03_value_and_freight_features.sql`  
5. `sql/exploration/04_baseline_p0.sql`  
6. `sql/exploration/05_customer_value_at_anchor.sql`  
7. `sql/exploration/06_offer_cost_model.sql`  
8. `sql/exploration/07_lift_model.sql`  
9. `sql/exploration/09_expected_value.sql`  
10. `sql/exploration/10_budget_constraint.sql`  
11. `sql/exploration/11_exports.sql`

Optional (recommended for speed on re-runs):
- `sql/exploration/08_materialization_and_indexes.sql`  
This materializes the heavier intermediate views and adds indexes.

### 3) Run sanity checks (recommended)
After key stages, run:
- `sql/checks/07_sanity_checks.sql`  (lift + p1 logic)
- `sql/checks/09_sanity_checks.sql`  (expected value logic)
- `sql/checks/10_sanity_checks.sql`  (budget allocator constraints)

These checks catch:
- missing joins / duplicated rows
- NULL propagation that breaks EV
- budget monotonicity and selection validity

### 4) Export Tableau input CSVs
`11_exports.sql` creates Tableau-facing views such as:
- `churn.tableau_baseline_anchors`
- `churn.tableau_avg_freight_baseline`
- `churn.tableau_offer_economics`
- `churn.tableau_budget_decisions`
- `churn.tableau_budget_curve`
- `churn.tableau_budget_curve_landscape`
- `churn.tableau_offer_mix_by_bucket`
- `churn.tableau_budget_summary`

Export each to CSV into `baseline_v1/tableau/` (that’s what your current workbook is wired to).

> Tip: Keep filenames timestamped (as you did) for traceability.

### 5) Open Tableau dashboard
Open `tableau/Baseline_V1.twb`.

If Tableau prompts for missing files, re-point the data sources to the latest CSVs in `tableau/`.

---

## ⦿ What the baseline is doing (method overview)

### A) Define an anchor date per customer
For repeat customers, choose a historical **anchor order** such that there is a full **60-day observation window** after the anchor.

### B) Estimate baseline repurchase probability (p0)
Compute whether each anchored customer repurchased within 60 days.

Then aggregate p0 by **avg freight bucket**.
- If a bucket has low sample size, fallback to the overall rate.

### C) Build offer cost options (customer × offer)
For each customer at anchor date, compute cost for:
- `no_offer`
- `free_shipping` (expected freight cost)
- `discount_5_percent` (5% of expected order value)
- `discount_10_percent` (10% of expected order value)

### D) Apply assumed lift → compute p1
Use a rule table of assumed uplift by offer type (and by freight bucket for free shipping).

Clamp probabilities to [0, 1].

### E) Expected value (EV)
Incremental expected revenue:
- `delta_p × expected_order_value_at_anchor`

Net expected value:
- `incremental_revenue − offer_cost`

### F) Budget allocation
Select the best offer per customer (max EV),
rank candidates by efficiency (`EV / cost`),
and pick down the list until the budget cap is reached.

---

## ⦿ Notes on the Tableau “Budget Allocation Curve” chart

In Baseline V1 you only have **4 positive-EV selected customers**, so the curve will look “tiny” if you filter to selected only.

For a clean, presentation-friendly curve, use **`tableau_budget_curve_landscape`**:
- it ranks best offer per customer even if EV is negative (so you can *see* how value collapses as spend increases)
- still flags the “selected” region under budget and positive EV

Recommended chart setup:
- X axis: `cumulative_cost`
- Y axis: `cumulative_net_ev`
- Marks: Line
- Detail: `decision_rank` (not customer ID)
- Add a reference line: **Y = max(cumulative_net_ev)** (or label the peak as “optimal stop point”)

If you want the cleanest possible view: hide tooltips, remove customer id from tooltip, and label only the peak.

---

## ⦿ Known limitations (Baseline V1 is supposed to fail)

Baseline V1 is intentionally brittle because:
- p0 is bucket-level → very few distinct probability values
- sparse buckets trigger fallback → weak customer differentiation
- EV becomes compressed → ranking collapses
- the allocator amplifies small probability errors

This is the whole point: it creates a transparent “control condition” for later ML upgrades.

---

## ⦿ Next steps (planned upgrades)
- Customer-level churn modeling (classification)
- Probability calibration and better ranking resolution
- Offer-response modeling (uplift estimation)
- Scenario testing and sensitivity analysis (lift, margin, budget)
- Compare Baseline V1 vs ML-driven policy



