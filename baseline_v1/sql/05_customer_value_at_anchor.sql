-- ============================================================
-- File: 05_customer_value_at_anchor.sql
-- Purpose: Estimate expected customer order value and profit
--          at the intervention anchor date using pre-anchor
--          behavior with a population-level fallback.
--
-- Depends on:
-- - churn.v5_p0_anchor_customers     (from 04_p0_baseline.sql)
-- - churn.v2_order_spine             (from 02_order_level_aggregation.sql)
-- - churn.v2_avg_next_order_value    (from 03_value_and_freight_features.sql)
--
-- Creates:
-- - churn.v5_customer_value_at_anchor
-- ============================================================

SET search_path TO churn



CREATE OR REPLACE VIEW churn.v5_customer_value_at_anchor AS
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