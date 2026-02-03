-- FILE 9_expected_value.sql SANITY CHECKS 

SELECT
  (SELECT COUNT(*) FROM churn.v5_expected_value_by_offer) AS ev_rows,
  (SELECT COUNT(*) FROM churn.v5_offer_costs) AS offer_rows;



SELECT
  SUM(CASE WHEN expected_order_value_safe IS NULL THEN 1 ELSE 0 END) AS null_eov,
  SUM(CASE WHEN offer_cost IS NULL THEN 1 ELSE 0 END) AS null_cost,
  SUM(CASE WHEN delta_p IS NULL THEN 1 ELSE 0 END) AS null_delta,
  SUM(CASE WHEN expected_value IS NULL THEN 1 ELSE 0 END) AS null_ev
FROM churn.v5_expected_value_by_offer;


-- EV sanity check for 'no_offer' rows - EXPECTED = 0
SELECT COUNT(*) AS bad_rows
FROM churn.v5_expected_value_by_offer
WHERE offer_type = 'no_offer'
  AND (ABS(expected_value) > 1e-6 OR ABS(offer_cost) > 1e-6 OR ABS(delta_p) > 1e-6);


-- =========================
-- EV distribution by offer
-- Purpose: confirm that:
-- discounts have higher variance
-- free shipping behaves non-uniformly
-- no_offer is flat at 0
-- ========================

SELECT
  offer_type,
  MIN(expected_value) AS min_ev,
  AVG(expected_value) AS avg_ev,
  MAX(expected_value) AS max_ev
FROM churn.v5_expected_value
GROUP BY offer_type;

-- ========================
-- % positive EV by offer
-- Purpose: intuition check before optimization.
-- =======================
SELECT
  offer_type,
  AVG(CASE WHEN expected_value > 0 THEN 1.0 ELSE 0.0 END) AS pct_positive
FROM churn.v5_expected_value
GROUP BY offer_type;


-- ==========
-- How many unique p0 values exist?
-- ==========

SELECT
  COUNT(*) AS n_rows,
  COUNT(DISTINCT p0_60d_final) AS n_distinct_p0,
  MIN(p0_60d_final) AS min_p0,
  MAX(p0_60d_final) AS max_p0
FROM churn.v5_expected_value;

-- ==========
-- Show the top repeated p0 values
-- ==========

SELECT
  p0_60d_final,
  COUNT(*) AS n
FROM churn.v5_expected_value
GROUP BY 1
ORDER BY n DESC
LIMIT 20;


-- ==========
-- Check whether p0 varies by customer (it should)
-- ==========

SELECT
  customer_unique_id,
  COUNT(DISTINCT p0_60d_final) AS distinct_p0_values_for_customer
FROM churn.v5_expected_value
GROUP BY 1
ORDER BY distinct_p0_values_for_customer DESC
LIMIT 20;

