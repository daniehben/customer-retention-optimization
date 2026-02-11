-- ===============================================
-- 5. C Analysis: Why are all EVs 0/negative?
-- ===============================================


-- 1) Confirm whether it’s “all negative” vs “mostly zero because delta_p=0”

SELECT
    offer_type,
    SUM((delta_p_default = 0)::int) AS n_delta_p_zero,
    AVG(delta_p_default) AS avg_delta_p,
    MIN(delta_p_default) AS min_delta_p,
    MAX(delta_p_default) AS max_delta_p,
    AVG(net_ev_default) AS avg_net_ev,
    MIN(net_ev_default) AS min_net_ev,
    MAX(net_ev_default) AS max_net_ev
FROM churn.v6_phase5_c_offer_ev_spine
GROUP BY 1
ORDER BY 1;

-- 2) Check if your “benefit” driver is NULL/0

SELECT
  COUNT(*) AS n,
  SUM((aov_pre_anchor IS NULL)::int) AS n_aov_null,
  MIN(aov_pre_anchor) AS min_aov,
  AVG(aov_pre_anchor) AS avg_aov,
  MAX(aov_pre_anchor) AS max_aov
FROM churn.v6_phase5_b_eligibility;

-- 3) Look directly at the EV components to see which term kills it

SELECT
  offer_type,
  AVG(expected_offer_cost) AS avg_expected_cost,
  AVG(offer_cost) AS avg_offer_cost,
  AVG(delta_p_default) AS avg_delta_p,
  AVG(net_ev_default) AS avg_net_ev
FROM churn.v6_phase5_c_offer_ev_spine
GROUP BY 1
ORDER BY avg_net_ev;


-- LIFT TABLE JOIN MISMATCH CHECK

SELECT
  offer_type,
  COUNT(*) AS n,
  SUM((lift_default IS NULL)::int) AS n_lift_null
FROM churn.v6_phase5_c_offer_ev_spine
GROUP BY 1
ORDER BY 1;


-- P0 IS NULL OR 0 FOR EVERYONE

SELECT
  COUNT(*) AS n,
  SUM((p_base_default IS NULL)::int) AS n_p0_null,
  AVG(p_base_default) AS avg_p0,
  MIN(p_base_default) AS min_p0,
  MAX(p_base_default) AS max_p0
FROM churn.v6_4_offer_spine;  -- or wherever p0 lives


-- ACCIDENTLY ROUNDING DELTA

SELECT
  offer_type,
  p_base_default,
  lift_default,
  p_offer_default,
  delta_p_default
FROM churn.v6_offer_ev
WHERE offer_type <> 'no_offer'
LIMIT 50;



-- Step A — inspect the EV view itself (one row, all fields)

SELECT *
FROM churn.v6_offer_ev
WHERE offer_type <> 'no_offer'
LIMIT 20;


-- Step B — prove whether it’s “join problem” or “math problem”

SELECT
  offer_type,
  AVG(COALESCE(lift_default, 0)) AS avg_lift,
  MIN(COALESCE(lift_default, 0)) AS min_lift,
  MAX(COALESCE(lift_default, 0)) AS max_lift
FROM churn.v6_offer_ev
GROUP BY 1
ORDER BY 1;



SELECT
    COUNT(*) AS n,
    p_base_default
FROM churn.v6_phase_5_c_offer_ev_spine
GROUP BY 2


SELECT
    COUNT(*) AS n,
    lift_default,
    risk_band,
    offer_type
FROM churn.v6_phase_5_c_offer_ev_spine
GROUP BY 2,3,4


SELECT *
FROM churn.v6_p_base_by_risk_band
ORDER BY risk_band;


SELECT
  risk_band,
  COUNT(*) AS n,
  MIN(days_to_next_order) AS min_d,
  MAX(days_to_next_order) AS max_d,
  AVG((days_to_next_order IS NOT NULL)::int) AS pct_any_next,
  AVG((days_to_next_order IS NOT NULL AND days_to_next_order <= 180)::int) AS p_180
FROM churn.v6_baseline_risk_segment
GROUP BY 1
ORDER BY 1;
