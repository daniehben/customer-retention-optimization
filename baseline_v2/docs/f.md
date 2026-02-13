

## Add this to `07E_activation_feed.md`

#

## Add this to `07F_to_07I_scenario_comparison_and_winner.md`

#

---

## Add this to `07J_exports_and_csv_deliverables.md`

### Dependencies / Build Order

**Upstream dependencies (must exist first)**

* `churn.v7_e_activation_feed_customers`
* `churn.v7d_decision_kpis_scenario_month`
* `churn.v7f_scenario_rollup`
* `churn.v7h_scenario_winner_rollup`
* `churn.v7i_scenario_winner_final`

**This file produces (export order)**

1. Activation List CSV (selected customers only)
2. Monthly KPI CSV
3. Scenario Rollup CSV
4. Winner Rollup CSV
5. Final Champion CSV

---

If you want it extra portfolio-grade, I can also add a **1-line “Sanity checks to run after build”** section under each dependency box (the specific tests you already ran: p95 test returning 0 rows, distinct budget check, duplicate customer check, etc.).
