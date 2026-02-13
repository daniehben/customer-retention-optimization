CREATE OR REPLACE VIEW churn.v7_e_activation_feed_customers AS
WITH decision_raw AS (
  SELECT
    scenario_id,
    decision_month,
    customer_unique_id,
    anchor_date,
    recommended_offer_type,
    'p95_buffer'::text AS final_policy_name,
    final_selected_flag,
    final_pass,
    candidate_flag,
    net_ev_scn,
    incremental_profit_scn,
    expected_margin_value_scn,
    lift_scn,
    delta_p_scn,
    p_offer_scn,
    offer_cost_scn,
    expected_offer_cost_scn,
    priority_rank,
    cut_by_buffer_flag,
    missing_p_offer_flag
  FROM churn.v1_7_c_decision_output_customers
),
decision AS (
  SELECT *
  FROM (
    SELECT
      d.*,
      ROW_NUMBER() OVER (
        PARTITION BY scenario_id, decision_month, customer_unique_id
        ORDER BY final_selected_flag DESC, net_ev_scn DESC, offer_cost_scn ASC
      ) AS rn
    FROM decision_raw d
  ) x
  WHERE rn = 1
),
kpi AS (
  SELECT *
  FROM churn.v7d_decision_kpis_scenario_month
)
SELECT
  d.*,
  k.budget_amount,
  k.z_value_used,
  k.selected_customers,
  k.spend_expected_selected,
  k.spend_p95_selected,
  k.spend_raw_if_all_redeem_selected,
  k.incremental_profit_selected,
  k.net_ev_selected,
  k.budget_util_expected,
  k.budget_util_p95,
  k.roi_expected,
  k.p95_overspend_flag_month,
  k.raw_overspend_flag_month,
  k.missing_p_offer_rows,
  k.avg_p_offer_selected,
  1 AS is_selected
FROM decision d
LEFT JOIN kpi k
  ON d.scenario_id = k.scenario_id
 AND d.decision_month = k.decision_month
WHERE d.final_selected_flag = 1;
