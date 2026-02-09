-- 5.C = “For each allowed customer, simulate every offer option.” (customer × offer rows with EV fields)

CREATE OR REPLACE VIEW churn.v6_phase5_c_offer_ev_spine AS
WITH eligible AS (
    SELECT
        customer_unique_id,
        anchor_date,
        risk_band
    FROM churn.v6_phase5b_eligibility
    WHERE eligibility_status = 'eligible_for_review'
),
offers AS (
    SELECT 'no_offer'            AS offer_type UNION ALL
    SELECT 'free_shipping'       UNION ALL
    SELECT 'discount_5_percent'  UNION ALL
    SELECT 'discount_10_percent'
),
expanded AS (
    SELECT
        e.customer_unique_id,
        e.anchor_date,
        e.risk_band,
        o.offer_type
    FROM eligible e
    CROSS JOIN offers o
)
SELECT
    ex.customer_unique_id,
    ex.anchor_date,
    ex.risk_band,
    ex.offer_type,

    ev.offer_cost,
    ev.lift_default,
    ev.p_offer_default,
    ev.delta_p_default,
    ev.expected_offer_cost,
    ev.net_ev_default

FROM expanded ex
LEFT JOIN churn.v6_offer_ev ev
  ON ex.customer_unique_id = ev.customer_unique_id
 AND ex.anchor_date = ev.anchor_date
 AND ex.offer_type = ev.offer_type;




