SELECT
  COUNT(*) AS rows_checked,
  AVG(ABS(net_ev_scn - net_ev_default)) AS avg_abs_diff,
  MAX(ABS(net_ev_scn - net_ev_default)) AS max_abs_diff
FROM churn.v_7a_offer_ev_by_scenario scn
JOIN churn.v_6_offer_ev d
  USING (customer_unique_id, anchor_date, risk_segment, offer_type)
WHERE scn.scenario_id = 'BASE';


SELECT
  offer_type,
  AVG(offer_cost_scn - offer_cost) AS avg_cost_delta
FROM churn.v_7a_offer_ev_by_scenario
WHERE scenario_id = 'SHIP_120'
GROUP BY 1
ORDER BY 1;


SELECT
  scenario_id,
  AVG(expected_margin_value_scn / NULLIF(expected_margin_value,0)) AS avg_benefit_scale
FROM churn.v_7a_offer_ev_by_scenario
WHERE scenario_id IN ('BASE','MARGIN_20','MARGIN_30')
GROUP BY 1
ORDER BY 1;

SELECT
  decision_month,
  MAX(period_expected_gp) FILTER (WHERE scenario_id='BASE') AS gp_base,
  MAX(period_expected_gp) FILTER (WHERE scenario_id='MARGIN_20') AS gp_20,
  MAX(period_expected_gp) FILTER (WHERE scenario_id='MARGIN_30') AS gp_30
FROM churn.v_7a_budget_pool_by_scenario
GROUP BY 1
ORDER BY 1;


SELECT * 
FROM v_7a_budget_pool_by_scenario
LIMIT 5

SELECT
COUNT(*) AS num_rows
FROM v_7a_budget_pool_by_scenario


SELECT * 
FROM v_7a_offer_ev_by_scenario
LIMIT 5


SELECT
COUNT(*) AS num_rows
FROM v_7a_offer_ev_by_scenario