-- FILE 08_materialization_and_indexes.sql
-- ================
-- P0 ANCHOR CUSTOMERS
-- =================

DROP VIEW IF EXISTS churn.v5_p0_anchor_customers CASCADE;

CREATE MATERIALIZED VIEW churn.v5_p0_anchor_customers AS
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

CREATE INDEX idx_p0_anchor_customer
ON churn.v5_p0_anchor_customers (customer_unique_id, anchor_date);


-- ================
-- FREIGHT CUSTOMERS
-- =================

DROP VIEW IF EXISTS churn.v3_freight_customers CASCADE;

CREATE MATERIALIZED VIEW churn.v3_freight_customers AS
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


CREATE INDEX idx_freight_customer_anchor
ON churn.v3_freight_customers (customer_unique_id, anchor_date);

CREATE INDEX idx_freight_bucket
ON churn.v3_freight_customers (avg_freight_bucket);

-- =========================
-- CUSTOMER VALUE AT ANCHOR
-- =========================

DROP VIEW IF EXISTS churn.v5_customer_value_at_anchor CASCADE;

CREATE MATERIALIZED VIEW churn.v5_customer_value_at_anchor AS
WITH calcs AS (
SELECT
    cb.customer_unique_id,
    cb.anchor_date,
    cb.customer_type,
    AVG(o.order_value) AS avg_order_value_pre_anchor,
    COUNT(o.order_id) AS n_orders_pre_anchor,
    ano.avg_next_order_value
FROM churn.v5_p0_anchor_customers cb
LEFT JOIN churn.v2_order_spine o
    ON cb.customer_unique_id = o.customer_unique_id
    AND o.order_delivered_customer_date::date <= cb.anchor_date
    AND o.order_delivered_customer_date IS NOT NULL
LEFT JOIN churn.v2_avg_next_order_value ano
    ON cb.customer_type = ano.customer_type
GROUP BY cb.customer_unique_id, cb.anchor_date, cb.customer_type, ano.avg_next_order_value
)
SELECT 
    customer_unique_id,
    anchor_date,
    customer_type,
    n_orders_pre_anchor,
    avg_order_value_pre_anchor,
    avg_next_order_value,
    CASE 
        WHEN n_orders_pre_anchor >= 2 AND avg_order_value_pre_anchor IS NOT NULL THEN avg_order_value_pre_anchor
        ELSE avg_next_order_value
    END AS expected_order_value_at_anchor,
    CASE 
        WHEN n_orders_pre_anchor >= 2 AND avg_order_value_pre_anchor IS NOT NULL THEN 0
        ELSE 1
    END AS used_value_fallback,
    CASE
        WHEN n_orders_pre_anchor >=2 AND avg_order_value_pre_anchor IS NOT NULL THEN 0.25 * avg_order_value_pre_anchor
        ELSE 0.25 * avg_next_order_value
    END AS expected_profit_at_anchor

FROM calcs;

CREATE INDEX idx_value_customer_anchor
ON churn.v5_customer_value_at_anchor (customer_unique_id, anchor_date);


-- =========================
-- OFFER COSTS
-- =========================

DROP VIEW IF EXISTS churn.v5_offer_costs CASCADE;


CREATE MATERIALIZED VIEW churn.v5_offer_costs AS
WITH base AS(
    SELECT
        a.customer_unique_id,
        a.anchor_date,
        a.customer_type,
        COALESCE(v.expected_order_value_at_anchor, 0) AS expected_order_value_safe ,
        COALESCE(fb.avg_freight, 0) AS avg_freight_safe ,
        fb.avg_freight_bucket
    FROM churn.v5_p0_anchor_customers a
    LEFT JOIN churn.v5_customer_value_at_anchor v
        ON a.customer_unique_id = v.customer_unique_id
        AND a.anchor_date = v.anchor_date
    LEFT JOIN churn.v3_freight_customers fb
        ON a.customer_unique_id = fb.customer_unique_id
        AND a.anchor_date = fb.anchor_date
)
SELECT 
    customer_unique_id,
    anchor_date,
    customer_type,
    expected_order_value_safe,
    avg_freight_safe,
    'no_offer' AS offer_type, 0.0::double precision AS offer_cost,
    avg_freight_bucket
FROM base
UNION ALL
SELECT 
    customer_unique_id,
    anchor_date,
    customer_type,
    expected_order_value_safe,
    avg_freight_safe,
    'free_shipping' AS offer_type,
    avg_freight_safe AS offer_cost,
    avg_freight_bucket
FROM base
UNION ALL
SELECT 
    customer_unique_id,
    anchor_date,
    customer_type,
    expected_order_value_safe,
    avg_freight_safe,
    'discount_5_percent' AS offer_type,
    0.05 * expected_order_value_safe AS offer_cost,
    avg_freight_bucket
FROM base
UNION ALL
SELECT 
    customer_unique_id,
    anchor_date,
    customer_type,
    expected_order_value_safe,
    avg_freight_safe,
    'discount_10_percent' AS offer_type,
    0.10 * expected_order_value_safe  AS offer_cost,
    avg_freight_bucket
FROM base;


CREATE INDEX idx_offer_customer_anchor
ON churn.v5_offer_costs (customer_unique_id, anchor_date);

CREATE INDEX idx_offer_bucket_type
ON churn.v5_offer_costs (avg_freight_bucket, offer_type);
