-- FILE 09_expected_value.sql

CREATE OR REPLACE VIEW churn.v5_expected_value AS
WITH base AS(
    SELECT 
        o.customer_unique_id,
        o.anchor_date,
        o.offer_type,
        c.p0_60d_final,
        c.p1_60d,
        c.delta_p,
        o.expected_order_value_safe,
        o.offer_cost
    FROM churn.v5_offer_costs o
    LEFT JOIN churn.v5_customer_p1_by_offer c
        ON o.customer_unique_id = c.customer_unique_id
        AND o.anchor_date = c.anchor_date
        AND o.offer_type = c.offer_type
), calc AS(
    SELECT
        *,
        (delta_p * expected_order_value_safe) AS incremental_revenue
    FROM base
)
SELECT
    customer_unique_id,
    anchor_date,
    offer_type,
    p0_60d_final,
    p1_60d,
    delta_p,
    expected_order_value_safe,
    offer_cost,
    incremental_revenue,
    (incremental_revenue - offer_cost) AS expected_value,
    (incremental_revenue - offer_cost) > 0 AS is_positive_ev
FROM calc;