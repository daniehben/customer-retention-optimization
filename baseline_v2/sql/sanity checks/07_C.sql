SELECT scenario_id, decision_month, customer_unique_id, anchor_date, COUNT(*)
FROM churn.v7c_decision_output_customers
GROUP BY 1,2,3,4
HAVING COUNT(*) > 1;

SELECT
  COUNT(*) FILTER (WHERE final_selected_flag IS NULL) AS nulls,
  COUNT(*) FILTER (WHERE final_selected_flag NOT IN (0,1)) AS weird_values
FROM churn.v7c_decision_output_customers;


-- 1) Uniqueness: should be 1 row per (scenario, customer, anchor_date)
SELECT scenario_id, customer_unique_id, anchor_date, COUNT(*)
FROM churn.v7c_decision_output_customers
GROUP BY 1,2,3
HAVING COUNT(*) > 1;

-- 2) Policy is actually enforced: no selected rows should breach p95 budget
SELECT *
FROM churn.v7c_decision_output_customers
WHERE final_selected_flag = 1
  AND running_spend_p95 > budget_amount;

-- 3) Coverage sanity: how many selected per scenario-month?
SELECT scenario_id, decision_month,
       COUNT(*) FILTER (WHERE final_selected_flag = 1) AS selected_customers
FROM churn.v7c_decision_output_customers
GROUP BY 1,2
ORDER BY 1,2;


SELECT 
*
FROM churn.v1_7_c_decision_output_customers
LIMIT 2;