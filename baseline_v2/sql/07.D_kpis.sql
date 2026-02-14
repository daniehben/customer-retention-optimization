CREATE OR REPLACE VIEW churn.v7d_decision_kpis_scenario_month AS
WITH src AS(
    SELECT *
    FROM churn.v4_7_b_budget_allocator_by_scenarios
)
SELECT
    scenario_id,
    decision_month,
    -- Budget inputs
    MAX(budget_amount) AS budget_amount,
    MAX(z_value) AS z_value_used,
    -- Official policy volume
    COUNT(DISTINCT customer_unique_id) FILTER (WHERE selected_flag_p95_buffer = 1) AS selected_customers,
    -- Spend 
    MAX(running_spend_expected) FILTER (WHERE selected_flag_p95_buffer = 1) AS spend_expected_selected,
    MAX(running_spend_p95)      FILTER (WHERE selected_flag_p95_buffer = 1) AS spend_p95_selected,
    MAX(running_spend_raw)      FILTER (WHERE selected_flag_p95_buffer = 1) AS spend_raw_if_all_redeem_selected,
    -- Value 
    SUM(incremental_profit_scn) FILTER (WHERE selected_flag_p95_buffer = 1) AS incremental_profit_selected,
    SUM(net_ev_scn)             FILTER (WHERE selected_flag_p95_buffer = 1) AS net_ev_selected,
    -- Utilization + ROI
    (MAX(running_spend_expected) FILTER (WHERE selected_flag_p95_buffer = 1))
        / NULLIF(MAX(budget_amount),0) AS budget_util_expected,
    (MAX(running_spend_p95) FILTER (WHERE selected_flag_p95_buffer = 1))
        / NULLIF(MAX(budget_amount),0) AS budget_util_p95,
    (SUM(incremental_profit_scn) FILTER (WHERE selected_flag_p95_buffer = 1))
        / NULLIF((MAX(running_spend_expected) FILTER (WHERE selected_flag_p95_buffer = 1)),0) AS roi_expected,
    -- Official month-level monitors
    MAX(p95_overspend_p95_buffer_flag) AS p95_overspend_flag_month,
    MAX(raw_overspend_p95_buffer_flag) AS raw_overspend_flag_month,
    -- Data quality / explainability monitors
    SUM(CASE WHEN p_offer_scn IS NULL THEN 1 ELSE 0 END) AS missing_p_offer_rows,
    AVG(p_offer_scn) FILTER (WHERE selected_flag_p95_buffer = 1) AS avg_p_offer_selected
FROM src
GROUP BY 1,2;