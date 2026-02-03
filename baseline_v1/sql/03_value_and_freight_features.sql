-- ============================================================
-- File: 03_value_and_freight_features.sql
-- Purpose: Derive customer value and freight-related features
--          from the order spine for downstream modeling.
--
-- Depends on:
-- - churn.v2_order_spine   (from 02_order_level_aggregation.sql)
--
-- Creates:
-- - churn.v2_avg_order_value
-- - churn.v2_next_order_value
-- - churn.v2_avg_next_order_value
-- - churn.v2_freight_bucketed
-- ============================================================


-- REPLACE avg_order_value

CREATE OR REPLACE VIEW churn.v2_avg_order_value AS
SELECT 
    customer_type,
    AVG(order_value) AS avg_order_value
FROM churn.v2_order_spine
GROUP BY customer_type;


-- REDEFINE RETENTION VALUE

CREATE OR REPLACE VIEW churn.v2_next_order_value AS
SELECT
    customer_unique_id,
    customer_type,
    churn_flag,
    order_value AS next_order_value
FROM churn.v2_order_spine
WHERE order_sequence = 2;

CREATE OR REPLACE VIEW churn.v2_avg_next_order_value AS
SELECT
    customer_type,
    AVG(next_order_value) AS avg_next_order_value
FROM churn.v2_next_order_value
GROUP BY customer_type;

CREATE OR REPLACE VIEW churn.v2_freight_bucketed AS
SELECT
    customer_unique_id,
    customer_type,
    churn_flag,
    order_freight,
    CASE
        WHEN order_freight = 0 THEN 'Free'
        WHEN order_freight <= 10 THEN '0-10'
        WHEN order_freight <= 20 THEN '10-20'
        WHEN order_freight <= 30 THEN '20-30'
        WHEN order_freight <= 50 THEN '31-50'
        WHEN order_freight <= 100 THEN '51-100'
        ELSE '100+'
    END AS freight_bucket
FROM churn.v2_order_spine;