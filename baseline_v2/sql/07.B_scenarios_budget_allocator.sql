CREATE OR REPLACE VIEW churn.v4_7_b_budget_allocator_by_scenarios AS
WITH offers AS (
  SELECT
    o.*,
    date_trunc('month', o.anchor_date) AS decision_month
  FROM churn.v_7a_offer_ev_by_scenario o
),offers_one_per_customer AS (
  SELECT *
  FROM (
    SELECT
      o.*,
      ROW_NUMBER() OVER (
        PARTITION BY o.scenario_id, o.customer_unique_id, o.anchor_date
        ORDER BY o.net_ev_scn DESC,
                 o.offer_cost_scn ASC,
                 COALESCE(o.p_offer_scn, 0.0) DESC
      ) AS rn_offer
    FROM offers o
  ) x
  WHERE rn_offer = 1
),
base AS (
  SELECT
    o.customer_unique_id,
    o.anchor_date,
    o.offer_type,
    o.net_ev_scn,
    o.offer_cost_scn,
    o.expected_margin_value_scn,
    o.lift_scn,
    o.p_offer_scn,
    o.delta_p_scn,
    o.incremental_profit_scn,
    o.expected_offer_cost_scn,
    o.risk_segment,
    o.decision_month,
    b.scenario_id,
    b.budget_amount,
    eb.effective_budget_amount,
    eb.risk_buffer_amount,
    eb.z_value,
    eb.missing_p_offer_rows,
    d.final_pass,
    d.candidate_flag
  FROM offers_one_per_customer o
  LEFT JOIN churn.v_7a_budget_pool_by_scenario b
    ON o.scenario_id = b.scenario_id
   AND o.decision_month = b.decision_month
  LEFT JOIN churn.v_7_a_budget_pool_by_scenario_effective eb
    ON o.scenario_id = eb.scenario_id
   AND o.decision_month = eb.decision_month
  LEFT JOIN churn.v_6_phase6_a_budget_base d
    ON o.customer_unique_id = d.customer_unique_id
   AND o.anchor_date = d.anchor_date
  WHERE d.final_pass = 1
),
ranked AS (
  SELECT
    b.*,
    ROW_NUMBER() OVER (
      PARTITION BY scenario_id, decision_month
      ORDER BY net_ev_scn DESC, offer_cost_scn ASC
    ) AS priority_rank
  FROM base b
  WHERE candidate_flag = 1
    AND COALESCE(net_ev_scn, 0.0) > 0.0
    AND COALESCE(offer_cost_scn, 0.0) > 0.0
)
,scored AS (
  SELECT
    r.*,
    -- expected spend curve
    SUM(expected_offer_cost_scn) OVER (
      PARTITION BY scenario_id, decision_month
      ORDER BY priority_rank
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_spend_expected,
    -- worst-case spend curve (all redeem)
    SUM(offer_cost_scn) OVER (
      PARTITION BY scenario_id, decision_month
      ORDER BY priority_rank
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_spend_raw,
    -- variance curve (risk)
    SUM(
      POWER(COALESCE(offer_cost_scn,0.0), 2)
      * COALESCE(p_offer_scn,0.0)
      * (1 - COALESCE(p_offer_scn,0.0))
    ) OVER (
      PARTITION BY scenario_id, decision_month
      ORDER BY priority_rank
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_var

  FROM ranked r
)
,final_scored AS (
  SELECT
    s.*,
    SQRT(COALESCE(running_var,0.0)) AS running_std,
    (running_spend_expected + COALESCE(z_value, 1.645) * SQRT(COALESCE(running_var,0.0))) AS running_spend_p95,
    -- policies (define ONCE, reuse everywhere)
    CASE WHEN running_spend_expected <= budget_amount THEN 1 ELSE 0 END AS selected_flag_no_buffer,
    CASE WHEN (running_spend_expected + COALESCE(z_value, 1.645) * SQRT(COALESCE(running_var,0.0))) <= budget_amount
         THEN 1 ELSE 0 END AS selected_flag_p95_buffer

  FROM scored s
)
,month_rollup AS (
  SELECT
    scenario_id,
    decision_month,
    -- Worst-case monitor (can still overspend even with p95 buffering)
    MAX(running_spend_raw) FILTER (WHERE selected_flag_no_buffer = 1)      AS spend_raw_no_buffer,
    MAX(running_spend_raw) FILTER (WHERE selected_flag_p95_buffer = 1)     AS spend_raw_p95_buffer,
    -- p95 monitor (should NOT overspend under p95-buffered selection)
    MAX(running_spend_p95) FILTER (WHERE selected_flag_no_buffer = 1)      AS spend_p95_no_buffer,
    MAX(running_spend_p95) FILTER (WHERE selected_flag_p95_buffer = 1)     AS spend_p95_p95_buffer,

    MAX(budget_amount) AS budget_amount
  FROM final_scored
  GROUP BY 1,2
)
SELECT
  f.*,
  -- row-level monitors (readable)
  CASE WHEN f.selected_flag_no_buffer = 1 AND f.running_spend_raw > f.budget_amount THEN 1 ELSE 0 END AS worst_case_overspend_row_flag,
  -- month-level "uh-oh" monitors (broadcast)
  CASE WHEN m.spend_raw_no_buffer       > m.budget_amount THEN 1 ELSE 0 END AS raw_overspend_no_buffer_flag,
  CASE WHEN m.spend_raw_p95_buffer      > m.budget_amount THEN 1 ELSE 0 END AS raw_overspend_p95_buffer_flag,
  CASE WHEN m.spend_p95_no_buffer       > m.budget_amount THEN 1 ELSE 0 END AS p95_overspend_no_buffer_flag,
  CASE WHEN m.spend_p95_p95_buffer      > m.budget_amount THEN 1 ELSE 0 END AS p95_overspend_p95_buffer_flag,
  -- explainability
  CASE WHEN f.priority_rank = 1 THEN 1 ELSE 0 END AS is_top_ev_customer_flag,
  CASE WHEN f.p_offer_scn IS NULL THEN 1 ELSE 0 END AS missing_p_offer_flag,
  CASE WHEN f.selected_flag_no_buffer = 1 AND f.selected_flag_p95_buffer = 0 THEN 1 ELSE 0 END AS cut_by_buffer_flag
FROM final_scored f
LEFT JOIN month_rollup m
  ON f.scenario_id = m.scenario_id
 AND f.decision_month = m.decision_month;





-- =======================================================
-- CREATE RISK BUFFERS AND ADD BACK TO THE MAIN ALLOCATOR
-- =======================================================

CREATE OR REPLACE VIEW churn.v_7b_budget_risk_monitor AS
WITH picked AS (
  SELECT
    scenario_id,
    decision_month,
    -- total expected + raw cost of selected customers
    SUM(expected_offer_cost_scn) FILTER (WHERE selected_flag = 1) AS spend_expected,
    SUM(offer_cost_scn)         FILTER (WHERE selected_flag = 1) AS spend_raw,
    COUNT(*)                    FILTER (WHERE selected_flag = 1) AS selected_ct
  FROM churn.v1_7_b_budget_allocator_by_scenarios
  GROUP BY 1,2
)
SELECT
  scenario_id,
  decision_month,
  spend_expected,
  spend_raw,
  selected_ct,
  CASE
    WHEN spend_expected IS NULL OR spend_expected = 0 THEN NULL
    ELSE spend_raw / spend_expected
  END AS risk_ratio,
  CASE
    WHEN spend_expected IS NULL OR spend_expected = 0 THEN 0
    WHEN (spend_raw / spend_expected) <= 1.05 THEN 0.00
    WHEN (spend_raw / spend_expected) <= 1.20 THEN 0.05
    WHEN (spend_raw / spend_expected) <= 1.50 THEN 0.10
    ELSE 0.15
  END AS risk_buffer
FROM picked;


-- =======================================================
-- CREATE RISK BUFFERS AND ADD BACK TO THE MAIN ALLOCATOR
-- =======================================================

CREATE OR REPLACE VIEW churn.v_7_a_budget_pool_by_scenario_effective AS
WITH offers AS (
  SELECT
    o.*,
    date_trunc('month', o.anchor_date) AS decision_month
  FROM churn.v_7a_offer_ev_by_scenario o
),
base AS (
  SELECT
    o.scenario_id,
    o.decision_month,
    o.customer_unique_id,
    o.anchor_date,
    o.offer_cost_scn,
    o.p_offer_scn,
    o.net_ev_scn,
    b.budget_amount,
    d.final_pass,
    d.candidate_flag
  FROM offers o
  LEFT JOIN churn.v_7a_budget_pool_by_scenario b
    ON o.scenario_id = b.scenario_id
   AND date_trunc('month', o.anchor_date) = b.decision_month
  LEFT JOIN churn.v_6_phase6_a_budget_base d
    ON o.customer_unique_id = d.customer_unique_id
   AND o.anchor_date = d.anchor_date
  WHERE d.final_pass = 1
),
eligible AS (
  SELECT *
  FROM base
  WHERE candidate_flag = 1
    AND COALESCE(net_ev_scn, 0.0) > 0.0
    AND COALESCE(offer_cost_scn, 0.0) > 0.0
),
stats AS (
  SELECT
    scenario_id,
    decision_month,
    MAX(budget_amount) AS budget_amount,
    -- if p_offer_scn is NULL, treat it conservatively
    AVG(COALESCE(p_offer_scn, 1.0)) AS avg_p_offer_used,
    SUM(CASE WHEN p_offer_scn IS NULL THEN 1 ELSE 0 END) AS missing_p_offer_rows,
    -- variance of redemption cost
    SUM(
      (COALESCE(p_offer_scn, 1.0) * (1 - COALESCE(p_offer_scn, 1.0)))
      * (offer_cost_scn * offer_cost_scn)
    ) AS var_cost
  FROM eligible
  GROUP BY 1,2
),
buffered AS (
  SELECT
    s.*,
    1.645::double precision AS z_value, -- pick your safety level here
    (1.645 * SQRT(COALESCE(var_cost,0.0))) AS risk_buffer_amount
  FROM stats s
)
SELECT
  scenario_id,
  decision_month,
  budget_amount,
  z_value,
  var_cost,
  risk_buffer_amount,
  GREATEST(budget_amount - risk_buffer_amount, 0.0) AS effective_budget_amount,
  avg_p_offer_used,
  missing_p_offer_rows
FROM buffered;

