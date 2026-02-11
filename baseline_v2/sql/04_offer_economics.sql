CREATE OR REPLACE VIEW churn.v_6_customer_offer_spine AS
WITH spine AS (
  SELECT
    customer_unique_id,
    anchor_date,
    risk_segment,
    aov_pre_anchor,
    avg_freight_pre_anchor
  FROM churn.v_6_baseline_risk_segment
)
SELECT
  customer_unique_id,
  anchor_date,
  aov_pre_anchor,
  avg_freight_pre_anchor,
  risk_segment,
  'no_offer'::text AS offer_type,
  0.0::double precision AS offer_cost
FROM spine

UNION ALL

SELECT
  customer_unique_id,
  anchor_date,
  aov_pre_anchor,
  avg_freight_pre_anchor,
  risk_segment,
  'free_shipping'::text AS offer_type,
  COALESCE(avg_freight_pre_anchor, 0.0)::double precision AS offer_cost
FROM spine

UNION ALL

SELECT
  customer_unique_id,
  anchor_date,
  aov_pre_anchor,
  avg_freight_pre_anchor,
  risk_segment,
  'discount_5_percent'::text AS offer_type,
  (0.05 * COALESCE(aov_pre_anchor, 0.0))::double precision AS offer_cost
FROM spine

UNION ALL

SELECT
  customer_unique_id,
  anchor_date,
  aov_pre_anchor,
  avg_freight_pre_anchor,
  risk_segment,
  'discount_10_percent'::text AS offer_type,
  (0.10 * COALESCE(aov_pre_anchor, 0.0))::double precision AS offer_cost
FROM spine;



-- =====================================================



CREATE OR REPLACE VIEW churn.v_6_p_base_by_risk_segment AS
WITH dataset_end AS(
  SELECT 
    MAX(order_delivered_customer_date::date) AS max_delivered_date
    FROM churn.v2_order_spine
    WHERE order_delivered_customer_date IS NOT NULL
),
base AS(
  SELECT
    r.*,
    (d.max_delivered_date - r.anchor_date) AS days_of_followup
  FROM churn.v_6_baseline_risk_segment r
  CROSS JOIN dataset_end d
)
SELECT
  risk_segment,
  COUNT(*) AS n_anchors,
  -- Eligibility counts (how many anchors have enough runway)
  SUM((days_of_followup >= 90)::int) AS n_eligible_90d,
  SUM((days_of_followup >= 120)::int) AS n_eligible_120d,
  SUM((days_of_followup >= 180)::int) AS n_eligible_180d,
  SUM((days_of_followup >= 365)::int) AS n_eligible_365d,
  -- Reorder probabilities *among eligible anchors only*
  AVG(
    CASE 
      WHEN days_of_followup >= 90
      THEN (days_to_next_order IS NOT NULL AND days_to_next_order <= 90)::int
      END
  ) AS p_reorder_90d,
  AVG(
    CASE 
      WHEN days_of_followup >= 120
      THEN (days_to_next_order IS NOT NULL AND days_to_next_order <= 120)::int
      END
  ) AS p_reorder_120d,
  AVG(
    CASE 
      WHEN days_of_followup >= 180
      THEN (days_to_next_order IS NOT NULL AND days_to_next_order <= 180)::int
      END
  ) AS p_reorder_180d,
  AVG(
    CASE 
      WHEN days_of_followup >= 365
      THEN (days_to_next_order IS NOT NULL AND days_to_next_order <= 365)::int
      END
  ) AS p_reorder_365d,
  SUM(
  CASE WHEN days_of_followup >= 180 THEN 1 ELSE 0 END
) AS denom_180d,
  -- ✅ sanity summaries (won’t affect group by)
  MIN(days_of_followup) AS min_followup_days,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_of_followup) AS median_followup_days,
  -- ✅ “slow-cycle” check: what does next-order timing look like among eligible?
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CASE WHEN days_of_followup >= 180 THEN days_to_next_order END) AS median_next_order_180_eligible,
  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY CASE WHEN days_of_followup >= 180 THEN days_to_next_order END) AS p75_next_order_180_eligible

FROM base
GROUP BY 1
ORDER BY 1;




-- =====================================================



CREATE OR REPLACE VIEW churn.v_6_4_offer_spine AS
SELECT
  s.customer_unique_id,
  s.anchor_date,
  s.risk_segment,
  s.offer_type,
  s.aov_pre_anchor,
  s.avg_freight_pre_anchor,
  s.offer_cost,

  p.p_reorder_90d,
  p.p_reorder_120d,
  p.p_reorder_180d,
  p.p_reorder_365d,

  p.p_reorder_180d AS p_base_default,

  0.25::double precision AS margin_rate,
  (0.25::double precision * COALESCE(s.aov_pre_anchor, 0.0)) AS expected_margin_value
FROM churn.v_6_customer_offer_spine s
LEFT JOIN churn.v_6_p_base_by_risk_segment p
  ON s.risk_segment = p.risk_segment;


-- =====================================================

CREATE OR REPLACE VIEW churn.v_6_lift_assumption AS
WITH base AS (
  SELECT
    risk_segment,
    split_part(risk_segment, ' | ', 1) AS recency_band,
    p_reorder_90d,
    p_reorder_120d,
    p_reorder_180d,
    p_reorder_365d
  FROM churn.v_6_p_base_by_risk_segment
),
lift_matrix AS (
  SELECT *
  FROM (VALUES
    -- recency_band, offer_type, lift_pct_of_p_base
    ('Active (≤p25)',      'no_offer',            0.00),
    ('Active (≤p25)',      'discount_5_percent',  0.05),
    ('Active (≤p25)',      'free_shipping',       0.07),
    ('Active (≤p25)',      'discount_10_percent', 0.10),

    ('Warm (p25–p50)',     'no_offer',            0.00),
    ('Warm (p25–p50)',     'discount_5_percent',  0.10),
    ('Warm (p25–p50)',     'free_shipping',       0.15),
    ('Warm (p25–p50)',     'discount_10_percent', 0.18),

    ('Cold (p50–p75)',     'no_offer',            0.00),
    ('Cold (p50–p75)',     'discount_5_percent',  0.15),
    ('Cold (p50–p75)',     'free_shipping',       0.22),
    ('Cold (p50–p75)',     'discount_10_percent', 0.25),

    ('Dormant (≥p75)',     'no_offer',            0.00),
    ('Dormant (≥p75)',     'discount_5_percent',  0.20),
    ('Dormant (≥p75)',     'free_shipping',       0.30),
    ('Dormant (≥p75)',     'discount_10_percent', 0.35)
  ) AS t(recency_band, offer_type, lift_pct)
)
SELECT
  b.risk_segment,
  m.offer_type,
  m.lift_pct,
  b.p_reorder_90d,
  b.p_reorder_120d,
  b.p_reorder_180d,
  b.p_reorder_365d,
  (b.p_reorder_90d  * m.lift_pct)::double precision  AS lift_90d,
  (b.p_reorder_120d * m.lift_pct)::double precision  AS lift_120d,
  (b.p_reorder_180d * m.lift_pct)::double precision  AS lift_180d,
  (b.p_reorder_365d * m.lift_pct)::double precision  AS lift_365d,
  (b.p_reorder_180d * m.lift_pct)::double precision  AS lift_default
FROM base b
JOIN lift_matrix m
  ON b.recency_band = m.recency_band;


-- =====================================================



CREATE OR REPLACE VIEW churn.v_6_offer_ev AS
SELECT
    s.customer_unique_id,
    s.anchor_date,
    s.risk_segment,
    s.offer_type,

    s.p_base_default,
    l.lift_default,

    LEAST(1.0::double precision, s.p_base_default + COALESCE(l.lift_default,0.0)) AS p_offer_default,
    (LEAST(1.0::double precision, s.p_base_default + COALESCE(l.lift_default,0.0)) - s.p_base_default) AS delta_p_default,

    s.expected_margin_value,

    ((LEAST(1.0::double precision, s.p_base_default + COALESCE(l.lift_default,0.0)) - s.p_base_default)
      * s.expected_margin_value) AS incremental_profit,

    s.offer_cost,

    (LEAST(1.0::double precision, s.p_base_default + COALESCE(l.lift_default, 0.0)) * s.offer_cost) AS expected_offer_cost,

    (
      ((LEAST(1.0::double precision, s.p_base_default + COALESCE(l.lift_default, 0.0)) - s.p_base_default)
        * s.expected_margin_value)
      - (LEAST(1.0::double precision, s.p_base_default + COALESCE(l.lift_default, 0.0)) * s.offer_cost)
    ) AS net_ev_default

FROM churn.v_6_4_offer_spine s
LEFT JOIN churn.v_6_lift_assumption l
  ON s.risk_segment = l.risk_segment
 AND s.offer_type   = l.offer_type;



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
