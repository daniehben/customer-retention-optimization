-- ============================================================
-- File: 04_p0_baseline.sql
-- Purpose: Estimate baseline repurchase probability (p0)
--          using customer-level anchor dates and a 60-day
--          post-anchor observation window, with freight-based
--          segmentation and fallback logic.
--
-- Depends on:
-- - churn.v2_order_spine           (from 02_order_level_aggregation.sql)
-- - churn.v2_freight_bucketed      (from 03_value_and_freight_features.sql)
--
-- Creates:
-- - churn.v5_p0_anchor_customers
-- - churn.v3_freight_customers
-- - churn.v5_p0_outcomes_60d
-- - churn.v4_p0_baseline_final
-- - churn.v5_p0_customer_baseline
-- ============================================================

CREATE OR REPLACE VIEW churn.v5_p0_anchor_customers AS
WITH delivered AS(
    SELECT
        customer_unique_id,
        order_delivered_customer_date::date AS delivered_date
    FROM churn.v2_order_spine
    WHERE order_delivered_customer_date IS NOT NULL
),
dataset_max AS(
    SELECT MAX(delivered_date) AS max_delivered_date
    FROM delivered
),
ranked_deliveries AS(
    SELECT
        customer_unique_id,
        delivered_date,
        ROW_NUMBER() OVER(
            PARTITION BY customer_unique_id 
            ORDER BY delivered_date DESC
            ) AS rn
    FROM delivered
),
eligible_anchors AS(
    SELECT
        r.customer_unique_id,
        r.delivered_date AS anchor_date

    FROM ranked_deliveries r
    CROSS JOIN dataset_max m
    WHERE r.rn = 2 
        AND r.delivered_date <= (m.max_delivered_date - INTERVAL '60 days')
),
customer_info AS (
    SELECT
        customer_unique_id,
        MAX(customer_type) AS customer_type,
        MAX(churn_flag) AS churn_flag
    FROM churn.v2_order_spine
    GROUP BY customer_unique_id
)
SELECT
    ea.customer_unique_id,
    ci.customer_type,
    ci.churn_flag,
    ea.anchor_date
FROM eligible_anchors ea
JOIN customer_info ci
    ON ea.customer_unique_id = ci.customer_unique_id
WHERE ci.customer_type = 'Repeat Customer';


CREATE OR REPLACE VIEW churn.v3_freight_customers AS
SELECT
    a.customer_unique_id,
    a.anchor_date,
    a.customer_type,
    a.churn_flag,

    AVG(o.order_freight) AS avg_freight,

    CASE
        WHEN AVG(o.order_freight) IS NULL THEN 'Unknown'
        WHEN AVG(o.order_freight) = 0 THEN 'Free'
        WHEN AVG(o.order_freight) <= 10 THEN '0-10'
        WHEN AVG(o.order_freight) <= 20 THEN '10-20'
        WHEN AVG(o.order_freight) <= 30 THEN '20-30'
        WHEN AVG(o.order_freight) <= 50 THEN '31-50'
        WHEN AVG(o.order_freight) <= 100 THEN '51-100'
        ELSE '100+'
    END AS avg_freight_bucket
FROM churn.v5_p0_anchor_customers a
LEFT JOIN churn.v2_order_spine o
    ON a.customer_unique_id = o.customer_unique_id
    AND o.order_delivered_customer_date IS NOT NULL
    AND o.order_delivered_customer_date::date <= a.anchor_date
GROUP BY a.customer_unique_id, a.anchor_date, a.customer_type, a.churn_flag;




CREATE OR REPLACE VIEW churn.v5_p0_outcomes_60d AS
SELECT 
    a.customer_unique_id,
    a.anchor_date,

    CASE WHEN COUNT(o.order_id) > 0 THEN 1 ELSE 0 END AS repurchased_60d,
    COUNT(o.order_id) AS orders_60d,
    COALESCE(SUM(o.order_value), 0)  AS revenue_60d,
    COALESCE(SUM(o.order_freight), 0) AS freight_60d,
    0.25 * COALESCE(SUM(o.order_value), 0) AS profit_60d,
    MIN(o.order_delivered_customer_date::date)- a.anchor_date AS days_to_next_order

FROM churn.v5_p0_anchor_customers a
LEFT JOIN churn.v2_order_spine o
    ON a.customer_unique_id = o.customer_unique_id
    AND o.order_delivered_customer_date IS NOT NULL
    AND o.order_delivered_customer_date::date > a.anchor_date
    AND o.order_delivered_customer_date::date <= a.anchor_date + INTERVAL '60 days'
GROUP BY a.customer_unique_id, a.anchor_date;

-- Final baseline p0 layer with fallback (depends on outcomes + freight buckets)

CREATE OR REPLACE VIEW churn.v4_p0_baseline_final AS
WITH joined AS(
    SELECT
        f.avg_freight_bucket,
        f.customer_type,
        o.repurchased_60d
    FROM churn.v3_freight_customers f
    JOIN churn.v5_p0_outcomes_60d o
        ON f.customer_unique_id = o.customer_unique_id
        AND f.anchor_date = o.anchor_date
    WHERE f.customer_type = 'Repeat Customer'
),
bucket_stats AS (
    SELECT
        avg_freight_bucket,
        COUNT(*) AS n_customers,
        AVG(repurchased_60d::numeric) AS bucket_p0_60d
    FROM joined
    GROUP BY 1
),
overall AS (
    SELECT
        AVG(repurchased_60d::numeric) AS overall_p0_60d
    FROM joined
)
SELECT
    b.*,
    o.overall_p0_60d,
    CASE
        WHEN b.n_customers >= 50 THEN b.bucket_p0_60d
        ELSE o.overall_p0_60d
    END AS p0_60d_final,
    CASE 
        WHEN b.n_customers >= 50 THEN 0
        ELSE 1
    END AS used_fallback
FROM bucket_stats b
CROSS JOIN overall o
ORDER BY b.avg_freight_bucket;

SELECT
  COUNT(*) AS n_rows,
  COUNT(DISTINCT p0_60d_final) AS n_distinct_p0,
  MIN(p0_60d_final) AS min_p0,
  MAX(p0_60d_final) AS max_p0
FROM churn.v4_p0_baseline_final;

-- Customer-level final baseline p0 with fallback
CREATE OR REPLACE VIEW churn.v5_p0_customer_baseline AS
SELECT
    a.customer_unique_id,
    a.anchor_date,
    f.avg_freight_bucket,
    b.p0_60d_final,
    b.used_fallback
FROM churn.v5_p0_anchor_customers a
JOIN churn.v3_freight_customers f
  ON a.customer_unique_id = f.customer_unique_id
  AND a.anchor_date = f.anchor_date
JOIN churn.v4_p0_baseline_final b
    ON f.avg_freight_bucket = b.avg_freight_bucket;


