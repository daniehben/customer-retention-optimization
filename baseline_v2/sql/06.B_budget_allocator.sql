CREATE OR REPLACE VIEW churn.v_6_phase6b_budgeted_allocation_2pct AS
WITH base AS(
    SELECT
        *,
        COALESCE(budget_gp_2pct,0.0) AS budget_amount
    FROM churn.v_6_phase6_a_budget_base 
    WHERE final_pass = 1
),
ranked AS(
    SELECT 
    b.*,
    ROW_NUMBER() OVER (
        PARTITION BY decision_month
        ORDER BY net_ev_default DESC, offer_cost ASC
    ) AS priority_rank
    FROM base b
    WHERE candidate_flag = 1
        AND COALESCE(net_ev_default, 0.0) > 0.0
        AND COALESCE(offer_cost, 0.0) > 0.0
),scored AS(
    SELECT
    r.*,
    SUM(offer_cost) OVER (
        PARTITION BY decision_month
        ORDER BY priority_rank
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_spend
    FROM ranked r
)
SELECT
    s.*,
    CASE
        WHEN running_spend <= budget_amount THEN 1
        ELSE 0
    END AS selected_flag,
    (budget_amount - running_spend) AS budget_remaining_after_row
FROM scored s


CREATE OR REPLACE VIEW churn.v_6_phase6b_allocation_summary_2pct AS
SELECT
  decision_month,
  COUNT(*) AS candidates,
  SUM(selected_flag) AS selected,
  SUM(offer_cost) AS total_candidate_cost,
  SUM(CASE WHEN selected_flag = 1 THEN offer_cost ELSE 0 END) AS allocated_cost,
  MAX(budget_amount) AS budget_amount,
  SUM(CASE WHEN selected_flag = 1 THEN net_ev_default ELSE 0 END) AS total_net_ev_selected
FROM churn.v_6_phase6b_budgeted_allocation_2pct
GROUP BY 1
ORDER BY 1;

CREATE OR REPLACE VIEW churn.v_6_phase6b_budget_feasibility_check AS
SELECT
  decision_month,
  MIN(offer_cost) FILTER (WHERE candidate_flag = 1 AND COALESCE(net_ev_default,0) > 0) AS min_candidate_cost,
  MAX(budget_gp_2pct) AS budget_2pct,
  CASE
    WHEN MIN(offer_cost) FILTER (WHERE candidate_flag = 1 AND COALESCE(net_ev_default,0) > 0) IS NULL THEN 'no_candidates'
    WHEN MIN(offer_cost) FILTER (WHERE candidate_flag = 1 AND COALESCE(net_ev_default,0) > 0) > MAX(budget_gp_2pct) THEN 'budget_too_low'
    ELSE 'budget_can_fund_at_least_one'
  END AS feasibility_status
FROM churn.v_6_phase6_a_budget_base
GROUP BY 1
ORDER BY 1;




CREATE OR REPLACE VIEW churn.v_6_phase6b_budgeted_allocation_5pct AS
WITH base AS(
    SELECT
        *,
        COALESCE(budget_gp_2pct,0.0)*2.5 AS budget_amount
    FROM churn.v_6_phase6_a_budget_base 
    WHERE final_pass = 1
),
ranked AS(
    SELECT 
    b.*,
    ROW_NUMBER() OVER (
        PARTITION BY decision_month
        ORDER BY net_ev_default DESC, offer_cost ASC
    ) AS priority_rank
    FROM base b
    WHERE candidate_flag = 1
        AND COALESCE(net_ev_default, 0.0) > 0.0
        AND COALESCE(offer_cost, 0.0) > 0.0

),
scored AS(
    SELECT
    r.*,
    SUM(offer_cost) OVER (
        PARTITION BY decision_month
        ORDER BY priority_rank
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_spend
    FROM ranked r
)
SELECT
    s.*,
    CASE
        WHEN running_spend <= budget_amount THEN 1
        ELSE 0
    END AS selected_flag,
    (budget_amount - running_spend) AS budget_remaining_after_row
FROM scored s





CREATE OR REPLACE VIEW churn.v_6_phase6b_budgeted_allocation_10pct AS
WITH base AS(
    SELECT
        *,
        COALESCE(budget_gp_2pct,0.0)*5 AS budget_amount
    FROM churn.v_6_phase6_a_budget_base 
    WHERE final_pass = 1
),
ranked AS(
    SELECT 
    b.*,
    ROW_NUMBER() OVER (
        PARTITION BY decision_month
        ORDER BY net_ev_default DESC, offer_cost ASC
    ) AS priority_rank
    FROM base b
    WHERE candidate_flag = 1
        AND COALESCE(net_ev_default, 0.0) > 0.0
        AND COALESCE(offer_cost, 0.0) > 0.0

),
scored AS(
    SELECT
    r.*,
    SUM(offer_cost) OVER (
        PARTITION BY decision_month
        ORDER BY priority_rank
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_spend
    FROM ranked r
)
SELECT
    s.*,
    CASE
        WHEN running_spend <= budget_amount THEN 1
        ELSE 0
    END AS selected_flag,
    (budget_amount - running_spend) AS budget_remaining_after_row
FROM scored s




CREATE OR REPLACE VIEW churn.v_6_phase6b_budgeted_allocation_20pct AS
WITH base AS(
    SELECT
        *,
        COALESCE(budget_gp_2pct,0.0)*10 AS budget_amount
    FROM churn.v_6_phase6_a_budget_base 
    WHERE final_pass = 1
),
ranked AS(
    SELECT 
    b.*,
    ROW_NUMBER() OVER (
        PARTITION BY decision_month
        ORDER BY net_ev_default DESC, offer_cost ASC
    ) AS priority_rank
    FROM base b
    WHERE candidate_flag = 1
        AND COALESCE(net_ev_default, 0.0) > 0.0
        AND COALESCE(offer_cost, 0.0) > 0.0

),
scored AS(
    SELECT
    r.*,
    SUM(offer_cost) OVER (
        PARTITION BY decision_month
        ORDER BY priority_rank
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_spend
    FROM ranked r
)
SELECT
    s.*,
    CASE
        WHEN running_spend <= budget_amount THEN 1
        ELSE 0
    END AS selected_flag,
    (budget_amount - running_spend) AS budget_remaining_after_row
FROM scored s





CREATE OR REPLACE VIEW churn.v_6_phase6b_budgeted_allocation_30pct AS
WITH base AS(
    SELECT
        *,
        COALESCE(budget_gp_2pct,0.0)*15 AS budget_amount
    FROM churn.v_6_phase6_a_budget_base 
    WHERE final_pass = 1
),
ranked AS(
    SELECT 
    b.*,
    ROW_NUMBER() OVER (
        PARTITION BY decision_month
        ORDER BY net_ev_default DESC, offer_cost ASC
    ) AS priority_rank
    FROM base b
    WHERE candidate_flag = 1
        AND COALESCE(net_ev_default, 0.0) > 0.0
        AND COALESCE(offer_cost, 0.0) > 0.0

),
scored AS(
    SELECT
    r.*,
    SUM(offer_cost) OVER (
        PARTITION BY decision_month
        ORDER BY priority_rank
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_spend
    FROM ranked r
)
SELECT
    s.*,
    CASE
        WHEN running_spend <= budget_amount THEN 1
        ELSE 0
    END AS selected_flag,
    (budget_amount - running_spend) AS budget_remaining_after_row
FROM scored s



-- SCENARIO COMPARISON


CREATE OR REPLACE VIEW churn.v_6_phase6b_scenario_comparison AS
WITH scenario_summaries AS (
  -- 2%
  SELECT
    '2pct'::text AS scenario,
    decision_month,
    COUNT(*) AS candidates,
    SUM(selected_flag) AS selected,
    COALESCE(SUM(offer_cost), 0.0) AS total_candidate_cost,
    COALESCE(SUM(CASE WHEN selected_flag = 1 THEN offer_cost ELSE 0 END), 0.0) AS allocated_cost,
    MAX(budget_amount) AS budget_amount,
    COALESCE(SUM(CASE WHEN selected_flag = 1 THEN net_ev_default ELSE 0 END), 0.0) AS total_net_ev_selected
  FROM churn.v_6_phase6b_budgeted_allocation_2pct
  GROUP BY 2

  UNION ALL
  -- 5%
  SELECT
    '5pct'::text AS scenario,
    decision_month,
    COUNT(*) AS candidates,
    SUM(selected_flag) AS selected,
    COALESCE(SUM(offer_cost), 0.0) AS total_candidate_cost,
    COALESCE(SUM(CASE WHEN selected_flag = 1 THEN offer_cost ELSE 0 END), 0.0) AS allocated_cost,
    MAX(budget_amount) AS budget_amount,
    COALESCE(SUM(CASE WHEN selected_flag = 1 THEN net_ev_default ELSE 0 END), 0.0) AS total_net_ev_selected
  FROM churn.v_6_phase6b_budgeted_allocation_5pct
  GROUP BY 2

  UNION ALL
  -- 10%
  SELECT
    '10pct'::text AS scenario,
    decision_month,
    COUNT(*) AS candidates,
    SUM(selected_flag) AS selected,
    COALESCE(SUM(offer_cost), 0.0) AS total_candidate_cost,
    COALESCE(SUM(CASE WHEN selected_flag = 1 THEN offer_cost ELSE 0 END), 0.0) AS allocated_cost,
    MAX(budget_amount) AS budget_amount,
    COALESCE(SUM(CASE WHEN selected_flag = 1 THEN net_ev_default ELSE 0 END), 0.0) AS total_net_ev_selected
  FROM churn.v_6_phase6b_budgeted_allocation_10pct
  GROUP BY 2

  UNION ALL
  -- 20%
  SELECT
    '20pct'::text AS scenario,
    decision_month,
    COUNT(*) AS candidates,
    SUM(selected_flag) AS selected,
    COALESCE(SUM(offer_cost), 0.0) AS total_candidate_cost,
    COALESCE(SUM(CASE WHEN selected_flag = 1 THEN offer_cost ELSE 0 END), 0.0) AS allocated_cost,
    MAX(budget_amount) AS budget_amount,
    COALESCE(SUM(CASE WHEN selected_flag = 1 THEN net_ev_default ELSE 0 END), 0.0) AS total_net_ev_selected
  FROM churn.v_6_phase6b_budgeted_allocation_20pct
  GROUP BY 2
),
scored AS (
  SELECT
    s.*,
    CASE WHEN budget_amount > 0 THEN allocated_cost / budget_amount ELSE NULL END AS budget_utilization,
    CASE WHEN candidates > 0 THEN selected::double precision / candidates ELSE NULL END AS selection_rate,

    -- ROI on actual spend (how much net EV per $ we spent)
    CASE WHEN allocated_cost > 0 THEN total_net_ev_selected / allocated_cost ELSE NULL END AS roi_ev_per_cost,

    -- ensure scenario order for incremental calcs
    CASE
      WHEN scenario = '2pct' THEN 2
      WHEN scenario = '5pct' THEN 5
      WHEN scenario = '10pct' THEN 10
      WHEN scenario = '20pct' THEN 20
      ELSE NULL
    END AS scenario_pct
  FROM scenario_summaries s
),
with_deltas AS (
  SELECT
    *,
    LAG(allocated_cost) OVER (PARTITION BY decision_month ORDER BY scenario_pct) AS prev_allocated_cost,
    LAG(total_net_ev_selected) OVER (PARTITION BY decision_month ORDER BY scenario_pct) AS prev_total_net_ev
  FROM scored
)
SELECT
  scenario,
  decision_month,
  candidates,
  selected,
  total_candidate_cost,
  allocated_cost,
  budget_amount,
  total_net_ev_selected,
  budget_utilization,
  selection_rate,
  roi_ev_per_cost,

  -- incremental spend & incremental EV vs previous scenario
  (allocated_cost - prev_allocated_cost) AS delta_cost_vs_prev,
  (total_net_ev_selected - prev_total_net_ev) AS delta_ev_vs_prev,

  -- incremental ROI: extra EV per extra $ when moving up budget
  CASE
    WHEN prev_allocated_cost IS NULL THEN NULL
    WHEN (allocated_cost - prev_allocated_cost) <= 0 THEN NULL
    ELSE (total_net_ev_selected - prev_total_net_ev) / (allocated_cost - prev_allocated_cost)
  END AS incremental_roi_ev_per_cost

FROM with_deltas
ORDER BY decision_month, scenario_pct;




CREATE OR REPLACE VIEW churn.v_6_phase6b_scenario_export AS
WITH monthly AS (
  SELECT
    scenario,
    decision_month,
    candidates,
    selected,
    total_candidate_cost,
    allocated_cost,
    budget_amount,
    total_net_ev_selected,
    budget_utilization,
    selection_rate,
    roi_ev_per_cost,
    delta_cost_vs_prev,
    delta_ev_vs_prev,
    incremental_roi_ev_per_cost
  FROM churn.v_6_phase6b_scenario_comparison
),
totals AS (
  SELECT
    scenario,
    NULL::timestamptz AS decision_month,
    SUM(candidates) AS candidates,
    SUM(selected) AS selected,
    SUM(total_candidate_cost) AS total_candidate_cost,
    SUM(allocated_cost) AS allocated_cost,
    SUM(budget_amount) AS budget_amount,
    SUM(total_net_ev_selected) AS total_net_ev_selected,
    CASE WHEN SUM(budget_amount) > 0 THEN SUM(allocated_cost)/SUM(budget_amount) ELSE NULL END AS budget_utilization,
    CASE WHEN SUM(candidates) > 0 THEN SUM(selected)::double precision/SUM(candidates) ELSE NULL END AS selection_rate,
    CASE WHEN SUM(allocated_cost) > 0 THEN SUM(total_net_ev_selected)/SUM(allocated_cost) ELSE NULL END AS roi_ev_per_cost,
    NULL::double precision AS delta_cost_vs_prev,
    NULL::double precision AS delta_ev_vs_prev,
    NULL::double precision AS incremental_roi_ev_per_cost
  FROM monthly
  GROUP BY 1
)
SELECT
  'monthly'::text AS row_type,
  *
FROM monthly

UNION ALL

SELECT
  'total'::text AS row_type,
  *
FROM totals
ORDER BY
  scenario,
  row_type DESC,       -- total first if you prefer; change to ASC for monthly first
  decision_month;


SELECT * FROM churn.v_6_phase6b_scenario_export;
