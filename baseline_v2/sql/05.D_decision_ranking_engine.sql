CREATE OR REPLACE VIEW churn.v_6_phase5d_best_offer_per_customer AS
WITH spine AS (
  SELECT
    customer_unique_id,
    anchor_date,
    risk_segment,
    net_ev_default,
    delta_p_default,
    offer_type,
    offer_cost
  FROM churn.v_6_phase_5_c_offer_ev_spine 
),
ranked AS (
  SELECT
    customer_unique_id,
    anchor_date,
    risk_segment,
    offer_type,
    net_ev_default,
    offer_cost,

    MAX(COALESCE(net_ev_default, -1e18)) OVER (
      PARTITION BY customer_unique_id, anchor_date
    ) AS max_ev_over_anchor,

    ROW_NUMBER() OVER (
      PARTITION BY customer_unique_id, anchor_date
      ORDER BY
        COALESCE(net_ev_default, -1e18) DESC,
        COALESCE(offer_cost, 1e18) ASC,
        offer_type ASC
    ) AS rn_best_offer
  FROM spine
)
SELECT
  customer_unique_id,
  anchor_date,
  risk_segment,
  max_ev_over_anchor,
  CASE
    WHEN max_ev_over_anchor <= 0 THEN 'no_offer'
    ELSE offer_type
  END AS best_offer_type
FROM ranked
WHERE rn_best_offer = 1;





SELECT
  best_offer_type,
  COUNT(*) AS n,
  AVG(max_ev_over_anchor) AS avg_max_ev
FROM churn.v_6_phase5d_best_offer_per_customer
GROUP BY 1
ORDER BY n DESC;

SELECT
  offer_type,
  AVG(offer_cost) AS avg_offer_cost,
  AVG(0.25 * aov_pre_anchor) AS avg_margin_value
FROM churn.v_6_customer_offer_spine
WHERE offer_type IN ('discount_5_percent','discount_10_percent')
GROUP BY 1;


SELECT
  offer_type,
  COUNT(*) AS n,
  SUM((net_ev_default > 0)::int) AS n_positive,
  AVG(net_ev_default) AS avg_ev,
  MIN(net_ev_default) AS min_ev,
  MAX(net_ev_default) AS max_ev,
  AVG(offer_cost) AS avg_offer_cost,
  AVG(expected_margin_value) AS avg_margin_value
FROM churn.v_6_offer_ev
GROUP BY 1
ORDER BY 1;

SELECT
  best_offer_type,
  COUNT(*) AS n,
  AVG(max_ev_over_anchor) AS avg_ev,
  MIN(max_ev_over_anchor) AS min_ev,
  MAX(max_ev_over_anchor) AS max_ev
FROM churn.v_6_phase5d_best_offer_per_customer
GROUP BY 1
ORDER BY n DESC;
