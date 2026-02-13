


## `07E_activation_feed.md`

#
## `07F_to_07I_scenario_comparison_and_winner.md`

#
## `07J_exports_and_csv_deliverables.md`

### Sanity checks to run after build

**Activation list export is consistent**

```sql
SELECT
  scenario_id,
  decision_month,
  COUNT(*) AS selected_rows
FROM churn.v7_e_activation_feed_customers
GROUP BY 1,2
ORDER BY 1,2;
```

Expected: counts align with KPI `selected_customers`.

**Champion scenario exists in all exports**

```sql
WITH champ AS (
  SELECT scenario_id FROM churn.v7i_scenario_winner_final
)
SELECT
  (SELECT COUNT(*) FROM churn.v7f_scenario_rollup r JOIN champ c USING(scenario_id)) AS in_rollup,
  (SELECT COUNT(*) FROM churn.v7h_scenario_winner_rollup r JOIN champ c USING(scenario_id)) AS in_winner_rollup;
```

Expected: both counts = **1**.

---

If you want, I can also add a tiny **“Expected outcomes”** sentence per check (like “0 rows = pass, non-zero = investigate”) so the doc reads like a proper engineering runbook.
