-- ========================
-- Baseline Truth Table v1
-- =======================


-- ===========================================
-- 1. How many anchors / customers exist?
-- ===========================================

-- Total decision rows (customer x anchor x offer)
SELECT COUNT(*) AS n_rows
FROM churn.v5_expected_value;

-- Distinct anchors (customer x anchor)
SELECT COUNT(DISTINCT (customer_unique_id, anchor_date)) AS n_anchors
FROM churn.v5_expected_value;

-- Distinct customers
SELECT COUNT(DISTINCT customer_unique_id) AS n_customers
FROM churn.v5_expected_value;



-- =====================================================================
-- 2. How many have p0_60d_final = 0 (basically dead at baseline)?
-- =====================================================================

WITH anchors AS (
  SELECT DISTINCT
      customer_unique_id,
      anchor_date,
      p0_60d_final
  FROM churn.v5_expected_value
)
SELECT
  COUNT(*) AS n_anchors,
  SUM(CASE WHEN p0_60d_final = 0 THEN 1 ELSE 0 END) AS n_dead_anchors,
  1.0 * SUM(CASE WHEN p0_60d_final = 0 THEN 1 ELSE 0 END) / COUNT(*) AS pct_dead_anchors
FROM anchors;

-- Optional distrubution 

WITH anchors AS (
  SELECT DISTINCT customer_unique_id, anchor_date, p0_60d_final
  FROM churn.v5_expected_value
)
SELECT
  CASE
    WHEN p0_60d_final = 0 THEN 'p0=0 (dead)'
    WHEN p0_60d_final < 0.05 THEN '0–5%'
    WHEN p0_60d_final < 0.10 THEN '5–10%'
    WHEN p0_60d_final < 0.20 THEN '10–20%'
    ELSE '20%+'
  END AS p0_bucket,
  COUNT(*) AS n_anchors
FROM anchors
GROUP BY 1
ORDER BY 1;



-- ============================================
-- 3. How many offers are EV > 0 by offer_type?
-- ============================================

SELECT
  offer_type,
  COUNT(*) AS n_rows,
  SUM(CASE WHEN expected_value > 0 THEN 1 ELSE 0 END) AS n_positive_ev,
  1.0 * SUM(CASE WHEN expected_value > 0 THEN 1 ELSE 0 END) / COUNT(*) AS pct_positive_ev,
  MIN(expected_value) AS min_ev,
  AVG(expected_value) AS avg_ev,
  MAX(expected_value) AS max_ev
FROM churn.v5_expected_value
GROUP BY offer_type
ORDER BY pct_positive_ev DESC, max_ev DESC;


-- ===============================================
-- 4. Total EV of selected set + total cost + ROI
-- ===============================================

SELECT
  COUNT(*) FILTER (WHERE is_selected = true) AS n_selected_rows,
  SUM(expected_value) FILTER (WHERE is_selected = true) AS total_ev,
  SUM(offer_cost) FILTER (WHERE is_selected = true) AS total_cost,
  CASE
    WHEN SUM(offer_cost) FILTER (WHERE is_selected = true) = 0 THEN NULL
    ELSE
      SUM(expected_value) FILTER (WHERE is_selected = true)
      / SUM(offer_cost) FILTER (WHERE is_selected = true)
  END AS roi_ev_per_cost
FROM budget_alloco;


-- How much budget was spent?
SELECT
  SUM(offer_cost) FILTER (WHERE is_selected = true) AS spent,
  10000.0 - SUM(offer_cost) FILTER (WHERE is_selected = true) AS remaining
FROM budget_alloco;


-- =================================================================
-- 5. Top 10 selected rows (customer, offer, EV, cost, ev_per_cost)
-- =================================================================

SELECT
  customer_unique_id,
  anchor_date,
  offer_type,
  expected_value,
  ev_per_cost,
  expected_order_value_at_anchor,
  p0_60d_final,
  p1_60d,
  delta_p,
  cumulative_cost
FROM budget_alloc
WHERE is_selected = true
ORDER BY ev_per_cost DESC NULLS LAST, expected_value DESC
LIMIT 10;



-- Top 10 not selected but high value

SELECT
  customer_unique_id,
  anchor_date,
  offer_type,
  expected_value,
  offer_cost,
  ev_per_cost,
  cumulative_cost
FROM churn.budget_alloc
WHERE is_selected = false
ORDER BY ev_per_cost DESC NULLS LAST, expected_value DESC
LIMIT 10;





