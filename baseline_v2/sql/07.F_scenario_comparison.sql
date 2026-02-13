CREATE OR REPLACE VIEW churn.v7f_scenario_rollup AS
WITH k AS(
    SELECT *
    FROM churn.v7d_decision_kpis_scenario_month
),
scenario_agg AS(
    SELECT
        scenario_id,
        COUNT(*) AS months_covered,
        MIN(decision_month) AS first_month,
        MAX(decision_month) AS last_month,
        SUM(budget_amount) AS total_budget,
        SUM(COALESCE(spend_expected_selected, 0.0)) AS total_spend_expected,
        SUM(COALESCE(spend_p95_selected, 0.0))      AS total_spend_p95,
        SUM(COALESCE(spend_raw_if_all_redeem_selected, 0.0)) AS total_spend_raw_if_all_redeem,
        SUM(COALESCE(incremental_profit_selected, 0.0)) AS total_incremental_profit,
        SUM(COALESCE(net_ev_selected, 0.0))             AS total_net_ev,

        SUM(COALESCE(selected_customers, 0)) AS total_selected_customers,
        AVG(COALESCE(selected_customers, 0)) AS avg_selected_customers_per_month,

        (SUM(COALESCE(spend_expected_selected, 0.0)) / NULLIF(SUM(budget_amount), 0)) AS util_expected_weighted,
        (SUM(COALESCE(spend_p95_selected, 0.0))      / NULLIF(SUM(budget_amount), 0)) AS util_p95_weighted,
        (SUM(COALESCE(incremental_profit_selected, 0.0)) / NULLIF(SUM(COALESCE(spend_expected_selected, 0.0)), 0)) AS roi_expected_weighted,

        MAX(COALESCE(p95_overspend_flag_month, 0)) AS any_p95_overspend_month,
        MAX(COALESCE(raw_overspend_flag_month, 0)) AS any_raw_overspend_month,
        SUM(COALESCE(raw_overspend_flag_month, 0)) AS raw_overspend_months
  FROM k
  GROUP BY 1
),
joined AS (
  SELECT
    a.*,
    c.margin,
    c.lift_multiplier,
    c.shipping_cost_multiplier,
    c.budget_rate,
    -- handy exposures
    (a.total_spend_raw_if_all_redeem / NULLIF(a.total_budget, 0)) AS raw_redeem_exposure_vs_budget
  FROM scenario_agg a
  LEFT JOIN churn.v_7a_scenario_params c
    ON a.scenario_id = c.scenario_id
),
ranked AS (
  SELECT
    j.*,
    -- Business “winner” rank with hard gate (p95 overspend disqualifies)
    DENSE_RANK() OVER(
        ORDER BY
            CASE WHEN any_p95_overspend_month = 1 THEN 1 ELSE 0 END ASC, -- 0 first (eligible)
            total_net_ev DESC,
            roi_expected_weighted DESC,
            util_expected_weighted DESC,
            raw_overspend_months ASC
    ) AS rank_business_winner,

    DENSE_RANK() OVER (ORDER BY total_net_ev DESC) AS rank_by_total_net_ev,
    DENSE_RANK() OVER (ORDER BY roi_expected_weighted DESC) AS rank_by_roi_expected
  FROM joined j
)
SELECT *
FROM ranked;

