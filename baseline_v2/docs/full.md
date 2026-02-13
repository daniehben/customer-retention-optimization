
# File 5 — `07F_to_07I_scenario_comparison_and_winner.md`

## Phase 7F–7I — Scenario comparison and selection of the overall champion

### Purpose

Once you can produce decisions under each scenario, the business needs:

> “Which scenario should we run as the baseline policy assumption?”

You built this in two layers:

* a **global leaderboard** (7F)
* a **monthly winner** view (7G)
* a **winner stability rollup** (7H)
* a **single champion** view (7I)

---

## 7F `churn.v7f_scenario_rollup` — Scenario leaderboard (all months)

### What it does

Aggregates monthly KPIs (7D) up to scenario-level totals:

* total net EV
* total spend
* weighted ROI
* utilization
* number of raw-overspend months
* whether any p95 overspend occurred (hard disqualifier)

Then ranks scenarios using `DENSE_RANK`.

### Why `DENSE_RANK` here

You want a ranking where ties share the same rank and you don’t “skip numbers.”

* `RANK`: 1,1,3 (skips)
* `DENSE_RANK`: 1,1,2 (cleaner)
* `ROW_NUMBER`: forces a single winner even if tied (not desired for governance discussion)

So `DENSE_RANK` is correct for business leaderboards.

---

## 7G `churn.v7g_scenario_rollup_month` + `v7g_scenario_winner_month` — Winner per month

### What it does

Ranks scenarios **within each month**, using:

* p95 overspend = hard gate
* then net EV
* ROI, utilization
* then raw overspend / tail exposure preference

This answers:

* “Does the champion win consistently, or is it volatile?”

---

## 7H `churn.v7h_scenario_winner_rollup` — Winner stability summary

This aggregates the monthly winners to compute:

* months won
* win rate
* value delivered during winner months
* risk flags during winner months
* coverage across all months

This is the bridge to final champion selection.

---

## 7I `churn.v7i_scenario_winner_final` — Single champion

### What it does

Selects one row (the champion) using:

1. must have zero p95 overspend any month
2. highest win_rate
3. highest net EV in months it wins
4. ROI/utilization as tie-breakers
5. fewer raw overspend months preferred

This yields the final “business-ready decision”:

* **which scenario is most defensible to run**

---

---

# Short File — `07J_exports_and_csv_deliverables.md`

## Phase 7J — Export queries and deliverable CSVs

Phase 7 ends with four business-ready outputs:

### 1) Activation List (selected customers only)

Source: `churn.v7_e_activation_feed_customers`

What it’s for:

* operational activation (“who gets what offer, this month”)
* includes economics + governance context

Recommended export name:

* `activation_list.csv`

---

### 2) Monthly KPIs

Source: `churn.v7d_decision_kpis_scenario_month`

What it’s for:

* month-by-month performance tracking
* governance reporting (p95 flags, raw flags)
* scenario comparisons by month

Recommended export name:

* `monthly_kpis.csv`

---

### 3) Scenario comparison leaderboard (whole horizon)

Source: `churn.v7f_scenario_rollup`

What it’s for:

* “which scenario is best overall?”
* easy to show in a 1-slide executive summary

Recommended export name:

* `scenario_rollup.csv`

---

### 4) Scenario winner logic (stability + champion)

Sources:

* `churn.v7h_scenario_winner_rollup`
* `churn.v7i_scenario_winner_final`

What it’s for:

* proves the champion is not a fluke
* documents win rate + risk

Recommended export names:

* `scenario_winner_rollup.csv`
* `scenario_winner_final.csv`

---

## What Phase 7 means for the project

At the end of Phase 7 you have a complete decision product:

* scenario engine (stress tests)
* governance budgeting with p95 policy
* final customer decision output
* KPI reporting layer
* scenario selection layer
* operational activation feed

**You have bridged business logic → statistical governance → executable output.**

---

## One tiny note (so your docs are honest and aligned with what we agreed)

In Phase 7 documentation, you will explicitly state:

* official decision policy is **customer-level p95 buffer selection**
* month-level governance uses **p95 monitors**
* Test 1 returned 0 rows (p95 logic working)
* some raw overspend can remain and is acceptable, but monitored

(You already told me to keep this for Phase 7 docs — this is exactly where it belongs.)

---

If you want, next message: paste the exact filenames you want (like `07A_...md` etc.) and I’ll format the headers exactly to match your repo structure (and include a “Dependencies / Build Order” box at the top of each file so readers can run Phase 7 without guessing).
