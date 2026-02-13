SELECT
  a.scenario_id, a.decision_month,
  COUNT(*) FILTER (WHERE a.selected_flag_p95_buffer=1) AS allocator_selected,
  k.selected_customers AS kpi_selected
FROM churn.v4_7_b_budget_allocator_by_scenarios a
JOIN churn.v7d_decision_kpis_scenario_month k
  USING (scenario_id, decision_month)
GROUP BY 1,2,4
HAVING COUNT(*) FILTER (WHERE a.selected_flag_p95_buffer=1) <> k.selected_customers;

SELECT *
FROM churn.v7d_decision_kpis_scenario_month
WHERE p95_overspend_flag_month = 1;


SELECT *
FROM churn.v7d_decision_kpis_scenario_month
WHERE raw_overspend_flag_month = 1
ORDER BY scenario_id, decision_month;
