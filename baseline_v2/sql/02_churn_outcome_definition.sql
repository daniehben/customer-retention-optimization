-- ==========================================================
-- Purpose: Define churn as the absence of a delivered order within 60 days after the anchor date. The first post-anchor delivery is used to avoid multi-row ambiguity.
-- THe churn as no reorder was defined within 60 days because beyond that point the likelihood of spontaneous return drops sharply, and intervention value declines.
-- ==========================================================



CREATE OR REPLACE VIEW churn.v6_churn_outcomes AS
WITH post_anchor_delv AS (
SELECT
    a.customer_unique_id,
    a.anchor_date,
    o.order_delivered_customer_date::date AS delivered_date,
    ROW_NUMBER() OVER(
        PARTITION BY a.customer_unique_id, a.anchor_date
        ORDER BY o.order_delivered_customer_date::date ASC
    ) AS order_rank
FROM churn.v6_anchor_customers a
LEFT JOIN churn.v2_order_spine o
    ON a.customer_unique_id = o.customer_unique_id
    AND o.order_delivered_customer_date IS NOT NULL
    AND o.order_delivered_customer_date::date > a.anchor_date
),
next_order AS(
    SELECT
    customer_unique_id,
    anchor_date,
    (delivered_date - anchor_date) AS days_to_next_order
FROM post_anchor_delv
WHERE order_rank = 1
)
SELECT
    a.customer_unique_id,
    a.anchor_date,
    n.days_to_next_order,

    CASE
        WHEN n.days_to_next_order IS NOT NULL
        AND n.days_to_next_order <= 60 THEN 1
        ELSE 0
    END AS has_post_anchor_order_60d,

    CASE
        WHEN n.days_to_next_order IS NOT NULL
        AND n.days_to_next_order <= 60 THEN 0
        ELSE 1
    END AS churn_60d
FROM churn.v6_anchor_customers a
LEFT JOIN next_order n
    ON a.customer_unique_id = n.customer_unique_id
    AND a.anchor_date = n.anchor_date;


    -- SANITY CHECKS

SELECT
  COUNT(*) AS n_anchor_rows,
  COUNT(DISTINCT customer_unique_id) AS n_anchor_customers
FROM churn.v6_anchor_customers;


SELECT COUNT(*) AS customers_with_multiple_rows
FROM (
  SELECT customer_unique_id
  FROM churn.v6_churn_outcomes
  GROUP BY 1
  HAVING COUNT(*) > 1
) x;


SELECT
  AVG(churn_60d::float) AS churn_rate_60d,
  SUM(churn_60d) AS n_churned,
  COUNT(*) AS n_total
FROM churn.v6_churn_outcomes;



SELECT
  MIN(days_to_next_order) AS min_days,
  MAX(days_to_next_order) AS max_days,
  AVG(days_to_next_order::float) AS avg_days,
  SUM(CASE WHEN days_to_next_order < 0 THEN 1 ELSE 0 END) AS n_negative_days
FROM churn.v6_churn_outcomes;


SELECT *
FROM churn.v6_churn_outcomes
WHERE has_post_anchor_order_60d = 1
ORDER BY days_to_next_order
LIMIT 10;

SELECT *
FROM churn.v6_churn_outcomes
WHERE churn_60d = 1
ORDER BY days_to_next_order NULLS FIRST
LIMIT 10;
