CREATE OR REPLACE VIEW churn.v7h_scenario_winner_rollup AS
WITH month_winners AS (
  SELECT *
  FROM churn.v7g_scenario_rollup_month
  WHERE rank_business_winner = 1
),
all_months AS (
  SELECT *
  FROM churn.v7g_scenario_rollup_month
),
winner_agg AS (
  SELECT
    scenario_id,
    COUNT(*) AS months_won,
    MIN(decision_month) AS first_win_month,
    MAX(decision_month) AS last_win_month,
    -- Value when it wins
    SUM(COALESCE(net_ev_selected, 0.0)) AS net_ev_in_winner_months,
    SUM(COALESCE(incremental_profit_selected, 0.0)) AS incr_profit_in_winner_months,
    SUM(COALESCE(spend_expected_selected, 0.0)) AS spend_expected_in_winner_months,
    SUM(COALESCE(budget_amount, 0.0)) AS budget_in_winner_months,
    -- Weighted KPIs when it wins
    (SUM(COALESCE(incremental_profit_selected,0.0))
      / NULLIF(SUM(COALESCE(spend_expected_selected,0.0)),0)) AS roi_expected_weighted_when_winner,

    (SUM(COALESCE(spend_expected_selected,0.0))
      / NULLIF(SUM(COALESCE(budget_amount,0.0)),0)) AS util_expected_weighted_when_winner,
    -- Risk flags when it wins
    MAX(COALESCE(p95_overspend_flag_month, 0)) AS any_p95_overspend_in_winner_months,
    SUM(COALESCE(raw_overspend_flag_month, 0)) AS raw_overspend_winner_months,
    -- Params / explainability
    MAX(margin) AS margin,
    MAX(lift_multiplier) AS lift_multiplier,
    MAX(shipping_cost_multiplier) AS shipping_cost_multiplier,
    MAX(budget_rate) AS budget_rate
  FROM month_winners
  GROUP BY 1
),
coverage AS (
  SELECT
    scenario_id,
    COUNT(*) AS months_covered,
    MIN(decision_month) AS first_month,
    MAX(decision_month) AS last_month,
    MAX(COALESCE(p95_overspend_flag_month,0)) AS any_p95_overspend_any_month,
    SUM(COALESCE(raw_overspend_flag_month,0)) AS raw_overspend_months_all
  FROM all_months
  GROUP BY 1
)
SELECT
  w.*,
  c.months_covered,
  c.first_month,
  c.last_month,
  c.any_p95_overspend_any_month,
  c.raw_overspend_months_all,
  -- share of months won (stability)
  (w.months_won::double precision / NULLIF(c.months_covered,0)) AS win_rate
FROM winner_agg w
LEFT JOIN coverage c
  ON w.scenario_id = c.scenario_id;

