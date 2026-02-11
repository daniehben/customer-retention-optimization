-- 5.C = “For each allowed customer, simulate every offer option.” (customer × offer rows with EV fields)

CREATE OR REPLACE VIEW churn.v_6_phase_5_c_offer_ev_spine AS
WITH eligible AS (
    SELECT
        customer_unique_id,
        anchor_date,
        risk_segment
    FROM churn.v_6_phase5_b_eligibility
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
        e.risk_segment,
        o.offer_type
    FROM eligible e
    CROSS JOIN offers o
)
SELECT
    ex.customer_unique_id,
    ex.anchor_date,
    ex.risk_segment,
    ex.offer_type,

    ev.offer_cost,
    ev.lift_default,
    ev.p_offer_default,
    ev.delta_p_default,
    ev.expected_offer_cost,
    ev.p_base_default,
    ev.net_ev_default,
    CASE WHEN ev.customer_unique_id IS NULL THEN 1 ELSE 0 END AS is_missing_ev_row


FROM expanded ex
LEFT JOIN churn.v_6_offer_ev ev
  ON ex.customer_unique_id = ev.customer_unique_id
 AND ex.anchor_date = ev.anchor_date
 AND ex.risk_segment = ev.risk_segment
 AND ex.offer_type = ev.offer_type;






 SELECT
  COUNT(*) AS rows,
  COUNT(DISTINCT (customer_unique_id, anchor_date)) AS anchors,
  COUNT(*)::numeric / NULLIF(COUNT(DISTINCT (customer_unique_id, anchor_date)),0) AS offers_per_anchor
FROM churn.v_6_phase_5_c_offer_ev_spine;

SELECT
  offer_type,
  COUNT(*) AS n,
  SUM((net_ev_default IS NULL)::int) AS n_null_ev
FROM churn.v_6_phase_5_c_offer_ev_spine
GROUP BY 1
ORDER BY 1;


SELECT
  COUNT(*) AS rows,
  COUNT(DISTINCT (customer_unique_id, anchor_date, risk_segment, offer_type)) AS distinct_rows
FROM churn.v_6_offer_ev;
