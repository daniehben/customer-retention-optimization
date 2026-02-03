-- File 11_exports.sql

-- ====================================
-- Anchor / Customer Baseline Reality
-- ====================================

CREATE OR REPLACE VIEW churn.tableau_baseline_anchors AS
SELECT DISTINCT
    customer_unique_id,
    anchor_date,
    p0_60d_final
FROM churn.v5_expected_value;

CREATE OR REPLACE VIEW churn.tableau_avg_freight_baseline AS
SELECT
    avg_freight_bucket,
    n_customers,
    used_fallback,
    p0_60d_final
FROM churn.v4_p0_baseline_final
ORDER BY n_customers DESC;


-- ====================================
-- Offer Economics (Pre-Selection EV)
-- ====================================
CREATE OR REPLACE VIEW churn.tableau_offer_economics AS
SELECT
  customer_unique_id,
  anchor_date,
  offer_type,
  offer_cost            AS expected_cost,     -- X axis
  incremental_revenue   AS expected_gain,     -- Y axis
  expected_value        AS net_ev,            -- tooltip/filter
  p0_60d_final,
  p1_60d,
  delta_p,
  expected_order_value_safe
FROM churn.v5_expected_value
WHERE offer_type <> 'no_offer';



-- ============================================
-- Budget Allocation Result (Decision Output)
-- ============================================

CREATE OR REPLACE VIEW churn.tableau_budget_decisions AS
SELECT
    customer_unique_id,
    anchor_date,
    offer_type,
    expected_value,
    offer_cost,
    ev_per_cost,
    cumulative_cost,
    is_selected
FROM budget_alloco;


-- Budget allocation spine

CREATE OR REPLACE VIEW churn.tableau_budget_curve AS
SELECT
    customer_unique_id,
    anchor_date,
    offer_type,

    offer_cost,
    expected_value AS net_ev,
    ev_per_cost,

    cumulative_cost,
    SUM(expected_value) OVER (
        ORDER BY ev_per_cost DESC NULLS LAST,
                 expected_value DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_net_ev,

    is_selected
FROM budget_alloco
ORDER BY ev_per_cost DESC, expected_value DESC;

-- Full Landscape Budget Curve

CREATE OR REPLACE VIEW churn.tableau_budget_curve_landscape AS
WITH params AS (
    SELECT 10000.0::numeric AS total_budget
),
-- choose the BEST offer per customer even if EV is negative
best_offer AS (
    SELECT
        ev.customer_unique_id,
        ev.anchor_date,
        ev.offer_type,
        ev.offer_cost,
        ev.expected_value AS net_ev,
        ev.p0_60d_final,
        ev.p1_60d,
        ev.delta_p,
        ev.expected_order_value_safe,
        ROW_NUMBER() OVER (
            PARTITION BY ev.customer_unique_id, ev.anchor_date
            ORDER BY ev.expected_value DESC, ev.offer_cost ASC
        ) AS rn
    FROM churn.v5_expected_value ev
    WHERE ev.offer_type <> 'no_offer'
),
ranked AS (
    SELECT *
    FROM best_offer
    WHERE rn = 1
),
cum AS (
    SELECT
        r.*,

        -- decision order (net EV descending)
        ROW_NUMBER() OVER (
            ORDER BY r.net_ev DESC, r.offer_cost ASC
        ) AS decision_rank,

        SUM(r.offer_cost) OVER (
            ORDER BY r.net_ev DESC, r.offer_cost ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_cost,

        SUM(r.net_ev) OVER (
            ORDER BY r.net_ev DESC, r.offer_cost ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_net_ev
    FROM ranked r
)
SELECT
    c.*,
    p.total_budget,
    (c.cumulative_cost <= p.total_budget AND c.net_ev > 0) AS is_selected
FROM cum c
CROSS JOIN params p
ORDER BY decision_rank;



-- Offer mix under budget

CREATE OR REPLACE VIEW churn.tableau_offer_mix_by_bucket AS
SELECT
    b.offer_type,
    fb.avg_freight_bucket,
    COUNT(*) AS n_customers,
    SUM(b.expected_value) AS total_net_ev,
    SUM(b.offer_cost) AS total_cost
FROM budget_alloco b
JOIN churn.v3_freight_customers fb
  ON b.customer_unique_id = fb.customer_unique_id
 AND b.anchor_date = fb.anchor_date
WHERE b.is_selected = TRUE
GROUP BY b.offer_type, fb.avg_freight_bucket;




-- ====================================
-- Summary Metrics
-- ====================================

CREATE OR REPLACE VIEW churn.tableau_budget_summary AS
SELECT
    COUNT(*) FILTER (WHERE is_selected = true) AS n_selected,
    SUM(expected_value) FILTER (WHERE is_selected = true) AS total_ev,
    SUM(offer_cost) FILTER (WHERE is_selected = true) AS total_cost,
    CASE
        WHEN SUM(offer_cost) FILTER (WHERE is_selected = true) = 0 THEN NULL
        ELSE
            SUM(expected_value) FILTER (WHERE is_selected = true)
            / SUM(offer_cost) FILTER (WHERE is_selected = true)
    END AS roi
FROM budget_alloco;