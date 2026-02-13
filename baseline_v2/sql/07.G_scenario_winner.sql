CREATE OR REPLACE VIEW churn.v7g_scenario_rollup_month AS
WITH k AS (
  SELECT *
  FROM churn.v7d_decision_kpis_scenario_month
),
joined AS (
  SELECT
    k.*,
    p.margin,
    p.lift_multiplier,
    p.shipping_cost_multiplier,
    p.budget_rate,
    -- Helpful exposure metric: "if everyone redeems, how bad could it get vs budget?"
    (k.spend_raw_if_all_redeem_selected / NULLIF(k.budget_amount, 0)) AS raw_redeem_exposure_vs_budget
  FROM k
  LEFT JOIN churn.v_7a_scenario_params p
    ON k.scenario_id = p.scenario_id
),
ranked AS (
  SELECT
    j.*,
    -- ✅ Business winner rank (hard gate: p95 overspend disqualifies)
    DENSE_RANK() OVER (
      PARTITION BY decision_month
      ORDER BY
        CASE WHEN p95_overspend_flag_month = 1 THEN 1 ELSE 0 END ASC, -- 0 first (eligible)
        net_ev_selected DESC,
        roi_expected DESC,
        budget_util_expected DESC,
        raw_overspend_flag_month ASC,             -- prefer no raw overspend
        raw_redeem_exposure_vs_budget ASC         -- prefer lower tail exposure
    ) AS rank_business_winner,
    -- Optional “single-metric” ranks (useful for explanation)
    DENSE_RANK() OVER (PARTITION BY decision_month ORDER BY net_ev_selected DESC) AS rank_by_net_ev,
    DENSE_RANK() OVER (PARTITION BY decision_month ORDER BY roi_expected DESC) AS rank_by_roi,
    DENSE_RANK() OVER (PARTITION BY decision_month ORDER BY budget_util_expected DESC) AS rank_by_util_expected
  FROM joined j
)
SELECT *
FROM ranked;

CREATE OR REPLACE VIEW churn.v7g_scenario_winner_month AS
SELECT *
FROM churn.v7g_scenario_rollup_month
WHERE rank_business_winner = 1;


