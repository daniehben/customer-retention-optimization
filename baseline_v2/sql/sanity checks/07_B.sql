SELECT scenario_id, decision_month, COUNT(*)
FROM churn.v_7a_budget_pool_by_scenario
GROUP BY 1,2
HAVING COUNT(*) > 1;


SELECT scenario_id, decision_month,
       MAX(running_spend) FILTER (WHERE selected_flag=1) AS max_spend_selected,
       MAX(budget_amount) AS budget_amount
FROM churn.v_7_b_budget_allocator_by_scenarios
GROUP BY 1,2
HAVING MAX(running_spend) FILTER (WHERE selected_flag=1) > MAX(budget_amount);


SELECT
*
FROM churn.v_7b_budget_allocator_by_scenarios
LIMIT 5


SELECT
COUNT(*) AS num_rows
FROM churn.v_7b_budget_allocator_by_scenarios


SELECT
    COUNT(*) AS num_rows,
    selected_flag
FROM churn.v_7b_budget_allocator_by_scenarios
GROUP BY selected_flag


SELECT
    COUNT(*) AS num_rows,
    offer_type
FROM churn.v_7b_budget_allocator_by_scenarios
WHERE selected_flag = 1
GROUP BY offer_type;


SELECT
  scenario_id,
  decision_month,
  COUNT(DISTINCT budget_amount) AS distinct_budgets
FROM churn.v_7_b_budget_allocator_by_scenarios
GROUP BY 1,2
HAVING COUNT(DISTINCT budget_amount) > 1;



-- DIAGNOSTICS

-- 1) Budget utilization by scenario-month (are we leaving money on the table?)

SELECT
  scenario_id,
  decision_month,
  MAX(budget_amount) AS budget_amount,
  MAX(running_spend) FILTER (WHERE selected_flag = 1) AS spend_selected,
  (MAX(budget_amount) - MAX(running_spend) FILTER (WHERE selected_flag = 1)) AS budget_left,
  (MAX(running_spend) FILTER (WHERE selected_flag = 1)) / NULLIF(MAX(budget_amount),0) AS utilization
FROM churn.v_7_b_budget_allocator_by_scenarios
GROUP BY 1,2
ORDER BY 1,2;


-- 2 — How many customers selected (volume sanity)

SELECT
  scenario_id,
  decision_month,
  COUNT(*) FILTER (WHERE selected_flag = 1) AS selected_customers,
  COUNT(*) AS eligible_rows
FROM churn.v_7_b_budget_allocator_by_scenarios
GROUP BY 1,2
ORDER BY 1,2;



-- 3) Offer mix chosen (does one offer dominate?)

SELECT
  scenario_id,
  COUNT(*) AS selected_rows,
  offer_type,
  COUNT(*) AS selected_by_offer,
  COUNT(*)::numeric / NULLIF(COUNT(*) OVER (PARTITION BY scenario_id),0) AS share
FROM churn.v_7_b_budget_allocator_by_scenarios
WHERE selected_flag = 1
GROUP BY 1,3
ORDER BY 1, share DESC;


-- 4 — Net EV distribution of selected vs not selected (are we picking the top EVs?)

SELECT
  scenario_id,
  selected_flag,
  COUNT(*) AS n,
  AVG(net_ev_scn) AS avg_ev,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_ev_scn) AS median_ev,
  MAX(net_ev_scn) AS max_ev
FROM churn.v_7_b_budget_allocator_by_scenarios
GROUP BY 1,2
ORDER BY 1,2;


-- 5 — “Budget efficiency”: EV per $ spent

SELECT
  scenario_id,
  decision_month,
  SUM(net_ev_scn) FILTER (WHERE selected_flag=1) AS total_ev,
  SUM(offer_cost_scn) FILTER (WHERE selected_flag=1) AS total_cost,
  SUM(net_ev_scn) FILTER (WHERE selected_flag=1) / NULLIF(SUM(offer_cost_scn) FILTER (WHERE selected_flag=1),0) AS ev_per_cost
FROM churn.v_7_b_budget_allocator_by_scenarios
GROUP BY 1,2
ORDER BY 1,2;


-- 6 — Spend proxy check: cost vs expected_cost

SELECT
  scenario_id,
  AVG(offer_cost_scn) FILTER (WHERE selected_flag=1) AS avg_cost_raw,
  AVG(expected_offer_cost_scn) FILTER (WHERE selected_flag=1) AS avg_cost_expected,
  AVG(offer_cost_scn - expected_offer_cost_scn) FILTER (WHERE selected_flag=1) AS avg_gap
FROM churn.v_7_b_budget_allocator_by_scenarios
GROUP BY 1
ORDER BY 1;

-- 7 — Scenario sensitivity: does selection actually change?
SELECT
  scenario_id,
  COUNT(*) FILTER (WHERE selected_flag=1) AS selected_n
FROM churn.v_7_b_budget_allocator_by_scenarios
GROUP BY 1
ORDER BY 2 DESC;




-- TESTING WHETHER TO USE raw cost or expected cost

-- Option A (Finance-safe / worst-case budget): keep raw cost.
-- Then your KPI queries should also talk about raw spend.

-- Option B (Expected monthly spend budget): use expected cost.

WITH ranked AS (
  SELECT
    scenario_id,
    decision_month,
    customer_unique_id,
    offer_cost_scn,
    expected_offer_cost_scn,
    net_ev_scn,
    ROW_NUMBER() OVER (
      PARTITION BY scenario_id, decision_month
      ORDER BY net_ev_scn DESC, offer_cost_scn ASC
    ) AS rnk
  FROM churn.v_7_b_budget_allocator_by_scenarios
  WHERE candidate_flag = 1
    AND final_pass = 1
    AND net_ev_scn > 0
),
spend AS (
  SELECT
    r.*,
    SUM(offer_cost_scn) OVER (PARTITION BY scenario_id, decision_month ORDER BY rnk) AS spend_raw,
    SUM(expected_offer_cost_scn) OVER (PARTITION BY scenario_id, decision_month ORDER BY rnk) AS spend_exp
  FROM ranked r
)
SELECT
  s.scenario_id,
  s.decision_month,
  b.budget_amount,
  COUNT(*) FILTER (WHERE s.spend_raw <= b.budget_amount) AS selected_raw_budget,
  COUNT(*) FILTER (WHERE s.spend_exp <= b.budget_amount) AS selected_expected_budget
FROM spend s
JOIN churn.v_7a_budget_pool_by_scenario b
  ON s.scenario_id = b.scenario_id
 AND s.decision_month = b.decision_month
GROUP BY 1,2,3
ORDER BY 1,2;

SELECT scenario_id, offer_type, COUNT(*)
FROM churn.v_7a_offer_ev_by_scenario
GROUP BY 1,2;


SELECT
  scenario_id,
  AVG(offer_cost_scn) FILTER (WHERE selected_flag=1) AS avg_raw,
  AVG(expected_offer_cost_scn) FILTER (WHERE selected_flag=1) AS avg_expected,
  AVG(p_offer_scn) FILTER (WHERE selected_flag=1) AS avg_p
FROM churn.v6_7_b_budget_allocator_by_scenarios
GROUP BY 1
ORDER BY 1;

SELECT
  scenario_id,
  decision_month,
  MAX(running_spend_expected) FILTER (WHERE selected_flag=1) AS spend_expected,
  MAX(budget_amount) AS budget
FROM churn.v6_7_b_budget_allocator_by_scenarios
GROUP BY 1,2
HAVING MAX(running_spend_expected) FILTER (WHERE selected_flag=1) > MAX(budget_amount);

SELECT
  scenario_id,
  decision_month,
  MAX(running_spend_raw) FILTER (WHERE selected_flag=1) AS spend_raw,
  MAX(budget_amount) AS budget,
  (MAX(running_spend_raw) FILTER (WHERE selected_flag=1) / NULLIF(MAX(budget_amount),0)) AS raw_to_budget
FROM churn.v6_7_b_budget_allocator_by_scenarios
GROUP BY 1,2
ORDER BY raw_to_budget DESC;


SELECT scenario_id, decision_month, COUNT(*) AS rows_missing_budget
FROM churn.v2_7_b_budget_allocator_by_scenarios
WHERE budget_amount IS NULL OR effective_budget_amount IS NULL
GROUP BY 1,2
ORDER BY 1,2;

SELECT
  scenario_id,
  decision_month,
  MAX(scenario_month_has_raw_overspend_flag) AS overspend_no_buffer,
  MAX(scenario_month_has_raw_overspend_buffered_flag) AS overspend_with_buffer,
  COUNT(*) FILTER (WHERE selected_flag_no_buffer = 1) AS selected_no_buffer,
  COUNT(*) FILTER (WHERE selected_flag = 1) AS selected_with_buffer
FROM churn.v2_7_b_budget_allocator_by_scenarios
GROUP BY 1,2
ORDER BY 1,2;


SELECT
  scenario_id,
  decision_month,
  budget_amount,
  risk_buffer_amount,
  effective_budget_amount,
  missing_p_offer_rows
FROM churn.v_7_a_budget_pool_by_scenario_effective
ORDER BY 1,2;


SELECT
  scenario_id,
  decision_month,
  COUNT(*) FILTER (WHERE selected_flag_no_buffer=1) AS selected_no_buffer,
  COUNT(*) FILTER (WHERE selected_flag_with_buffer=1) AS selected_with_buffer,
  COUNT(*) FILTER (WHERE cut_by_buffer_flag=1) AS cut_by_buffer
FROM churn.v3_7_b_budget_allocator_by_scenarios
GROUP BY 1,2
ORDER BY 1,2;

SELECT
  scenario_id,
  decision_month,
  MAX(overspend_no_buffer_flag)  AS overspend_no_buffer,
  MAX(overspend_with_buffer_flag) AS overspend_with_buffer
FROM churn.v3_7_b_budget_allocator_by_scenarios
GROUP BY 1,2
ORDER BY 1,2;


SELECT scenario_id, decision_month,
       MAX(p95_overspend_p95_buffer_flag) AS any_p95_overspend
FROM churn.v4_7_b_budget_allocator_by_scenarios
GROUP BY 1,2
HAVING MAX(p95_overspend_p95_buffer_flag) = 1;


SELECT scenario_id, decision_month,
       MAX(raw_overspend_p95_buffer_flag) AS any_raw_overspend
FROM churn.v4_7_b_budget_allocator_by_scenarios
GROUP BY 1,2
ORDER BY 3 DESC;



