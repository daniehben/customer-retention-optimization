-- ============================================================
-- File: 01_base_tables.sql
-- Purpose: Build foundational order- and customer-level views:
--          delivered orders, customer order summaries,
--          temporal customer facts, recency segmentation,
--          and descriptive churn labels.
--
-- Depends on:
-- - churn.orders     (raw orders table)
-- - churn.customers  (raw customers table)
-- - churn.order_items (raw order items table)   -- if used in summary
--
-- Creates:
-- - churn.delivered_orders
-- - churn.customer_order_summary
-- - churn.customer_fact_data
-- - churn.customer_recency_buckets
-- - churn.customer_churn_labels
-- ============================================================


-- =============================
-- DELIVERED ORDERS ONLY
-- =============================

CREATE OR REPLACE VIEW churn.delivered_orders AS
SELECT *
FROM orders
WHERE order_status = 'delivered';

-- =============================
-- pre-aggregated customer summary
-- =============================

CREATE VIEW churn.customer_order_summary AS 
        SELECT c.customer_unique_id, COUNT(DISTINCT d.order_id) AS num_orders,
            MIN(d.order_delivered_customer_date) AS first_order_date,
            MAX(d.order_delivered_customer_date) AS last_order_date,
            COUNT(DISTINCT DATE_TRUNC('month', d.order_delivered_customer_date)) AS active_months
        FROM churn.delivered_orders AS d
        INNER JOIN churn.customers AS c
        USING (customer_id)
        GROUP BY c.customer_unique_id;

-- =============================
-- CUSTOMER FACTS
-- =============================
CREATE OR REPLACE VIEW churn.customer_fact_data AS 
    WITH 
        date_anchor AS (SELECT MAX(order_delivered_customer_date)  AS today
                        FROM churn.delivered_orders
    )
    SELECT 
        c.customer_unique_id,
        c.num_orders,
        c.first_order_date,
        c.last_order_date,
        
        (date_anchor.today - c.last_order_date) AS recency_days
    FROM churn.customer_order_summary c
    CROSS JOIN date_anchor
    WHERE c.last_order_date IS NOT NULL;

-- =============================
-- Exploratory Recency Distribution
-- =============================

CREATE OR REPLACE VIEW churn.customer_recency_buckets AS
    SELECT 
        customer_unique_id,
        num_orders,
        recency_days,
        CASE 
            WHEN recency_days BETWEEN 0 AND 30 THEN '0-30 days'
            WHEN recency_days BETWEEN 31 AND 60 THEN '31-60 days'
            WHEN recency_days BETWEEN 61 AND 90 THEN '61-90 days'
            WHEN recency_days BETWEEN 91 AND 120 THEN '91-120 days'
            ELSE '120+ days'
        END AS recency_bucket
    FROM churn.customer_fact_data;

-- =============================
-- Churn Labeling View
-- =============================

CREATE OR REPLACE VIEW churn.customer_churn_labels AS 
    SELECT 
        customer_unique_id,
        num_orders,
        recency_days,
        CASE 
            WHEN recency_days > 120 THEN 1 
            ELSE 0 
        END AS churn_flag,
        CASE 
            WHEN num_orders = 1 THEN 'One-time Buyer'
            ELSE 'Repeat Customer' 
        END AS customer_type
    FROM churn.customer_fact_data;


