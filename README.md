# Customer Retention Optimization 

*A decision-focused analytics project for allocating retention incentives under budget constraints*

---

## 1. Project Overview (Business Context)

This project addresses a common but poorly specified business problem:

> **Given a limited retention budget, which customers should receive incentives — and which incentives — so that retained value exceeds cost?**

Rather than starting with machine learning, this project treats retention as a **decision optimization problem**, not a prediction exercise.

The core objective is to:

* Quantify the **economic value** of retention actions
* Make tradeoffs between **cost, uplift, and budget**
* Produce **decision-ready outputs**, not just model scores

The project is deliberately structured to evolve through **increasingly sophisticated probability assumptions**, allowing business stakeholders to see *why* simple approaches fail and *what* improvements are required before automation can be trusted.

---

## 2. Decision Framing (What This System Decides)

For each customer at a defined decision point (“anchor date”), the system evaluates:

* Should we intervene or not?
* If yes, **which incentive** should we offer?
* Under a fixed budget, **when should we stop spending**?

Each potential action is evaluated using **expected value (EV)**:

```
Expected Value = (Change in purchase probability × Expected order value) − Incentive cost
```

The system then allocates budget by selecting the **highest-value actions first**, stopping when additional spend becomes value-destructive.

---

## 3. How This Repository Is Structured (Conceptually)

This repository is organized as a **decision pipeline**, not a one-off analysis.

The pipeline has four conceptual layers:

### A. Data & Customer History

* Delivered orders only
* Clean customer identifiers
* Order-level value and freight cost

### B. Customer Value & Probability Assumptions

* Baseline repurchase probability (`p0`)
* Expected order value at decision time
* Incentive-specific probability uplift assumptions

### C. Economics & Optimization

* Incremental revenue vs. incentive cost
* Net expected value per customer-offer
* Budget-constrained allocation logic

### D. Decision Outputs

* Selected customers and offers
* Budget utilization
* Cumulative value curves
* Tableau-ready exports for storytelling

Each layer is implemented explicitly in SQL to keep assumptions transparent and auditable.

---

## 4. Implemented Milestone: Baseline V1 (Why It Exists)

### What Baseline V1 Tests

Baseline V1 implements a **rule-based retention strategy** using:

* Bucket-level churn probabilities (based on average freight)
* Global fallback probabilities for sparse segments
* Fixed uplift assumptions by incentive type

This baseline is **intentionally simple**.

Its purpose is **not** to perform well, but to answer a critical business question:

> *What happens if we try to allocate retention budget using coarse, bucket-level probabilities?*

### Key Result (High-Level)

* Only **4 out of 2,784 customers (0.14%)** show positive expected value
* Budget allocation becomes value-destructive almost immediately
* Offer recommendations collapse into unrealistic edge cases

**Interpretation:**
This is not a business failure — it is a **modeling signal failure**.

Baseline V1 demonstrates that:

* Coarse probability assumptions destroy ranking resolution
* Budget optimization amplifies small probability errors
* “Reasonable” heuristics can still lead to bad decisions at scale

Baseline V1 serves as a **control condition** against which all future improvements are measured.

📄 Full Baseline V1 analysis and visuals are documented here:
`/docs/baseline_v1.md`

---

## 5. How This Project Evolves (Why Baseline V1 Is Not the End)

The repository is designed so that **only the probability layer changes across versions**, while everything else remains comparable.

* **Baseline V1:** Bucket-level probabilities (diagnostic failure)
* **Baseline V2:** Customer-level probability estimation
* **Future versions:** Calibrated models, scenario testing, robustness checks

This structure allows:

* Apples-to-apples comparison across versions
* Clear attribution of improvement
* Business-safe iteration rather than blind model replacement

---

## 6. How to Run the Project (Practical, Minimal)

### Environment

* PostgreSQL
* DBeaver (or any SQL client)
* Tableau Public (for visualization)

### Data

Raw data is stored under:

```
/data/raw/
```

(Primary customer, order, and order item tables)

### Execution Order (SQL Pipeline)

Run the SQL scripts **in order** from:

```
/baseline_v1/sql/exploration/
```

Order:

1. `00_setup.sql`
2. `01_base_tables.sql`
3. `02_order_level_aggregation.sql`
4. `03_value_and_freight_features.sql`
5. `04_baseline_p0.sql`
6. `05_customer_value_at_anchor.sql`
7. `06_offer_cost_model.sql`
8. `07_lift_model.sql`
9. `08_materialization_and_indexes.sql`
10. `09_expected_value.sql`
11. `10_budget_constraint.sql`
12. `11_exports.sql`

### Outputs

* Decision tables and summaries are created as SQL views
* Tableau-ready CSVs are exported into:

```
/baseline_v1/tableau/
```

---

## 7. Repository Structure

```
customer-retention-optimization/
│
├── baseline_v1/
│   ├── sql/          # Full decision pipeline (00 → 11)
│   ├── tableau/      # Tableau workbook + CSV exports
│   ├── docs/         # Baseline V1 narrative analysis
│   └── slides/       # Presentation-ready summaries
│
├── data/
│   ├── raw/          # Primary source tables
│   └── extra/        # Supporting datasets
│
└── README.md
```

---

## 8. Why This Project Is Business-First

This project prioritizes:

* Decision quality over prediction accuracy
* Economic reasoning over model complexity
* Transparency over black-box optimization

Machine learning is introduced **only when the business logic is proven sound**.

---

## 9. Dataset & Attribution

This project uses the publicly available **Olist Brazilian E-Commerce Dataset** for demonstration purposes.
















