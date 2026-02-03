-- ============================================================
-- File: 02_order_level_aggregation.sql
-- Purpose: Aggregate order items to order-level monetary values
--          and construct the corrected customer order spine.
--
-- Depends on:
-- - churn.order_items            (raw order items table)
-- - churn.delivered_orders       (from 01_base_tables.sql)
-- - churn.customers              (raw customers table)
-- - churn.customer_churn_labels  (from 01_base_tables.sql)
--
-- Creates:
-- - churn.v2_order_items
-- - churn.v2_order_spine
-- ============================================================


-- BUILD ORDER-LEVEL ITEMS AGGREGATION

CREATE OR REPLACE VIEW churn.v2_order_items AS
SELECT
    order_id,
    SUM(price) AS order_value,
    SUM(freight_value) AS order_freight
FROM churn.order_items
GROUP BY order_id;

-- CREATE THE CORRECTED ORDER-LEVEL SPINE 

CREATE OR REPLACE VIEW churn.v2_order_spine AS
SELECT 
    o.order_id,
    o.order_delivered_customer_date,
    a.order_value,
    a.order_freight,
    c.customer_unique_id,
    l.churn_flag,
    l.customer_type,
    ROW_NUMBER() OVER (
        PARTITION BY c.customer_unique_id 
        ORDER BY o.order_delivered_customer_date,o.order_id
        ) AS order_sequence
FROM churn.delivered_orders o
JOIN churn.customers c
    ON o.customer_id = c.customer_id
JOIN churn.customer_churn_labels l
    ON c.customer_unique_id = l.customer_unique_id
JOIN churn.v2_order_items a
    ON o.order_id = a.order_id;
