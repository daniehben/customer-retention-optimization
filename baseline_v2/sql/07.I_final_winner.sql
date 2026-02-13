CREATE OR REPLACE VIEW churn.v7i_scenario_winner_final AS
WITH ranked AS (
  SELECT
    r.*,
    ROW_NUMBER() OVER (
      ORDER BY
        CASE WHEN any_p95_overspend_any_month = 1 THEN 1 ELSE 0 END ASC, -- must be 0 to be eligible
        win_rate DESC,                         -- stability: wins most often
        net_ev_in_winner_months DESC,          -- value delivered in months it wins
        roi_expected_weighted_when_winner DESC,
        util_expected_weighted_when_winner DESC,
        raw_overspend_months_all ASC,          -- prefer fewer raw overspend months
        scenario_id ASC
    ) AS rn
  FROM churn.v7h_scenario_winner_rollup r
)
SELECT *
FROM ranked
WHERE rn = 1;
