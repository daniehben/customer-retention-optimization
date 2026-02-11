CREATE OR REPLACE VIEW churn.v_6_phase6a_candidates AS
WITH winners AS(
SELECT
    b.customer_unique_id,
    b.anchor_date,
    b.risk_segment,
    b.max_ev_over_anchor,
    b.best_offer_type,
    date_trunc('month', b.anchor_date) AS decision_month,
    date_trunc('week', b.anchor_date) AS decision_week,
    CASE 
        WHEN best_offer_type <> 'no_offer' THEN 1
        ELSE 0
    END AS candidate_flag
FROM churn.v_6_phase5d_best_offer_per_customer b

) , elig AS(
    SELECT
    customer_unique_id,
    anchor_date,
    risk_segment,
    recency_band,
    aov_pre_anchor,
    avg_freight_pre_anchor,
    final_pass,
    eligibility_status,
    ineligibility_reason
FROM churn.v_6_phase5_b_eligibility
), 
winner_econ AS(
    SELECT
    w.customer_unique_id,
    w.anchor_date,
    w.risk_segment,
    w.max_ev_over_anchor,
    w.best_offer_type,
    w.decision_month,
    w.decision_week,
    w.candidate_flag,
    -- bring observable-at-anchor fields from 5B
    e.recency_band,
    e.aov_pre_anchor,
    e.avg_freight_pre_anchor,
    e.final_pass,
    e.eligibility_status,
    e.ineligibility_reason,
    -- pull EV + expected cost for the winning offer ONLY
    s.net_ev_default,
    s.offer_cost,
    -- worst-case spend (assume redeemed)
    CASE
        WHEN w.best_offer_type = 'no_offer' THEN 0.0
        WHEN w.best_offer_type = 'free_shipping' THEN COALESCE(e.avg_freight_pre_anchor, 0.0)
        WHEN w.best_offer_type = 'discount_5_percent' THEN 0.05 * COALESCE(e.aov_pre_anchor, 0.0)
        WHEN w.best_offer_type = 'discount_10_percent' THEN 0.10 * COALESCE(e.aov_pre_anchor, 0.0)
        ELSE COALESCE(s.expected_offer_cost, 0.0)
    END AS worst_case_offer_cost,
    -- sanity flags
    CASE WHEN e.aov_pre_anchor IS NULL THEN 1 ELSE 0 END AS missing_aov_flag,
    CASE WHEN e.avg_freight_pre_anchor IS NULL THEN 1 ELSE 0 END AS missing_freight_flag,
    CASE WHEN s.net_ev_default IS NULL THEN 1 ELSE 0 END AS missing_ev_flag,
    CASE WHEN s.offer_cost IS NULL AND w.best_offer_type <> 'no_offer' THEN 1 ELSE 0 END AS missing_cost_flag

    FROM winners w
    LEFT JOIN elig e
      ON e.customer_unique_id = w.customer_unique_id
     AND e.anchor_date       = w.anchor_date
     AND e.risk_segment      = w.risk_segment
    
    LEFT JOIN churn.v_6_phase_5_c_offer_ev_spine s
      ON s.customer_unique_id = w.customer_unique_id
     AND s.anchor_date       = w.anchor_date
     AND s.offer_type        = w.best_offer_type

)
SELECT
    customer_unique_id,
    anchor_date,
    risk_segment,
    max_ev_over_anchor,
    best_offer_type,
    decision_month,
    decision_week,
    candidate_flag,
    final_pass,
    eligibility_status,
    ineligibility_reason,
    aov_pre_anchor,
    avg_freight_pre_anchor,
    net_ev_default,
    offer_cost,
    worst_case_offer_cost,
    missing_aov_flag,
    missing_freight_flag,
    missing_ev_flag,
    missing_cost_flag
FROM winner_econ;


CREATE OR REPLACE VIEW churn.v_6_phase6a_gp_pool AS
WITH anchors AS (
  SELECT
    customer_unique_id,
    anchor_date,
    date_trunc('month', anchor_date) AS decision_month,
    risk_segment,
    aov_pre_anchor
  FROM churn.v_6_baseline_risk_segment
),
pb AS (
  SELECT
    risk_segment,
    p_reorder_180d
  FROM churn.v_6_p_base_by_risk_segment
),
enriched AS (
  SELECT
    a.decision_month,
    a.customer_unique_id,
    a.aov_pre_anchor,
    pb.p_reorder_180d
  FROM anchors a
  LEFT JOIN pb
    ON pb.risk_segment = a.risk_segment
)
SELECT
  decision_month,
  SUM(0.25 * COALESCE(aov_pre_anchor, 0.0) * COALESCE(p_reorder_180d, 0.0)) AS period_expected_gp,
  COUNT(*) AS anchor_count,
  SUM(CASE WHEN p_reorder_180d IS NULL THEN 1 ELSE 0 END) AS missing_p_rows
FROM enriched
GROUP BY 1
ORDER BY 1;



CREATE OR REPLACE VIEW churn.v_6_phase6_a_budget_base AS
SELECT
  c.*,
  p.period_expected_gp,
  0.25::double precision AS margin_assumption,
  0.01 * p.period_expected_gp AS budget_gp_1pct,
  0.02 * p.period_expected_gp AS budget_gp_2pct,
  0.03 * p.period_expected_gp AS budget_gp_3pct
FROM churn.v_6_phase6a_candidates c
LEFT JOIN churn.v_6_phase6a_gp_pool p
  USING (decision_month);



SELECT
  decision_month,
  COUNT(*) FILTER (WHERE candidate_flag = 1) AS candidates,
  SUM(offer_cost) FILTER (WHERE candidate_flag = 1) AS total_expected_cost_if_fund_all,
  MAX(budget_gp_2pct) AS budget_2pct
FROM churn.v_6_phase6_a_budget_base
GROUP BY 1
ORDER BY 1;
