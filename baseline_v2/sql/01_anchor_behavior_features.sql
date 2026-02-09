-- Create a new anchor table/view where repeat customers anchor on their 2nd delivered
CREATE OR REPLACE VIEW churn.v6_anchor_customers AS
WITH deliveries AS(
SELECT
    customer_unique_id,
    order_delivered_customer_date::date AS delivered_date,
    ROW_NUMBER() OVER(
        PARTITION BY customer_unique_id 
        ORDER BY order_delivered_customer_date::date ASC
    ) AS delivered_rank
FROM churn.v2_order_spine
WHERE order_delivered_customer_date IS NOT NULL
)
SELECT
    d.customer_unique_id,
    d.delivered_date AS anchor_date
FROM deliveries d
WHERE d.delivered_rank = 2;




CREATE OR REPLACE VIEW churn.v6_anchor_behavior_features AS
WITH features AS(
    SELECT
    a.customer_unique_id,
    a.anchor_date,
    COUNT(o.order_id) AS n_orders_pre_anchor,
    MIN(o.order_delivered_customer_date) AS first_order_date_pre_anchor,
    MAX(o.order_delivered_customer_date) AS last_order_date_pre_anchor,
    AVG(i.order_value) AS aov_pre_anchor,
    AVG(i.order_freight) AS avg_freight_pre_anchor
FROM churn.v6_anchor_customers a
LEFT JOIN churn.v2_order_spine o
    ON a.customer_unique_id = o.customer_unique_id
    AND o.order_delivered_customer_date IS NOT NULL
    AND o.order_delivered_customer_date::date < a.anchor_date
LEFT JOIN churn.v2_order_items i
    ON o.order_id = i.order_id
GROUP BY a.customer_unique_id, a.anchor_date
)
SELECT
    f.customer_unique_id,
    f.anchor_date,
    f.n_orders_pre_anchor,
    f.last_order_date_pre_anchor,
    f.first_order_date_pre_anchor,
    (f.anchor_date::date - f.last_order_date_pre_anchor) AS recency_days,
    (f.anchor_date::date - f.first_order_date_pre_anchor) AS tenure_days,
    f.aov_pre_anchor,
    f.avg_freight_pre_anchor,
    e.expected_order_value_at_anchor,
    fc.avg_freight_bucket

FROM features f
LEFT JOIN churn.v5_customer_value_at_anchor e
    ON f.customer_unique_id = e.customer_unique_id
    AND f.anchor_date = e.anchor_date
LEFT JOIN churn.v3_freight_customers fc
    ON f.customer_unique_id = fc.customer_unique_id
    AND f.anchor_date = fc.anchor_date;


-- ================================================================
-- SANITY CHECKS
-- ===============================================================

-- 1. Grain check
SELECT
  COUNT(*) AS n_rows,
  COUNT(DISTINCT customer_unique_id) AS n_customers
FROM churn.v6_anchor_behavior_features;

-- 2. Recency sanity
SELECT
  MIN(recency_days),
  MAX(recency_days),
  AVG(recency_days)
FROM churn.v6_anchor_behavior_features;

-- 3. Zero-history check
SELECT COUNT(*)
FROM churn.v6_anchor_behavior_features
WHERE n_orders_pre_anchor = 0;


SELECT
  n_orders_pre_anchor,
  COUNT(*) AS n_customers
FROM churn.v6_anchor_behavior_features
GROUP BY 1
ORDER BY 1;



SELECT
  COUNT(*) FILTER (WHERE n_delivered_orders = 2) AS customers_with_2_orders,
  COUNT(*) AS total_customers
FROM (
  SELECT
    customer_unique_id,
    COUNT(*) AS n_delivered_orders
  FROM churn.customer_order_summary
  GROUP BY 1
) t;


WITH delivered AS (
  SELECT
    a.customer_unique_id,
    a.anchor_date,
    o.order_delivered_customer_date::date AS delivered_date,
    ROW_NUMBER() OVER (
      PARTITION BY a.customer_unique_id
      ORDER BY o.order_delivered_customer_date
    ) AS delivered_rank
  FROM churn.v5_p0_anchor_customers a
  JOIN churn.v2_order_spine o
    ON o.customer_unique_id = a.customer_unique_id
   AND o.order_delivered_customer_date IS NOT NULL
),
first_second AS (
  SELECT
    customer_unique_id,
    anchor_date,
    MAX(CASE WHEN delivered_rank = 1 THEN delivered_date END) AS first_delivered_date,
    MAX(CASE WHEN delivered_rank = 2 THEN delivered_date END) AS second_delivered_date
  FROM delivered
  GROUP BY 1,2
)
SELECT
  COUNT(*) AS n_anchors,
  COUNT(*) FILTER (WHERE anchor_date::date = first_delivered_date) AS anchors_equal_first_delivery,
  COUNT(*) FILTER (WHERE anchor_date::date < second_delivered_date) AS anchors_before_second_delivery
FROM first_second;


WITH delivered AS (
  SELECT
    a.customer_unique_id,
    a.anchor_date,
    o.order_id,
    o.order_delivered_customer_date::date AS delivered_date,
    ROW_NUMBER() OVER (
      PARTITION BY a.customer_unique_id
      ORDER BY o.order_delivered_customer_date
    ) AS delivered_rank
  FROM churn.v5_p0_anchor_customers a
  JOIN churn.v2_order_spine o
    ON o.customer_unique_id = a.customer_unique_id
   AND o.order_delivered_customer_date IS NOT NULL
),
first_second AS (
  SELECT
    customer_unique_id,
    anchor_date,
    MAX(CASE WHEN delivered_rank = 1 THEN delivered_date END) AS first_delivered_date,
    MAX(CASE WHEN delivered_rank = 2 THEN delivered_date END) AS second_delivered_date
  FROM delivered
  GROUP BY 1,2
)
SELECT *
FROM first_second
WHERE anchor_date::date <= first_delivered_date
ORDER BY anchor_date
LIMIT 10;


-- count customers with multiple distinct anchors (use the right table)
WITH x AS (
  SELECT
    customer_unique_id,
    COUNT(DISTINCT anchor_date) AS n_anchors
  FROM churn.v5_p0_anchor_customers
  GROUP BY 1
)
-- top 10 examples
SELECT *
FROM x
WHERE n_anchors > 1
ORDER BY n_anchors DESC
LIMIT 10;


SELECT
  COUNT(*) AS n_rows,
  COUNT(DISTINCT customer_unique_id) AS n_customers
FROM churn.v6_anchor_customers;


WITH firsts AS (
  SELECT customer_unique_id, MIN(order_delivered_customer_date::date) AS first_delivered
  FROM churn.v2_order_spine
  WHERE order_delivered_customer_date IS NOT NULL
  GROUP BY 1
)
SELECT COUNT(*) AS anchors_equal_first
FROM churn.v6_anchor_customers a
JOIN firsts f USING (customer_unique_id)
WHERE a.anchor_date = f.first_delivered;


WITH ranked AS (
  SELECT
    customer_unique_id,
    order_delivered_customer_date::date AS delivered_date,
    ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY order_delivered_customer_date::date) AS rnk
  FROM churn.v2_order_spine
  WHERE order_delivered_customer_date IS NOT NULL
)
SELECT
  customer_unique_id,
  MAX(CASE WHEN rnk=1 THEN delivered_date END) AS first_delivered,
  MAX(CASE WHEN rnk=2 THEN delivered_date END) AS second_delivered
FROM ranked
WHERE rnk <= 2
GROUP BY 1
LIMIT 10;



SELECT COUNT(*) 
FROM churn.v6_anchor_customers a
LEFT JOIN (
  SELECT customer_unique_id, COUNT(*) AS n_delivered
  FROM churn.v2_order_spine
  WHERE order_delivered_customer_date IS NOT NULL
  GROUP BY 1
) x USING (customer_unique_id)
WHERE x.n_delivered < 2;

SELECT
  MIN(recency_days),
  MAX(recency_days),
  AVG(recency_days)
FROM churn.v6_anchor_behavior_features;




-- NOTE:
-- Some customers have multiple delivered orders on the same calendar date.
-- In those cases, first and second delivered dates are equal.
-- These are treated as valid repeat-customer anchors.
