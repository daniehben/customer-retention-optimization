-- Total decision rows (customer x anchor x offer)
SELECT COUNT(*) AS n_anchors
FROM churn.v5_p0_customer_baseline;

SELECT COUNT(DISTINCT customer_unique_id) AS n_customers
FROM churn.v5_p0_customer_baseline


SELECT AVG(repurchased_60d)
FROM churn.v5_p0_outcomes_60d;

SELECT 
    customer_unique_id,
    anchor_date
FROM churn.v5_p0_customer_baseline 
GROUP BY 1, 2
HAVING COUNT(*) > 1


SELECT 
    COUNT(DISTINCT anchor_date) AS n_anchors_per_customer,
    MIN(anchor_date) AS min_anchor_date,
    MAX(anchor_date) AS max_anchor_date
FROM churn.v5_p0_customer_baseline



SELECT 
a.customer_unique_id,
repurchased_60d,
n_orders_pre_anchor
FROM churn.v5_p0_outcomes_60d a
LEFT JOIN churn.v5_customer_value_at_anchor b
    ON a.customer_unique_id = b.customer_unique_id
    AND a.anchor_date = b.anchor_date
GROUP BY 1,3


SELECT 
    COUNT(*) AS n_customers,
    COUNT(DISTINCT customer_unique_id) AS n_distinct_customers,
    COUNT(DISTINCT anchor_date) AS n_distinct_anchors,
    COUNT(DISTINCT offer_type) AS n_distinct_offer_types
FROM churn.v5_offer_costs


SELECT 
    COUNT(*) AS n_customers,
    COUNT(DISTINCT customer_unique_id) AS n_distinct_customers,
    COUNT(DISTINCT anchor_date) AS n_distinct_anchors,
    COUNT(DISTINCT offer_type) AS n_distinct_offer_types
FROM churn.v5_customer_p1_by_offer


SELECT 
    COUNT(*) AS n_customers,
    COUNT(DISTINCT customer_unique_id) AS n_distinct_customers,
    COUNT(DISTINCT anchor_date) AS n_distinct_anchors,
    COUNT(DISTINCT offer_type) AS n_distinct_offer_types
FROM churn.v5_expected_value



SELECT
    COUNT(DISTINCT p0_60d_final) AS n_distinct_p0_values
FROM churn.v5_p0_customer_baseline



SELECT
  COUNT(*) AS customers_with_multiple_anchors
FROM (
  SELECT customer_unique_id
  FROM churn.v5_p0_anchor_customers
  GROUP BY 1
  HAVING COUNT(*) > 1
) x;

SELECT
  customer_unique_id,
  COUNT(*) AS n_anchors,
  MIN(anchor_date) AS first_anchor,
  MAX(anchor_date) AS last_anchor
FROM churn.v5_p0_anchor_customers
GROUP BY 1
HAVING COUNT(*) > 1
ORDER BY n_anchors DESC, last_anchor DESC
LIMIT 10;


SELECT
  COUNT(*) AS n_selected_rows,
  COUNT(DISTINCT customer_unique_id) AS n_selected_customers,
  SUM(offer_cost) AS total_cost,
  SUM(expected_value) AS total_expected_value,
  AVG(expected_value) AS avg_expected_value
FROM churn.budget_alloco;


SELECT
  offer_type,
  COUNT(*) AS n_customers,
  SUM(offer_cost) AS total_cost,
  SUM(expected_value) AS total_expected_value,
  AVG(expected_value) AS avg_expected_value
FROM churn.budget_alloco
GROUP BY 1
ORDER BY n_customers DESC;


SELECT
  offer_type,
  COUNT(*) AS n_rows,
  SUM(CASE WHEN expected_value > 0 THEN 1 ELSE 0 END) AS n_positive_ev,
  AVG(CASE WHEN expected_value > 0 THEN 1.0 ELSE 0.0 END) AS pct_positive_ev
FROM churn.v5_expected_value
GROUP BY 1
ORDER BY pct_positive_ev DESC;

SELECT *
FROM churn.v5_p0_anchor_customers
LIMIT 5;
