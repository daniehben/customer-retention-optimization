-- ===============================================
-- How many customers are selected?
-- ==============================================

SELECT
  COUNT(*) FILTER (WHERE is_selected = true) AS selected_customers,
  COUNT(*) AS total_customers,
  1.0 * COUNT(*) FILTER (WHERE is_selected = true) / COUNT(*) AS pct_selected
FROM budget_alloc;


-- ===============================================
-- Budget Utilization
-- ==============================================

SELECT 
    SUM(offer_cost) FILTER (WHERE is_selected = true) AS spent,
    10000.0 - SUM(offer_cost) FILTER (WHERE is_selected = true) AS remaining
FROM churn.budget_alloc;


-- ===============================================
-- What offers are being chosen?
-- ==============================================

SELECT
  offer_type,
  COUNT(*) AS count_selected,
  AVG(offer_cost) AS avg_cost,
  AVG(expected_value) AS avg_ev
FROM churn.budget_alloc
WHERE is_selected = true
GROUP BY offer_type
ORDER BY count_selected DESC;


-- ===============================================
-- EV distribution for selected vs not selected
-- ==============================================

SELECT
  is_selected,
  MIN(expected_value) AS min_ev,
  AVG(expected_value) AS avg_ev,
  MAX(expected_value) AS max_ev,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY expected_value) AS median_ev
FROM churn.budget_alloc
GROUP BY is_selected;


-- ===============================================
-- Cost distribution for selected vs not
-- ==============================================

SELECT
    is_selected,
    MIN(offer_cost) AS min_cost,
    AVG(offer_cost) AS avg_cost,
    MAX(offer_cost) AS max_cost,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY offer_cost) AS median_cost
FROM churn.budget_alloc
GROUP BY is_selected;


-- ===============================================
-- Efficiency distribution for selected vs not
-- ==============================================

SELECT
    is_selected,
    MIN(ev_per_cost) AS min_eff,
    AVG(ev_per_cost) AS avg_eff,
    MAX(ev_per_cost) AS max_eff,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ev_per_cost) AS median_eff
FROM churn.budget_alloc
GROUP BY is_selected;


-- ======================================================
-- Who are the top 20 selected customers (audit sample)
-- ======================================================

SELECT
    customer_unique_id,
    anchor_date,
    offer_type,
    offer_cost,
    expected_value,
    ev_per_cost,
    cumulative_cost
FROM churn.budget_alloc
WHERE is_selected = true
ORDER BY ev_per_cost DESC NULLS LAST, expected_value DESC
LIMIT 20;

