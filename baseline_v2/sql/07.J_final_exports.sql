-- Activation List (Selected Customers Only)
SELECT
  scenario_id, decision_month, customer_unique_id, anchor_date,
  recommended_offer_type, final_policy_name, is_selected,
  net_ev_scn, incremental_profit_scn, expected_margin_value_scn,
  offer_cost_scn, expected_offer_cost_scn, p_offer_scn,
  priority_rank, cut_by_buffer_flag, missing_p_offer_flag,
  budget_amount, spend_expected_selected, spend_p95_selected,
  roi_expected, p95_overspend_flag_month, raw_overspend_flag_month
FROM churn.v7_e_activation_feed_customers
WHERE is_selected = 1
ORDER BY scenario_id, decision_month, priority_rank;



-- Monthly KPIs

SELECT *
FROM churn.v7d_decision_kpis_scenario_month
ORDER BY scenario_id, decision_month;


-- Scenario Comparison

SELECT *
FROM churn.v7f_scenario_rollup
ORDER BY rank_business_winner;

SELECT *
FROM churn.v7h_scenario_winner_rollup
ORDER BY
  CASE WHEN any_p95_overspend_any_month = 1 THEN 1 ELSE 0 END,
  win_rate DESC,
  net_ev_in_winner_months DESC;

SELECT *
FROM churn.v7i_scenario_winner_final;
