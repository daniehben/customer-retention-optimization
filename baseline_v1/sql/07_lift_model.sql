-- ============================================================
-- File: 07_lift_and_p1.sql
-- Purpose: Define assumed lift by offer type and freight bucket,
--          and compute post-offer repurchase probability (p1)
--          at the customer × offer level with probability bounds.
--
-- Depends on:
-- - churn.v3_freight_customers        (from 04_p0_baseline.sql)
-- - churn.v5_offer_costs              (from 06_offer_costs.sql)
-- - churn.v5_p0_customer_baseline     (from 04_p0_baseline.sql)
--
-- Creates:
-- - churn.v5_lift_assumptions
-- - churn.v5_customer_p1_by_offer
-- ============================================================


CREATE OR REPLACE VIEW churn.v5_lift_assumptions AS
WITH params AS (
    SELECT 
        0.03 AS discount_5_lift,
        0.05 AS discount_10_lift
), buckets AS (
    SELECT DISTINCT
        avg_freight_bucket
    FROM churn.v3_freight_customers
), offers AS(
    SELECT DISTINCT
        offer_type
    FROM churn.v5_offer_costs
)
    SELECT
  
    b.avg_freight_bucket,
    o.offer_type,

    CASE
        WHEN o.offer_type= 'no_offer' THEN 0.0
        WHEN o.offer_type = 'discount_5_percent' THEN p.discount_5_lift
        WHEN o.offer_type = 'discount_10_percent' THEN p.discount_10_lift
        WHEN o.offer_type = 'free_shipping' THEN 
            CASE
                WHEN b.avg_freight_bucket = 'Unknown' THEN 0.03
                WHEN b.avg_freight_bucket = 'Free' THEN 0.01
                WHEN b.avg_freight_bucket = '0-10' THEN 0.02
                WHEN b.avg_freight_bucket = '10-20' THEN 0.03
                WHEN b.avg_freight_bucket = '20-30' THEN 0.04
                WHEN b.avg_freight_bucket = '31-50' THEN 0.05
                WHEN b.avg_freight_bucket= '51-100' THEN 0.07
                WHEN b.avg_freight_bucket = '100+' THEN 0.08
                ELSE 0.0
            END
        ELSE 0.0
    END AS assumed_lift
FROM buckets b
CROSS JOIN offers o
CROSS JOIN params p;





CREATE OR REPLACE VIEW churn.v5_customer_p1_by_offer AS
WITH base AS (
SELECT 
    o.customer_unique_id,
    o.anchor_date,
    o.offer_type,
    o.avg_freight_bucket,
    pl.p0_60d_final,
    l.assumed_lift,
    pl.p0_60d_final + l.assumed_lift AS p1_raw
FROM churn.v5_offer_costs o
LEFT JOIN churn.v5_p0_customer_baseline pl 
    ON o.customer_unique_id = pl.customer_unique_id
    AND o.anchor_date = pl.anchor_date
LEFT JOIN churn.v5_lift_assumptions l
    ON o.avg_freight_bucket = l.avg_freight_bucket
    AND o.offer_type = l.offer_type
), clamp AS(
SELECT
    *,
    CASE
        WHEN p1_raw > 1.0 THEN 1.0
        WHEN p1_raw < 0.0 THEN 0.0
        ELSE p1_raw
    END AS p1_60d
FROM base
)
SELECT
    customer_unique_id,
    anchor_date,
    offer_type,
    avg_freight_bucket,
    p0_60d_final,
    assumed_lift,
    p1_60d,
    p1_60d - p0_60d_final AS delta_p
FROM clamp;
