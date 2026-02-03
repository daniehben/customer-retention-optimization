-- ============================================================
-- File: 06_offer_costs.sql
-- Purpose: Generate customer × offer option rows and compute
--          offer costs (no_offer, free_shipping, 5% discount,
--          10% discount) using value-at-anchor and freight history.
--
-- Depends on:
-- - churn.v5_p0_anchor_customers        (from 04_p0_baseline.sql)
-- - churn.v5_customer_value_at_anchor   (from 05_customer_value_at_anchor.sql)
-- - churn.v3_freight_customers          (from 04_p0_baseline.sql)
--
-- Creates:
-- - churn.v5_offer_costs
-- ============================================================


CREATE OR REPLACE VIEW churn.v5_offer_costs AS
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


