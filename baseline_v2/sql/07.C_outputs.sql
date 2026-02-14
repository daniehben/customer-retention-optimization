CREATE OR REPLACE VIEW churn.v1_7_c_decision_output_customers AS
WITH src AS (
  SELECT
    a.*,
    ROW_NUMBER() OVER (
      PARTITION BY a.scenario_id, a.decision_month, a.customer_unique_id, a.anchor_date
      ORDER BY a.net_ev_scn DESC, a.offer_cost_scn ASC
    ) AS rn
  FROM churn.v4_7_b_budget_allocator_by_scenarios a
),
one_row AS (
  SELECT *
  FROM src
  WHERE rn = 1
)
SELECT
  -- Keys
  scenario_id,
  decision_month,
  customer_unique_id,
  anchor_date,
  -- Action
  offer_type AS recommended_offer_type,
  -- Canonical policy (your official decision)
  'p95_buffer'::text AS final_policy_name,
  selected_flag_p95_buffer AS final_selected_flag,
  -- Gating context (why selected / not selected)
  final_pass,
  candidate_flag,
  -- Core economics
  net_ev_scn,
  incremental_profit_scn,
  offer_cost_scn,
  expected_offer_cost_scn,
  p_offer_scn,
  expected_margin_value_scn,
  lift_scn,
  delta_p_scn,
  -- Budget context + risk metrics (for explainability)
  budget_amount,
  z_value,
  running_spend_expected,
  running_spend_p95,
  running_spend_raw,
  -- Monitors you decided to keep
  priority_rank,
  missing_p_offer_flag,
  p95_overspend_p95_buffer_flag,
  raw_overspend_p95_buffer_flag,
  cut_by_buffer_flag
FROM one_row;
