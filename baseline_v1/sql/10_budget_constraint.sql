-- File 10_budget_constraint.sql

CREATE OR REPLACE VIEW budget_alloco AS
WITH params AS(
    SELECT
        10000.0::numeric AS total_budget
), candidates AS(
    SELECT
        ev.*,
        ev.expected_value / NULLIF(ev.offer_cost, 0) AS ev_per_cost
    FROM churn.v5_expected_value ev
    WHERE ev.expected_value > 0
        AND ev.offer_type <> 'no_offer'
    

),best_per_customer AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id, anchor_date 
            ORDER BY expected_value DESC) AS rn
    FROM candidates

), ranked AS (
    SELECT
        *
    FROM best_per_customer
    WHERE rn = 1
), cumilative AS (
    SELECT
        r.*,
        SUM(r.offer_cost) OVER (
            ORDER BY r.ev_per_cost DESC NULLS LAST,
            r.expected_value DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS cumulative_cost
    FROM ranked r
)
SELECT
    c.customer_unique_id,
    c.anchor_date,
    c.offer_type,
    c.expected_value,
    c.ev_per_cost,
    c.offer_cost,
    c.cumulative_cost,

    (c.cumulative_cost <= p.total_budget) AS is_selected
FROM cumilative c
CROSS JOIN params p;
