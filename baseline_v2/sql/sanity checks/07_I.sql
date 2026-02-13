-- must be 1 row
SELECT COUNT(*) FROM churn.v7i_scenario_winner_final;

-- see full scoreboard ordered like the champion logic
SELECT scenario_id, months_won, win_rate, net_ev_in_winner_months,
       roi_expected_weighted_when_winner, any_p95_overspend_any_month
FROM churn.v7h_scenario_winner_rollup
ORDER BY
  CASE WHEN any_p95_overspend_any_month = 1 THEN 1 ELSE 0 END,
  win_rate DESC,
  net_ev_in_winner_months DESC;

