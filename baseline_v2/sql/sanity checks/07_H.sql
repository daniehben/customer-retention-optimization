-- must be exactly 1 row
SELECT COUNT(*) FROM churn.v7h_scenario_winner_final;

-- should match the top row in v7f ordering
SELECT scenario_id, rank_business_winner, total_net_ev, roi_expected_weighted
FROM churn.v7h_scenario_winner_final;
